import SwiftUI

struct HostPlayView: View {
    @EnvironmentObject var vm: GameViewModel

    var body: some View {
        ZStack {
            KahootBackground()

            VStack(spacing: 16) {
                if let engine = vm.hostEngine, let state = engine.questionState {
                    switch state.phase {
                    case .asking:
                        askingView(engine: engine, state: state)
                    case .closed:
                        closedView(engine: engine, state: state)
                    case .finished:
                        finishedView(engine: engine)
                    default:
                        ProgressView().tint(.white)
                    }
                } else {
                    ProgressView().tint(.white)
                }
            }
        }
        .navigationBarHidden(true)
    }

    @ViewBuilder
    private func askingView(engine: HostEngine, state: QuestionState) -> some View {
        let qIndex = state.currentQuestionIndex
        let question = engine.currentQuestionIndex < 10 ? "Q\(qIndex + 1) of \(engine.game.questionCount)" : ""

        VStack(spacing: 16) {
            Text(question)
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 24)

            Spacer()

            Image(systemName: "hourglass")
                .font(.system(size: 60))
                .foregroundColor(K.gold)

            Text("Waiting for answers...")
                .font(.title2.bold())
                .foregroundColor(.white)

            Text("\(engine.players.count) players")
                .font(.headline)
                .foregroundColor(.white.opacity(0.6))

            Spacer()

            KahootButton(title: "Close Question Early", color: K.yellow) {
                try? engine.closeCurrentQuestion()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
    }

    @ViewBuilder
    private func closedView(engine: HostEngine, state: QuestionState) -> some View {
        VStack(spacing: 8) {
            Text("Question \(state.currentQuestionIndex + 1) Results")
                .font(.headline)
                .foregroundColor(.white.opacity(0.7))
                .padding(.top, 24)
        }

        if let lb = engine.leaderboard {
            LeaderboardListView(entries: lb.entries)
                .padding(.horizontal)
        }

        Spacer()

        KahootButton(title: "Next Question", color: K.accent) {
            vm.hostNextQuestion()
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private func finishedView(engine: HostEngine) -> some View {
        Spacer()

        VStack(spacing: 12) {
            Text("Game Over!")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundColor(K.gold)

            if let lb = engine.leaderboard, let winner = lb.entries.first {
                Text(winner.displayName)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("\(winner.totalPoints) pts")
                    .font(.title2)
                    .foregroundColor(K.gold)
            }
        }

        Spacer()

        if let lb = engine.leaderboard {
            LeaderboardListView(entries: lb.entries)
                .padding(.horizontal)
        }

        KahootButton(title: "Back to Home", color: K.red) {
            vm.leaveGame()
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 16)
    }
}
