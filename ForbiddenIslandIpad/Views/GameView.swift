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
            let layoutScale = layoutScale(for: proxy.size)
            let metrics = layoutMetrics(for: proxy.size, landscape: landscape, layoutScale: layoutScale)

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
                    maxHeight: metrics.playerColumnHeight,
                    layoutScale: metrics.layoutScale
                )
                .frame(width: metrics.playerColumnWidth, alignment: .topLeading)

                WaterLevelTrackView(level: viewModel.game.waterLevel, layoutScale: metrics.layoutScale)
                    .frame(width: metrics.waterLevelStripWidth, height: metrics.waterLevelStripHeight, alignment: .center)
            }
            .padding(.horizontal, metrics.topRowInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            GameStatusPanel(
                viewModel: viewModel,
                onShowRules: showRulesReference,
                isCompactPortrait: true,
                isLandscapeLayout: false,
                layoutScale: metrics.layoutScale
            )
            .frame(height: metrics.bottomBandHeight, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func portraitLayout(metrics: GameLayoutMetrics, size: CGSize) -> some View {
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

                Spacer(minLength: 0)

                WaterLevelTrackView(level: viewModel.game.waterLevel, layoutScale: metrics.layoutScale)
                    .frame(width: metrics.waterLevelStripWidth, height: metrics.waterLevelStripHeight, alignment: .center)
            }
            .padding(.horizontal, metrics.topRowInset)
            .frame(maxWidth: .infinity, alignment: .top)

            PlayerHandsView(
                viewModel: viewModel,
                isLandscape: false,
                maxHeight: metrics.playerColumnHeight,
                layoutScale: metrics.layoutScale
            )
            .padding(.horizontal, metrics.boardPadding)
            .frame(maxWidth: .infinity, maxHeight: metrics.playerColumnHeight, alignment: .top)

            Spacer(minLength: 0)
        }
        .padding(.top, metrics.boardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GameStatusPanel(
                viewModel: viewModel,
                onShowRules: showRulesReference,
                isCompactPortrait: true,
                isLandscapeLayout: false,
                layoutScale: metrics.layoutScale
            )
            .frame(height: metrics.bottomBandHeight, alignment: .topLeading)
        }
    }

    private func layoutScale(for size: CGSize) -> CGFloat {
        let shortEdge = min(size.width, size.height)
        return min(max(shortEdge / 834.0, 1.0), 1.25)
    }

    private func layoutMetrics(for size: CGSize, landscape: Bool, layoutScale: CGFloat) -> GameLayoutMetrics {
        let baseBoardPadding: CGFloat = min(size.width, size.height) > 700 ? 28 : 14
        let boardPadding = baseBoardPadding * layoutScale

        if landscape {
            let compactLandscape = size.width < 1300
            let layoutPadding: CGFloat = (compactLandscape ? 20 : baseBoardPadding) * layoutScale
            let waterLevelStripWidth: CGFloat = (compactLandscape ? 111 : 128) * layoutScale
            let waterLevelStripHeight: CGFloat = (compactLandscape ? 306 : 320) * layoutScale
            let playerColumnWidth: CGFloat = compactLandscape
                ? min(max(size.width * 0.28, 260 * layoutScale), 360 * layoutScale)
                : min(max(size.width * 0.26, 280 * layoutScale), 380 * layoutScale)
            let columnSpacing: CGFloat = (compactLandscape ? 10 : 12) * layoutScale
            let bottomBandHeight: CGFloat = (compactLandscape ? 190 : 220) * layoutScale
            let availableWidth = size.width
                - (layoutPadding * 2)
                - playerColumnWidth
                - waterLevelStripWidth
                - (columnSpacing * 2)
            let availableHeight = size.height
                - bottomBandHeight
                - (layoutPadding * 2)
                - (12 * layoutScale)
            let boardSide = max(240 * layoutScale, min(availableWidth, availableHeight))
            let playerColumnHeight = max(320 * layoutScale, availableHeight)
            let topRowContentWidth = boardSide + playerColumnWidth + waterLevelStripWidth + (columnSpacing * 2)
            let topRowInset = max(layoutPadding, (size.width - topRowContentWidth) / 2)

            return GameLayoutMetrics(
                layoutScale: layoutScale,
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
            let waterLevelStripWidth: CGFloat = 111 * layoutScale
            let waterLevelStripHeight: CGFloat = 306 * layoutScale
            let horizontalGutter: CGFloat = 14 * layoutScale
            let availableWidth = size.width - (boardPadding * 2) - waterLevelStripWidth - horizontalGutter
            let regularPortrait = size.height >= 1300 || size.width >= 900
            let playerColumnHeight = regularPortrait
                ? max(190 * layoutScale, min(size.height * 0.18, 260 * layoutScale))
                : max(160 * layoutScale, min(size.height * 0.16, 220 * layoutScale))
            let bottomBandHeight = regularPortrait
                ? max(210 * layoutScale, min(size.height * 0.22, 290 * layoutScale))
                : max(190 * layoutScale, min(size.height * 0.20, 240 * layoutScale))
            let availableHeightForBoard = size.height
                - (boardPadding * 2)
                - playerColumnHeight
                - bottomBandHeight
                - (24 * layoutScale)
            let boardSide = max(
                (regularPortrait ? 300 : 290) * layoutScale,
                min(availableWidth, availableHeightForBoard) * (regularPortrait ? 0.94 : 0.9)
            )
            let topRowInset = max(boardPadding, (size.width - (boardSide + waterLevelStripWidth + horizontalGutter)) / 2)

            return GameLayoutMetrics(
                layoutScale: layoutScale,
                leftPaneWidth: size.width,
                statusWidth: size.width,
                waterLevelStripWidth: waterLevelStripWidth,
                waterLevelStripHeight: waterLevelStripHeight,
                playerColumnWidth: 0,
                playerColumnHeight: playerColumnHeight,
                bottomBandHeight: bottomBandHeight,
                boardPadding: boardPadding,
                topRowInset: topRowInset,
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
    let layoutScale: CGFloat
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
    let layoutScale: CGFloat

    var body: some View {
        GeometryReader { proxy in
            BundleImage(name: waterLevelImageName, renderedContentMode: .fit)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(width: 111 * layoutScale, height: 306 * layoutScale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Water level \(level)")
    }

    private var waterLevelImageName: String {
        let clampedLevel = min(max(level + 1, 1), 10)
        return "wr\(clampedLevel)"
    }
}
