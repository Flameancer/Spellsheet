import Foundation

/// One homebrew document from the 5e.tools homebrew repository that contains spells.
public struct BrewCatalogEntry: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var path: String
    public var title: String
    public var abbreviation: String
    public var edition: String
    public var kind: String
    public var status: String

    public var id: String { path }

    public init(path: String, title: String, abbreviation: String, edition: String, kind: String, status: String) {
        self.path = path
        self.title = title
        self.abbreviation = abbreviation
        self.edition = edition
        self.kind = kind
        self.status = status
    }
}

/// A spell in a brew that should reuse an official spell's text when the brew file only copies it.
public struct BrewCopy: Codable, Equatable, Sendable {
    public var spellID: String
    public var copyName: String
    public var copySource: String

    public init(spellID: String, copyName: String, copySource: String) {
        self.spellID = spellID
        self.copyName = copyName
        self.copySource = copySource
    }
}

/// Spells and class-list links imported from one homebrew file.
public struct BrewDocument: Codable, Equatable, Sendable, Identifiable {
    public var path: String
    public var title: String
    public var abbreviation: String
    public var sourceNames: [String: String]
    public var spells: [Spell]
    public var lists: [String: SpellClassList]
    public var bareClasses: [String: [String]]
    public var copies: [BrewCopy]

    public var id: String { path }

    public init(
        path: String,
        title: String,
        abbreviation: String,
        sourceNames: [String: String],
        spells: [Spell],
        lists: [String: SpellClassList],
        bareClasses: [String: [String]],
        copies: [BrewCopy]
    ) {
        self.path = path
        self.title = title
        self.abbreviation = abbreviation
        self.sourceNames = sourceNames
        self.spells = spells
        self.lists = lists
        self.bareClasses = bareClasses
        self.copies = copies
    }
}

public enum BrewCatalog {
    public static let root = "https://raw.githubusercontent.com/TheGiddyLimit/homebrew/master"

    public static func fetchEntries(session: URLSession = .shared) async throws -> [BrewCatalogEntry] {
        async let props = fetch("_generated/index-props.json", session: session)
        async let meta = fetch("_generated/index-meta.json", session: session)
        return try entries(props: await props, meta: await meta)
    }

    public static func fetchDocument(_ entry: BrewCatalogEntry, session: URLSession = .shared) async throws -> BrewDocument {
        let data = try await fetch(entry.path, session: session)
        return try document(from: data, path: entry.path, title: entry.title, abbreviation: entry.abbreviation)
    }

    public static func entries(props: Data, meta: Data) throws -> [BrewCatalogEntry] {
        let propsRoot = try CatalogParser.jsonObject(props)
        guard let spellFiles = propsRoot["spell"] as? [String: Any], !spellFiles.isEmpty else {
            throw CatalogError.malformed("The homebrew index did not include a spell list.")
        }
        let metaRoot = try CatalogParser.jsonObject(meta)
        var entries: [BrewCatalogEntry] = []
        for path in spellFiles.keys {
            let filename = path.split(separator: "/").last.map(String.init) ?? path
            let info = metaRoot[filename] as? [String: Any]
            let names = info?["n"] as? [String] ?? []
            let abbreviations = info?["a"] as? [String] ?? []
            let editionCode = info?["e"] as? Int ?? 0
            let title = names.first ?? filename.replacingOccurrences(of: ".json", with: "")
            let kind = path.split(separator: "/").first.map(String.init) ?? "homebrew"
            entries.append(BrewCatalogEntry(
                path: path,
                title: title,
                abbreviation: abbreviations.first ?? "",
                edition: editionCode == 1 ? "2024" : "2014",
                kind: kind,
                status: CatalogParser.string(info?["s"]) ?? ""
            ))
        }
        entries.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        return entries
    }

    public static func document(from data: Data, path: String, title: String, abbreviation: String) throws -> BrewDocument {
        let root = try CatalogParser.jsonObject(data)
        var sourceNames: [String: String] = [:]
        if let meta = root["_meta"] as? [String: Any] {
            for source in CatalogParser.array(meta["sources"]) {
                guard let object = source as? [String: Any],
                      let code = CatalogParser.string(object["json"])
                else { continue }
                let full = CatalogParser.string(object["full"]) ?? CatalogParser.string(object["abbreviation"]) ?? code
                sourceNames[code] = full
            }
        }

        var spells: [Spell] = []
        var lists: [String: SpellClassList] = [:]
        var bareClasses: [String: [String]] = [:]
        var copies: [BrewCopy] = []
        var seenSources = Set<String>()

        for item in CatalogParser.array(root["spell"]) {
            guard let object = item as? [String: Any], let spell = CatalogParser.parseSpell(object) else { continue }
            seenSources.insert(spell.source)
            let classes = classLinks(from: object["classes"])
            if !classes.classes.isEmpty || !classes.variants.isEmpty {
                lists[spell.listKey] = SpellClassList(classes: classes.classes, variants: classes.variants)
            }
            if !classes.bare.isEmpty {
                bareClasses[spell.listKey] = classes.bare
            }
            if let copy = object["_copy"] as? [String: Any],
               let copyName = CatalogParser.string(copy["name"]),
               let copySource = CatalogParser.string(copy["source"]),
               spell.description.allSatisfy({ $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                copies.append(BrewCopy(spellID: spell.id, copyName: copyName, copySource: copySource))
            }
            let owned = sourceNames[spell.source] != nil || sourceNames.isEmpty
            guard owned else { continue }
            if let index = spells.firstIndex(where: { $0.id == spell.id }) {
                spells[index] = spell
            } else {
                spells.append(spell)
            }
        }

        if sourceNames.isEmpty {
            for source in seenSources {
                sourceNames[source] = source
            }
        }

        return BrewDocument(
            path: path,
            title: title,
            abbreviation: abbreviation,
            sourceNames: sourceNames,
            spells: spells,
            lists: lists,
            bareClasses: bareClasses,
            copies: copies
        )
    }

    private static func classLinks(from raw: Any?) -> (classes: [ClassRef], variants: [ClassRef], bare: [String]) {
        if let dict = raw as? [String: Any] {
            var classes = CatalogParser.refs(dict["fromClassList"])
            let variants = CatalogParser.refs(dict["fromClassListVariant"])
            for item in CatalogParser.array(dict["fromSubclass"]) {
                guard let object = item as? [String: Any] else { continue }
                classes.append(contentsOf: classRef(object["class"]))
            }
            let bare = CatalogParser.array(dict["fromClassList"]).compactMap { $0 as? String }
            return (classes, variants, bare)
        }
        let classes = CatalogParser.refs(raw)
        let bare = CatalogParser.array(raw).compactMap { $0 as? String }
        return (classes, [], bare)
    }

    private static func classRef(_ raw: Any?) -> [ClassRef] {
        let direct = CatalogParser.refs(raw)
        if !direct.isEmpty { return direct }
        guard let object = raw as? [String: Any] else { return [] }
        return CatalogParser.refs([object])
    }

    private static func fetch(_ path: String, session: URLSession) async throws -> Data {
        guard let url = url(for: path) else { throw CatalogError.address(path) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        request.setValue("Spellsheet/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw CatalogError.http(http.statusCode, path)
        }
        return data
    }

    private static func url(for path: String) -> URL? {
        let encoded = path.split(separator: "/", omittingEmptySubsequences: false).map { segment in
            String(segment).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(segment)
        }.joined(separator: "/")
        return URL(string: "\(root)/\(encoded)")
    }
}
