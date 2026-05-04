// XlsxSheetParser.swift
//
// 作者: Wang Chong
// 功能说明: Xlsx Sheet Parser.swift
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation

final class XlsxSheetParser: NSObject, XMLParserDelegate {
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
