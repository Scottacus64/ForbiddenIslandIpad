import SwiftUI

struct GameView: View {
    @StateObject private var viewModel: GameViewModel
    @State private var showingRulesReference = false

    init(viewModel: GameViewModel = GameView.makeInitialViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        GeometryReader { proxy in
            let landscape = proxy.size.width > proxy.size.height
            let metrics = layoutMetrics(for: proxy.size, landscape: landscape)

            Group {
                if landscape {
                    landscapeLayout(metrics: metrics, height: proxy.size.height)
                } else {
                    portraitLayout(metrics: metrics, size: proxy.size)
                }
            }
            .background(Color(red: 0.02, green: 0.09, blue: 0.16))
        }
        .fullScreenCover(isPresented: $showingRulesReference) {
            RulesReferenceView()
        }
    }

    @ViewBuilder
    private func landscapeLayout(metrics: GameLayoutMetrics, height: CGFloat) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                IslandBoardView(
                    game: viewModel.game,
                    highlightedLocations: Set(viewModel.selectableTileLocations),
                    selectionKind: selectionKind,
                    onTileTap: handleTileTap,
                    boardSide: metrics.boardSide
                )
                .frame(width: metrics.boardSide, height: metrics.boardSide)
                .frame(alignment: .topLeading)

                PlayerHandsView(
                    viewModel: viewModel,
                    isLandscape: true,
                    maxHeight: metrics.playerColumnHeight
                )
                .frame(width: metrics.playerColumnWidth, alignment: .topLeading)

