// IconPickerView.swift
//
// 作者: Wang Chong
// 功能说明: A reusable icon picker that presents categorized SF Symbols in a grid.
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI

// MARK: - Icon Picker View
/// A reusable icon picker that presents categorized SF Symbols in a grid.
/// Returns an optional String (SF Symbol name) via binding. nil = use default type icon.
struct IconPickerView: View {
    @Binding var selectedIcon: String?
    @Environment(\.dismiss) private var dismiss

    // MARK: - Icon Categories
    private static let iconCategories: [(String, [String])] = [
        ("iconPicker.common", [
            "person.text.rectangle.fill", "building.2.fill", "books.vertical.fill", "lightbulb.fill",
            "doc.richtext.fill", "globe", "star.fill", "heart.fill",
            "tag.fill", "folder.fill", "paperclip", "link",
            "camera.fill", "music.note", "paintpalette.fill", "hammer.fill"
        ]),
        ("iconPicker.academic", [
            "graduationcap.fill", "brain.head.profile.fill", "atom", "dna",
            "chart.bar.fill", "chart.pie.fill", "cube.box.fill", "gearshape.fill",
            "cpu", "desktopcomputer", "server.rack", "circle.hexagongrid.fill"
        ]),
        ("iconPicker.nature", [
            "tree.fill", "leaf.fill", "sun.max.fill", "moon.fill",
            "cloud.fill", "drop.fill", "flame.fill", "bolt.fill",
            "mountain.2.fill", "water.waves", "wind", "snowflake"
        ]),
        ("iconPicker.transport", [
            "airplane", "car.fill", "train.side.front.filled",
            "ship.fill", "bicycle", "sailboat.fill"
        ]),
        ("iconPicker.symbols", [
            "exclamationmark.triangle.fill", "checkmark.circle.fill",
            "xmark.circle.fill", "questionmark.circle.fill",
            "info.circle.fill", "bell.fill", "flag.fill", "bookmark.fill"
        ])
    ]

    private func categoryDisplayName(_ key: String) -> String {
        L10n.Editor.tr(key)
    }

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Current selection preview
                    currentSelectionPreview

                    // Icon categories
                    ForEach(Self.iconCategories, id: \.0) { category, icons in
                        iconCategorySection(title: categoryDisplayName(category), icons: icons)
                    }
                }
                .padding()
            }
            .background(Color.wikiBackground)
            .navigationTitle(L10n.Editor.tr("iconPicker.selectIcon"))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(L10n.Common.tr("ok")) { dismiss() }
                        .fontWeight(.medium)
                }
            }
        }
    }

    // MARK: - Current Selection Preview
    private var currentSelectionPreview: some View {
        HStack(spacing: 12) {
            Image(systemName: selectedIcon ?? "person.text.rectangle.fill")
                .font(.title)
                .foregroundStyle(.wikiAccent)
                .frame(width: 48, height: 48)
                .background(Color.wikiAccent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))

            VStack(alignment: .leading, spacing: 4) {
                Text(selectedIcon != nil ? L10n.Editor.tr("iconPicker.customSelected") : L10n.Editor.tr("iconPicker.useDefault"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.wikiText)
                if selectedIcon != nil {
                    Text(selectedIcon!)
                        .font(.caption)
                        .foregroundStyle(.wikiSecondary)
                }
            }

            Spacer()

            if selectedIcon != nil {
                Button(action: {
                    selectedIcon = nil
                    dismiss()
                }) {
                    Text(L10n.Editor.tr("iconPicker.reset"))
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.wikiCard)
                        .clipShape(Capsule())
                        .foregroundStyle(.wikiSecondary)
                }
            }
        }
        .padding()
        .background(Color.wikiCard)
        .clipShape(RoundedRectangle(cornerRadius: WikiUI.cardRadius))
    }

    // MARK: - Icon Category Section
    @ViewBuilder
    private func iconCategorySection(title: String, icons: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.wikiSecondary)

            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(icons, id: \.self) { icon in
                    Button(action: {
                        selectedIcon = icon
                        dismiss()
                    }) {
                        Image(systemName: icon)
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(selectedIcon == icon ? Color.wikiAccent.opacity(0.25) : Color.wikiCard)
                            .clipShape(RoundedRectangle(cornerRadius: WikiUI.standardRadius))
                            .foregroundStyle(selectedIcon == icon ? .wikiAccent : .wikiText)
                            .overlay(
                                RoundedRectangle(cornerRadius: WikiUI.standardRadius)
                                    .stroke(selectedIcon == icon ? Color.wikiAccent : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
