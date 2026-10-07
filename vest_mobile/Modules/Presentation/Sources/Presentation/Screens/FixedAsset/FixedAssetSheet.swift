import SwiftUI
import Core
import Domain

public struct FixedAssetSheet: View {
    @StateObject var viewModel: FixedAssetViewModel
    @Environment(\.dismiss) private var dismiss

    var onComplete: (() -> Void)?

    private let currencies = ["PLN", "EUR", "USD", "CHF", "GBP"]

    public init(viewModel: FixedAssetViewModel, onComplete: (() -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.onComplete = onComplete
    }

    private var activeColor: Color {
        viewModel.assetType == .cash ? VestTone.sage.color : VestTone.amber.color
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    assetTypeSelector

                    nameSection

                    amountSection

                    currencySection

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(VestActionColor.negative)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }

                    saveButton

                    if viewModel.mode.isEditing {
                        deleteButton
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(sheetBackground)
            .environment(\.colorScheme, .dark)
            .navigationTitle(viewModel.mode.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white.opacity(0.7))
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.mode.isEditing ? "Done" : "Save") {
                        Task {
                            if await viewModel.save() {
                                onComplete?()
                                dismiss()
                            }
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(viewModel.isFormValid ? activeColor : .white.opacity(0.3))
                    .disabled(!viewModel.isFormValid || viewModel.isSaving)
                }
            }
            .alert("Delete Fixed Asset", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task {
                        if await viewModel.delete() {
                            onComplete?()
                            dismiss()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this fixed asset? This action cannot be undone.")
            }
        }
    }

    private var assetTypeSelector: some View {
        HStack(spacing: 12) {
            assetTypeTile(
                type: .cash,
                title: "Cash",
                icon: "banknote.fill",
                color: VestTone.sage.color
            )

            assetTypeTile(
                type: .gold,
                title: "Gold",
                icon: "circle.hexagongrid.fill",
                color: VestTone.amber.color
            )
        }
    }

    private func assetTypeTile(type: AssetType, title: String, icon: String, color: Color) -> some View {
        let isSelected = viewModel.assetType == type
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.assetType = type
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? color.opacity(0.25) : Color.white.opacity(0.06))
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isSelected ? color : .white.opacity(0.4))
                }
                .frame(width: 32, height: 32)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.5))

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(color)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? color.opacity(0.12) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? color.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Asset Name")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))

            HStack {
                TextField(
                    viewModel.assetType == .cash ? "e.g. Emergency Fund, Safe Cash" : "e.g. 1 oz Krugerrand, 100g Bar",
                    text: $viewModel.details
                )
                .font(.body.weight(.medium))
                .autocorrectionDisabled()

                if !viewModel.details.isEmpty {
                    Button {
                        viewModel.details = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Value")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))

            HStack(spacing: 8) {
                TextField("0.00", text: $viewModel.amountText)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif

                Text(viewModel.currency)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(activeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(activeColor.opacity(0.15))
                    )
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }

    private var currencySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Currency")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))

            HStack(spacing: 8) {
                ForEach(currencies, id: \.self) { curr in
                    let isSelected = viewModel.currency == curr
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.currency = curr
                        }
                    } label: {
                        Text(curr)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isSelected ? .black : .white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isSelected ? activeColor : Color.white.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            Task {
                if await viewModel.save() {
                    onComplete?()
                    dismiss()
                }
            }
        } label: {
            HStack {
                Spacer()
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.black)
                } else {
                    Text(viewModel.mode.isEditing ? "Save Changes" : "Add Asset")
                        .font(.headline.weight(.bold))
                }
                Spacer()
            }
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(viewModel.isFormValid ? activeColor : Color.white.opacity(0.1))
            )
        }
        .disabled(!viewModel.isFormValid || viewModel.isSaving)
        .foregroundStyle(viewModel.isFormValid ? .black : .white.opacity(0.3))
        .padding(.top, 8)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            viewModel.showDeleteConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14))
                Text("Delete Fixed Asset")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(VestActionColor.negative)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(VestActionColor.negative.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(VestActionColor.negative.opacity(0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private var sheetBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.10, blue: 0.16),
                Color(red: 0.11, green: 0.13, blue: 0.20),
                Color(red: 0.16, green: 0.18, blue: 0.26)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
