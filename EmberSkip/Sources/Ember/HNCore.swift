import Foundation
import Observation

/// The selectable Hacker News feeds.
enum HNFeed: String, CaseIterable, Identifiable {
    case top = "topstories"
    case new = "newstories"
    case best = "beststories"
    case ask = "askstories"
    case show = "showstories"
    case job = "jobstories"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .top: return "Top"
        case .new: return "New"
        case .best: return "Best"
        case .ask: return "Ask HN"
        case .show: return "Show HN"
        case .job: return "Jobs"
        }
    }

    var systemImage: String {
        switch self {
        case .top: return "flame.fill"
        case .new: return "sparkles"
        case .best: return "trophy.fill"
        case .ask: return "questionmark.bubble.fill"
        case .show: return "eye.fill"
        case .job: return "briefcase.fill"
        }
    }
}

/// A Hacker News story/item decoded from the Firebase API.
struct HNStory: Identifiable, Hashable, Decodable {
    let id: Int
    var title: String?
    var by: String?
    var score: Int?
    var descendants: Int?
    var url: String?
    var time: Int?
    var text: String?
    var type: String?

    var displayTitle: String { title ?? "(untitled)" }
    var author: String { by ?? "unknown" }
    var points: Int { score ?? 0 }
    var commentCount: Int { descendants ?? 0 }
    var isJob: Bool { type == "job" }

    var articleURL: URL? {
        guard let url = url else { return nil }
        return URL(string: url)
    }

    var hnURL: URL {
        return URL(string: "https://news.ycombinator.com/item?id=\(id)")!
    }

    /// Bare display host parsed from the URL string (avoids URL.host() for
    /// cross-platform consistency).
    var host: String? {
        guard let url = url, let schemeRange = url.range(of: "://") else { return nil }
        var rest = String(url[schemeRange.upperBound...])
        if let slash = rest.firstIndex(of: "/") {
            rest = String(rest[..<slash])
        }
        if let colon = rest.firstIndex(of: ":") {
            rest = String(rest[..<colon])
        }
        if rest.hasPrefix("www.") {
            rest = String(rest.dropFirst(4))
        }
        return rest.isEmpty ? nil : rest
    }

    /// Relative time like "3h", "2d".
    var relativeTime: String {
        guard let time = time else { return "" }
        let seconds = max(0.0, Date().timeIntervalSince1970 - Double(time))
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))h" }
        if seconds < 604_800 { return "\(Int(seconds / 86_400))d" }
        return "\(Int(seconds / 604_800))w"
    }
}

/// Reads feeds and items from the official Hacker News Firebase API.
struct HNClient {
    static let shared = HNClient()
    private let base = "https://hacker-news.firebaseio.com/v0"

    func storyIDs(_ feed: HNFeed) async throws -> [Int] {
        let url = URL(string: "\(base)/\(feed.rawValue).json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([Int].self, from: data)
    }

    func item(_ id: Int) async throws -> HNStory {
        let url = URL(string: "\(base)/item/\(id).json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(HNStory.self, from: data)
    }

    /// Fetch many items concurrently, preserving order and dropping any that fail.
    /// Uses a struct result (not a tuple) and single-expression tasks so the
    /// transpiled Kotlin compiles cleanly on Android.
    func items(_ ids: [Int]) async throws -> [HNStory] {
        var indexed: [IndexedStory] = []
        try await withThrowingTaskGroup(of: IndexedStory.self) { group in
            for (index, id) in ids.enumerated() {
                group.addTask {
                    IndexedStory(index: index, story: try? await self.item(id))
                }
            }
            for try await result in group {
                indexed.append(result)
            }
        }
        return indexed.sorted { $0.index < $1.index }.compactMap { $0.story }
    }
}

/// A fetched story paired with its requested position, used to restore order
/// after a concurrent fetch.
struct IndexedStory {
    let index: Int
    let story: HNStory?
}

/// Drives the feed list.
@MainActor
@Observable
public class FeedViewModel {
    var feed: HNFeed = .top
    var stories: [HNStory] = []
    var isLoading = false
    var errorMessage: String?

    private let pageSize = 25

    public init() {}

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let ids = try await HNClient.shared.storyIDs(feed)
            let page = Array(ids.prefix(pageSize))
            stories = try await HNClient.shared.items(page)
        } catch {
            errorMessage = "\(error)"
        }
        isLoading = false
    }

    func select(_ newFeed: HNFeed) async {
        guard newFeed != feed else { return }
        feed = newFeed
        stories = []
        await load()
    }
}
