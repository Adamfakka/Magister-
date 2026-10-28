import SwiftUI
import Foundation
import Observation
import PhotosUI

/// Fictional starting values. This profile is never connected to a school account.
struct SchoolProfileData: Codable {
    var name = "Sam de Vries"
    var className = "HAVO/VWO 2 – Klas 2A"
    var privateEmail = ""
    var schoolEmail = "sam@leerling.example"
    var mobile = ""
    var officialName = "Sam de Vries"
    var birthdate = ""
    var address = ""
    var study = "HAVO/VWO – Leerjaar 2"
    var appearance = "Donker"
    // Optional for backwards-compatible decoding of profiles saved before photo support.
    var photoURL: String? = nil
}

@Observable @MainActor
final class SchoolProfileStore: Codable {
    static let persistenceKey = "local-school-profile-v1"
    static let appearanceOptions = ["Volg instelling toestel", "Licht", "Donker"]

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var persistenceAllowed = true
    @ObservationIgnored private(set) var photoRevision = 0
    private(set) var loadError: String?
    var profile: SchoolProfileData {
        didSet { persist() }
    }

    // Direct bindings shared by the profile editor and the root drawer.
    var photoURL: String? {
        get { profile.photoURL }
        set {
            guard persistenceAllowed else { return }
            photoRevision += 1
            profile.photoURL = newValue
        }
    }

    @discardableResult
    func setPhotoURL(_ url: String, expectedRevision: Int) -> Bool {
        guard persistenceAllowed, photoRevision == expectedRevision else { return false }
        photoURL = url
        return true
    }

    var name: String { get { profile.name } set { profile.name = newValue } }
    var className: String { get { profile.className } set { profile.className = newValue } }
    var privateEmail: String { get { profile.privateEmail } set { profile.privateEmail = newValue } }
    var schoolEmail: String { get { profile.schoolEmail } set { profile.schoolEmail = newValue } }
    var mobile: String { get { profile.mobile } set { profile.mobile = newValue } }
    var officialName: String { get { profile.officialName } set { profile.officialName = newValue } }
    var birthdate: String { get { profile.birthdate } set { profile.birthdate = newValue } }
    var address: String { get { profile.address } set { profile.address = newValue } }
    var study: String { get { profile.study } set { profile.study = newValue } }
    var appearance: String {
        get { profile.appearance }
        set {
            guard persistenceAllowed, Self.appearanceOptions.contains(newValue) else { return }
            profile.appearance = newValue
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.persistenceKey) {
            do {
                var saved = try JSONDecoder().decode(SchoolProfileData.self, from: data)
                if !Self.appearanceOptions.contains(saved.appearance) { saved.appearance = "Donker" }
                profile = saved
            } catch {
                profile = SchoolProfileData()
                persistenceAllowed = false
                loadError = "Je opgeslagen profiel kon niet worden gelezen. De oorspronkelijke gegevens zijn bewaard; "
                    + "wijzigen en opslaan zijn geblokkeerd. Je ziet nu voorbeeldgegevens. Alleen via ‘Mijn account’ "
                    + "kun je het profiel bewust wissen en opnieuw beginnen."
                print("[SchoolProfileStore] Could not read local profile; preserving original bytes: \(error)")
            }
        } else {
            profile = SchoolProfileData()
        }
    }

    init(from decoder: Decoder) throws {
        defaults = .standard
        var decoded = try SchoolProfileData(from: decoder)
        if !Self.appearanceOptions.contains(decoded.appearance) { decoded.appearance = "Donker" }
        profile = decoded
    }

    func encode(to encoder: Encoder) throws {
        try profile.encode(to: encoder)
    }

    func save(_ value: SchoolProfileData) {
        guard persistenceAllowed else {
            print("[SchoolProfileStore] Save blocked to preserve unreadable profile")
            return
        }
        var value = value
        // An editor draft must not replace a photo changed after the editor opened.
        value.photoURL = profile.photoURL
        if !Self.appearanceOptions.contains(value.appearance) { value.appearance = "Donker" }
        profile = value
        print("[SchoolProfileStore] Profile saved on this device")
    }

    func clearProfile() {
        // Invalidate any in-flight upload so it cannot restore a cleared reference.
        photoRevision += 1
        var empty = SchoolProfileData()
        empty.name = "Leerling"
        empty.className = ""
        empty.privateEmail = ""
        empty.schoolEmail = ""
        empty.mobile = ""
        empty.officialName = ""
        empty.birthdate = ""
        empty.address = ""
        empty.study = ""
        empty.appearance = appearance
        // Only the explicit, confirmed clear action may replace unreadable saved bytes.
        persistenceAllowed = true
        loadError = nil
        profile = empty
        print("[SchoolProfileStore] Local profile cleared; theme preserved")
    }

