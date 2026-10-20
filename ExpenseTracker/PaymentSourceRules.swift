import Foundation

/// Shared by entry, management, and storage. Archived tokens stay reserved.
enum PaymentSourceRules {
    enum RuleError: LocalizedError, Equatable {
        case emptyName, emptyAlias, duplicateToken(String), ambiguous(String), archived(String)

        var errorDescription: String? {
            switch self {
            case .emptyName: return "Enter a payment source name."
            case .emptyAlias: return "Aliases cannot be blank."
            case .duplicateToken(let token): return "‘\(token)’ is already a source name or alias. Use each name or alias only once, including archived sources."
            case .ambiguous(let token): return "‘\(token)’ matches more than one source. Choose a source explicitly."
            case .archived(let name): return "\(name) is archived. Restore it in Manage sources before using it."
            }
        }
    }

    static func cleaned(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    static func key(_ text: String) -> String {
        cleaned(text).folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                              locale: Locale(identifier: "en_US_POSIX"))
    }

    static func validate(sources: [PaymentSource]) throws {
        var tokens = Set<String>()
        for source in sources {
            guard !cleaned(source.name).isEmpty else { throw RuleError.emptyName }
            for token in [source.name] + source.aliases {
                guard !cleaned(token).isEmpty else { throw RuleError.emptyAlias }
                guard tokens.insert(key(token)).inserted else { throw RuleError.duplicateToken(cleaned(token)) }
            }
        }
    }

    static func normalized(_ source: PaymentSource, in sources: [PaymentSource]) throws -> PaymentSource {
        var result = source
        result.name = cleaned(source.name)
        result.aliases = source.aliases.map(cleaned)
        try validate(sources: sources.filter { $0.id != source.id } + [result])
        return result
    }

    /// Nil means unfamiliar. Callers must confirm before creating that source.
    static func resolve(_ text: String, in sources: [PaymentSource]) throws -> PaymentSource? {
        let token = key(text)
        guard !token.isEmpty else { throw RuleError.emptyName }
        let matches = sources.filter { source in
            ([source.name] + source.aliases).contains { key($0) == token }
        }
        guard matches.count <= 1 else { throw RuleError.ambiguous(cleaned(text)) }
        guard let source = matches.first else { return nil }
        guard !source.isArchived else { throw RuleError.archived(source.name) }
        return source
    }
}
