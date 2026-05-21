import SwiftUI

struct LocationSearchView: View {
    @ObservedObject var viewModel: PollenViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                VStack(spacing: 16) {
                    TextField("Search city or ZIP", text: $viewModel.searchText)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .padding(16)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.12)))
                        .foregroundStyle(.white)
                        .submitLabel(.search)
                        .onSubmit { Task { await viewModel.searchLocations() } }
                        .onChange(of: viewModel.searchText) { _, newValue in
                            Task {
                                try? await Task.sleep(nanoseconds: 400_000_000)
                                if newValue == viewModel.searchText { await viewModel.searchLocations() }
                            }
                        }

                    if viewModel.isSearching {
                        ProgressView().tint(.white)
                    }

                    List(viewModel.searchResults) { result in
                        Button {
                            Task {
                                await viewModel.select(result)
                                dismiss()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.name).font(.headline).foregroundStyle(.white)
                                Text([result.admin1, result.country].compactMap { $0 }.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(Color.clear)
                    }
                    .scrollContentBackground(.hidden)
                }
                .padding()
            }
            .navigationTitle("Choose Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}
