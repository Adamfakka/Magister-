import SwiftUI
import Observation

struct SchoolDocument: Identifiable, Codable {
    var id = UUID()
    var module: String
    var title: String
    var subject = ""
    var content = ""
    var status = "Openstaand"
    var folder = "Mijn ELO-documenten"
}

@Observable @MainActor
final class SchoolLibraryStore {
    var documents: [SchoolDocument]
    var loadError: String?
    private let key = "local-school-library-v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key) {
            do { documents = try JSONDecoder().decode([SchoolDocument].self, from: data) }
            catch {
                documents = []
                loadError = "Je opgeslagen items konden niet worden gelezen. De oorspronkelijke gegevens zijn bewaard; bewerken is tijdelijk uitgeschakeld."
                print("[SchoolLibrary] Load failed, original data retained: \(error)")
            }
        } else {
            documents = [
                SchoolDocument(module: "Studiewijzers", title: "4 HAVO - Engels studiewijzer", subject: "Engels", content: "Periode 1\n\nWeek 1: Unit 2 lezen en woordenschat.\nWeek 2: Oefenen met de verleden tijd.\nWeek 3: Leesvaardigheid en voorbereiding proefwerk."),
                SchoolDocument(module: "Studiewijzers", title: "Studiewijzer 4 Havo periode 1 Wiskunde", subject: "Wiskunde", content: "Hoofdstuk 3: vergelijkingen.\n\nMaak per week de opdrachten uit de agenda. Controleer je antwoorden en noteer je vragen voor de volgende les."),
                SchoolDocument(module: "Studiewijzers", title: "Studiewijzer Nederlands 2026–2027", subject: "Nederlands", content: "Leesvaardigheid, argumentatie en het leesdossier.\n\nNeem iedere les je boek en schrift mee."),
                SchoolDocument(module: "Studiewijzers", title: "Studiewijzer Geschiedenis periode 1", subject: "Geschiedenis", content: "De Republiek. Lees de samenvattingen en maak de verwerkingsvragen."),
                SchoolDocument(module: "Studiewijzers", title: "Studiewijzer Biologie - 4 havo", subject: "Biologie", content: "Cellen en organismen. Leer de begrippen en oefen met de tekeningen."),
                SchoolDocument(module: "Studiewijzers", title: "Studiewijzer lichamelijke opvoeding", subject: "Lichamelijke opvoeding", content: "Sportkleding meenemen. Deze studiewijzer is een lokaal voorbeeld."),
                SchoolDocument(module: "Studiewijzers", title: "Studiewijzer natuurkunde", subject: "Natuurkunde", content: "Krachten en beweging. Oefen met formules en eenheden."),
                SchoolDocument(module: "Leermiddelen", title: "Biologie voor jou MAX boek + online onderbouw", content: "Lokaal voorbeeld van een leermiddel. Er is geen digitale licentie of schoolverbinding gekoppeld."),
                SchoolDocument(module: "Leermiddelen", title: "Geschiedeniswerkplaats FLEX boek + online", content: "Lokaal voorbeeld. Voeg hier je eigen aantekeningen toe."),
                SchoolDocument(module: "Leermiddelen", title: "Overal NaSk FLEX boek + online", content: "Lokaal voorbeeld. Voeg hier je eigen aantekeningen toe."),
                SchoolDocument(module: "Leermiddelen", title: "buiteNLand FLEX boek + online", subject: "AK", content: "Aardrijkskunde — lokaal voorbeeld."),
                SchoolDocument(module: "Leermiddelen", title: "TrabiTour FLEX Deutschbuch", subject: "DU", content: "Duits — lokaal voorbeeld."),
                SchoolDocument(module: "Leermiddelen", title: "Stepping Stones FLEX boek + online", subject: "EN", content: "Engels — lokaal voorbeeld."),
                SchoolDocument(module: "Leermiddelen", title: "Nieuw Nederlands FLEX boek + online", subject: "NE", content: "Nederlands — lokaal voorbeeld.")
            ]
            persist()
        }
    }

    func save(_ document: SchoolDocument) {
        guard loadError == nil else { return }
        if let index = documents.firstIndex(where: { $0.id == document.id }) { documents[index] = document }
        else { documents.append(document) }
        persist()
    }

    func delete(_ id: UUID) {
        guard loadError == nil else { return }
        documents.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        guard loadError == nil else { return }
        do {
            UserDefaults.standard.set(try JSONEncoder().encode(documents), forKey: key)
            print("[SchoolLibrary] Saved local documents")
        } catch { print("[SchoolLibrary] Save failed: \(error)") }
    }
}

