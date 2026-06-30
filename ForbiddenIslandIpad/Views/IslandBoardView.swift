import SwiftUI

struct IslandBoardView: View {
    let game: GameState
    let highlightedLocations: Set<Int>
    let selectionKind: TileSelectionKind?
    let onTileTap: (Int) -> Void
    let boardSide: CGFloat

    private let gridSize = 6
    private let gridSpacing: CGFloat = 8
    private let gridPadding: CGFloat = 12

    var body: some View {
        let cellSide = (boardSide - (gridPadding * 2) - (gridSpacing * CGFloat(gridSize - 1))) / CGFloat(gridSize)

        ZStack {
            BundleImage(name: "water", contentMode: .fill)
                .frame(width: boardSide, height: boardSide)
                .clipped()

            VStack(spacing: gridSpacing) {
                ForEach(0..<gridSize, id: \.self) { row in
                    HStack(spacing: gridSpacing) {
                        ForEach(0..<gridSize, id: \.self) { column in
                            let location = (row * gridSize) + column

                            ZStack {
                                if let tile = game.tilesByLocation[location] {
                                    TileView(
                                        location: location,
                                        tile: tile,
                                        players: players(at: location),
                                        tileSide: cellSide,
                                        highlight: highlightedLocations.contains(location) ? selectionKind : nil,
                                        onTap: { onTileTap(location) }
                                    )
                                } else {
                                    Color.clear
                                }
                            }
                            .frame(width: cellSide, height: cellSide)
                        }
                    }
                }
            }
            .padding(gridPadding)
        }
        .frame(width: boardSide, height: boardSide)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("island.board")
    }

    private func players(at location: Int) -> [Player] {
        game.players.filter { $0.location == location }
    }
}

enum TileSelectionKind {
    case move
    case shoreUp
}

private struct TileView: View {
    let location: Int
    let tile: IslandTile
    let players: [Player]
    let tileSide: CGFloat
    let highlight: TileSelectionKind?
    let onTap: () -> Void

    private var pawnSize: CGSize {
        if tileSide < 110 {
            return CGSize(width: 22, height: 36)
        } else if tileSide < 128 {
            return CGSize(width: 24, height: 40)
        } else {
            return CGSize(width: 28, height: 46)
        }
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                tileImage
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(borderColor, lineWidth: 2)
                    }
                    .overlay {
                        if let highlight {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(highlightColor(for: highlight).opacity(0.34))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 5)
                                        .strokeBorder(highlightColor(for: highlight), lineWidth: 4)
                                }
                        }
                    }

                if !players.isEmpty {
                    pawnCluster
                        .padding(.bottom, 1)
                }
            }
        }
        .buttonStyle(.plain)
        .allowsHitTesting(highlight != nil)
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tile.kind.name), \(stateName), location \(location)")
        .accessibilityIdentifier("tile.\(location)")
    }

    @ViewBuilder
    private var opaqueTileBackground: some View {
        switch tile.state {
        case .dry:
            Color(.systemBackground)
        case .flooded:
            Color(.secondarySystemBackground)
        case .sunk:
            Color(.tertiarySystemBackground)
        }
    }

    @ViewBuilder
    private var tileImage: some View {
        switch tile.state {
        case .dry:
            BundleImage(
                name: "\(tile.kind.rawValue)F",
                interpolation: .high
            )
        case .flooded:
            BundleImage(
                name: "\(tile.kind.rawValue)B",
                interpolation: .high
            )
        case .sunk:
            Rectangle()
                .fill(.clear)
        }
    }

    @ViewBuilder
    private var pawnCluster: some View {
        switch players.count {
        case 1:
            HStack {
                Spacer(minLength: 0)
                pawn(players[0])
                Spacer(minLength: 0)
            }
        case 2:
            HStack(spacing: 2) {
                ForEach(players) { player in
                    pawn(player)
                }
            }
        case 3:
            VStack(spacing: 1) {
                HStack {
                    Spacer(minLength: 0)
                    pawn(players[0])
                    Spacer(minLength: 0)
                }
                HStack(spacing: 2) {
                    pawn(players[1])
                    pawn(players[2])
                }
            }
        default:
            VStack(spacing: 1) {
                HStack(spacing: 2) {
                    pawn(players[0])
                    pawn(players[1])
                }
                HStack(spacing: 2) {
                    pawn(players[2])
                    pawn(players[3])
                }
            }
        }
    }

    private func pawn(_ player: Player) -> some View {
        BundleImage(
            name: "P\(player.role.rawValue)",
            renderedContentMode: .fit
        )
        .frame(width: pawnSize.width, height: pawnSize.height)
        .accessibilityLabel(player.role.name)
    }

    private var borderColor: Color {
        switch tile.state {
        case .dry: .white.opacity(0.35)
        case .flooded: .cyan.opacity(0.85)
        case .sunk: .clear
        }
    }

    private var stateName: String {
        switch tile.state {
        case .dry: "dry"
        case .flooded: "flooded"
        case .sunk: "sunk"
        }
    }

    private func highlightColor(for highlight: TileSelectionKind) -> Color {
        switch highlight {
        case .move: .yellow
        case .shoreUp: .green
        }
    }
}
