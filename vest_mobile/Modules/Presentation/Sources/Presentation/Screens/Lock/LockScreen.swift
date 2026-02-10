import SwiftUI

public struct LockScreen: View {
    @StateObject var viewModel: LockViewModel
    @State private var logoAppeared = false
    @State private var buttonAppeared = false

    public init(viewModel: LockViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ZStack {
            VestGradientBackground()

            VStack(spacing: 32) {
                Spacer()

                appBranding
                    .opacity(logoAppeared ? 1 : 0)
                    .scaleEffect(logoAppeared ? 1 : 0.8)

                Spacer()

                if let error = viewModel.error {
                    errorView(message: error)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                unlockButton
                    .opacity(buttonAppeared ? 1 : 0)
                    .offset(y: buttonAppeared ? 0 : 24)

                Spacer()
                    .frame(height: 60)
            }
            .padding(.horizontal, 40)
        }
        .environment(\.colorScheme, .dark)
        .animation(.easeOut(duration: 0.35), value: viewModel.error != nil)
        .task {
            withAnimation(.easeOut(duration: 0.7)) {
                logoAppeared = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                buttonAppeared = true
            }
            await viewModel.authenticate()
        }
    }

    private var appBranding: some View {
        VStack(spacing: 20) {
            Image("VestIcon", bundle: .module)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(color: Color(red: 0.2, green: 0.55, blue: 0.9).opacity(0.4), radius: 30, x: 0, y: 4)
                .shadow(color: Color(red: 0.25, green: 0.8, blue: 0.55).opacity(0.2), radius: 20, x: 0, y: 2)

            Text("vest")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }

    private func errorView(message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(VestActionColor.negative)
            .multilineTextAlignment(.center)
    }

    private var unlockButton: some View {
        Button {
            Task { await viewModel.authenticate() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "faceid")
                    .font(.system(size: 20))
                Text(viewModel.error != nil ? "Retry with Face ID" : "Unlock with Face ID")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