struct SchoolEmptyState: View {
    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 2) {
                Text("GG").font(.system(size: 23, weight: .bold))
                Rectangle().frame(width: 18, height: 3)
            }
            .frame(width: 45, height: 45)
            .foregroundStyle(SchoolTheme.background)
            .background(.gray, in: RoundedRectangle(cornerRadius: 5))
            .accessibilityHidden(true)
            Text("Geen gegevens gevonden").font(.system(size: 17)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LibraryModule: View {
    let module: String
    var store: SchoolLibraryStore
    let editing: Bool
    @State private var folder: String?
    @State private var status = "Alle"
    @State private var showFilter = false
    @State private var bannerVisible = true
    @State private var selectedDocument: SchoolDocument?
    @State private var newDocument = false
    @State private var showControl = false
    private let folders = ["Mijn ELO-documenten", "Gedeelde documenten", "Portfolio documenten", "Prullenbak"]
    private let statuses = ["Alle", "Openstaand", "Ingeleverd", "Beoordeeld", "Afgerond"]

    private var records: [SchoolDocument] {
        store.documents.filter {
            $0.module == module && (module != "Bronnen" || $0.folder == folder)
                && (module != "Opdrachten" || status == "Alle" || $0.status == status)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let error = store.loadError {
                Text(error).font(.callout).padding().foregroundStyle(SchoolTheme.ink)
            }
            if module == "Leermiddelen" && bannerVisible { informationBanner }
            if module == "Opdrachten" {
                Button { showFilter = true } label: {
                    HStack {
                        Text(status)
                        Spacer()
                        Image(systemName: "arrowtriangle.down.fill").font(.system(size: 11))
                    }
                    .font(.system(size: 17)).padding(.horizontal, 12).frame(height: 38)
                    .background(Color.secondary.opacity(0.22), in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain).padding(8).accessibilityIdentifier("assignment-filter")
            }
            if module == "Bronnen" && folder == nil {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(folders, id: \.self) { name in
                            Button { folder = name } label: {
                                HStack(spacing: 18) {
                                    Image(systemName: "folder.fill").font(.system(size: 19))
                                    Text(name).font(.system(size: 21, weight: .bold))
                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                                .padding(.horizontal, 9).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            SchoolTheme.divider.frame(height: 0.5).padding(.leading, 16)
                        }
                    }
                }
            } else {
                if let folder {
                    HStack {
                        Button { self.folder = nil } label: { Label("Bronnen", systemImage: "chevron.left") }
                        Spacer()
                        Text(folder).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                    }.padding(12)
                }
                if records.isEmpty { SchoolEmptyState() }
                else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(records) { document in
                                Button { selectedDocument = document } label: { documentRow(document) }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("document-\(document.id.uuidString.lowercased())")
                                SchoolTheme.divider.frame(height: 0.5).padding(.leading, 16)
                            }
                        }
                    }.frame(maxHeight: .infinity)
                }
            }
            if editing {
                HStack {
                    Text("Bewerkmodus").font(.system(size: 13))
                    Spacer()
                    Button("Nieuw") { newDocument = true }.accessibilityIdentifier("add-document")
                        .disabled(store.loadError != nil)
                }.foregroundStyle(SchoolTheme.blue).padding(.horizontal, 16).frame(height: 46)
                    .overlay(alignment: .top) { SchoolTheme.divider.frame(height: 0.5) }
            } else if module == "Leermiddelen" {
                HStack {
                    Spacer()
                    Button("Controle") { showControl = true }.accessibilityIdentifier("check-materials")
                }.font(.system(size: 20)).foregroundStyle(SchoolTheme.blue)
                    .padding(.horizontal, 16).frame(height: 42)
                    .overlay(alignment: .top) { SchoolTheme.divider.frame(height: 0.5) }
            }
        }
        .foregroundStyle(SchoolTheme.ink).background(SchoolTheme.background)
        .onChange(of: module) { _, _ in folder = nil; status = "Alle" }
        .sheet(isPresented: $showFilter) {
            VStack(spacing: 0) {
                HStack { Spacer(); Button("Gereed") { showFilter = false }.padding(16) }
                Picker("Status", selection: $status) {
                    ForEach(statuses, id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.wheel).labelsHidden()
            }.presentationDetents([.height(260)])
        }
        .sheet(item: $selectedDocument) { document in
            DocumentDetail(store: store, document: document, initiallyEditing: editing)
        }
        .sheet(isPresented: $newDocument) {
            DocumentEditor(store: store, document: SchoolDocument(module: module, title: "", status: status == "Alle" ? "Openstaand" : status, folder: folder ?? folders[0]), isNew: true)
        }
        .alert("Leermiddelen", isPresented: $showControl) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Je leermiddelen zijn lokaal beschikbaar als aantekeningen. Digitale boeken en schoollicenties zijn niet gekoppeld.")
        }
    }

    private var informationBanner: some View {
        HStack(spacing: 16) {
            Image(systemName: "lightbulb").font(.system(size: 21))
            Text("Dit zijn lokale voorbeelden. Digitale boeken en Magister-accounts zijn niet gekoppeld.")
                .font(.system(size: 16)).frame(maxWidth: .infinity, alignment: .leading)
            Button { bannerVisible = false } label: {
                Image(systemName: "xmark").font(.system(size: 18, weight: .bold)).frame(width: 32, height: 44)
            }.accessibilityLabel("Melding sluiten")
        }.padding(.horizontal, 8).padding(.vertical, 10)
            .foregroundStyle(.white).background(Color(red: 0.76, green: 0.33, blue: 0))
    }

    private func documentRow(_ document: SchoolDocument) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if module == "Leermiddelen" && !document.subject.isEmpty {
                Text(document.subject).font(.system(size: 20, weight: .bold))
            }
            Text(document.title)
                .font(.system(size: module == "Leermiddelen" ? 17 : 20, weight: module == "Leermiddelen" ? .regular : .bold))
                .lineLimit(module == "Leermiddelen" ? 1 : 2)
            if module == "Opdrachten" { Text(document.status).font(.system(size: 14)).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .padding(.horizontal, 9).padding(.vertical, 5).contentShape(Rectangle())
    }
}

