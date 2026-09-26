// TEMPLATE — Leaf view. Copy, rename, delete this header.
//
// Layer: Presentation/<Feature>/<Name>View.swift
//
// - A leaf view takes plain values and an action closure. It does not read
//   a service; the screen does that and passes down what this view renders.
//   Never pass a whole service or state object to a view that didn't create it.
// - NO LOGIC. Any decision (which element focuses next, whether an action
//   is enabled, how a list orders) is a use case in Domain/. If you can't
//   test a branch without launching the app, it doesn't belong here.
// - ONE VIEW PER FILE. A computed `some View` region used only here stays
//   colocated. A region with its own state, async work or reuse gets its
//   own file.
// - NO SIDE EFFECT IN A COMPUTED `Binding`'S `set`. A `set` that clears a
//   different property or triggers navigation is a hidden mutation that
//   fires on every write. Bind the real state and react with `.onChange(of:)`.
// - Copy is `String(localized:)`, sentence case, never a literal.
// - Tokens, not literals: spacing from `AppSpacing`; fonts and colours from
//   the system's semantic styles until a design system diverges. Sizes this
//   view alone needs live in `Constants`.
// - Focus treatment comes from the shared `cardFocusable` modifier
//   (ViewModifierTemplate.swift). Never re-implement `.focusable()` +
//   `.scaleEffect` per card.
// - Modifier order: content -> frame -> focus -> clip -> overlay -> gesture.
// - `#Preview` inside `#if DEBUG`, with the long-text, no-image and
//   zero-count variants, not only the happy path.
//
// MEMBER ORDER, one MARK per section:
//   Constants -> @Environment -> @State/@FocusState -> @Binding -> private let -> let/var -> body -> subviews ->
//   helpers

import SwiftUI

struct ExampleFeatureItemView: View {
    // MARK: - Constants

    private enum Constants {
        static let width: CGFloat = 320
        static let imageHeight: CGFloat = 180
        static let cornerRadius: CGFloat = 12
        static let selectedBorderWidth: CGFloat = 4
    }

    // MARK: - State

    @State private var isFocused = false

    // MARK: - Input

    let item: ExampleFeatureItem
    let isSelected: Bool
    var onSelect: (ExampleFeatureItem) -> Void = { _ in }

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            thumbnail

            Text(item.title)
                .font(.headline)
                .lineLimit(1)

            Text(likeCountText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(width: Constants.width, alignment: .leading)
    }

    // MARK: - Thumbnail

    private var thumbnail: some View {
        AsyncImage(url: item.thumbnailURL) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            Rectangle()
                .fill(.quaternary)
        }
        .frame(width: Constants.width, height: Constants.imageHeight)
        .cardFocusable { isFocused = $0 }
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .stroke(.primary, lineWidth: isSelected ? Constants.selectedBorderWidth : 0)
        }
        .onTapGesture {
            onSelect(item)
        }
    }

    // MARK: - Helpers

    private var likeCountText: String {
        String(localized: "example_feature_like_count \(item.likeCount)")
    }
}

#if DEBUG
    #Preview {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: AppSpacing.regular) {
                ExampleFeatureItemView(
                    item: ExampleFeatureItem(
                        id: "1",
                        title: "Morning news",
                        thumbnailURL: URL(string: "https://placecats.com/300/200"),
                        likeCount: 1_234_567,
                        ownerID: 42
                    ),
                    isSelected: true
                )
                ExampleFeatureItemView(
                    item: ExampleFeatureItem(
                        id: "2",
                        title: "A Very Long Title That Should Truncate At Some Point",
                        thumbnailURL: nil,
                        likeCount: 0,
                        ownerID: 43
                    ),
                    isSelected: false
                )
            }
            .padding()
        }
    }
#endif
