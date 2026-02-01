import SwiftUI

struct VestGradientBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.12),
                    Color(red: 0.10, green: 0.12, blue: 0.18),
                    Color(red: 0.16, green: 0.18, blue: 0.26)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.22, green: 0.46, blue: 0.78).opacity(0.35))
                .frame(width: 280, height: 280)
                .blur(radius: 40)
                .offset(x: 140, y: -230)

            RoundedRectangle(cornerRadius: 80, style: .continuous)
                .fill(Color(red: 0.90, green: 0.66, blue: 0.44).opacity(0.18))
                .frame(width: 240, height: 240)
                .blur(radius: 30)
                .offset(x: -160, y: 260)
        }
    }
}

struct VestCardBackground: View {
    var cornerRadius: CGFloat = 24
    var fillOpacity: Double = 0.06
    var strokeOpacity: Double = 0.08

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(fillOpacity))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(strokeOpacity), lineWidth: 1)
            )
    }
}
