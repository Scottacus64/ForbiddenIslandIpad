import SwiftUI

struct GameStatusPanel: View {
    @ObservedObject var viewModel: GameViewModel
    let onShowRules: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            BundleImage(name: "fiLogo")
                .frame(height: 86)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onShowRules()
            } label: {
                Label("Rules", systemImage: "book.fill")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("rules.button")

            Button {
                viewModel.resetGame()
            } label: {
                Label("New Game", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("newGame.button")

            VStack(alignment: .leading, spacing: 8) {
                Label(phaseTitle, systemImage: "flag.checkered")
                Label("Water Level \(viewModel.game.waterLevel)", systemImage: "water.waves")
                if let activePlayer = viewModel.activePlayer {
                    Label(activePlayer.role.name, systemImage: "person.fill")
                    Label(viewModel.game.tileName(at: activePlayer.location), systemImage: "mappin.and.ellipse")
                    Label("\(activePlayer.actionsRemaining) Actions", systemImage: "circle.grid.3x3.fill")
                }
            }
            .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                Text("Treasures")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    ForEach(Treasure.allCases, id: \.self) { treasure in
                        BundleImage(name: "TR\(treasure.rawValue)")
                            .opacity(viewModel.game.collectedTreasures.contains(treasure) ? 1 : 0.35)
                            .frame(width: 44, height: 44)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label("Treasure Deck", systemImage: "rectangle.stack.fill")
                Label("\(viewModel.game.floodDeck.count) Flood", systemImage: "drop.fill")
                Label("\(viewModel.game.floodDiscard.count) Flood Discard", systemImage: "tray.fill")
            }
            .font(.subheadline)

            DeckDiscardView(viewModel: viewModel)

            Divider()

            phaseControls

            Divider()

            eventLogSection

            Divider()

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(minWidth: 260, maxWidth: 320)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var phaseControls: some View {
        switch viewModel.phase {
        case .choosePlayerCount:
            VStack(alignment: .leading, spacing: 10) {
                Text("Players")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    ForEach(2...4, id: \.self) { count in
                        Button("\(count)") {
                            _ = viewModel.choosePlayerCount(count)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("playerCount.\(count)")
                    }
                }
            }

        case .chooseDifficulty:
            VStack(alignment: .leading, spacing: 10) {
                Text("Difficulty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(difficulties, id: \.level) { difficulty in
                    Button(difficulty.name) {
                        _ = viewModel.chooseDifficulty(waterLevel: difficulty.level)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("difficulty.\(difficulty.level)")
                }
            }

        case .initialFlood(let remaining, _):
            VStack(alignment: .leading, spacing: 10) {
                Button("Flood Tile (\(remaining))") {
                    _ = viewModel.floodInitialTile()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("initialFlood.next")
            }

        case .playerAction:
            VStack(alignment: .leading, spacing: 10) {
                Button("Move") {
                    _ = viewModel.selectAction(.move)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("action.move")

                Button("Shore Up") {
                    _ = viewModel.selectAction(.shoreUp)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("action.shoreUp")

                Button("Collect Treasure") {
                    _ = viewModel.selectAction(.collectTreasure)
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canCollectTreasure)
                .accessibilityIdentifier("action.collectTreasure")

                Button("Give Treasure") {
                    _ = viewModel.selectAction(.giveTreasure)
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canGiveTreasure)
                .accessibilityIdentifier("action.giveTreasure")

                Button("Special") {
                    _ = viewModel.selectAction(.special)
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canUseSpecialAction)
                .accessibilityIdentifier("action.special")

                Button("End Turn") {
                    _ = viewModel.selectAction(.endTurn)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("action.endTurn")
            }

        case .selectingMove(_, let targets):
            selectionBlock(
                title: "Choose a destination",
                detail: targetDetail(targets)
            )

        case .selectingShoreUp(_, let targets):
            VStack(alignment: .leading, spacing: 8) {
                instructionBlock(
                    title: "Choose a flooded tile",
                    detail: targetDetail(targets)
                )
                if viewModel.activePlayer?.role == .engineer,
                   viewModel.game.engineerHasPendingShoreUp {
                    Text("Engineer bonus shore up available.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if viewModel.canCancelSelection {
                    cancelSelectionButton
                }
            }

        case .selectingPilotFly(_, let targets):
            selectionBlock(
                title: "Choose a flight destination",
                detail: targetDetail(targets)
            )

        case .selectingNavigatorTarget(_, let targetPlayerIDs):
            VStack(alignment: .leading, spacing: 10) {
                Text("Choose player to move")
                    .font(.headline)
                ForEach(targetPlayerIDs, id: \.self) { targetPlayerID in
                    if let player = viewModel.game.players.first(where: { $0.id == targetPlayerID }) {
                        Button(player.role.name) {
                            _ = viewModel.selectNavigatorTarget(targetPlayerID)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                if viewModel.canCancelSelection {
                    cancelSelectionButton
                }
            }

        case .selectingNavigatorMove(_, let targetPlayerID, let remainingSteps, let hasMoved, let targets):
            VStack(alignment: .leading, spacing: 10) {
                if let player = viewModel.game.players.first(where: { $0.id == targetPlayerID }) {
                    Text("Move \(player.role.name)")
                        .font(.headline)
                }
                Text("\(remainingSteps) step\(remainingSteps == 1 ? "" : "s") remaining")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(targetDetail(targets))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Done") {
                    _ = viewModel.finishNavigatorMove()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasMoved)
                if viewModel.canCancelSelection {
                    cancelSelectionButton
                }
            }

        case .selectingTreasureReceiver(_, let receiverIDs):
            VStack(alignment: .leading, spacing: 10) {
                Text("Choose receiver")
                    .font(.headline)
                ForEach(receiverIDs, id: \.self) { receiverID in
                    if let player = viewModel.game.players.first(where: { $0.id == receiverID }) {
                        Button(player.role.name) {
                            _ = viewModel.selectTreasureReceiver(receiverID)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("treasureReceiver.\(receiverID)")
                    }
                }
                if viewModel.canCancelSelection {
                    cancelSelectionButton
                }
            }

        case .selectingTreasureToGive:
            selectionBlock(
                title: "Choose treasure card",
                detail: "Tap a treasure card in the active player's hand."
            )

        case .selectingSandbagTarget(_, _, let targets):
            selectionBlock(
                title: "Sandbag a tile",
                detail: targetDetail(targets)
            )

        case .selectingHelicopterSource(_, _, let sourceLocations):
            selectionBlock(
                title: "Choose lift origin",
                detail: targetDetail(sourceLocations)
            )

        case .selectingHelicopterPassengers(_, _, let candidatePlayerIDs, let selectedPlayerIDs):
            VStack(alignment: .leading, spacing: 10) {
                Text("Choose passengers")
                    .font(.headline)
                ForEach(candidatePlayerIDs, id: \.self) { passengerID in
                    if let player = viewModel.game.players.first(where: { $0.id == passengerID }) {
                        if selectedPlayerIDs.contains(passengerID) {
                            Button {
                                _ = viewModel.toggleHelicopterPassenger(passengerID)
                            } label: {
                                Label(player.role.name, systemImage: "checkmark.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button {
                                _ = viewModel.toggleHelicopterPassenger(passengerID)
                            } label: {
                                Label(player.role.name, systemImage: "circle")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                Button("Choose Destination") {
                    _ = viewModel.confirmHelicopterPassengers()
                }
                .buttonStyle(.bordered)
                .disabled(selectedPlayerIDs.isEmpty)
                if viewModel.canCancelSelection {
                    cancelSelectionButton
                }
            }

        case .selectingHelicopterDestination(_, _, _, let targets):
            selectionBlock(
                title: "Choose landing tile",
                detail: targetDetail(targets)
            )

        case .drawingTreasure(_, let drawnCount):
            VStack(alignment: .leading, spacing: 10) {
                Button("Draw Treasure Card") {
                    _ = viewModel.drawTreasureCard()
                }
                .buttonStyle(.borderedProminent)
                Text("\(drawnCount) of 2 drawn")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .resolvingWatersRise:
            VStack(alignment: .leading, spacing: 10) {
                Text("Waters Rise")
                    .font(.headline)
                if let revealedCard = viewModel.revealedTreasureCard {
                    TreasureCardImage(card: revealedCard)
                        .frame(width: 54, height: 76)
                }
                Button("Continue") {
                    _ = viewModel.resolveWatersRise()
                }
                .buttonStyle(.borderedProminent)
            }

        case .discardingHandLimit(let playerID, _):
            VStack(alignment: .leading, spacing: 8) {
                Text("Discard to 5 cards")
                    .font(.headline)
                if let player = viewModel.game.players.first(where: { $0.id == playerID }) {
                    if let selection = viewModel.selectedHandLimitCard,
                       selection.playerID == playerID,
                       player.hand.indices.contains(selection.cardIndex) {
                        let card = player.hand[selection.cardIndex]
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Choose an action for \(player.role.name)'s card.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TreasureCardImage(card: card)
                                .frame(width: 54, height: 76)
                            HStack(spacing: 8) {
                                Button("Play") {
                                    _ = viewModel.playSelectedHandLimitCard()
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(!viewModel.canPlaySelectedHandLimitCard())

                                Button("Discard") {
                                    _ = viewModel.discardSelectedHandLimitCard()
                                }
                                .buttonStyle(.bordered)

                                if viewModel.canCancelSelection {
                                    cancelSelectionButton
                                }
                            }
                        }
                    } else {
                        Text("Tap a sandbag or helicopter card to choose whether to play it or discard it.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

        case .swimmingToSafety(let playerID, let targets, _):
            if let player = viewModel.game.players.first(where: { $0.id == playerID }) {
                instructionBlock(
                    title: "\(player.role.name) is in the water",
                    detail: targetDetail(targets)
                )
            } else {
                instructionBlock(
                    title: "Player is in the water",
                    detail: targetDetail(targets)
                )
            }

        case .flooding(let remaining, _):
            VStack(alignment: .leading, spacing: 10) {
                Button("Flood Tile (\(remaining))") {
                    _ = viewModel.floodNextTile()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("flood.next")
            }

        case .gameOver(let outcome):
            VStack(alignment: .leading, spacing: 10) {
                Text(gameOverText(for: outcome))
                    .font(.headline)
                Text("Start a new game from the panel controls.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var difficulties: [(level: Int, name: String)] {
        [
            (0, "Novice"),
            (1, "Normal"),
            (2, "Elite"),
            (3, "Legendary")
        ]
    }

    private func instructionBlock(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func selectionBlock(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            instructionBlock(title: title, detail: detail)
            if viewModel.canCancelSelection {
                cancelSelectionButton
            }
        }
    }

    private var cancelSelectionButton: some View {
        Button {
            _ = viewModel.cancelSelection()
        } label: {
            Label("Back", systemImage: "arrow.uturn.backward")
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("selection.cancel")
    }

    private func targetDetail(_ targets: [Int]) -> String {
        if targets.isEmpty {
            return "No legal targets."
        }
        return "Highlighted tiles: " + targets.map { viewModel.game.tileName(at: $0) }.joined(separator: ", ")
    }

    @ViewBuilder
    private var eventLogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Log")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if viewModel.recentEvents.isEmpty {
                Text("No events yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.recentEvents) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: entry.symbol)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 16)
                                Text(entry.message)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.trailing, 4)
                }
                .frame(maxHeight: 180)
            }
        }
    }

    private func gameOverText(for outcome: GameOutcome) -> String {
        switch outcome {
        case .won:
            return "You won."
        case .lost(let loss):
            return "Lost: \(lossText(loss))"
        }
    }

    private func lossText(_ loss: GameLoss) -> String {
        switch loss {
        case .foolsLandingSunk:
            "Fools' Landing sank"
        case .treasureUnavailable(let treasure):
            "\(treasure) treasure unavailable"
        case .waterLevelOverflow:
            "Water level overflow"
        case .playerDrowned(let playerID):
            "Player \(playerID) drowned"
        case .noPlayers:
            "No players remain"
        }
    }

    private var phaseTitle: String {
        switch viewModel.phase {
        case .choosePlayerCount: "Choose Players"
        case .chooseDifficulty: "Choose Difficulty"
        case .initialFlood(let remaining, _): "Initial Flood: \(remaining)"
        case .playerAction: "Player Action"
        case .selectingMove: "Selecting Move"
        case .selectingShoreUp: "Selecting Shore Up"
        case .selectingPilotFly: "Selecting Pilot Flight"
        case .selectingNavigatorTarget: "Selecting Navigator Target"
        case .selectingNavigatorMove: "Moving Navigator Target"
        case .selectingTreasureReceiver: "Selecting Receiver"
        case .selectingTreasureToGive: "Selecting Treasure"
        case .selectingSandbagTarget: "Selecting Sandbag Target"
        case .selectingHelicopterSource: "Selecting Helicopter Source"
        case .selectingHelicopterPassengers: "Selecting Helicopter Passengers"
        case .selectingHelicopterDestination: "Selecting Helicopter Destination"
        case .drawingTreasure(_, let drawnCount): "Drawing Treasure \(drawnCount)/2"
        case .resolvingWatersRise: "Waters Rise"
        case .discardingHandLimit: "Discarding Cards"
        case .swimmingToSafety: "Swimming to Safety"
        case .flooding(let remaining, _): "Flooding: \(remaining)"
        case .gameOver(let outcome):
            switch outcome {
            case .won: "Game Won"
            case .lost: "Game Lost"
            }
        }
    }
}