struct DocumentDetail: View {
    var store: SchoolLibraryStore
    let document: SchoolDocument
    let initiallyEditing: Bool
    @State private var editing = false
    @Environment(\.dismiss) private var dismiss
    private var current: SchoolDocument { store.documents.first(where: { $0.id == document.id }) ?? document }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(current.title).font(.title2.bold())
                    if !current.subject.isEmpty { Text(current.subject).foregroundStyle(SchoolTheme.blue) }
                    Text(current.content.isEmpty ? "Er zijn nog geen aantekeningen. Tik op Wijzig om tekst toe te voegen." : current.content)
                        .font(.body).textSelection(.enabled)
                    Text("Lokaal opgeslagen • Geen officiële schoolgegevens").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
            }
            .background(SchoolTheme.background).navigationTitle(current.module).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Sluiten") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Wijzig") { editing = true } }
            }
        }
        .onAppear { editing = initiallyEditing }
        .sheet(isPresented: $editing) { DocumentEditor(store: store, document: current, isNew: false) }
        .onChange(of: store.documents.count) { _, _ in
            if !store.documents.contains(where: { $0.id == document.id }) { dismiss() }
        }
    }
}

struct DocumentEditor: View {
    var store: SchoolLibraryStore
    @State var document: SchoolDocument
    let isNew: Bool
    @State private var confirmDelete = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Gegevens") {
                    TextField("Titel", text: $document.title)
                    TextField("Vak", text: $document.subject)
                    if document.module == "Opdrachten" {
                        Picker("Status", selection: $document.status) {
                            ForEach(["Openstaand", "Ingeleverd", "Beoordeeld", "Afgerond"], id: \.self) { Text($0).tag($0) }
                        }
                    }
                    if document.module == "Bronnen" {
                        Picker("Map", selection: $document.folder) {
                            ForEach(["Mijn ELO-documenten", "Gedeelde documenten", "Portfolio documenten", "Prullenbak"], id: \.self) { Text($0).tag($0) }
                        }
                    }
                }
                Section("Tekst / aantekeningen") {
                    TextEditor(text: $document.content).frame(minHeight: 180).accessibilityLabel("Aantekeningen")
                }
                Section { Text("Wijzigingen blijven alleen op dit apparaat.").font(.caption).foregroundStyle(.secondary) }
                if !isNew { Button("Verwijderen", role: .destructive) { confirmDelete = true } }
            }
            .navigationTitle(isNew ? "Nieuw" : "Wijzig").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuleren") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Opslaan") { store.save(document); dismiss() }
                        .disabled(store.loadError != nil || document.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .interactiveDismissDisabled()
            .confirmationDialog("Dit lokale item verwijderen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Verwijderen", role: .destructive) { store.delete(document.id); dismiss() }
            }
        }
    }
}
