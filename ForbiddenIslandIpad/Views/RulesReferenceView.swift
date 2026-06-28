import SwiftUI

struct RulesReferenceView: View {
    @Environment(\.dismiss) private var dismiss

    private let pageNames = (1...8).map { "R\($0)" }
    private let columns = [
        GridItem(.adaptive(minimum: 280), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(pageNames, id: \.self) { pageName in
                        VStack(alignment: .leading, spacing: 10) {
                            BundleImage(name: pageName)
                                .aspectRatio(0.75, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                                }

                            Text(pageLabel(for: pageName))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(16)
            }
            .background(Color(red: 0.02, green: 0.09, blue: 0.16))
            .navigationTitle("Rules")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func pageLabel(for pageName: String) -> String {
        switch pageName {
        case "R1":
            return "Overview"
        case "R2":
            return "Setup"
        case "R3":
            return "Player Actions"
        case "R4":
            return "Special Powers"
        case "R5":
            return "Treasure Cards"
        case "R6":
            return "Flooding"
        case "R7":
            return "Winning and Losing"
        case "R8":
            return "Reference"
        default:
            return pageName
        }
    }
}
