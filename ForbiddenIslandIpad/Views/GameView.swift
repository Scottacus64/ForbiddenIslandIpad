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
        HStack(spacing: 0) {
            VStack(spacing: 14) {
                IslandBoardView(
                    game: viewModel.game,
                    highlightedLocations: Set(viewModel.selectableTileLocations),
                    selectionKind: selectionKind,
                    onTileTap: handleTileTap,
                    boardSide: metrics.boardSide
                )
                .frame(width: metrics.boardSide, height: metrics.boardSide)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                PlayerHandsView(viewModel: viewModel)
            }
            .padding(metrics.boardPadding)
            .frame(width: metrics.leftPaneWidth, height: height, alignment: .topLeading)

            GameStatusPanel(
                viewModel: viewModel,
                onShowRules: showRulesReference
            )
            .frame(width: metrics.statusWidth, height: height, alignment: .top)
        }
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

                GameStatusPanel(
                    viewModel: viewModel,
                    onShowRules: showRulesReference
                )
                .frame(maxWidth: .infinity)

                PlayerHandsView(viewModel: viewModel)
                    .frame(maxWidth: .infinity)
            }
            .padding(metrics.boardPadding)
            .frame(maxWidth: .infinity)
        }
    }

    private func layoutMetrics(for size: CGSize, landscape: Bool) -> GameLayoutMetrics {
        let boardPadding: CGFloat = min(size.width, size.height) > 700 ? 28 : 14

        if landscape {
            let statusWidth = min(max(size.width * 0.20, 240), 320)
            let leftPaneWidth = max(size.width - statusWidth, 320)
            let handStripHeight: CGFloat = 300
            let verticalSpacing: CGFloat = 14
            let availableWidth = leftPaneWidth - (boardPadding * 2)
            let availableHeight = size.height - (boardPadding * 2) - handStripHeight - verticalSpacing
            let boardSide = max(240, min(availableWidth, availableHeight))

            return GameLayoutMetrics(
                leftPaneWidth: leftPaneWidth,
                statusWidth: statusWidth,
                boardPadding: boardPadding,
                boardSide: boardSide,
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
                boardPadding: boardPadding,
                boardSide: boardSide,
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
            return GameViewModel(seed: 20260627)
        }

        switch process.arguments[scenarioIndex + 1] {
        case "giveTreasure":
            return GameViewModel(
                game: makeGiveTreasureScenario(),
                phase: .playerAction(playerID: 0),
                seed: 20260627
            )
        default:
            return GameViewModel(seed: 20260627)
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
    let boardPadding: CGFloat
    let boardSide: CGFloat
    let rightPaneWidth: CGFloat
}
