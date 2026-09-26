// TEMPLATE — Screen. Copy, rename, delete this header.
//
// Layer: Presentation/<Feature>/<Name>Screen.swift
//
// A screen is the view that owns a service's lifecycle for one part of the
// app. It does three things and nothing else:
//
// 1. `.task { await service.start() }`. `start()` is idempotent, so
//    re-appearance is safe. Never `await` a fetch from `body` or a computed
//    property.
// 2. `switch service.loadState` exhaustively. Four cases, four regions, no
//    `if isLoading` recombination. The error region offers a real recovery
//    action (`refresh()`), not a dead-end message.
// 3. Wires decisions to use cases. Which item the hero shows next is
//    `ExampleFeatureFocusUseCase`, fed a domain direction mapped from
//    `MoveCommandDirection` at this boundary (MoveCommandMappingTemplate.swift).
//    `moveHero` is wiring only: read, call, assign.
//
// - `.onMoveCommand` fires on the focused hero for directions the focus
//   engine has no neighbour for. tvOS and macOS only; drop it on iOS.
// - `.focusSection()` around each independently navigable region.
// - Preview injects a service built on the app-target `Mock*`. The `@Entry`
//   default is the real implementation; the preview overrides it.
//
// MEMBER ORDER: Constants -> @Environment -> @State -> body -> subviews -> helpers

import SwiftUI

struct ExampleFeatureScreen: View {
    // MARK: - Constants

    private enum Constants {
        static let errorSpacing: CGFloat = 24
    }

    // MARK: - Environment

    @Environment(\.exampleFeatureService) private var service

    // MARK: - State

    @State private var heroIndex = 0

    // MARK: - View

    var body: some View {
        content
            .task {
                await service.start()
            }
    }

    // MARK: - Load state

    @ViewBuilder
    private var content: some View {
        switch service.loadState {
        case .loading:
            ProgressView()
        case .error:
            errorState
        case .empty:
            Text(String(localized: "example_feature_empty"))
        case let .loaded(items):
            loaded(items)
        }
    }

    private var errorState: some View {
        VStack(spacing: Constants.errorSpacing) {
            Text(String(localized: "example_feature_load_error"))

            Button(String(localized: "retry")) {
                Task {
                    await service.refresh()
                }
            }
        }
    }

    // MARK: - Loaded

    private func loaded(_ items: [ExampleFeatureItem]) -> some View {
        let index = ExampleFeatureFocusUseCase.clamped(heroIndex, count: items.count)

        return VStack(alignment: .leading, spacing: AppSpacing.regular) {
            hero(items[index], count: items.count)
            rail(items, selectedID: items[index].id)
        }
    }

    private func hero(_ item: ExampleFeatureItem, count: Int) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            Text(item.title)
                .font(.largeTitle)
                .lineLimit(2)

            Text(String(localized: "example_feature_like_count \(item.likeCount)"))
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .focusable()
        .focusSection()
        .onMoveCommand { direction in
            moveHero(direction, count: count)
        }
    }

    private func rail(_ items: [ExampleFeatureItem], selectedID: ExampleFeatureItem.ID) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: AppSpacing.regular) {
                ForEach(items) { item in
                    ExampleFeatureItemView(item: item, isSelected: item.id == selectedID) { selected in
                        heroIndex = items.firstIndex(of: selected) ?? heroIndex
                    }
                }
            }
            .padding(.horizontal, AppSpacing.regular)
        }
        .focusSection()
    }

    // MARK: - Helpers

    private func moveHero(_ direction: MoveCommandDirection, count: Int) {
        guard let moved = direction.exampleMoveDirection,
              let next = ExampleFeatureFocusUseCase.nextIndex(current: heroIndex, count: count, moved: moved) else {
            return
        }

        heroIndex = next
    }
}

#if DEBUG
    #Preview {
        ExampleFeatureScreen()
            .environment(
                \.exampleFeatureService,
                ExampleFeatureService(repository: MockExampleFeatureRepository())
            )
    }
#endif
