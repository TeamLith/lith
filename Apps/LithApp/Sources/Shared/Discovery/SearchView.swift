import SwiftUI
import Lith

struct SearchView: View {
    let dependencies: AppDependencyContainer
    @State private var viewModel: SearchViewModel

    init(dependencies: AppDependencyContainer) {
        self.dependencies = dependencies
        _viewModel = State(initialValue: SearchViewModel(service: dependencies.searchService))
    }

    var body: some View {
        @Bindable var model = viewModel
        List {
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
                                noteID: note.id
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
        .searchable(text: $model.input.query, prompt: "Search notes, tags, and metadata")
        .task(id: model.input) { await model.search() }
    }
}
