import SwiftUI
import Lith

struct GraphView: View {
    let dependencies: AppDependencyContainer
    @State private var viewModel: GraphViewModel
    @State private var showList = false
    @GestureState private var translation = CGSize.zero
    @GestureState private var magnification: CGFloat = 1

    init(dependencies: AppDependencyContainer) {
        self.dependencies = dependencies
        _viewModel = State(initialValue: GraphViewModel(service: GraphService(
            noteRepository: dependencies.noteRepository, linkRepository: dependencies.linkRepository
        )))
    }

    var body: some View {
        @Bindable var model = viewModel
        VStack(spacing: 12) {
            VStack(alignment: .leading) {
                Picker("Graph", selection: $model.selection.centerID) {
                    Text("All notes").tag(nil as UUID?)
                    if let center = model.selection.centerID, !model.availableCenters.contains(where: { $0.id == center }) {
                        Text("Selected note unavailable").tag(Optional(center))
                    }
                    ForEach(model.availableCenters) { node in
                        Text(node.title.isEmpty ? "Untitled" : node.title).tag(Optional(node.id))
                    }
                }
                if model.selection.centerID != nil {
                    Stepper("Link depth: \(model.selection.depth)", value: $model.selection.depth, in: 0...5)
                }
                Toggle("Show accessible note list", isOn: $showList)
            }.padding(.horizontal)

            if model.isLoading {
                ProgressView("Loading graph…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = model.errorMessage {
                ContentUnavailableView {
                    Label("Could Not Load Graph", systemImage: "exclamationmark.triangle")
                } description: { Text(error) } actions: {
                    Button("Retry") { Task { await model.load() } }
                }
            } else if model.graph.nodes.isEmpty {
                ContentUnavailableView("No Notes in Graph", systemImage: "point.3.connected.trianglepath",
                                       description: Text("Create a note or choose another graph center."))
            } else if showList {
                List(model.graph.nodes) { node in
                    Button { model.openNote(node.id) } label: {
                        HStack {
                            Text(node.title.isEmpty ? "Untitled" : node.title)
                            Spacer()
                            Text("\(node.degree) links").foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                graphCanvas
                HStack {
                    Button { model.viewport.zoom(by: 0.8) } label: { Label("Zoom out", systemImage: "minus.magnifyingglass") }
                    Button { model.viewport.reset() } label: { Label("Reset view", systemImage: "arrow.counterclockwise") }
                    Button { model.viewport.zoom(by: 1.25) } label: { Label("Zoom in", systemImage: "plus.magnifyingglass") }
                }.labelStyle(.iconOnly)
                Text("Drag to pan. Pinch to zoom. Select a note to open it.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical)
        .navigationTitle("Graph")
        .task(id: model.selection) {
            model.viewport.reset()
            await model.load()
        }
        .navigationDestination(isPresented: Binding(
            get: { model.selectedNoteID != nil },
            set: { if !$0 { model.selectedNoteID = nil } }
        )) {
            if let id = model.selectedNoteID {
                NoteDetailView(repository: dependencies.noteRepository, wikiLinkService: dependencies.wikiLinkService, noteID: id, audioRepository: dependencies.audioRecordingRepository, audioServices: dependencies.audioServices) {
                    await model.load()
                }
            }
        }
    }

    private var graphCanvas: some View {
        GeometryReader { geometry in
            let positions = GraphLayout().positions(for: viewModel.graph.nodes)
            let points = positions.mapValues { position in
                var viewport = viewModel.viewport
                viewport.zoom(by: Double(magnification))
                viewport.pan(x: translation.width, y: translation.height)
                let point = viewport.project(position, width: geometry.size.width, height: geometry.size.height)
                return CGPoint(x: point.x, y: point.y)
            }
            ZStack {
                Color.clear
                Canvas { context, _ in
                    for edge in viewModel.graph.edges {
                        if let from = points[edge.sourceID], let to = points[edge.targetID] {
                            var line = Path()
                            line.move(to: from)
                            line.addLine(to: to)
                            context.stroke(line, with: .color(.secondary.opacity(0.45)), lineWidth: 1.5)
                        }
                    }
                }.accessibilityHidden(true)
                ForEach(viewModel.graph.nodes) { node in
                    if let point = points[node.id] {
                        Button { viewModel.openNote(node.id) } label: {
                            VStack(spacing: 4) {
                                Circle().fill(node.id == viewModel.selection.centerID ? Color.orange : Color.accentColor)
                                    .frame(width: 20, height: 20)
                                Text(node.title.isEmpty ? "Untitled" : node.title)
                                    .font(.caption).lineLimit(2).frame(width: 112)
                                    .padding(3).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(node.title.isEmpty ? "Untitled" : node.title), \(node.degree) links")
                        .accessibilityHint("Opens this note")
                        .position(point)
                    }
                }
            }
            .contentShape(Rectangle())
            .clipped()
            .simultaneousGesture(DragGesture(minimumDistance: 10)
                .updating($translation) { value, state, _ in state = value.translation }
                .onEnded { viewModel.viewport.pan(x: $0.translation.width, y: $0.translation.height) })
            .simultaneousGesture(MagnifyGesture()
                .updating($magnification) { value, state, _ in state = value.magnification }
                .onEnded { viewModel.viewport.zoom(by: $0.magnification) })
        }
        .frame(minHeight: 240)
    }
}
