import Foundation

// MARK: - Link Service (Link Resolution + Search + Tags)
/// Handles link resolution, backlinks, search, and tag aggregation.
/// Stateless — operates on PageStore's pages array.
final class LinkService {
    // MARK: - Link Resolution
    func pageByTitle(_ title: String, in pages: [WikiPage]) -> WikiPage? {
        pages.first { $0.title.lowercased() == title.lowercased() }
            ?? pages.first { $0.aliases.contains(where: { $0.lowercased() == title.lowercased() }) }
    }

    func backlinks(for pageID: UUID, in pages: [WikiPage]) -> [WikiPage] {
        guard let page = pages.first(where: { $0.id == pageID }) else { return [] }
        return pages.filter { p in
            p.outgoingLinks.contains(where: { link in
                link.lowercased() == page.title.lowercased() ||
                page.aliases.contains(where: { $0.lowercased() == link.lowercased() })
            })
        }
    }

    func pageByID(_ id: UUID, in pages: [WikiPage]) -> WikiPage? {
        pages.first { $0.id == id }
    }

    // MARK: - Search
    func search(query: String, in pages: [WikiPage]) -> [WikiPage] {
        guard !query.isEmpty else { return pages }
        let q = query.lowercased()
        return pages.filter { page in
            page.title.lowercased().contains(q) ||
            page.content.lowercased().contains(q) ||
            page.tags.contains(where: { $0.lowercased().contains(q) }) ||
            page.aliases.contains(where: { $0.lowercased().contains(q) })
        }
    }

    // MARK: - Tag Aggregation
    func allTags(in pages: [WikiPage]) -> [(tag: String, count: Int)] {
        var tagCount: [String: Int] = [:]
        for page in pages {
            for tag in page.tags {
                tagCount[tag, default: 0] += 1
            }
        }
        return tagCount.map { ($0.key, $0.value) }.sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            return $0.0 < $1.0
        }
    }
}