                WaterLevelTrackView(level: viewModel.game.waterLevel)
                    .frame(width: metrics.waterLevelStripWidth, height: metrics.waterLevelStripHeight, alignment: .center)
            }
            .padding(.horizontal, metrics.topRowInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            GameStatusPanel(
                viewModel: viewModel,
                onShowRules: showRulesReference,
                isCompactPortrait: false,
                isLandscapeLayout: true
            )
            .frame(height: metrics.bottomBandHeight, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func portraitLayout(metrics: GameLayoutMetrics, size: CGSize) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 16) {
                IslandBoardView(
                    game: viewModel.game,
                    highlightedLocations: Set(viewModel.selectableTileLocations),
                    selectionKind: selectionKind,
                    onTileTap: handleTileTap,
                    boardSide: metrics.boardSide
                )
                .frame(width: metrics.boardSide, height: metrics.boardSide)
                .frame(maxWidth: .infinity)

                PlayerHandsView(viewModel: viewModel, isLandscape: false, maxHeight: .infinity)
                    .frame(maxWidth: .infinity)

                GameStatusPanel(
                    viewModel: viewModel,
                    onShowRules: showRulesReference,
                    isCompactPortrait: true
                )
                .frame(maxWidth: .infinity)
            }
            .padding(metrics.boardPadding)
            .frame(maxWidth: .infinity)
        }
    }

    private func layoutMetrics(for size: CGSize, landscape: Bool) -> GameLayoutMetrics {
        let boardPadding: CGFloat = min(size.width, size.height) > 700 ? 28 : 14

        if landscape {
            let compactLandscape = size.width < 1300
            let layoutPadding = compactLandscape ? 20 : boardPadding
            let waterLevelStripWidth: CGFloat = compactLandscape ? 111 : 128
            let waterLevelStripHeight: CGFloat = compactLandscape ? 306 : 320
            let playerColumnWidth: CGFloat = compactLandscape
                ? min(max(size.width * 0.28, 260), 360)
                : min(max(size.width * 0.26, 280), 380)
            let columnSpacing: CGFloat = compactLandscape ? 10 : 12
            let bottomBandHeight: CGFloat = compactLandscape ? 190 : 220
            let availableWidth = size.width
                - (layoutPadding * 2)
                - playerColumnWidth
                - waterLevelStripWidth
                - (columnSpacing * 2)
            let availableHeight = size.height
                - bottomBandHeight
                - (layoutPadding * 2)
                - 12
            let boardSide = max(240, min(availableWidth, availableHeight))
            let playerColumnHeight = max(320, availableHeight)
            let topRowContentWidth = boardSide + playerColumnWidth + waterLevelStripWidth + (columnSpacing * 2)
            let topRowInset = max(layoutPadding, (size.width - topRowContentWidth) / 2)

            return GameLayoutMetrics(
                leftPaneWidth: size.width,
                statusWidth: 0,
                waterLevelStripWidth: waterLevelStripWidth,
                waterLevelStripHeight: waterLevelStripHeight,
                playerColumnWidth: playerColumnWidth,
                playerColumnHeight: playerColumnHeight,
                bottomBandHeight: bottomBandHeight,
                boardPadding: layoutPadding,
                topRowInset: topRowInset,
                boardSide: boardSide,
                handStripHeight: 0,
                rightPaneWidth: 0
            )
        } else {
            let usableWidth = size.width - (boardPadding * 2)
            let boardSide = max(
                280,
                min(usableWidth, size.height * 0.58)
            )

            return GameLayoutMetrics(
                leftPaneWidth: size.width,
                statusWidth: size.width,
                waterLevelStripWidth: 0,
                waterLevelStripHeight: 0,
                playerColumnWidth: 0,
                playerColumnHeight: 0,
                bottomBandHeight: 0,
                boardPadding: boardPadding,
                topRowInset: boardPadding,
                boardSide: boardSide,
                handStripHeight: 0,
                rightPaneWidth: 0
            )
        }
    }

    private var selectionKind: TileSelectionKind? {
        switch viewModel.phase {
        case .selectingMove:
            .move
        case .selectingPilotFly:
            .move
        case .selectingNavigatorMove:
            .move
        case .selectingShoreUp:
            .shoreUp
        case .selectingSandbagTarget:
            .shoreUp
        case .selectingHelicopterSource:
            .move
        case .selectingHelicopterDestination:
            .move
        case .swimmingToSafety:
            .move
        default:
            nil
        }
    }

    private func handleTileTap(_ location: Int) {
        switch viewModel.phase {
        case .selectingMove:
            _ = viewModel.moveActivePlayer(to: location)
        case .selectingPilotFly:
            _ = viewModel.pilotFly(to: location)
        case .selectingNavigatorMove:
            _ = viewModel.moveNavigatorTarget(to: location)
        case .selectingShoreUp:
            _ = viewModel.shoreUp(location: location)
        case .selectingSandbagTarget:
            _ = viewModel.playSandbag(at: location)
        case .selectingHelicopterSource:
            _ = viewModel.selectHelicopterSource(location)
        case .selectingHelicopterDestination:
            _ = viewModel.playHelicopter(to: location)
        case .swimmingToSafety:
            _ = viewModel.swimPlayerToSafety(to: location)
        default:
            break
        }
    }

    private func showRulesReference() {
        showingRulesReference = true
    }

    private static func makeInitialViewModel() -> GameViewModel {
        let process = ProcessInfo.processInfo
        guard let scenarioIndex = process.arguments.firstIndex(of: "-uitestScenario"),
              scenarioIndex + 1 < process.arguments.count else {
            return GameViewModel(seed: UInt64.random(in: 1...UInt64.max))
        }

        switch process.arguments[scenarioIndex + 1] {
        case "giveTreasure":
            return GameViewModel(
                game: makeGiveTreasureScenario(),
                phase: .playerAction(playerID: 0),
                seed: 20260627
            )
        default:
            return GameViewModel(seed: UInt64.random(in: 1...UInt64.max))
        }
    }

    private static func makeGiveTreasureScenario() -> GameState {
        var generator = SeededGenerator(seed: 20260627)
        var game = GameState.newGame(using: &generator)
        game.players = [
            Player(id: 0, role: .messenger, location: 9, hand: [.treasure(.water)]),
            Player(id: 1, role: .pilot, location: 2)
        ]
        game.activePlayerIndex = 0
        game.gameStarted = true
        return game
    }
}

private struct GameLayoutMetrics {
    let leftPaneWidth: CGFloat
    let statusWidth: CGFloat
    let waterLevelStripWidth: CGFloat
    let waterLevelStripHeight: CGFloat
    let playerColumnWidth: CGFloat
    let playerColumnHeight: CGFloat
    let bottomBandHeight: CGFloat
    let boardPadding: CGFloat
    let topRowInset: CGFloat
    let boardSide: CGFloat
    let handStripHeight: CGFloat
    let rightPaneWidth: CGFloat
}

private struct WaterLevelTrackView: View {
    let level: Int

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let clampedLevel = min(max(level, 1), 8)
            let stepCount = CGFloat(7)
            let levelIndex = CGFloat(clampedLevel - 1)
            let indicatorY = size.height * (0.89 - (levelIndex / stepCount) * 0.64)
            let indicatorWidth = size.width * 0.51
            let indicatorHeight = size.width * 0.24
            let indicatorX = (indicatorWidth / 2) + 6

            ZStack {
                BundleImage(name: "wrCard", renderedContentMode: .fit)
                BundleImage(name: "wrIndicator", renderedContentMode: .fit)
                    .frame(width: indicatorWidth, height: indicatorHeight)
                    .position(x: indicatorX, y: indicatorY)
            }
            .frame(width: size.width, height: size.height)
        }
        .frame(width: 111, height: 306)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Water level \(level)")
    }
}
