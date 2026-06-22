import SwiftUI

/// Horizontal, pinned feed selector. Each chip pairs an icon with a label so
/// selection never relies on color alone, and exposes the `.isSelected` trait
/// to VoiceOver.
struct FeedChipBar: View {
    let selection: Feed
    let onSelect: (Feed) -> Void

    @Environment(SettingsStore.self) private var settings

    private enum Edge: Hashable { case leading, trailing }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s) {
                    // Edge markers sit at the true content extremes so scrolling to
                    // them lands at offset 0 / max with the padding intact, rather
                    // than hugging a chip against the viewport edge. Width makes up
                    // the horizontal padding minus the HStack's own leading gap.
                    Color.clear.frame(width: Spacing.l - Spacing.s, height: 0).id(Edge.leading)
                    ForEach(Feed.allCases) { feed in
                        chip(feed)
                            .id(feed)
                    }
                    Color.clear.frame(width: Spacing.l - Spacing.s, height: 0).id(Edge.trailing)
                }
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.s)
            }
            // Selecting one of the first half scrolls fully left; the second half
            // fully right. Deferred a runloop tick because the tap also mutates the
            // view model (the feed reload churns layout), and a scroll issued in
            // the same render pass gets dropped.
            .onChange(of: selection) { _, newValue in
                scroll(to: newValue, proxy: proxy, animated: true)
            }
            // A feed switch tears this bar down and rebuilds it (the phase swaps the
            // list for a skeleton and back), resetting the scroll to offset 0. Each
            // rebuild's onAppear re-pins the bar to the selection so the position
            // survives the churn. Instant, since it's restoring an existing state.
            .onAppear {
                scroll(to: selection, proxy: proxy, animated: false)
            }
        }
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider().background(Theme.hairline)
        }
    }

    /// First half of the chips scrolls the bar to its leading extreme, the second
    /// half to its trailing extreme. Coarse by design — no need to center.
    private func scrollEdge(for feed: Feed) -> Edge {
        let index = Feed.allCases.firstIndex(of: feed) ?? 0
        return index < Feed.allCases.count / 2 ? .leading : .trailing
    }

    private func scroll(to feed: Feed, proxy: ScrollViewProxy, animated: Bool) {
        let edge = scrollEdge(for: feed)
        DispatchQueue.main.async {
            withAnimation(animated ? .easeInOut : nil) {
                proxy.scrollTo(edge, anchor: edge == .leading ? .leading : .trailing)
            }
        }
    }

    private func chip(_ feed: Feed) -> some View {
        let isSelected = feed == selection
        return Button {
            onSelect(feed)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: feed.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(feed.shortTitle)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? Color.white : Theme.textSecondary)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? settings.accent.color : Theme.surface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : Theme.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(feed.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
