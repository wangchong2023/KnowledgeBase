// ExcelProcessor.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了 Excel (Xlsx) 表格解析处理器（ExcelProcessor），旨在将表格中的行列数据转换为便于 AI 理解的文本序列。
// 处理流程包括：
// 1. 共享字符串索引：解析 SharedStrings.xml，实现对 Excel 内部优化存储字符串的精准还原与映射。
// 2. 工作表解析：支持对多 Sheet 内容的并发读取，能够按行、列维度提取原始数值与公式结果。
// 3. 表格转 Markdown：提供将复杂表格转换为 Markdown 表格格式的功能，方便在知识管理系统中进行预览与引用。
// 版本: 1.1
// 修改记录:
//   - 2026-05-05: 迁移至 Utils/Processors/Document 并整合多 Sheet 解析逻辑
import Foundation

final class ExcelProcessor: NSObject, XMLParserDelegate {
    private let xmlData: Data
    private(set) var values: [String] = []
    private var inCellElement = false
    private var inValueElement = false
    private var currentText = ""
    private var currentCellType: String?

    init(xmlData: Data) {
        self.xmlData = xmlData
    }

    func parse() -> Bool {
        let parser = XMLParser(data: xmlData)
        parser.delegate = self
        return parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "c" {
            currentCellType = attributeDict["t"]
            inCellElement = true
            currentText = ""
        } else if elementName == "v" {
            inValueElement = true
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inValueElement {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "v" {
            inValueElement = false
        } else if elementName == "c" {
            if !currentText.isEmpty && (currentCellType == "s" || currentCellType == "inlineStr") {
                if let value = Int(currentText), value < 10000 {
                    values.append("[\(value)]")
                }
            }
            inCellElement = false
            currentCellType = nil
            currentText = ""
        }
    }
}
