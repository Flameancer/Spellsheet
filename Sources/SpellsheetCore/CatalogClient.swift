import Foundation

public struct CatalogClient: Sendable {
    public static let datasetRoot = "https://raw.githubusercontent.com/5etools-mirror-3/5etools-src/main/data"
    public static let datasetPage = "https://github.com/5etools-mirror-3/5etools-src"

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func download(progress: @escaping @Sendable (String) -> Void) async throws -> Library {
        progress("Class index")
        let classIndex = try CatalogParser.classIndex(from: try await fetch("class/index.json"))
        progress("Source books")
        let books = try CatalogParser.bookNames(from: try await fetch("books.json"))
        progress("Class spell lists")
        let lists = try CatalogParser.classLists(from: try await fetch("spells/sources.json"))

        var classes: [ClassDefinition] = []
        var subclasses: [SubclassDefinition] = []
        var copies: [SubclassCopy] = []
        let classFiles = classIndex.sorted { $0.key < $1.key }
        for (offset, entry) in classFiles.enumerated() {
            progress("Classes \(offset + 1) of \(classFiles.count)")
            let parsed = try CatalogParser.classFile(from: try await fetch("class/\(entry.value)"))
            classes.append(contentsOf: parsed.classes)
            subclasses.append(contentsOf: parsed.subclasses)
            copies.append(contentsOf: parsed.copies)
        }
        subclasses = CatalogParser.resolveCopies(subclasses, copies: copies)

        progress("Spell index")
        let spellIndex = try CatalogParser.spellIndex(from: try await fetch("spells/index.json"))
        var spells: [Spell] = []
        let spellFiles = spellIndex.sorted { $0.key < $1.key }
        try await withThrowingTaskGroup(of: [Spell].self) { group in
            for entry in spellFiles {
                group.addTask {
                    let data = try await self.fetch("spells/\(entry.value)")
                    return try CatalogParser.spells(from: data)
                }
            }
            var finished = 0
            for try await file in group {
                finished += 1
                progress("Spell books \(finished) of \(spellFiles.count)")
                spells.append(contentsOf: file)
            }
        }
        spells.sort {
            if $0.level != $1.level { return $0.level < $1.level }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        return Library(
            fetchedAt: Date(),
            sourceNames: books,
            classes: classes.sorted {
                if $0.name != $1.name { return $0.name < $1.name }
                return $0.editionLabel < $1.editionLabel
            },
            subclasses: subclasses,
            spells: spells,
            lists: lists
        )
    }

    private func fetch(_ path: String) async throws -> Data {
        guard let url = URL(string: "\(Self.datasetRoot)/\(path)") else {
            throw CatalogError.address(path)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        request.setValue("Spellsheet/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw CatalogError.http(http.statusCode, path)
        }
        return data
    }
}
