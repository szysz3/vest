import SwiftUI

public struct LockScreen: View {
    @StateObject var viewModel: LockViewModel

    public init(viewModel: LockViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ZStack {
            VestGradientBackground()

            VStack(spacing: 32) {
                Spacer()

                appBranding

                Spacer()

                if let error = viewModel.error {
                    errorView(message: error)
                }

                unlockButton

                Spacer()
                    .frame(height: 60)
            }
            .padding(.horizontal, 40)
        }
        .environment(\.colorScheme, .dark)
        .task {
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
        .buttonStyle(.plain)
    }
}
