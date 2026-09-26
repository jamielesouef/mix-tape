// TEMPLATE — leaf view that edits a value its parent owns. Copy, rename, delete this header.
//
// Layer: Presentation/<Feature>/<Name>Row.swift
//
// - `@Binding` because the PARENT owns the value. This view edits it and
//   knows nothing about where it goes. The parent decides whether a change
//   is just state or a service intent (PropertyWrappersTemplate.swift).
// - `@Binding` is not `private`: the parent passes `$value` through the
//   memberwise init. It sits before the `let` inputs, so the init reads
//   `isOn:` first.
// - No `Binding(get:set:)` here or in the parent. If the value needs
//   transforming, the parent owns a `@State` of the transformed shape.
// - Preview with `@Previewable @State`, never `.constant(...)`, so the
//   toggle works in the canvas. Include the long-text variant.
//
// MEMBER ORDER: @Binding -> let/var -> body

import SwiftUI

struct ExampleFeatureSettingRow: View {
    // MARK: - Binding

    @Binding var isOn: Bool

    // MARK: - Input

    let title: String
    let detail: String

    // MARK: - View

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                Text(title)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#if DEBUG
    #Preview("Short") {
        @Previewable @State var isOn = true

        Form {
            ExampleFeatureSettingRow(isOn: $isOn, title: "Show like counts", detail: "On every card.")
        }
        .formStyle(.grouped)
    }

    #Preview("Long text") {
        @Previewable @State var isOn = false

        Form {
            ExampleFeatureSettingRow(
                isOn: $isOn,
                title: "Show like counts on every card, including ones you have already seen",
                detail: "Counts refresh when the feed does, so a card you are looking at can change while you read it."
            )
        }
        .formStyle(.grouped)
    }
#endif
