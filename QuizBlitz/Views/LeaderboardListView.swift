import SwiftUI

struct LeaderboardListView: View {
    let entries: [LeaderboardEntry]
    var highlightPlayerId: String? = nil

    var body: some View {
        VStack(spacing: 6) {
            ForEach(entries.prefix(8)) { entry in
                HStack(spacing: 12) {
                    // Rank badge
                    ZStack {
                        Circle()
                            .fill(rankColor(entry.rank))
                            .frame(width: 32, height: 32)
                        Text("\(entry.rank)")
                            .font(.system(.caption, design: .rounded, weight: .black))
                            .foregroundColor(.white)
                    }

                    Text(entry.displayName)
                        .font(.body.bold())
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    Text("\(entry.totalPoints)")
                        .font(.system(.body, design: .rounded, weight: .black))
                        .foregroundColor(K.gold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHighlighted(entry) ? K.accent.opacity(0.5) : Color.white.opacity(0.08))
                )
            }
        }
    }

    private func isHighlighted(_ entry: LeaderboardEntry) -> Bool {
        guard let pid = highlightPlayerId else { return false }
        return entry.playerId == pid || entry.playerId.contains(pid) || pid.contains(entry.playerId)
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return K.gold
        case 2: return K.silver
        case 3: return K.bronze
        default: return Color.white.opacity(0.2)
        }
    }
}
