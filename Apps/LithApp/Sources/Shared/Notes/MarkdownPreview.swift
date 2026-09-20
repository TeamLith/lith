import SwiftUI
import UniformTypeIdentifiers
import Lith

struct MarkdownPreview: View {
    let markdown: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(MarkdownBlockParser().parse(markdown).enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case let .heading(level, text):
            inline(text).font(level == 1 ? .title : level == 2 ? .title2 : .headline)
                .accessibilityAddTraits(.isHeader)
        case let .paragraph(text): inline(text)
        case let .unorderedItem(text):
            HStack(alignment: .top) { Text("•"); inline(text) }
        case let .orderedItem(number, text):
            HStack(alignment: .top) { Text("\(number)."); inline(text) }
        case let .quote(text):
            HStack(alignment: .top) { Rectangle().fill(.secondary).frame(width: 3); inline(text).foregroundStyle(.secondary) }
                .fixedSize(horizontal: false, vertical: true)
        case let .code(language, text):
            VStack(alignment: .leading, spacing: 4) {
                if !language.isEmpty { Text(language).font(.caption).foregroundStyle(.secondary) }
                ScrollView(.horizontal) { Text(verbatim: text).font(.body.monospaced()) }
            }.padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        case .rule: Divider()
        }
    }

    private func inline(_ text: String) -> Text {
        let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        return attributed.map(Text.init) ?? Text(verbatim: text)
    }
}

struct MarkdownFile: FileDocument {
    static var readableContentTypes: [UTType] { [UTType(filenameExtension: "md") ?? .plainText, .plainText] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
