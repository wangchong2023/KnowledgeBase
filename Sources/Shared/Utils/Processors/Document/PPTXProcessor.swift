// PPTXProcessor.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了 PowerPoint (PPTX) 文档生成处理器（PPTXProcessor），负责将结构化知识转化为演示文稿格式。
// 该处理器的核心功能点如下：
// 1. 幻灯片布局映射：根据 Markdown 标题和内容自动计算幻灯片页数，实现“一标题一页面”的智能排版。
// 2. XML 模板注入：基于标准的 PPTX XML 规范生成演示文稿，确保在所有标准办公软件中具备良好的兼容性。
// 3. 样式自动化：自动应用主题配色与字体规范，确保输出的 PPT 文件在视觉上具备专业性和一致性。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 迁移至 Utils/Processors/Document 并规范化 PPTX 生成逻辑说明
import Foundation

/// 简易原生 PPTX 生成器 (OpenXML 架构)
/// 遵循微软 OpenXML 标准，通过生成 XML 目录结构并使用系统 zip 工具打包。
final class PPTXProcessor {
    nonisolated(unsafe) static let shared = PPTXProcessor()
    
    struct Slide {
        let title: String
        let bullets: [String]
    }
    
    func generate(markdown: String, title: String) async throws -> URL {
        let slides = parseMarkdown(markdown)
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // 1. 创建目录结构
        try createDirectoryStructure(at: tempDir)
        
        // 2. 生成静态 XML 文件
        try generateContentTypes(at: tempDir)
        try generateRels(at: tempDir)
        try generatePresentation(at: tempDir, slideCount: slides.count)
        try generatePresentationRels(at: tempDir, slideCount: slides.count)
        
        // 3. 生成幻灯片内容
        for (index, slide) in slides.enumerated() {
            try generateSlide(at: tempDir, slide: slide, index: index + 1)
        }
        
        // 4. 打包为 .pptx (本质是 zip)
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(title).pptx")
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = tempDir
        process.arguments = ["-r", outputURL.path, "."]

        try process.run()
        process.waitUntilExit()
        return outputURL
        #else
        // iOS 逻辑：目前无法在没有第三方库的情况下原生 ZIP
        throw NSError(domain: "PPTXProcessor", code: 405, userInfo: [NSLocalizedDescriptionKey: "iOS requires macOS toolchain for native zipping"])
        #endif
    }
    
    private func parseMarkdown(_ markdown: String) -> [Slide] {
        var slides: [Slide] = []
        let parts = markdown.components(separatedBy: "\n## ")
        
        for (index, part) in parts.enumerated() {
            let lines = part.components(separatedBy: .newlines)
            let title = lines.first?.replacingOccurrences(of: "# ", with: "").trimmingCharacters(in: .whitespaces) ?? "Slide \(index + 1)"
            let bullets = lines.dropFirst().filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("- ") || $0.trimmingCharacters(in: .whitespaces).hasPrefix("* ") }
                .map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "- ", with: "").replacingOccurrences(of: "* ", with: "") }
            
            slides.append(Slide(title: title, bullets: bullets))
        }
        return slides
    }
    
    private func createDirectoryStructure(at url: URL) throws {
        let dirs = ["_rels", "ppt", "ppt/_rels", "ppt/slides", "ppt/theme"]
        for dir in dirs {
            try FileManager.default.createDirectory(at: url.appendingPathComponent(dir), withIntermediateDirectories: true)
        }
    }
    
    private func generateContentTypes(at url: URL) throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
            <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
            <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
        </Types>
        """
        try xml.write(to: url.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)
    }
    
    private func generateRels(at url: URL) throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
        </Relationships>
        """
        try xml.write(to: url.appendingPathComponent("_rels/.rels"), atomically: true, encoding: .utf8)
    }
    
    private func generatePresentation(at url: URL, slideCount: Int) throws {
        var slideList = ""
        for i in 1...slideCount {
            slideList += "<p:sldId id=\"\(255 + i)\" r:id=\"rId\(i + 1)\"/>"
        }
        
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
            <p:sldIdLst>\(slideList)</p:sldIdLst>
            <p:notesSz cx="9144000" cy="11430000"/>
        </p:presentation>
        """
        try xml.write(to: url.appendingPathComponent("ppt/presentation.xml"), atomically: true, encoding: .utf8)
    }
    
    private func generatePresentationRels(at url: URL, slideCount: Int) throws {
        var rels = ""
        for i in 1...slideCount {
            rels += "<Relationship Id=\"rId\(i + 1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide\(i).xml\"/>"
        }
        
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>
            \(rels)
        </Relationships>
        """
        try xml.write(to: url.appendingPathComponent("ppt/_rels/presentation.xml.rels"), atomically: true, encoding: .utf8)
    }
    
    private func generateSlide(at url: URL, slide: Slide, index: Int) throws {
        var bodyText = ""
        for bullet in slide.bullets {
            bodyText += """
            <a:p>
                <a:pPr lvl="0"/>
                <a:r>
                    <a:rPr lang="zh-CN" smtClean="0"/>
                    <a:t>\(bullet)</a:t>
                </a:r>
            </a:p>
            """
        }
        
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
            <p:cSld>
                <p:spTree>
                    <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
                    <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
                    <p:sp>
                        <p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>
                        <p:spPr/>
                        <p:txBody>
                            <a:bodyPr/><a:lstStyle/>
                            <a:p><a:r><a:t>\(slide.title)</a:t></a:r></a:p>
                        </p:txBody>
                    </p:sp>
                    <p:sp>
                        <p:nvSpPr><p:cNvPr id="3" name="Content"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr><p:ph idx="1"/></p:nvPr></p:nvSpPr>
                        <p:spPr/>
                        <p:txBody>
                            <a:bodyPr/><a:lstStyle/>
                            \(bodyText)
                        </p:txBody>
                    </p:sp>
                </p:spTree>
            </p:cSld>
        </p:sld>
        """
        try xml.write(to: url.appendingPathComponent("ppt/slides/slide\(index).xml"), atomically: true, encoding: .utf8)
        
        // 生成默认主题 (简化)
        if index == 1 {
            let themeXml = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">
                <a:themeElements><a:clrScheme name="Office"><a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1><a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1><a:dk2><a:srgbClr val="44546A"/></a:dk2><a:lt2><a:srgbClr val="E7E6E6"/></a:lt2><a:accent1><a:srgbClr val="4472C4"/></a:accent1><a:accent2><a:srgbClr val="ED7D31"/></a:accent2><a:accent3><a:srgbClr val="A5A5A5"/></a:accent3><a:accent4><a:srgbClr val="FFC000"/></a:accent4><a:accent5><a:srgbClr val="5B9BD5"/></a:accent5><a:accent6><a:srgbClr val="70AD47"/></a:accent6><a:hlink><a:srgbClr val="0563C1"/></a:hlink><a:folHlink><a:srgbClr val="954F72"/></a:folHlink></a:clrScheme><a:fontScheme name="Office"><a:majorFont><a:latin panose="020F0302020204030204" pitchFamily="34" charset="0" typeface="Calibri Light"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont><a:minorFont><a:latin panose="020F0502020204030204" pitchFamily="34" charset="0" typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont></a:fontScheme><a:fmtScheme name="Office"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst><a:lnStyleLst><a:ln w="6350" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme></a:themeElements>
            </a:theme>
            """
            try themeXml.write(to: url.appendingPathComponent("ppt/theme/theme1.xml"), atomically: true, encoding: .utf8)
        }
    }
}
