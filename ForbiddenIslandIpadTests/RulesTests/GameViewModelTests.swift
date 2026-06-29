import XCTest
@testable import ForbiddenIslandRules

final class GameViewModelTests: XCTestCase {
    func testSetupFlowMovesFromPlayerCountToDifficultyToInitialFlood() {
        let viewModel = GameViewModel(game: fixedGame())

        XCTAssertEqual(viewModel.phase, .choosePlayerCount)
        XCTAssertTrue(viewModel.choosePlayerCount(3))
        XCTAssertEqual(viewModel.game.players.count, 3)
        XCTAssertTrue(viewModel.game.players.allSatisfy { $0.hand.count == 2 })
        XCTAssertEqual(viewModel.phase, .chooseDifficulty(playerCount: 3))

        XCTAssertTrue(viewModel.chooseDifficulty(waterLevel: 2))
        XCTAssertEqual(viewModel.game.waterLevel, 2)
        XCTAssertEqual(viewModel.phase, .initialFlood(remaining: 6, lastFloodedLocation: nil))
    }

    func testResetGameReturnsToFreshPlayerCountSetup() {
        let viewModel = GameViewModel(seed: 7)

        XCTAssertTrue(viewModel.choosePlayerCount(2))
        XCTAssertFalse(viewModel.game.players.isEmpty)
        XCTAssertFalse(viewModel.eventLog.isEmpty)

        viewModel.resetGame(seed: 7)

        XCTAssertEqual(viewModel.phase, .choosePlayerCount)
        XCTAssertTrue(viewModel.game.players.isEmpty)
        XCTAssertEqual(viewModel.game.treasureDeck.count, 28)
        XCTAssertEqual(viewModel.game.floodDeck.count, 24)
        XCTAssertEqual(viewModel.recentEvents.first?.message, "New game ready.")
    }

    func testInitialFloodAdvancesToActivePlayerAfterSixFloods() {
        var game = fixedGame()
        game.floodDeck = [.bronzeGate, .copperGate, .caveOfEmbers, .caveOfShadows, .goldGate, .ironGate]
        let viewModel = GameViewModel(game: game, phase: .initialFlood(remaining: 6, lastFloodedLocation: nil))

        for _ in 0..<5 {
            XCTAssertNotNil(viewModel.floodInitialTile())
        }
        XCTAssertNotNil(viewModel.floodInitialTile())
        XCTAssertEqual(viewModel.phase, .playerAction(playerID: 0))
        XCTAssertEqual(viewModel.game.totalFloodCardsFlipped, 6)
        XCTAssertTrue(viewModel.game.gameStarted)
    }

    func testMoveActionPublishesTargetsAndReturnsToPlayerActionWhenActionsRemain() {
        let viewModel = GameViewModel(game: fixedGame(), phase: .playerAction(playerID: 0))

        XCTAssertTrue(viewModel.selectAction(.move))
        XCTAssertEqual(viewModel.phase, .selectingMove(playerID: 0, targets: [3, 10, 15, 8]))

        XCTAssertTrue(viewModel.moveActivePlayer(to: 8))
        XCTAssertEqual(viewModel.game.players[0].location, 8)
        XCTAssertEqual(viewModel.game.players[0].actionsRemaining, 2)
        XCTAssertEqual(viewModel.phase, .playerAction(playerID: 0))
    }

    func testMoveActionStartsTreasureDrawWhenNoActionsRemain() {
        var game = fixedGame()
        game.players[0].actionsRemaining = 1
        let viewModel = GameViewModel(game: game, phase: .playerAction(playerID: 0))

        XCTAssertTrue(viewModel.selectAction(.move))
        XCTAssertTrue(viewModel.moveActivePlayer(to: 8))
        XCTAssertEqual(viewModel.phase, .drawingTreasure(playerID: 0, drawnCount: 0))
    }

    func testEngineerPendingShoreUpKeepsShoreUpSelectionOpen() {
        var game = fixedGame()
        game.players = [Player(id: 0, role: .engineer, location: 14)]
        game.tilesByLocation[13]?.state = .flooded
        game.tilesByLocation[15]?.state = .flooded
        let viewModel = GameViewModel(game: game, phase: .playerAction(playerID: 0))

        XCTAssertTrue(viewModel.selectAction(.shoreUp))
        XCTAssertEqual(Set(currentTargets(from: viewModel.phase)), [13, 15])

        XCTAssertTrue(viewModel.shoreUp(location: 13))
        XCTAssertEqual(viewModel.game.players[0].actionsRemaining, 3)
        XCTAssertEqual(viewModel.phase, .selectingShoreUp(playerID: 0, targets: [15]))

        XCTAssertTrue(viewModel.shoreUp(location: 15))
        XCTAssertEqual(viewModel.game.players[0].actionsRemaining, 2)
        XCTAssertEqual(viewModel.phase, .playerAction(playerID: 0))
    }

