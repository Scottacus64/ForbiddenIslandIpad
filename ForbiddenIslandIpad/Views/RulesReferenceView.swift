import SwiftUI

struct RulesReferenceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    private let pages: [(image: String, title: String)] = [
        ("R1", "Overview"),
        ("R2", "Setup"),
        ("R3", "Player Actions"),
        ("R4", "Special Powers"),
        ("R5", "Treasure Cards"),
        ("R6", "Flooding"),
        ("R7", "Winning and Losing"),
        ("R8", "Reference")
    ]

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                VStack(spacing: 16) {
                    TabView(selection: $currentPage) {
                        ForEach(pages.indices, id: \.self) { index in
                            let page = pages[index]
                            VStack(spacing: 12) {
                                BundleImage(name: page.image)
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                                    }

                                Text(page.title)
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    HStack(spacing: 12) {
                        Button {
                            currentPage = max(0, currentPage - 1)
                        } label: {
                            Label("Previous", systemImage: "chevron.left")
                        }
                        .buttonStyle(.bordered)
                        .disabled(currentPage == 0)

                        Text("\(currentPage + 1) / \(pages.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 72)

                        Button {
                            currentPage = min(pages.count - 1, currentPage + 1)
                        } label: {
                            Label("Next", systemImage: "chevron.right")
                        }
                        .buttonStyle(.bordered)
                        .disabled(currentPage >= pages.count - 1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, max(0, proxy.safeAreaInsets.bottom))
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)
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
}
