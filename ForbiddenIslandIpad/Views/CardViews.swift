import SwiftUI

struct PlayerHandsView: View {
    @ObservedObject var viewModel: GameViewModel
    let isLandscape: Bool
    let maxHeight: CGFloat
    let layoutScale: CGFloat

    var body: some View {
        Group {
            if isLandscape {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.game.players) { player in
                        playerHand(player: player, showsMetadata: player.id == viewModel.activePlayer?.id, cardScale: 0.85 * layoutScale)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(viewModel.game.players) { player in
                        playerHand(player: player, showsMetadata: player.id == viewModel.activePlayer?.id, cardScale: 0.92 * layoutScale)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: maxHeight, alignment: .topLeading)
    }

    private func playerHand(player: Player, showsMetadata: Bool, cardScale: CGFloat) -> some View {
        PlayerHandView(
            player: player,
            locationName: viewModel.game.tileName(at: player.location),
            isActive: player.id == viewModel.activePlayer?.id,
            showsMetadata: showsMetadata,
            showsCards: true,
            layoutScale: cardScale,
            canPlayCard: { cardIndex in
                viewModel.canPlayTreasureCard(playerID: player.id, cardIndex: cardIndex) ||
                    viewModel.canPlayReactionCard(playerID: player.id, cardIndex: cardIndex) ||
                    viewModel.canSelectTreasureToGive(playerID: player.id, cardIndex: cardIndex) ||
                    viewModel.canDiscardForHandLimit(playerID: player.id, cardIndex: cardIndex)
            },
            onCardTap: { cardIndex in
                if viewModel.canSelectHandLimitCardAction(playerID: player.id, cardIndex: cardIndex) {
                    _ = viewModel.selectHandLimitCardAction(playerID: player.id, cardIndex: cardIndex)
                } else if viewModel.canDiscardForHandLimit(playerID: player.id, cardIndex: cardIndex) {
                    _ = viewModel.discardForHandLimit(playerID: player.id, cardIndex: cardIndex)
                } else if viewModel.canSelectTreasureToGive(playerID: player.id, cardIndex: cardIndex) {
                    _ = viewModel.giveTreasure(cardIndex: cardIndex)
                } else {
                    _ = viewModel.playTreasureCard(playerID: player.id, cardIndex: cardIndex)
                }
            }
        )
    }
}

private struct PlayerHandView: View {
    let player: Player
    let locationName: String
    let isActive: Bool
    let showsMetadata: Bool
    let showsCards: Bool
    let layoutScale: CGFloat
    let canPlayCard: (Int) -> Bool
    let onCardTap: (Int) -> Void

    var body: some View {
        let scaledPadding = max(7, 8 * layoutScale)
        let iconWidth = showsMetadata ? 30 * layoutScale : 24 * layoutScale
        let iconHeight = showsMetadata ? 42 * layoutScale : 34 * layoutScale
        let minBoxHeight: CGFloat = showsMetadata ? 112 : 96

        VStack(alignment: .leading, spacing: showsCards ? 5 : 4) {
            HStack(spacing: 8) {
                BundleImage(name: "C\(player.role.rawValue)")
                    .frame(width: iconWidth, height: iconHeight)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(player.role.name)
                            .font(showsMetadata ? .headline : .subheadline.weight(.semibold))
                            .lineLimit(1)
                        if isActive {
                            Text("Active")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .foregroundStyle(.black)
                                .background(Color.yellow, in: Capsule())
                        }
                    }
                    if showsMetadata {
                        Text(locationName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text("\(player.actionsRemaining) actions / \(player.hand.count) cards")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if isActive {
                        Text("\(player.actionsRemaining) actions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }

            if showsCards {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        if player.hand.isEmpty {
                            Text("No treasure cards")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(height: 82)
                        } else {
                            ForEach(Array(player.hand.enumerated()), id: \.offset) { cardIndex, card in
                                TreasureCardButton(
                                    card: card,
                                    isPlayable: canPlayCard(cardIndex),
                                    compact: !showsMetadata,
                                    cardScale: layoutScale,
                                    onTap: { onCardTap(cardIndex) },
                                    accessibilityIdentifier: "hand.\(player.id).card.\(cardIndex)"
                                )
                            }
                        }
                    }
                    .padding(.trailing, 2)
                }
            }
        }
        .padding(showsMetadata ? 10 * layoutScale : scaledPadding)
        .frame(minHeight: minBoxHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isActive ? Color.yellow : Color.white.opacity(0.18), lineWidth: isActive ? 3 : 1)
        }
    }
}

private struct TreasureCardButton: View {
    let card: TreasureCard
    let isPlayable: Bool
    let compact: Bool
    let cardScale: CGFloat
    let onTap: () -> Void
    let accessibilityIdentifier: String

    var body: some View {
        Button(action: onTap) {
            TreasureCardImage(card: card)
                .frame(
                    width: (compact ? 40 : 54) * cardScale,
                    height: (compact ? 58 : 76) * cardScale
                )
                .overlay(alignment: .topTrailing) {
                    if isPlayable {
                        Image(systemName: "play.fill")
                            .font(.caption2)
                            .foregroundStyle(.black)
                            .padding(4)
                            .background(Color.yellow, in: Circle())
                            .offset(x: 4, y: -4)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(!isPlayable)
        .opacity(isPlayable ? 1 : 0.88)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct TreasureCardImage: View {
    let card: TreasureCard

    var body: some View {
        BundleImage(name: imageName)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(.white.opacity(0.25), lineWidth: 1)
            }
    }

    private var imageName: String {
        switch card {
        case .treasure(let treasure):
            "T\(treasure.rawValue)"
        case .helicopter:
            "T5"
        case .sandbag:
            "T6"
        case .watersRise:
            "T7"
        }
    }
}

struct DeckDiscardView: View {
    @ObservedObject var viewModel: GameViewModel
    var landscapeStyle: Bool = false
    var layoutScale: CGFloat = 1.0
    @State private var showsTreasureDiscardTop = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if landscapeStyle {
                VStack(alignment: .center, spacing: 12) {
                    HStack(spacing: 14) {
                        deckSlot(
                            imageName: "FIC",
                            count: viewModel.game.treasureDeck.count,
                            title: "TREASURE DECK",
                            titleColor: .black,
                            layoutScale: layoutScale
                        )

                        deckSlot(
                            imageName: "WRBC",
                            count: viewModel.game.floodDeck.count,
                            title: "Flood Deck",
                            titleColor: .black,
                            layoutScale: layoutScale
                        )

                        Button {
                            guard !viewModel.game.treasureDiscard.isEmpty else { return }
                            showsTreasureDiscardTop.toggle()
                        } label: {
                            discardSlot(title: "Discards", layoutScale: layoutScale, titleColor: .black) {
                                if let card = viewModel.treasureDiscardTopCard,
                                   showsTreasureDiscardTop || card == .watersRise {
                                    TreasureCardImage(card: card)
                                } else {
                                    BundleImage(name: "FIC")
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.game.treasureDiscard.isEmpty)
                    }
                }
            } else {
                VStack(alignment: .center, spacing: 12) {
                    HStack(spacing: 14) {
                        deckSlot(
                            imageName: "FIC",
                            count: viewModel.game.treasureDeck.count,
                            title: "Deck",
                            layoutScale: layoutScale
                        )

                        deckSlot(
                            imageName: "WRBC",
                            count: viewModel.game.floodDeck.count,
                            title: "Flood Deck",
                            layoutScale: layoutScale
                        )
                    }

                    HStack(spacing: 14) {
                        Button {
                            guard !viewModel.game.treasureDiscard.isEmpty else { return }
                            showsTreasureDiscardTop.toggle()
                        } label: {
                            discardSlot(title: "Treasure", layoutScale: layoutScale) {
                                if let card = viewModel.treasureDiscardTopCard,
                                   showsTreasureDiscardTop || card == .watersRise {
                                    TreasureCardImage(card: card)
                                } else {
                                    BundleImage(name: "FIC")
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.game.treasureDiscard.isEmpty)

                        discardSlot(title: "Flood", layoutScale: layoutScale) {
                            if let flood = viewModel.latestFloodDiscard {
                                BundleImage(name: "\(flood.rawValue)C")
                            } else {
                                BundleImage(name: "WRBC")
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: viewModel.game.treasureDiscard.count) { _, newValue in
            if newValue == 0 {
                showsTreasureDiscardTop = false
            }
        }
    }

    private func deckSlot(
        imageName: String,
        count: Int,
        title: String,
        titleColor: Color = .secondary,
        layoutScale: CGFloat = 1.0
    ) -> some View {
        VStack(spacing: 5) {
            ZStack(alignment: .topTrailing) {
                BundleImage(name: imageName)
                    .frame(width: 48 * layoutScale, height: 68 * layoutScale)
                    .clipShape(RoundedRectangle(cornerRadius: 5))

                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.75), in: Capsule())
                    .padding(4)
            }
            Text(title)
                .font(.caption2)
                .foregroundStyle(titleColor)
        }
    }

    private func discardSlot<Content: View>(
        title: String,
        layoutScale: CGFloat = 1.0,
        titleColor: Color = .secondary,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 5) {
            content()
                .frame(width: 48 * layoutScale, height: 68 * layoutScale)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            Text(title)
                .font(.caption2)
                .foregroundStyle(titleColor)
        }
    }
}