    func testDrawingTwoTreasureCardsStartsFloodingPhase() {
        var game = fixedGame()
        game.treasureDeck = [.treasure(.fire), .sandbag]
        let viewModel = GameViewModel(game: game, phase: .drawingTreasure(playerID: 0, drawnCount: 0))

        XCTAssertEqual(viewModel.drawTreasureCard(), .card(.sandbag))
        XCTAssertEqual(viewModel.phase, .drawingTreasure(playerID: 0, drawnCount: 1))

        XCTAssertEqual(viewModel.drawTreasureCard(), .card(.treasure(.fire)))
        XCTAssertEqual(viewModel.phase, .flooding(remaining: viewModel.game.floodDrawCount, lastFloodedLocation: nil))
    }

    func testHandLimitAfterFirstTreasureDrawResumesDrawing() {
        var game = fixedGame()
        game.players = [
            Player(
                id: 0,
                role: .pilot,
                location: 9,
                hand: [.treasure(.fire), .treasure(.water), .treasure(.wind), .treasure(.earth), .sandbag]
            )
        ]
        game.treasureDeck = [.helicopter]
        let viewModel = GameViewModel(game: game, phase: .drawingTreasure(playerID: 0, drawnCount: 0))

        XCTAssertEqual(viewModel.drawTreasureCard(), .card(.helicopter))
        XCTAssertEqual(
            viewModel.phase,
            .discardingHandLimit(playerID: 0, continuation: .drawingTreasure(playerID: 0, drawnCount: 1))
        )
        XCTAssertTrue(viewModel.canDiscardForHandLimit(playerID: 0, cardIndex: 5))
        XCTAssertTrue(viewModel.discardForHandLimit(playerID: 0, cardIndex: 5))
        XCTAssertEqual(viewModel.game.players[0].hand.count, GameState.maximumHandSize)
        XCTAssertEqual(viewModel.game.treasureDiscard, [.helicopter])
        XCTAssertEqual(viewModel.phase, .drawingTreasure(playerID: 0, drawnCount: 1))
    }

    func testHandLimitAfterSecondTreasureDrawResumesFlooding() {
        var game = fixedGame()
        game.players = [
            Player(
                id: 0,
                role: .pilot,
                location: 9,
                hand: [.treasure(.fire), .treasure(.water), .treasure(.wind), .treasure(.earth), .sandbag]
            )
        ]
        game.treasureDeck = [.helicopter]
        let viewModel = GameViewModel(game: game, phase: .drawingTreasure(playerID: 0, drawnCount: 1))

        XCTAssertEqual(viewModel.drawTreasureCard(), .card(.helicopter))
        XCTAssertEqual(
            viewModel.phase,
            .discardingHandLimit(playerID: 0, continuation: .flooding)
        )
        XCTAssertTrue(viewModel.discardForHandLimit(playerID: 0, cardIndex: 0))
        XCTAssertEqual(viewModel.game.players[0].hand.count, GameState.maximumHandSize)
        XCTAssertEqual(viewModel.phase, .flooding(remaining: viewModel.game.floodDrawCount, lastFloodedLocation: nil))
    }

    func testHandLimitReactionCardRequiresExplicitPlayOrDiscardChoice() {
        var game = fixedGame()
        game.gameStarted = true
        game.players = [
            Player(
                id: 0,
                role: .pilot,
                location: 9,
                hand: [.treasure(.fire), .treasure(.water), .treasure(.wind), .treasure(.earth), .sandbag, .helicopter]
            )
        ]
        game.tilesByLocation[8]?.state = .flooded
        let viewModel = GameViewModel(game: game, phase: .discardingHandLimit(playerID: 0, continuation: .flooding))

        XCTAssertTrue(viewModel.selectHandLimitCardAction(playerID: 0, cardIndex: 4))
        XCTAssertEqual(viewModel.selectedHandLimitCard, HandLimitCardSelection(playerID: 0, cardIndex: 4))
        XCTAssertTrue(viewModel.canPlaySelectedHandLimitCard())

        XCTAssertTrue(viewModel.discardSelectedHandLimitCard())
        XCTAssertNil(viewModel.selectedHandLimitCard)
        XCTAssertEqual(viewModel.game.players[0].hand.count, GameState.maximumHandSize)
        XCTAssertEqual(viewModel.game.treasureDiscard, [.sandbag])
        if case .flooding = viewModel.phase {
            // expected
        } else {
            XCTFail("Expected flooding phase after discarding to hand limit")
        }
    }

    func testHandLimitReactionCardCanBePlayedInsteadOfDiscarded() {
        var game = fixedGame()
        game.gameStarted = true
        game.players = [
            Player(
                id: 0,
                role: .pilot,
                location: 9,
                hand: [.sandbag, .treasure(.water), .treasure(.wind), .treasure(.earth), .treasure(.fire), .treasure(.water)]
            )
        ]
        game.tilesByLocation[8]?.state = .flooded
        let viewModel = GameViewModel(game: game, phase: .discardingHandLimit(playerID: 0, continuation: .flooding))

        XCTAssertTrue(viewModel.selectHandLimitCardAction(playerID: 0, cardIndex: 0))
        XCTAssertTrue(viewModel.playSelectedHandLimitCard())
        XCTAssertEqual(viewModel.phase, .selectingSandbagTarget(playerID: 0, cardIndex: 0, targets: [8]))
        XCTAssertNil(viewModel.selectedHandLimitCard)

        XCTAssertTrue(viewModel.playSandbag(at: 8))
        XCTAssertEqual(viewModel.game.players[0].hand.count, GameState.maximumHandSize)
        XCTAssertEqual(viewModel.game.treasureDiscard, [.sandbag])
        if case .flooding = viewModel.phase {
            // expected
        } else {
            XCTFail("Expected flooding phase after playing the reaction card")
        }
    }