    func persist() {
        guard persistenceAllowed else {
            print("[SchoolProfileStore] Persistence blocked to preserve unreadable profile")
            return
        }
        do {
            let data = try JSONEncoder().encode(profile)
            defaults.set(data, forKey: Self.persistenceKey)
        } catch {
            print("[SchoolProfileStore] Could not save local profile: \(error)")
        }
    }
}

/// Content only: the root supplies the navigation/header chrome.
struct ProfileModule: View {
    let store: SchoolProfileStore
    @State private var activeSheet: ProfileSheet?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoModel = SchoolProfilePhotoViewModel()

    private enum ProfileSheet: String, Identifiable {
        case editor, consent, account, photo
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let error = store.loadError {
                    Text(error)
                        .font(.system(size: 15))
                        .foregroundStyle(SchoolTheme.ink)
                        .padding(12)
                        .accessibilityIdentifier("profile-load-error")
                }
                HStack(spacing: 10) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        SchoolProfileAvatar(url: store.photoURL, size: 54)
                            .accessibilityHidden(true)
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(SchoolTheme.blue, in: Circle())
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Profielfoto wijzigen")
                    .accessibilityHint("Kies een foto. Uploaden gebeurt pas na je toestemming.")
                    .accessibilityIdentifier("profile-photo-button")
                    .disabled(store.loadError != nil || photoModel.isBusy || activeSheet != nil)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.name)
                            .font(.system(size: 19))
                            .foregroundStyle(SchoolTheme.blue)
                        Text(displayValue(store.className))
                            .font(.system(size: 15))
                            .lineLimit(2)
                            .foregroundStyle(SchoolTheme.ink)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.top, 9)

                if photoModel.isPreparing {
                    ProgressView("Foto voorbereiden…")
                        .font(.footnote)
                        .padding(12)
                        .accessibilityIdentifier("profile-photo-preparing")
                }
                if let error = photoModel.errorMessage, activeSheet != .photo {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(SchoolTheme.ink)
                        .padding(12)
                        .accessibilityIdentifier("profile-photo-error")
                }

                HStack {
                    Spacer()
                    Button { activeSheet = .editor } label: {
                        Text("Wijzig").underline()
                            .font(.system(size: 17))
                            .frame(minWidth: 60, minHeight: 44)
                    }
                    .foregroundStyle(SchoolTheme.blue)
                    .accessibilityIdentifier("profile-edit-button")
                    .disabled(store.loadError != nil || photoModel.isBusy)
                }
                .padding(.horizontal, 12)
                profileRule

                VStack(alignment: .leading, spacing: 0) {
                    infoRow("Toestemming gebruik gegevens", value: "Profiel lokaal; foto na toestemming", sheet: .consent)
                    infoRow("Mijn account", value: "Beheer lokaal profiel", sheet: .account)
                    SchoolProfileTextRow(label: "E-mailadres (Privé)", value: displayValue(store.privateEmail), separator: false)
                    SchoolProfileTextRow(label: "E-mailadres (School)", value: displayValue(store.schoolEmail))
                    SchoolProfileTextRow(label: "Mobiel nummer", value: displayValue(store.mobile))
                    SchoolProfileTextRow(label: "Naam", value: displayValue(store.name))
                    SchoolProfileTextRow(label: "Officiële naam", value: displayValue(store.officialName))
                    SchoolProfileTextRow(label: "Geboortedatum", value: displayValue(store.birthdate))
                    SchoolProfileTextRow(label: "Adres", value: displayValue(store.address))
                    SchoolProfileTextRow(label: "Studie", value: displayValue(store.study), separator: false)
                }
                .padding(.horizontal, 9)
            }
            .padding(.bottom, 20)
        }
        .background(SchoolTheme.background)
        .foregroundStyle(SchoolTheme.ink)
        .task(id: selectedPhoto) {
            guard let item = selectedPhoto else { return }
            await photoModel.prepare(item)
            if photoModel.hasPendingPhoto { activeSheet = .photo }
            selectedPhoto = nil
        }
        .sheet(item: $activeSheet, onDismiss: { photoModel.discard() }) { sheet in
            switch sheet {
            case .editor:
                SchoolProfileEditor(store: store)
            case .consent:
                SchoolProfileInformationSheet(
                    title: "Gebruik van gegevens",
                    paragraphs: [
                        "Je profielvelden, zoals naam en contactgegevens, blijven in de lokale opslag van deze app. "
                            + "Ze worden niet naar een school of accountdienst verstuurd.",
                        "Alleen een profielfoto wordt na jouw expliciete toestemming via onze backend "
                            + "naar Vibecode Storage geüpload. De foto krijgt een openbare afbeeldingslink: "
                            + "iedereen met die link kan de foto bekijken. Alleen die link wordt bij je lokale "
                            + "profiel bewaard. Bij het uploaden verwijderen we locatiegegevens uit de foto.",
                        "Er is geen officiële Magister-koppeling, schooltoestemming of aanmelding. "
                            + "De eerste voorbeeldgegevens zijn fictief. Gebruik bij voorkeur fictieve gegevens.",
                        "In ‘Mijn account’ kun je de profielvelden en de lokale fotolink wissen. "
                            + "Dat verwijdert de geüploade foto niet uit de opslagdienst. "
                            + "Een eventuele toestelback-up kan lokale appgegevens bevatten."
                    ]
                )
            case .account:
                SchoolLocalAccountSheet(store: store)
            case .photo:
                SchoolProfilePhotoConsentSheet(store: store, model: photoModel)
            }
        }
    }

    private func infoRow(_ title: String, value: String, sheet: ProfileSheet) -> some View {
        Button { activeSheet = sheet } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 18, weight: .bold))
                    Text(value).font(.system(size: 18))
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right").font(.system(size: 18, weight: .medium))
            }
            .foregroundStyle(SchoolTheme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(photoModel.isBusy)
        .accessibilityIdentifier("profile-\(sheet.rawValue)-button")
        .overlay(alignment: .bottom) { profileRule.padding(.horizontal, 3) }
    }

    private var profileRule: some View {
        Rectangle().fill(SchoolTheme.divider).frame(height: 0.5)
    }

    private func displayValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "–" : value
    }
}

