import SwiftUI

struct SchoolProfilePhotoConsentSheet: View {
    let store: SchoolProfileStore
    let model: SchoolProfilePhotoViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var uploadRequested = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let preview = model.preview {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("Voorbeeld van gekozen profielfoto")
                            .accessibilityIdentifier("profile-photo-preview")
                    }
                    Text("Toestemming voor upload").font(.title2.bold())
                    Text("Deze foto staat nu alleen in het geheugen van de app. Met ‘Upload en gebruik foto’ "
                         + "geef je toestemming om deze foto via onze backend naar Vibecode Storage te sturen.")
                    Text("De foto krijgt een openbare afbeeldingslink: iedereen met die link kan de foto bekijken. "
                         + "Alleen de link wordt lokaal bij je profiel opgeslagen. Je naam en andere profielvelden "
                         + "worden niet meegestuurd. De foto wordt verkleind en locatiegegevens worden verwijderd.")
                    Text("Annuleren verstuurt niets en behoudt je huidige foto. Later je profiel wissen "
                         + "verwijdert de lokale fotolink, niet de geüploade foto in de opslagdienst.")
                        .font(.footnote)
                    if let error = model.errorMessage {
                        Text(error)
                            .font(.callout)
                            .accessibilityIdentifier("profile-photo-upload-error")
                    }
                    if model.isUploading {
                        HStack(spacing: 10) {
                            ProgressView().tint(SchoolTheme.blue)
                            Text("Foto uploaden…")
                        }
                        .accessibilityIdentifier("profile-photo-uploading")
                    }
                    Button {
                        uploadRequested = true
                    } label: {
                        Text(model.errorMessage == nil ? "Upload en gebruik foto" : "Probeer upload opnieuw")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("profile-photo-upload-button")
                    .disabled(model.isBusy || !model.hasPendingPhoto || store.loadError != nil)
                }
                .foregroundStyle(SchoolTheme.ink)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(SchoolTheme.background)
            .navigationTitle("Profielfoto wijzigen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") {
                        model.discard()
                        dismiss()
                    }
                    .disabled(model.isUploading)
                    .accessibilityIdentifier("profile-photo-cancel-button")
                }
            }
            .tint(SchoolTheme.blue)
            .task(id: uploadRequested) {
                guard uploadRequested else { return }
                if await model.upload(to: store) { dismiss() }
                uploadRequested = false
            }
        }
        .interactiveDismissDisabled(model.isUploading)
    }
}
