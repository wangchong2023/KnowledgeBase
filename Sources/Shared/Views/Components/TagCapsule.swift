import SwiftUI

struct TagCapsule: View {
    let tag: String
    let count: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "tag.fill")
                .font(.caption2)
            Text(tag)
                .font(.subheadline.weight(.medium))
            Text("\(count)")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.wikiAccent.opacity(0.2))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.wikiCard)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.wikiBorder, lineWidth: 1)
        )
        .foregroundStyle(.wikiText)
    }
}