private struct SchoolProfileTextRow: View {
    let label: String
    let value: String
    var separator = true

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 18, weight: .bold))
            Text(value).font(.system(size: 18))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .foregroundStyle(SchoolTheme.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            if separator {
                Rectangle().fill(SchoolTheme.divider).frame(height: 0.5).padding(.horizontal, 3)
            }
        }
    }
}

private struct SchoolProfileEditor: View {
    let store: SchoolProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SchoolProfileData

    init(store: SchoolProfileStore) {
        self.store = store
        _draft = State(initialValue: store.profile)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let error = store.loadError {
                    Section { Text(error).accessibilityIdentifier("profile-editor-load-error") }
                }
                Section("Profiel") {
                    TextField("Naam", text: $draft.name).accessibilityIdentifier("profile-name-field")
                    TextField("Klas", text: $draft.className).accessibilityIdentifier("profile-class-field")
                    TextField("Officiële naam", text: $draft.officialName)
                    TextField("Studie", text: $draft.study)
                }
                Section("Contactgegevens") {
                    TextField("E-mailadres (Privé)", text: $draft.privateEmail)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("E-mailadres (School)", text: $draft.schoolEmail)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Mobiel nummer", text: $draft.mobile).keyboardType(.phonePad)
                }
                Section("Overige gegevens") {
                    TextField("Geboortedatum, bijvoorbeeld 1 januari 2012", text: $draft.birthdate)
                    TextField("Adres", text: $draft.address, axis: .vertical).lineLimit(2...4)
                }
                Section {
                    Text("Alleen op dit toestel. Gebruik fictieve gegevens; dit verandert geen gegevens bij een school.")
                        .font(.footnote)
                }
            }
            .foregroundStyle(SchoolTheme.ink)
            .scrollContentBackground(.hidden)
            .background(SchoolTheme.background)
            .navigationTitle("Gegevens wijzigen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar") {
                        // Keep any theme change that happened after the editor opened.
                        draft.appearance = store.appearance
                        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.save(draft)
                        dismiss()
                    }
                    .disabled(store.loadError != nil || draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("profile-save-button")
                }
            }
            .tint(SchoolTheme.blue)
        }
        .interactiveDismissDisabled()
    }
}

struct ThemeSettingsView: View {
    let store: SchoolProfileStore

