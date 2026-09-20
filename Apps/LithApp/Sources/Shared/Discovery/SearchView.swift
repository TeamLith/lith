import SwiftUI
import Lith

struct SearchView: View {
    let dependencies: AppDependencyContainer
    @State private var viewModel: SearchViewModel
    @State private var namingSearch = false
    @State private var editedSearchID: UUID?
    @State private var searchName = ""
    @State private var deletingSearch: SavedSearch?

    init(dependencies: AppDependencyContainer) {
        self.dependencies = dependencies
        _viewModel = State(initialValue: SearchViewModel(service: dependencies.searchService, savedRepository: dependencies.savedSearchRepository))
    }

    var body: some View {
        @Bindable var model = viewModel
        List {
            Section("Saved searches") {
                Button("Save current search") {
                    editedSearchID = nil
                    searchName = ""
                    namingSearch = true
                }
                if let error = model.savedSearchError {
                    Text(error).foregroundStyle(.red)
                    Button("Reload saved searches") { Task { await model.loadSavedSearches() } }
                }
                ForEach(model.savedSearches) { saved in
                    HStack {
                        Button(saved.name) { Task { await model.applySavedSearch(saved) } }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Menu {
                            Button("Rename") {
                                editedSearchID = saved.id
                                searchName = saved.name
                                namingSearch = true
                            }
                            Button("Delete", role: .destructive) { deletingSearch = saved }
                        } label: { Image(systemName: "ellipsis.circle") }
                        .accessibilityLabel("Manage saved search \(saved.name)")
                    }
                }
            }
            Section("Filters") {
                Picker("Source", selection: $model.input.source) {
                    Text("All sources").tag(nil as NoteSource?)
                    ForEach(NoteSource.allCases, id: \.self) { source in
                        Text(source.rawValue.capitalized).tag(Optional(source))
                    }
                }
                TextField("Tags, separated by commas", text: $model.input.tags)
                    .accessibilityLabel("Filter tags")
                Toggle("Filter by last updated date", isOn: $model.input.restrictDates)
                if model.input.restrictDates {
                    DatePicker("From", selection: $model.input.startDate, displayedComponents: .date)
                    DatePicker("Through", selection: $model.input.endDate, displayedComponents: .date)
                }
                Button("Clear search and filters") { model.clearFilters() }
            }
            Section("Results") {
                if model.isLoading {
                    ProgressView("Searching notes…")
                } else if let error = model.errorMessage {
                    Text(error).foregroundStyle(.secondary)
                    Button("Retry") { Task { await model.search() } }
                } else if model.results.isEmpty {
                    ContentUnavailableView.search(text: model.input.query)
                } else {
                    ForEach(model.results) { note in
                        NavigationLink {
                            NoteDetailView(
                                repository: dependencies.noteRepository,
                                wikiLinkService: dependencies.wikiLinkService,
                                noteID: note.id,
                                audioServices: dependencies.audioServices
                            ) { await model.search() }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(note.title.isEmpty ? "Untitled" : note.title).font(.headline)
                                Text(model.snippet(for: note)).lineLimit(3).foregroundStyle(.secondary)
                                HStack {
                                    Text(note.source.rawValue.capitalized)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(.quaternary, in: Capsule())
                                    Text(note.updatedAt, style: .date)
                                }.font(.caption)
                                if !note.tags.isEmpty {
                                    Text(note.tags.sorted().map { "#\($0)" }.joined(separator: " "))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }.padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("Search")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink { GraphView(dependencies: dependencies) } label: {
                    Label("Graph", systemImage: "point.3.connected.trianglepath")
                }
            }
        }
        .searchable(text: $model.input.query, prompt: "Search notes, tags, and metadata")
        .task(id: model.input) { await model.search() }
        .task { await model.loadSavedSearches() }
        .sheet(isPresented: $namingSearch) {
            VStack(alignment: .leading, spacing: 16) {
                Text(editedSearchID == nil ? "Save current search" : "Rename saved search").font(.headline)
                TextField("Name", text: $searchName)
                if let error = model.savedSearchError { Text(error).foregroundStyle(.red) }
                HStack {
                    Button("Cancel") { namingSearch = false }
                    Spacer()
                    Button("Save") {
                        Task {
                            let saved: Bool
                            if let id = editedSearchID { saved = await model.renameSavedSearch(id: id, name: searchName) }
                            else { saved = await model.saveSearch(name: searchName) }
                            if saved { namingSearch = false }
                        }
                    }.disabled(searchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .disabled(model.isSavingSearch)
            .padding().frame(minWidth: 300, idealWidth: 420)
        }
        .confirmationDialog("Delete saved search?", isPresented: Binding(get: { deletingSearch != nil }, set: { if !$0 { deletingSearch = nil } })) {
            Button("Delete saved search", role: .destructive) {
                if let id = deletingSearch?.id { Task { await model.deleteSavedSearch(id: id) } }
                deletingSearch = nil
            }
        } message: { Text("Only the saved search is removed. Your notes are kept.") }
    }
}
