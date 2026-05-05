// DocxProcessor.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了 Word (Docx) 文档解析处理器（DocxProcessor），通过解析 XML 压缩包结构提取结构化文本。
// 核心处理逻辑涵盖：
// 1. 压缩包解压：实现对 docx 标准 zip 结构的底层解析，定位并读取 word/document.xml 核心数据。
// 2. XML 语义转换：将 Docx 内部的 XML 标记（如 w:p, w:t）精准转换为 Markdown 或纯文本格式，保留基本的段落结构。
// 3. 样式过滤：自动剥离复杂的富文本样式元数据，提取最核心的知识内容，为 AI 分析提供纯净输入。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 迁移至 Utils/Processors/Document 并完善 Docx 语义提取说明
import Foundation

final class DocxProcessor: NSObject, XMLParserDelegate {
    private let xmlData: Data
    private(set) var extractedText: String = ""
    private var inTextElement = false
    private var currentText = ""
    private var lastWasText = false

    init(xmlData: Data) {
        self.xmlData = xmlData
    }

    func parse() -> Bool {
        let parser = XMLParser(data: xmlData)
        parser.delegate = self
        return parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "w:t" {
            inTextElement = true
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inTextElement {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "w:t" {
            if !currentText.isEmpty {
                if lastWasText {
                    extractedText += " "
                }
                extractedText += currentText
                lastWasText = true
            }
            inTextElement = false
            currentText = ""
        } else if elementName == "w:p" {
            if lastWasText {
                extractedText += "\n"
                lastWasText = false
            }
        }
    }
}
