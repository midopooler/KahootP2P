import SwiftUI
import Combine

struct ClientPlayView: View {
    @EnvironmentObject var vm: GameViewModel
    @State private var timeRemaining: Double = 15
    @State private var timerCancellable: AnyCancellable?
    @State private var activeQuestionId: String?
    @State private var timerExpired = false

    var body: some View {
        ZStack {
            KahootBackground()

            VStack(spacing: 0) {
                if let engine = vm.clientEngine, let state = engine.questionState {
                    let expiredForThisQuestion = timerExpired && activeQuestionId == state.currentQuestionId
                    if state.phase == .finished {
                        finishedView(engine: engine)
                    } else if state.phase == .closed {
                        resultView(engine: engine)
                    } else if state.phase == .asking && expiredForThisQuestion {
                        timeoutWaitingView(engine: engine)
                    } else if state.phase == .asking {
                        questionView(engine: engine, state: state)
                    } else {
                        waitingView()
                    }
                } else {
                    waitingView()
                }
            }
        }
        .navigationBarHidden(true)
        .onReceive(Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()) { _ in
            guard let state = vm.clientEngine?.questionState else { return }
            let qId = state.currentQuestionId

            // New question arrived - immediately clear expired flag, then reset
            if qId != activeQuestionId {
                timerExpired = false
                timeRemaining = 15
                stopTimer()
                activeQuestionId = qId
                startTimer()
                return
            }

            // Phase left .asking - kill the countdown
            if state.phase != .asking {
                stopTimer()
            }
        }
        .onDisappear { stopTimer() }
    }

    private func startTimer() {
        stopTimer()
        timerExpired = false
        let limit = vm.clientEngine?.currentQuestion?.timeLimitSeconds ?? 15
        timeRemaining = Double(limit)

        timerCancellable = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                guard vm.clientEngine?.questionState?.phase == .asking else {
                    stopTimer()
                    return
                }
                if timeRemaining > 0.05 {
                    timeRemaining -= 0.05
                } else {
                    timeRemaining = 0
                    timerExpired = true
                    stopTimer()
                }
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    // MARK: - Waiting

    @ViewBuilder
    private func waitingView() -> some View {
        Spacer()
        ProgressView().tint(.white).scaleEffect(1.5)
        Text("Get Ready...")
            .font(.title2.bold())
            .foregroundColor(.white)
            .padding(.top, 16)
        Spacer()
    }

    // MARK: - Timer expired, waiting for host to close

    @ViewBuilder
    private func timeoutWaitingView(engine: ClientEngine) -> some View {
        Spacer()

        VStack(spacing: 16) {
            Image(systemName: "clock.fill")
                .font(.system(size: 60))
                .foregroundColor(K.yellow)
            Text("Time's Up!")
                .font(.title.bold())
                .foregroundColor(.white)

            Text("+0")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundColor(K.red)

            if let question = engine.currentQuestion {
                let correctIdx = question.correctChoiceIndex
                HStack(spacing: 8) {
                    Image(systemName: K.choiceShapes[correctIdx % 4])
                        .foregroundColor(K.choiceColors[correctIdx % 4])
                    Text("Answer: \(question.choices[correctIdx])")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(K.choiceColors[correctIdx % 4].opacity(0.3))
                .cornerRadius(8)
            }
        }

        Spacer()
    }

    // MARK: - Question (with timer)

    @ViewBuilder
    private func questionView(engine: ClientEngine, state: QuestionState) -> some View {
        if let question = engine.currentQuestion {
            let totalTime = Double(question.timeLimitSeconds)
            let progress = max(0, timeRemaining / totalTime)
            let timerColor: Color = timeRemaining > 5 ? K.green : (timeRemaining > 2 ? K.yellow : K.red)

            // Timer bar
            VStack(spacing: 0) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 6)
                        Rectangle()
                            .fill(timerColor)
                            .frame(width: geo.size.width * progress, height: 6)
                            .animation(.linear(duration: 0.05), value: progress)
                    }
                }
                .frame(height: 6)

                VStack(spacing: 8) {
                    HStack {
                        Text("Q\(state.currentQuestionIndex + 1)")
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                            Text("\(Int(ceil(timeRemaining)))")
                                .font(.system(.title3, design: .rounded, weight: .black))
                        }
                        .foregroundColor(timerColor)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    Text(question.text)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }
                .background(Color.white.opacity(0.08))
            }

