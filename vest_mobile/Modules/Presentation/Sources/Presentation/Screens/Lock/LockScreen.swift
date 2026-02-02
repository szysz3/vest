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
        VStack(spacing: 16) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white)

            Text("vest")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
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
