import Foundation

/// The kinds of personal information the app can mask.
enum EntityCategory: String, Codable, CaseIterable, Identifiable {
    case person
    case location
    case organization
    case miscellaneous

    var id: String { rawValue }

    /// Prefix used in the placeholder sent to the LLM, e.g. `[PERSON_1]`.
    var aliasPrefix: String {
        switch self {
        case .person: return "PERSON"
        case .location: return "LOCATION"
        case .organization: return "ORG"
        case .miscellaneous: return "MISC"
        }
    }

    var displayName: String {
        switch self {
        case .person: return "Person"
        case .location: return "Location"
        case .organization: return "Organization"
        case .miscellaneous: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .person: return "person.fill"
        case .location: return "mappin.and.ellipse"
        case .organization: return "building.2.fill"
        case .miscellaneous: return "tag.fill"
        }
    }

    /// Maps a CoNLL-style NER label (`PER`, `LOC`, `ORG`, `MISC`) to a category.
    init?(nerLabel: String) {
        switch nerLabel {
        case "PER": self = .person
        case "LOC": self = .location
        case "ORG": self = .organization
        case "MISC": self = .miscellaneous
        default: return nil
        }
    }
}