    var body: some View {
        VStack(spacing: 0) {
            if let error = store.loadError {
                Text(error)
                    .font(.system(size: 15))
                    .foregroundStyle(SchoolTheme.ink)
                    .padding(12)
                    .accessibilityIdentifier("theme-profile-load-error")
            }
            ForEach(SchoolProfileStore.appearanceOptions, id: \.self) { option in
                Button {
                    store.appearance = option
                    print("[SchoolProfileStore] Appearance saved: \(option)")
                } label: {
                    HStack {
                        Text(option).font(.system(size: 19))
                        Spacer()
                        if store.appearance == option {
                            Image(systemName: "checkmark")
                                .font(.system(size: 22, weight: .heavy))
                        }
                    }
                    .foregroundStyle(SchoolTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                    .padding(.horizontal, 17)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(option == "Donker" ? "theme-dark-button" : option == "Licht" ? "theme-light-button" : "theme-device-button")
                .accessibilityAddTraits(store.appearance == option ? [.isSelected] : [])
                .disabled(store.loadError != nil)
                Rectangle().fill(SchoolTheme.divider).frame(height: 0.5)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SchoolTheme.background)
    }
}

struct AboutSchoolView: View {
    private var version: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SchoolProfileTextRow(label: "Applicatie", value: "Schoolagenda – lokale demo")
                SchoolProfileTextRow(label: "Uitgever", value: "Onafhankelijk demo-project")
                SchoolProfileTextRow(label: "Versie", value: version)
                SchoolProfileTextRow(label: "Feedback", value: "Dit is een lokaal prototype. Er is geen feedback-mail of klantenservice aan gekoppeld.")
                SchoolProfileTextRow(
                    label: "Veelgestelde vragen",
                    value: "Je kunt je profielvelden via ‘Wijzig’ aanpassen; deze blijven lokaal. "
                        + "Tik op je avatar om na toestemming een foto te uploaden. "
                        + "Het gekozen thema vind je onder ‘Thema’s’."
                )
                SchoolProfileTextRow(
                    label: "Beveiliging en privacy",
                    value: "Geen officiële schoollogin of verbinding met Magister. Profielvelden blijven lokaal. "
                        + "Alleen een gekozen profielfoto wordt na toestemming naar Vibecode Storage geüpload "
                        + "en krijgt een openbare link. ‘Mijn account’ wist de lokale velden en fotolink, "
                        + "niet de foto in de opslagdienst. Gebruik bij voorkeur fictieve gegevens.",
                    separator: false
                )
                Text("Deze app is niet uitgegeven door of verbonden aan Sanoma of Magister.")
                    .font(.system(size: 14))
                    .foregroundStyle(SchoolTheme.ink.opacity(0.7))
                    .padding(.top, 12)
            }
            .padding(.horizontal, 9)
            .padding(.top, 3)
            .padding(.bottom, 24)
        }
        .foregroundStyle(SchoolTheme.ink)
        .background(SchoolTheme.background)
    }
}

private struct SchoolProfileInformationSheet: View {
    let title: String
    let paragraphs: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(paragraphs, id: \.self) { text in
                        Text(text).font(.body).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .foregroundStyle(SchoolTheme.ink)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(SchoolTheme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gereed") { dismiss() }
                }
            }
            .tint(SchoolTheme.blue)
        }
    }
}

private struct SchoolLocalAccountSheet: View {
    let store: SchoolProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Lokaal profiel").font(.title2.bold())
                    Text("Je bent niet ingelogd bij een school. Dit profiel is alleen voor deze onafhankelijke demo. Er is geen extern account, wachtwoord of abonnement.")
                    Text("Met ‘Wijzig’ pas je je lokale profielvelden aan. Tik op je avatar om een foto te kiezen. "
                         + "Alleen na toestemming wordt die foto geüpload. Je kunt hieronder alle profielvelden "
                         + "en de lokale fotolink wissen. De geüploade foto blijft bij de opslagdienst. "
                         + "Je agenda, cijfers en thema blijven behouden.")
                    Button("Profielgegevens wissen", role: .destructive) { confirmClear = true }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("profile-clear-button")
                }
                .foregroundStyle(SchoolTheme.ink)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(SchoolTheme.background)
            .navigationTitle("Mijn account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Gereed") { dismiss() } }
            }
            .confirmationDialog("Profielgegevens op dit toestel wissen?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Wis profielgegevens", role: .destructive) { store.clearProfile(); dismiss() }
                Button("Annuleer", role: .cancel) { }
            } message: {
                Text("Dit wist je lokale profielvelden en fotolink en kan niet ongedaan worden gemaakt. "
                     + "Een geüploade foto blijft in de opslagdienst. Je agenda, cijfers en thema worden niet gewist.")
            }
            .tint(SchoolTheme.blue)
        }
    }
}
