import SwiftUI

enum K {
    static let bg = Color(red: 0.27, green: 0.11, blue: 0.55)
    static let bgDark = Color(red: 0.18, green: 0.07, blue: 0.40)
    static let accent = Color(red: 0.40, green: 0.20, blue: 0.85)

    static let red = Color(red: 0.89, green: 0.22, blue: 0.21)
    static let blue = Color(red: 0.11, green: 0.47, blue: 0.85)
    static let yellow = Color(red: 0.85, green: 0.65, blue: 0.08)
    static let green = Color(red: 0.15, green: 0.68, blue: 0.27)

    static let choiceColors: [Color] = [red, blue, yellow, green]
    static let choiceShapes: [String] = ["triangle.fill", "diamond.fill", "circle.fill", "square.fill"]

    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
    static let silver = Color(red: 0.75, green: 0.75, blue: 0.75)
    static let bronze = Color(red: 0.80, green: 0.50, blue: 0.20)
}

struct KahootBackground: View {
    var body: some View {
        LinearGradient(
            colors: [K.bg, K.bgDark],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

struct KahootButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(color)
                .foregroundColor(.white)
                .cornerRadius(8)
                .shadow(color: color.opacity(0.4), radius: 4, y: 3)
        }
    }
}

struct ChoiceButton: View {
    let index: Int
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: K.choiceShapes[index % 4])
                    .font(.title2)
                Text(text)
                    .font(.body.bold())
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(K.choiceColors[index % 4])
            .foregroundColor(.white)
            .cornerRadius(8)
            .shadow(color: K.choiceColors[index % 4].opacity(0.4), radius: 3, y: 2)
        }
    }
}