            if engine.hasAnsweredCurrent {
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(K.green)
                Text("Answer Locked In!")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(.top, 8)
                Text("Waiting for time to run out...")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 4)
                Spacer()
            } else {
                Spacer(minLength: 8)
                let columns = [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ]
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(question.choices.indices, id: \.self) { index in
                        Button {
                            engine.submitAnswer(choiceIndex: index)
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: K.choiceShapes[index % 4])
                                    .font(.title)
                                Text(question.choices[index])
                                    .font(.body.bold())
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.7)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 100)
                            .background(K.choiceColors[index % 4])
                            .cornerRadius(8)
                            .shadow(color: K.choiceColors[index % 4].opacity(0.4), radius: 3, y: 2)
                        }
                    }
                }
                .padding(12)
            }
        }
    }

    // MARK: - Result (with correct answer reveal)

    @ViewBuilder
    private func resultView(engine: ClientEngine) -> some View {
        Spacer()

        if let result = engine.lastResult {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(result.isCorrect ? K.green : K.red)
                        .frame(width: 100, height: 100)
                    Image(systemName: result.isCorrect ? "checkmark" : "xmark")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.white)
                }

                Text(result.isCorrect ? "Correct!" : "Wrong!")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)

                Text("+\(result.points)")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(K.gold)

                if !result.isCorrect, let question = engine.currentQuestion {
                    let correctIdx = question.correctChoiceIndex
                    HStack(spacing: 8) {
                        Image(systemName: K.choiceShapes[correctIdx % 4])
                            .foregroundColor(K.choiceColors[correctIdx % 4])
                        Text("Correct: \(question.choices[correctIdx])")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(K.choiceColors[correctIdx % 4].opacity(0.3))
                    .cornerRadius(8)
                    .padding(.top, 4)
                }
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 60))
                    .foregroundColor(K.yellow)
                Text("Time's Up!")
                    .font(.title.bold())
                    .foregroundColor(.white)

                Text("+0")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(K.red)

                if let question = engine.currentQuestion {
                    let correctIdx = question.correctChoiceIndex
                    HStack(spacing: 8) {
                        Image(systemName: K.choiceShapes[correctIdx % 4])
                            .foregroundColor(K.choiceColors[correctIdx % 4])
                        Text("Answer: \(question.choices[correctIdx])")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(K.choiceColors[correctIdx % 4].opacity(0.3))
                    .cornerRadius(8)
                }
            }
        }

        Spacer()

        if let lb = engine.leaderboard {
            LeaderboardListView(entries: lb.entries, highlightPlayerId: engine.playerId)
                .padding(.horizontal)
        }

        Text("Next question coming...")
            .font(.caption)
            .foregroundColor(.white.opacity(0.5))
            .padding(.bottom, 16)
    }

    // MARK: - Finished

    @ViewBuilder
    private func finishedView(engine: ClientEngine) -> some View {
        Spacer()

        VStack(spacing: 16) {
            Text("Game Over!")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundColor(K.gold)

            if let lb = engine.leaderboard,
               let myEntry = lb.entries.first(where: { $0.playerId == engine.playerId }) {
                Text("#\(myEntry.rank)")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("\(myEntry.totalPoints) points")
                    .font(.title2)
                    .foregroundColor(K.gold)
            }
        }

        Spacer()

        if let lb = engine.leaderboard {
            LeaderboardListView(entries: lb.entries, highlightPlayerId: engine.playerId)
                .padding(.horizontal)
        }

        KahootButton(title: "Back to Home", color: K.red) {
            vm.leaveGame()
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 16)
    }
}