    func testWatersRisePausesUntilResolvedThenContinuesDrawCount() {
        var game = fixedGame()
        game.gameStarted = true
        game.treasureDeck = [.treasure(.fire), .watersRise]
        game.floodDiscard = [.goldGate]
        let viewModel = GameViewModel(game: game, phase: .drawingTreasure(playerID: 0, drawnCount: 0))

        XCTAssertEqual(viewModel.drawTreasureCard(), .watersRise)
        XCTAssertEqual(viewModel.game.waterLevel, 2)
        XCTAssertEqual(viewModel.game.treasureDiscard.last, .watersRise)
        XCTAssertEqual(viewModel.revealedTreasureCard, .watersRise)
        XCTAssertEqual(viewModel.phase, .resolvingWatersRise(playerID: 0, drawnCount: 0))

        XCTAssertTrue(viewModel.resolveWatersRise())
        XCTAssertNil(viewModel.revealedTreasureCard)
        XCTAssertEqual(viewModel.phase, .drawingTreasure(playerID: 0, drawnCount: 1))
    }

    func testTreasureDeckCountsAndDiscardLatestIgnoreWatersRise() {
        var game = fixedGame()
        game.players = [Player(id: 0, role: .pilot, location: 9)]
        game.treasureDiscard = [.helicopter, .watersRise]
        let viewModel = GameViewModel(game: game, phase: .playerAction(playerID: 0))

        XCTAssertEqual(viewModel.latestTreasureDiscard, .helicopter)
        XCTAssertNil(viewModel.revealedTreasureCard)
    }

