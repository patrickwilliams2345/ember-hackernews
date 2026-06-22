import Foundation
import Observation
import SwiftUI

/// A node from the Algolia `/items/{id}` endpoint (story + nested comment tree).
struct AlgoliaItem: Decodable {
    let id: Int
    let author: String?
    let text: String?
    let createdAtI: Int?
    let children: [AlgoliaItem]?

    enum CodingKeys: String, CodingKey {
        case id, author, text
        case createdAtI = "created_at_i"
        case children
    }
}

/// A flattened comment ready for display.
struct FlatComment: Identifiable, Hashable {
    let id: Int
    let author: String
    let text: String
    let depth: Int
    let createdAtI: Int?

    var relativeTime: String {
        guard let t = createdAtI else { return "" }
        let seconds = max(0.0, Date().timeIntervalSince1970 - Double(t))
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))h" }
        if seconds < 604_800 { return "\(Int(seconds / 86_400))d" }
        return "\(Int(seconds / 604_800))w"
    }
}

/// Fetches a full comment tree in a single request and flattens it.
struct AlgoliaClient {
    static let shared = AlgoliaClient()

    func comments(_ id: Int) async throws -> [FlatComment] {
        let url = URL(string: "https://hn.algolia.com/api/v1/items/\(id)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let root = try JSONDecoder().decode(AlgoliaItem.self, from: data)
        var out: [FlatComment] = []
        flatten(root.children ?? [], depth: 0, into: &out)
        return out
    }

    private func flatten(_ nodes: [AlgoliaItem], depth: Int, into out: inout [FlatComment]) {
        for node in nodes {
            let children = node.children ?? []
            let deleted = (node.text == nil || node.text?.isEmpty == true) && node.author == nil
            if !(deleted && children.isEmpty) {
                out.append(
                    FlatComment(
                        id: node.id,
                        author: node.author ?? "[deleted]",
                        text: HTMLText.plain(node.text ?? ""),
                        depth: depth,
                        createdAtI: node.createdAtI
                    )
                )
            }
            flatten(children, depth: depth + 1, into: &out)
        }
    }
}

/// Converts the small subset of HTML the HN API emits into plain text.
enum HTMLText {
    static func plain(_ html: String) -> String {
        var s = html
        s = s.replacingOccurrences(of: "<p>", with: "\n\n")
        s = s.replacingOccurrences(of: "</p>", with: "")
        var result = ""
        var inTag = false
        for ch in s {
            if ch == "<" { inTag = true }
            else if ch == ">" { inTag = false }
            else if !inTag { result += String(ch) }
        }
        return decodeEntities(result).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeEntities(_ s: String) -> String {
        var r = s
        let map: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
            "&#x27;": "'", "&#39;": "'", "&#x2F;": "/", "&#x2f;": "/",
            "&nbsp;": " ", "&mdash;": "\u{2014}", "&ndash;": "\u{2013}", "&hellip;": "\u{2026}",
        ]
        for (k, v) in map {
            r = r.replacingOccurrences(of: k, with: v)
        }
        return r
    }
}

@MainActor
@Observable
public class CommentsViewModel {
    var comments: [FlatComment] = []
    var isLoading = false
    var loaded = false
    var errorMessage: String?

    public init() {}

    func load(_ storyID: Int) async {
        guard !loaded, !isLoading else { return }
        isLoading = true
        do {
            comments = try await AlgoliaClient.shared.comments(storyID)
            loaded = true
        } catch {
            errorMessage = "\(error)"
        }
        isLoading = false
    }
}

struct CommentsSection: View {
    let viewModel: CommentsViewModel
    let storyID: Int

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if viewModel.comments.isEmpty {
                Text("No comments yet.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.comments) { comment in
                        CommentRowView(comment: comment)
                        Divider()
                    }
                }
            }
        }
        .task { await viewModel.load(storyID) }
    }
}

struct CommentRowView: View {
    let comment: FlatComment

    private var indent: CGFloat { CGFloat(min(comment.depth, 6)) * 12 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(comment.author)
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.orange)
                Text(comment.relativeTime)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(comment.text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, indent)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
