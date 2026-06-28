import XCTest

final class ForbiddenIslandIpadUITests: XCTestCase {
    func testLaunchesIntoSetupAndCompletesTurnSetupFlow() {
        let app = XCUIApplication()
        startStandardGame(app)

        XCTAssertTrue(app.buttons["action.move"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["action.endTurn"].exists)
        XCTAssertTrue(app.otherElements["island.board"].exists)
    }

    func testLaunchesAndCanMoveThenEndTurnIntoTreasureDraw() {
        let app = XCUIApplication()
        startStandardGame(app)

        XCTAssertTrue(app.buttons["action.move"].waitForExistence(timeout: 5))
        app.buttons["action.move"].tap()

        let moveTarget = app.otherElements["Cliffs of Abandon, dry, location 8"]
        XCTAssertTrue(moveTarget.waitForExistence(timeout: 5))
        moveTarget.tap()

        XCTAssertTrue(app.buttons["action.endTurn"].waitForExistence(timeout: 5))
        app.buttons["action.endTurn"].tap()

        XCTAssertTrue(app.buttons["Draw Treasure Card"].waitForExistence(timeout: 5))
    }

    func testLaunchesAndCanReturnToSetupWithNewGame() {
        let app = XCUIApplication()
        startStandardGame(app)

        XCTAssertTrue(app.buttons["newGame.button"].waitForExistence(timeout: 5))
        app.buttons["newGame.button"].tap()

        XCTAssertTrue(app.buttons["playerCount.2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["rules.button"].exists)
        XCTAssertFalse(app.buttons["action.move"].exists)
    }

    func testLaunchesAndCanGiveTreasureFromAKnownScenario() {
        let app = XCUIApplication()
        app.launchArguments += ["-uitestScenario", "giveTreasure"]
        app.launch()

        XCTAssertTrue(app.buttons["action.giveTreasure"].waitForExistence(timeout: 5))
        app.buttons["action.giveTreasure"].tap()

        XCTAssertTrue(app.buttons["treasureReceiver.1"].waitForExistence(timeout: 5))
        app.buttons["treasureReceiver.1"].tap()

        let handCard = app.buttons["hand.0.card.0"]
        XCTAssertTrue(handCard.waitForExistence(timeout: 5))
        handCard.tap()

        XCTAssertFalse(handCard.exists)
        XCTAssertTrue(app.buttons["action.endTurn"].exists)
    }

    private func startStandardGame(_ app: XCUIApplication) {
        app.launch()

        XCTAssertTrue(app.buttons["rules.button"].waitForExistence(timeout: 5))
        app.buttons["rules.button"].tap()
        XCTAssertTrue(app.navigationBars["Rules"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()

        XCTAssertTrue(app.buttons["playerCount.2"].waitForExistence(timeout: 5))
        app.buttons["playerCount.2"].tap()

        XCTAssertTrue(app.buttons["difficulty.1"].waitForExistence(timeout: 5))
        app.buttons["difficulty.1"].tap()

        XCTAssertTrue(app.buttons["initialFlood.next"].waitForExistence(timeout: 5))
        for _ in 0..<6 {
            app.buttons["initialFlood.next"].tap()
        }
    }
}