    func testFloodingPhaseAdvancesToNextPlayer() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .pilot, location: 9, actionsRemaining: 0),
            Player(id: 1, role: .engineer, location: 2, actionsRemaining: 0)
        ]
        game.activePlayerIndex = 0
        game.floodDeck = [.goldGate, .ironGate]
        game.waterLevel = 0
        let viewModel = GameViewModel(game: game, phase: .flooding(remaining: 2, lastFloodedLocation: nil))

        XCTAssertNotNil(viewModel.floodNextTile())
        XCTAssertNotNil(viewModel.floodNextTile())
        XCTAssertEqual(viewModel.game.activePlayerIndex, 1)
        XCTAssertEqual(viewModel.game.players[1].actionsRemaining, 3)
        XCTAssertEqual(viewModel.phase, .playerAction(playerID: 1))
    }

    func testEventLogCapturesMoveDrawAndFloodTransitions() {
        var game = fixedGame()
        game.players = [Player(id: 0, role: .pilot, location: 9, actionsRemaining: 1)]
        let movementModel = GameViewModel(game: game, phase: .playerAction(playerID: 0))

        XCTAssertTrue(movementModel.selectAction(.move))
        XCTAssertTrue(movementModel.moveActivePlayer(to: 8))
        XCTAssertEqual(
            movementModel.recentEvents.first?.message,
            "Pilot moved to \(movementModel.game.tileName(at: 8))."
        )

        var treasureGame = fixedGame()
        treasureGame.players = [Player(id: 0, role: .pilot, location: 9)]
        treasureGame.treasureDeck = [.treasure(.fire)]
        let treasureModel = GameViewModel(game: treasureGame, phase: .drawingTreasure(playerID: 0, drawnCount: 0))
        XCTAssertEqual(treasureModel.drawTreasureCard(), .card(.treasure(.fire)))
        XCTAssertEqual(treasureModel.recentEvents.first?.message, "Drew fire card.")

        var floodGame = fixedGame()
        floodGame.floodDeck = [.goldGate]
        let floodModel = GameViewModel(game: floodGame, phase: .flooding(remaining: 1, lastFloodedLocation: nil))
        let floodedLocation = floodModel.floodNextTile()
        XCTAssertEqual(floodedLocation, 10)
        if let floodedLocation {
            XCTAssertEqual(
                floodModel.recentEvents.first?.message,
                "\(floodModel.game.tileName(at: floodedLocation)) flooded."
            )
        } else {
            XCTFail("Expected a flooded location")
        }
    }

    func testSmokeFlowThroughTurnDrawDiscardAndFlooding() {
        var game = fixedGame()
        game.players = [
            Player(
                id: 0,
                role: .pilot,
                location: 9,
                actionsRemaining: 3,
                hand: [.treasure(.fire), .treasure(.water), .treasure(.wind), .sandbag]
            ),
            Player(id: 1, role: .engineer, location: 2)
        ]
        game.activePlayerIndex = 0
        game.treasureDeck = [.watersRise, .treasure(.fire), .treasure(.earth)]
        game.floodDeck = [
            .bronzeGate, .copperGate, .caveOfEmbers,
            .caveOfShadows, .foolsLanding, .goldGate
        ]

        let viewModel = GameViewModel(game: game, phase: .playerAction(playerID: 0))

        XCTAssertTrue(viewModel.selectAction(.move))
        XCTAssertTrue(viewModel.moveActivePlayer(to: 8))
        XCTAssertEqual(viewModel.game.players[0].location, 8)

        XCTAssertTrue(viewModel.selectAction(.endTurn))
        XCTAssertEqual(viewModel.phase, .drawingTreasure(playerID: 0, drawnCount: 0))

        XCTAssertEqual(viewModel.drawTreasureCard(), .card(.treasure(.earth)))
        XCTAssertEqual(viewModel.phase, .drawingTreasure(playerID: 0, drawnCount: 1))

        XCTAssertEqual(viewModel.drawTreasureCard(), .card(.treasure(.fire)))
        XCTAssertEqual(
            viewModel.phase,
            .discardingHandLimit(playerID: 0, continuation: .flooding)
        )

        XCTAssertTrue(viewModel.discardForHandLimit(playerID: 0, cardIndex: 5))
        XCTAssertEqual(viewModel.game.players[0].hand.count, GameState.maximumHandSize)
        XCTAssertEqual(
            viewModel.phase,
            .flooding(remaining: viewModel.game.floodDrawCount, lastFloodedLocation: nil)
        )

        let floodCount = viewModel.game.floodDrawCount
        for _ in 0..<floodCount {
            XCTAssertNotNil(viewModel.floodNextTile())
        }

        XCTAssertEqual(viewModel.phase, .playerAction(playerID: 1))
        XCTAssertEqual(viewModel.game.activePlayerIndex, 1)
    }

    func testFloodingSunkTilePausesForPlayerToSwimThenContinuesFlooding() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .engineer, location: 10, actionsRemaining: 0),
            Player(id: 1, role: .pilot, location: 2, actionsRemaining: 0)
        ]
        game.activePlayerIndex = 0
        game.tilesByLocation[10]?.state = .flooded
        game.floodDeck = [.ironGate, .goldGate]
        let viewModel = GameViewModel(game: game, phase: .flooding(remaining: 2, lastFloodedLocation: nil))

        XCTAssertEqual(viewModel.floodNextTile(), 10)
        XCTAssertEqual(
            viewModel.phase,
            .swimmingToSafety(
                playerID: 0,
                targets: [16, 9],
                continuation: .flooding(remainingBeforeFlood: 2, lastFloodedLocation: 10)
            )
        )
        XCTAssertTrue(viewModel.swimPlayerToSafety(to: 16))
        XCTAssertEqual(viewModel.game.players[0].location, 16)
        XCTAssertEqual(viewModel.phase, .flooding(remaining: 1, lastFloodedLocation: 10))
    }

    func testMultiplePlayersOnSunkTileResolveBeforeFloodingContinues() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .engineer, location: 10, actionsRemaining: 0),
            Player(id: 1, role: .explorer, location: 10, actionsRemaining: 0)
        ]
        game.tilesByLocation[10]?.state = .flooded
        game.floodDeck = [.goldGate]
        let viewModel = GameViewModel(game: game, phase: .flooding(remaining: 1, lastFloodedLocation: nil))

        XCTAssertEqual(viewModel.floodNextTile(), 10)
        XCTAssertTrue(viewModel.swimPlayerToSafety(to: 16))
        XCTAssertEqual(
            viewModel.phase,
            .swimmingToSafety(
                playerID: 1,
                targets: [17, 16, 15, 9, 3],
                continuation: .flooding(remainingBeforeFlood: 1, lastFloodedLocation: 10)
            )
        )
        XCTAssertTrue(viewModel.swimPlayerToSafety(to: 15))
        XCTAssertEqual(viewModel.phase, .playerAction(playerID: 1))
    }

    func testPlayerDrownsWhenSunkTileHasNoSwimTargets() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .engineer, location: 10, actionsRemaining: 0)
        ]
        game.tilesByLocation[10]?.state = .flooded
        for location in [16, 9] {
            game.tilesByLocation[location]?.state = .sunk
        }
        game.floodDeck = [.goldGate]
        let viewModel = GameViewModel(game: game, phase: .flooding(remaining: 1, lastFloodedLocation: nil))

        XCTAssertEqual(viewModel.floodNextTile(), 10)
        XCTAssertEqual(viewModel.phase, .gameOver(.lost(.playerDrowned(0))))
    }

    func testSandbagCardSelectionTargetsFloodedTilesAndReturnsToActionPhase() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .pilot, location: 9, hand: [.sandbag])
        ]
        game.tilesByLocation[8]?.state = .flooded
        game.tilesByLocation[10]?.state = .flooded
        let viewModel = GameViewModel(game: game, phase: .playerAction(playerID: 0))

        XCTAssertTrue(viewModel.canPlayTreasureCard(playerID: 0, cardIndex: 0))
        XCTAssertTrue(viewModel.playTreasureCard(playerID: 0, cardIndex: 0))
        XCTAssertEqual(viewModel.phase, .selectingSandbagTarget(playerID: 0, cardIndex: 0, targets: [8, 10]))

        XCTAssertTrue(viewModel.playSandbag(at: 8))
        XCTAssertEqual(viewModel.game.tilesByLocation[8]?.state, .dry)
        XCTAssertTrue(viewModel.game.players[0].hand.isEmpty)
        XCTAssertEqual(viewModel.game.treasureDiscard, [.sandbag])
        XCTAssertEqual(viewModel.phase, .playerAction(playerID: 0))
    }

    func testReactionCardsAreVisibleForNonActivePlayersDuringGameplay() {
        var game = fixedGame()
        game.gameStarted = true
        game.players = [
            Player(id: 0, role: .pilot, location: 9, hand: [.treasure(.fire)]),
            Player(id: 1, role: .messenger, location: 14, hand: [.helicopter, .sandbag])
        ]
        let viewModel = GameViewModel(game: game, phase: .flooding(remaining: 2, lastFloodedLocation: nil))

        XCTAssertTrue(viewModel.canPlayReactionCard(playerID: 1, cardIndex: 0))
        XCTAssertTrue(viewModel.canPlayReactionCard(playerID: 1, cardIndex: 1))
        XCTAssertFalse(viewModel.canPlayReactionCard(playerID: 0, cardIndex: 0))
    }

    func testNonActivePlayerCanPlaySandbagDuringFloodingAndResumeFloodPhase() {
        var game = fixedGame()
        game.gameStarted = true
        game.players = [
            Player(id: 0, role: .pilot, location: 9),
            Player(id: 1, role: .messenger, location: 14, hand: [.sandbag])
        ]
        game.tilesByLocation[8]?.state = .flooded
        game.tilesByLocation[10]?.state = .flooded
        let viewModel = GameViewModel(game: game, phase: .flooding(remaining: 2, lastFloodedLocation: 8))

        XCTAssertTrue(viewModel.canPlayReactionCard(playerID: 1, cardIndex: 0))
        XCTAssertTrue(viewModel.playTreasureCard(playerID: 1, cardIndex: 0))
        XCTAssertEqual(viewModel.phase, .selectingSandbagTarget(playerID: 1, cardIndex: 0, targets: [8, 10]))

        XCTAssertTrue(viewModel.playSandbag(at: 10))
        XCTAssertEqual(viewModel.game.tilesByLocation[10]?.state, .dry)
        XCTAssertEqual(viewModel.game.treasureDiscard, [.sandbag])
        XCTAssertEqual(viewModel.phase, .flooding(remaining: 2, lastFloodedLocation: 8))
    }

    func testCancelSelectionReturnsToPlayerActionBeforeCommit() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .pilot, location: 9)
        ]
        let viewModel = GameViewModel(game: game, phase: .playerAction(playerID: 0))

        XCTAssertTrue(viewModel.selectAction(.move))
        XCTAssertTrue(viewModel.canCancelSelection)
        XCTAssertTrue(viewModel.cancelSelection())
        XCTAssertEqual(viewModel.phase, .playerAction(playerID: 0))
        XCTAssertEqual(viewModel.game.players[0].location, 9)
        XCTAssertEqual(viewModel.game.players[0].actionsRemaining, 3)
    }

    func testCancelSelectionAbandonsTreasureReceiverChoice() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .messenger, location: 9, hand: [.treasure(.fire)]),
            Player(id: 1, role: .pilot, location: 2)
        ]
        let viewModel = GameViewModel(game: game, phase: .playerAction(playerID: 0))

        XCTAssertTrue(viewModel.selectAction(.giveTreasure))
        XCTAssertTrue(viewModel.selectTreasureReceiver(1))
        XCTAssertTrue(viewModel.canCancelSelection)
        XCTAssertTrue(viewModel.cancelSelection())
        XCTAssertEqual(viewModel.phase, .playerAction(playerID: 0))
        XCTAssertEqual(viewModel.game.players[0].hand, [.treasure(.fire)])
        XCTAssertEqual(viewModel.game.players[1].hand, [])
    }

    func testGivingTreasureToOverLimitReceiverPromptsHandLimitDiscard() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .messenger, location: 9, hand: [.treasure(.fire)]),
            Player(
                id: 1,
                role: .pilot,
                location: 2,
                hand: [.treasure(.water), .treasure(.water), .treasure(.water), .treasure(.earth), .sandbag]
            )
        ]
        let viewModel = GameViewModel(game: game, phase: .playerAction(playerID: 0))

        XCTAssertTrue(viewModel.selectAction(.giveTreasure))
        XCTAssertTrue(viewModel.selectTreasureReceiver(1))
        XCTAssertTrue(viewModel.giveTreasure(cardIndex: 0))
        XCTAssertEqual(
            viewModel.phase,
            .discardingHandLimit(
                playerID: 1,
                continuation: .resume(.playerAction(playerID: 0))
            )
        )

        XCTAssertTrue(viewModel.discardForHandLimit(playerID: 1, cardIndex: 0))
        XCTAssertEqual(viewModel.phase, .playerAction(playerID: 0))
    }

    func testReactionCardCanBePlayedDuringHandLimitInsteadOfDiscarded() {
        var game = fixedGame()
        game.gameStarted = true
        game.players = [
            Player(id: 0, role: .pilot, location: 9),
            Player(
                id: 1,
                role: .messenger,
                location: 14,
                hand: [.sandbag, .treasure(.water), .treasure(.water), .treasure(.earth), .treasure(.fire), .treasure(.wind)]
            )
        ]
        game.tilesByLocation[8]?.state = .flooded
        let viewModel = GameViewModel(
            game: game,
            phase: .discardingHandLimit(
                playerID: 1,
                continuation: .resume(.playerAction(playerID: 0))
            )
        )

        XCTAssertTrue(viewModel.canPlayReactionCard(playerID: 1, cardIndex: 0))
        XCTAssertTrue(viewModel.playTreasureCard(playerID: 1, cardIndex: 0))
        XCTAssertEqual(viewModel.phase, .selectingSandbagTarget(playerID: 1, cardIndex: 0, targets: [8]))

        XCTAssertTrue(viewModel.playSandbag(at: 8))
        XCTAssertEqual(viewModel.game.tilesByLocation[8]?.state, .dry)
        XCTAssertEqual(viewModel.game.treasureDiscard, [.sandbag])
        XCTAssertEqual(
            viewModel.phase,
            .discardingHandLimit(
                playerID: 1,
                continuation: .resume(.playerAction(playerID: 0))
            )
        )
    }

    func testPilotSpecialFlyMovesToAnyNonSunkTileOncePerTurn() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .pilot, location: 9)
        ]
        game.tilesByLocation[8]?.state = .sunk
        let viewModel = GameViewModel(game: game, phase: .playerAction(playerID: 0))

        XCTAssertTrue(viewModel.canUseSpecialAction)
        XCTAssertTrue(viewModel.selectAction(.special))
        XCTAssertFalse(viewModel.selectableTileLocations.contains(8))
        XCTAssertTrue(viewModel.selectableTileLocations.contains(14))
        XCTAssertTrue(viewModel.pilotFly(to: 14))
        XCTAssertEqual(viewModel.game.players[0].location, 14)
        XCTAssertEqual(viewModel.game.players[0].actionsRemaining, 2)
        XCTAssertFalse(viewModel.canUseSpecialAction)
        XCTAssertEqual(viewModel.phase, .playerAction(playerID: 0))
    }

    func testNavigatorSpecialMovesOtherPlayerUpToTwoStepsForOneAction() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .navigator, location: 9),
            Player(id: 1, role: .engineer, location: 14, actionsRemaining: 1),
            Player(id: 2, role: .pilot, location: 2)
        ]
        let viewModel = GameViewModel(game: game, phase: .playerAction(playerID: 0))

        XCTAssertTrue(viewModel.canUseSpecialAction)
        XCTAssertTrue(viewModel.selectAction(.special))
        XCTAssertEqual(viewModel.phase, .selectingNavigatorTarget(playerID: 0, targetPlayerIDs: [1, 2]))
        XCTAssertTrue(viewModel.selectNavigatorTarget(1))
        XCTAssertEqual(
            viewModel.phase,
            .selectingNavigatorMove(playerID: 0, targetPlayerID: 1, remainingSteps: 2, hasMoved: false, targets: [8, 15, 20, 13])
        )

        XCTAssertTrue(viewModel.moveNavigatorTarget(to: 15))
        XCTAssertEqual(viewModel.game.players[1].location, 15)
        XCTAssertEqual(viewModel.game.players[1].actionsRemaining, 1)
        XCTAssertEqual(
            viewModel.phase,
            .selectingNavigatorMove(playerID: 0, targetPlayerID: 1, remainingSteps: 1, hasMoved: true, targets: [9, 16, 21, 14])
        )
        XCTAssertTrue(viewModel.finishNavigatorMove())
        XCTAssertEqual(viewModel.game.players[0].actionsRemaining, 2)
        XCTAssertEqual(viewModel.phase, .playerAction(playerID: 0))
    }

    func testNavigatorSecondStepCompletesAndStartsTreasureDrawWhenOutOfActions() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .navigator, location: 9, actionsRemaining: 1),
            Player(id: 1, role: .engineer, location: 14, actionsRemaining: 3)
        ]
        let viewModel = GameViewModel(game: game, phase: .playerAction(playerID: 0))

        XCTAssertTrue(viewModel.selectAction(.special))
        XCTAssertTrue(viewModel.selectNavigatorTarget(1))
        XCTAssertTrue(viewModel.moveNavigatorTarget(to: 15))
        XCTAssertTrue(viewModel.moveNavigatorTarget(to: 16))
        XCTAssertEqual(viewModel.game.players[1].location, 16)
        XCTAssertEqual(viewModel.game.players[1].actionsRemaining, 3)
        XCTAssertEqual(viewModel.game.players[0].actionsRemaining, 0)
        XCTAssertEqual(viewModel.phase, .drawingTreasure(playerID: 0, drawnCount: 0))
    }

    func testHelicopterCardMovesActivePlayerWithoutSpendingAction() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .pilot, location: 9, hand: [.helicopter])
        ]
        game.tilesByLocation[8]?.state = .sunk
        let viewModel = GameViewModel(game: game, phase: .playerAction(playerID: 0))

        XCTAssertTrue(viewModel.playTreasureCard(playerID: 0, cardIndex: 0))
        XCTAssertEqual(
            viewModel.phase,
            .selectingHelicopterSource(playerID: 0, cardIndex: 0, sourceLocations: [9])
        )
        XCTAssertTrue(viewModel.selectHelicopterSource(9))
        XCTAssertTrue(viewModel.toggleHelicopterPassenger(0))
        XCTAssertTrue(viewModel.confirmHelicopterPassengers())
        XCTAssertFalse(viewModel.selectableTileLocations.contains(8))
        XCTAssertTrue(viewModel.selectableTileLocations.contains(10))

        XCTAssertTrue(viewModel.playHelicopter(to: 10))
        XCTAssertEqual(viewModel.game.players[0].location, 10)
        XCTAssertEqual(viewModel.game.players[0].actionsRemaining, 3)
        XCTAssertEqual(viewModel.game.treasureDiscard, [.helicopter])
        XCTAssertEqual(viewModel.phase, .playerAction(playerID: 0))
    }

    func testHelicopterCanMoveSelectedPlayersFromActiveTile() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .pilot, location: 9, hand: [.helicopter]),
            Player(id: 1, role: .engineer, location: 9),
            Player(id: 2, role: .diver, location: 9),
            Player(id: 3, role: .messenger, location: 14)
        ]
        let viewModel = GameViewModel(game: game, phase: .playerAction(playerID: 0))

        XCTAssertTrue(viewModel.playTreasureCard(playerID: 0, cardIndex: 0))
        XCTAssertEqual(
            viewModel.phase,
            .selectingHelicopterSource(playerID: 0, cardIndex: 0, sourceLocations: [9])
        )

        XCTAssertTrue(viewModel.selectHelicopterSource(9))
        XCTAssertEqual(
            viewModel.phase,
            .selectingHelicopterPassengers(playerID: 0, cardIndex: 0, candidatePlayerIDs: [0, 1, 2], selectedPlayerIDs: [])
        )
        XCTAssertFalse(viewModel.toggleHelicopterPassenger(3))
        XCTAssertTrue(viewModel.toggleHelicopterPassenger(0))
        XCTAssertTrue(viewModel.toggleHelicopterPassenger(1))
        XCTAssertTrue(viewModel.confirmHelicopterPassengers())
        XCTAssertTrue(viewModel.playHelicopter(to: 14))

        XCTAssertEqual(viewModel.game.players[0].location, 14)
        XCTAssertEqual(viewModel.game.players[1].location, 14)
        XCTAssertEqual(viewModel.game.players[2].location, 9)
        XCTAssertEqual(viewModel.game.players[3].location, 14)
        XCTAssertEqual(viewModel.game.players[0].actionsRemaining, 3)
        XCTAssertEqual(viewModel.game.treasureDiscard, [.helicopter])
    }

    func testHelicopterLiftWinsImmediatelyWhenEveryoneIsOnFoolsLanding() {
        var game = fixedGame()
        game.collectedTreasures = Set(Treasure.allCases)
        game.players = [
            Player(id: 0, role: .pilot, location: 9, hand: [.helicopter]),
            Player(id: 1, role: .engineer, location: 9),
            Player(id: 2, role: .diver, location: 9),
            Player(id: 3, role: .messenger, location: 9)
        ]
        let viewModel = GameViewModel(game: game, phase: .playerAction(playerID: 0))

        XCTAssertTrue(viewModel.playTreasureCard(playerID: 0, cardIndex: 0))
        XCTAssertEqual(viewModel.game.treasureDiscard, [.helicopter])
        XCTAssertEqual(viewModel.phase, .gameOver(.won))
    }

    func testHelicopterPassengerSelectionRequiresAtLeastOnePassenger() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .pilot, location: 9, hand: [.helicopter]),
            Player(id: 1, role: .engineer, location: 9)
        ]
        let viewModel = GameViewModel(game: game, phase: .playerAction(playerID: 0))

        XCTAssertTrue(viewModel.playTreasureCard(playerID: 0, cardIndex: 0))
        XCTAssertTrue(viewModel.selectHelicopterSource(9))
        XCTAssertEqual(
            viewModel.phase,
            .selectingHelicopterPassengers(playerID: 0, cardIndex: 0, candidatePlayerIDs: [0, 1], selectedPlayerIDs: [])
        )
        XCTAssertFalse(viewModel.confirmHelicopterPassengers())
    }

    func testHelicopterCanStartFromAnyTileWithPlayers() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .pilot, location: 9, hand: [.helicopter]),
            Player(id: 1, role: .engineer, location: 14),
            Player(id: 2, role: .diver, location: 14)
        ]
        let viewModel = GameViewModel(game: game, phase: .playerAction(playerID: 0))

        XCTAssertTrue(viewModel.playTreasureCard(playerID: 0, cardIndex: 0))
        XCTAssertEqual(
            viewModel.phase,
            .selectingHelicopterSource(playerID: 0, cardIndex: 0, sourceLocations: [9, 14])
        )
        XCTAssertTrue(viewModel.selectHelicopterSource(14))
        XCTAssertEqual(
            viewModel.phase,
            .selectingHelicopterPassengers(playerID: 0, cardIndex: 0, candidatePlayerIDs: [1, 2], selectedPlayerIDs: [])
        )
        XCTAssertTrue(viewModel.toggleHelicopterPassenger(1))
        XCTAssertTrue(viewModel.confirmHelicopterPassengers())
        XCTAssertTrue(viewModel.playHelicopter(to: 10))

        XCTAssertEqual(viewModel.game.players[0].location, 9)
        XCTAssertEqual(viewModel.game.players[1].location, 10)
        XCTAssertEqual(viewModel.game.players[2].location, 14)
        XCTAssertEqual(viewModel.game.treasureDiscard, [.helicopter])
    }

    func testGiveTreasureRequiresEligibleReceiverAndTreasureCard() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .engineer, location: 9, hand: [.treasure(.fire), .sandbag]),
            Player(id: 1, role: .pilot, location: 9),
            Player(id: 2, role: .diver, location: 2)
        ]
        let viewModel = GameViewModel(game: game, phase: .playerAction(playerID: 0))

        XCTAssertTrue(viewModel.canGiveTreasure)
        XCTAssertTrue(viewModel.selectAction(.giveTreasure))
        XCTAssertEqual(viewModel.phase, .selectingTreasureReceiver(playerID: 0, receiverIDs: [1]))

        XCTAssertFalse(viewModel.selectTreasureReceiver(2))
        XCTAssertTrue(viewModel.selectTreasureReceiver(1))
        XCTAssertEqual(
            viewModel.phase,
            .selectingTreasureToGive(playerID: 0, receiverID: 1, receiverIDs: [1])
        )
        XCTAssertFalse(viewModel.canSelectTreasureToGive(playerID: 0, cardIndex: 1))
        XCTAssertTrue(viewModel.canSelectTreasureToGive(playerID: 0, cardIndex: 0))

        XCTAssertTrue(viewModel.giveTreasure(cardIndex: 0))
        XCTAssertEqual(viewModel.game.players[0].hand, [.sandbag])
        XCTAssertEqual(viewModel.game.players[1].hand, [.treasure(.fire)])
        XCTAssertEqual(viewModel.game.players[0].actionsRemaining, 2)
        XCTAssertEqual(viewModel.phase, .playerAction(playerID: 0))
    }

    func testMessengerCanGiveTreasureToAnyPlayer() {
        var game = fixedGame()
        game.players = [
            Player(id: 0, role: .messenger, location: 9, hand: [.treasure(.water)]),
            Player(id: 1, role: .pilot, location: 2),
            Player(id: 2, role: .diver, location: 33)
        ]
        let viewModel = GameViewModel(game: game, phase: .playerAction(playerID: 0))

        XCTAssertTrue(viewModel.selectAction(.giveTreasure))
        XCTAssertEqual(viewModel.phase, .selectingTreasureReceiver(playerID: 0, receiverIDs: [1, 2]))
        XCTAssertTrue(viewModel.selectTreasureReceiver(2))
        XCTAssertEqual(
            viewModel.phase,
            .selectingTreasureToGive(playerID: 0, receiverID: 2, receiverIDs: [1, 2])
        )
        XCTAssertTrue(viewModel.giveTreasure(cardIndex: 0))
        XCTAssertEqual(viewModel.game.players[2].hand, [.treasure(.water)])
    }

    private func currentTargets(from phase: GamePhase) -> [Int] {
        switch phase {
        case .selectingMove(_, let targets), .selectingShoreUp(_, let targets):
            targets
        default:
            []
        }
    }

    private func fixedGame() -> GameState {
        let orderedLocations = GameState.validSquares
        let orderedKinds: [TileKind] = [
            .bronzeGate, .copperGate, .caveOfEmbers, .caveOfShadows,
            .foolsLanding, .goldGate, .ironGate, .silverGate,
            .coralPalace, .tidalPalace, .howlingGarden, .whisperingGarden,
            .templeOfTheMoon, .templeOfTheSun, .breakersBridge, .cliffsOfAbandon,
            .crimsonForest, .dunesOfDeception, .lostLagoon, .mistyMarsh,
            .observatory, .phantomRock, .twilightHollow, .watchtower
        ]

        let tiles = Dictionary(
            uniqueKeysWithValues: zip(orderedLocations, orderedKinds).map {
                ($0.0, IslandTile(kind: $0.1))
            }
        )

        return GameState(
            tilesByLocation: tiles,
            floodDeck: orderedKinds,
            treasureDeck: GameState.makeTreasureDeck(),
            players: [Player(id: 0, role: .pilot, location: 9)]
        )
    }
}
