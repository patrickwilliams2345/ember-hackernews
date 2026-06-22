import SwiftUI

/// The Ember Android/iOS feed. Shared SwiftUI, transpiled to Jetpack Compose
/// on Android by Skip.
struct ContentView: View {
    @State var viewModel = FeedViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.stories.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage, viewModel.stories.isEmpty {
                    errorView(error)
                } else {
                    storyList
                }
            }
            .navigationTitle("Ember")
            .toolbar {
                ToolbarItem {
                    Menu {
                        ForEach(HNFeed.allCases) { feed in
                            Button {
                                Task { await viewModel.select(feed) }
                            } label: {
                                Label(feed.title, systemImage: feed.systemImage)
                            }
                        }
                    } label: {
                        Label(viewModel.feed.title, systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .navigationDestination(for: HNStory.self) { story in
                StoryDetailView(story: story)
            }
        }
        .task {
            if viewModel.stories.isEmpty { await viewModel.load() }
        }
    }

    private var storyList: some View {
        List {
            ForEach(Array(viewModel.stories.enumerated()), id: \.element.id) { index, story in
                NavigationLink(value: story) {
                    StoryRowView(rank: index + 1, story: story)
                }
            }
        }
        .refreshable { await viewModel.load() }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Couldn't load stories")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Try Again") {
                Task { await viewModel.load() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct StoryRowView: View {
    let rank: Int
    let story: HNStory

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(rank)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .trailing)

            VStack(alignment: .leading, spacing: 4) {
                Text(story.displayTitle)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                if let host = story.host {
                    Text(host)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    if !story.isJob {
                        Label("\(story.points)", systemImage: "arrow.up")
                        Label("\(story.commentCount)", systemImage: "bubble.left")
                    }
                    Text("\(story.author) · \(story.relativeTime)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StoryDetailView: View {
    let story: HNStory
    @State private var viewModel = CommentsViewModel()
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(story.displayTitle)
                    .font(.title2)
                    .bold()
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    if !story.isJob {
                        Label("\(story.points)", systemImage: "arrow.up")
                        Label("\(story.commentCount)", systemImage: "bubble.left")
                    }
                    Text(story.relativeTime)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text("by \(story.author)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let url = story.articleURL {
                    Button {
                        openURL(url)
                    } label: {
                        Label(story.host ?? "Open Link", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let text = story.text, !text.isEmpty {
                    Text(HTMLText.plain(text))
                        .font(.body)
                        .selectableText()
                }

                Divider()

                Text("Comments")
                    .font(.title3)
                    .bold()

                CommentsSection(viewModel: viewModel, storyID: story.id)
            }
            .padding()
        }
        .navigationTitle(story.host ?? "Discussion")
    }
}
