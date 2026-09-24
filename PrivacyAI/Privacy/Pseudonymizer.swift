import Foundation

/// Replaces tagged words with stable placeholders and restores them in the
/// LLM's answer.
///
/// One instance lives for the whole conversation, so the same entity always
/// maps to the same alias ("Mario Rossi" is `[PERSON_1]` in every message) and
/// the LLM can still reason about who did what.
struct Pseudonymizer: Codable, Equatable {
    /// Normalized original entity -> alias.
    private(set) var aliasesByKey: [String: String] = [:]
    /// Alias -> original entity, as the user first wrote it.
    private(set) var originalsByAlias: [String: String] = [:]
    /// Normalized single word -> category, for every word of every masked entity.
    private var categoriesByWord: [String: EntityCategory] = [:]
    private var nextIndexByPrefix: [String: Int] = [:]

    /// Masks every tagged token and returns the updated tokens together with
    /// the prompt to send to the LLM.
    ///
    /// Consecutive words with the same tag form one entity, so "Mario Rossi"
    /// becomes a single `[PERSON_1]` rather than two different people.
    /// Punctuation or a line break between the words ends the entity.
    mutating func mask(_ tokens: [WordToken]) -> (tokens: [WordToken], maskedText: String) {
        var maskedTokens = tokens
        var maskedText = ""
        var start = 0

        while start < maskedTokens.count {
            var end = start
            if let category = maskedTokens[start].category {
                while end + 1 < maskedTokens.count,
                      maskedTokens[end + 1].category == category,
                      maskedTokens[end].trailingWhitespace == " ",
                      Self.split(maskedTokens[end].text).trailing.isEmpty,
                      Self.split(maskedTokens[end + 1].text).leading.isEmpty {
                    end += 1
                }
            }

            let words = (start...end).map { Self.split(maskedTokens[$0].text) }
            let entity = words.map(\.core).filter { !$0.isEmpty }.joined(separator: " ")

            if let category = maskedTokens[start].category, !entity.isEmpty {
                let alias = alias(for: entity, category: category)
                maskedTokens[start].maskedText = words[0].leading + alias + words[words.count - 1].trailing
                // The other words of the entity are folded into the first one.
                for index in (start + 1)..<(end + 1) {
                    maskedTokens[index].maskedText = ""
                }
            } else {
                maskedTokens[start].maskedText = nil
            }

            maskedText += maskedTokens[start].displayText(masked: true) + maskedTokens[end].trailingWhitespace
            start = end + 1
        }

        return (maskedTokens, maskedText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Puts the original words back into a text produced by the LLM.
    func restore(_ text: String) -> String {
        // Longest aliases first, so `[PERSON_1]` never matches inside `[PERSON_10]`.
        originalsByAlias.keys
            .sorted { $0.count > $1.count }
            .reduce(text) { result, alias in
                result.replacingOccurrences(of: alias, with: originalsByAlias[alias] ?? alias)
            }
    }

    /// Category of a word that was already masked earlier in the conversation,
    /// alone or as part of a longer entity. Used to re-tag it even if the NER
    /// model misses it this time.
    func knownCategory(for word: String) -> EntityCategory? {
        let core = Self.split(word).core
        guard !core.isEmpty else { return nil }
        return categoriesByWord[Self.normalizedKey(core)]
    }

    mutating func alias(for entity: String, category: EntityCategory) -> String {
        let key = Self.normalizedKey(entity)
        if let existing = aliasesByKey[key] {
            return existing
        }
        let index = nextIndexByPrefix[category.aliasPrefix, default: 1]
        let alias = "[\(category.aliasPrefix)_\(index)]"
        nextIndexByPrefix[category.aliasPrefix] = index + 1
        aliasesByKey[key] = alias
        originalsByAlias[alias] = entity
        for word in key.split(separator: " ") {
            categoriesByWord[String(word)] = category
        }
        return alias
    }

    /// Case- and accent-insensitive key, so "Mario", "mario" and "MARIO"
    /// share one alias.
    static func normalizedKey(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// Separates a word from surrounding punctuation and English possessives,
    /// e.g. `"(Mario's,"` -> `("(", "Mario", "'s,")`.
    static func split(_ word: String) -> (leading: String, core: String, trailing: String) {
        let isEdge: (Character) -> Bool = { $0.isPunctuation || $0.isSymbol }
        let coreStart = word.firstIndex(where: { !isEdge($0) }) ?? word.endIndex
        let coreEnd = word.lastIndex(where: { !isEdge($0) }).map(word.index(after:)) ?? coreStart

        var core = String(word[coreStart..<max(coreStart, coreEnd)])
        var trailing = String(word[max(coreStart, coreEnd)...])
        for possessive in ["'s", "’s"] where core.count > possessive.count && core.lowercased().hasSuffix(possessive) {
            trailing = String(core.suffix(possessive.count)) + trailing
            core = String(core.dropLast(possessive.count))
        }
        return (String(word[..<coreStart]), core, trailing)
    }
}
