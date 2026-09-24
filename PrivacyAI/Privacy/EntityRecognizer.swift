import CoreML
import Foundation
import Tokenizers

struct RecognizedEntity: Equatable {
    let text: String
    let category: EntityCategory
}

/// On-device named-entity recognition with a BERT token-classification model
/// running on Core ML. Nothing the user types leaves the device at this stage.
final class EntityRecognizer: @unchecked Sendable {
    enum LoadError: LocalizedError {
        case modelNotBundled
        case unexpectedModelOutput

        var errorDescription: String? {
            switch self {
            case .modelNotBundled:
                return "\(EntityRecognizer.modelResourceName).mlpackage is not in the app bundle. See the README to build it."
            case .unexpectedModelOutput:
                return "The Core ML model does not expose a logits output."
            }
        }
    }

    static let modelResourceName = "BertNER"

    /// Label order of `dslim/bert-base-NER-uncased` (`id2label` in its config.json).
    static let labels = ["O", "B-MISC", "I-MISC", "B-PER", "I-PER", "B-ORG", "I-ORG", "B-LOC", "I-LOC"]

    /// The model was traced with a fixed input length.
    private static let sequenceLength = 128
    private static let padTokenID: Int32 = 0

    private let model: MLModel
    private let tokenizer: Tokenizer
    private let logitsOutputName: String

    init(model: MLModel, tokenizer: Tokenizer) throws {
        guard let outputName = model.modelDescription.outputDescriptionsByName
            .first(where: { $0.value.type == .multiArray })?.key else {
            throw LoadError.unexpectedModelOutput
        }
        self.model = model
        self.tokenizer = tokenizer
        self.logitsOutputName = outputName
    }

    /// Loads the compiled model and the WordPiece tokenizer shipped in the bundle.
    static func loadFromBundle(_ bundle: Bundle = .main) async throws -> EntityRecognizer {
        guard let modelURL = bundle.url(forResource: modelResourceName, withExtension: "mlmodelc"),
              let resourceURL = bundle.resourceURL else {
            throw LoadError.modelNotBundled
        }
        let model = try MLModel(contentsOf: modelURL, configuration: MLModelConfiguration())
        // Reads tokenizer.json and tokenizer_config.json from the bundle: no network needed.
        let tokenizer = try await AutoTokenizer.from(modelFolder: resourceURL)
        return try EntityRecognizer(model: model, tokenizer: tokenizer)
    }

    func recognize(in text: String) throws -> [RecognizedEntity] {
        try chunks(of: text).flatMap(recognizeChunk)
    }

    // MARK: - Inference

    /// Splits long text on word boundaries into pieces that fit the model window.
    private func chunks(of text: String) -> [String] {
        let budget = Self.sequenceLength - 2 // room for [CLS] and [SEP]
        var chunks: [String] = []
        var currentWords: [Substring] = []
        var usedTokens = 0

        for word in text.split(whereSeparator: \.isWhitespace) {
            let cost = tokenizer.encode(text: String(word), addSpecialTokens: false).count
            if usedTokens + cost > budget, !currentWords.isEmpty {
                chunks.append(currentWords.joined(separator: " "))
                currentWords.removeAll()
                usedTokens = 0
            }
            currentWords.append(word)
            usedTokens += cost
        }
        if !currentWords.isEmpty {
            chunks.append(currentWords.joined(separator: " "))
        }
        return chunks
    }

    private func recognizeChunk(_ chunk: String) throws -> [RecognizedEntity] {
        // [CLS] w1 w2 ... [SEP]
        let tokenIDs = Array(tokenizer.encode(text: chunk).prefix(Self.sequenceLength))
        guard tokenIDs.count > 2 else { return [] }

        let shape = [1, NSNumber(value: Self.sequenceLength)]
        let inputIDs = try MLMultiArray(shape: shape, dataType: .int32)
        let attentionMask = try MLMultiArray(shape: shape, dataType: .int32)
        for position in 0..<Self.sequenceLength {
            let isToken = position < tokenIDs.count
            inputIDs[position] = NSNumber(value: isToken ? Int32(tokenIDs[position]) : Self.padTokenID)
            attentionMask[position] = NSNumber(value: isToken ? 1 : 0)
        }

        let input = try MLDictionaryFeatureProvider(dictionary: [
            "input_ids": inputIDs,
            "attention_mask": attentionMask,
        ])
        let output = try model.prediction(from: input)
        guard let logits = output.featureValue(for: logitsOutputName)?.multiArrayValue else {
            throw LoadError.unexpectedModelOutput
        }

        // Rebuild whole words from WordPiece sub-tokens ("gor", "##gon", "##zola").
        // Each word takes the label of its first sub-token.
        var words: [(tokenIDs: [Int], label: String)] = []
        for position in 1..<(tokenIDs.count - 1) {
            let tokenID = tokenIDs[position]
            let piece = tokenizer.convertIdToToken(tokenID) ?? ""
            if piece.hasPrefix("##"), !words.isEmpty {
                words[words.count - 1].tokenIDs.append(tokenID)
            } else {
                words.append(([tokenID], label(at: position, in: logits)))
            }
        }

        return groupIntoEntities(words)
    }

    private func label(at position: Int, in logits: MLMultiArray) -> String {
        let scores = Self.labels.indices.map { labelIndex in
            logits[[0, NSNumber(value: position), NSNumber(value: labelIndex)]].floatValue
        }
        let best = scores.indices.max(by: { scores[$0] < scores[$1] }) ?? 0
        return Self.labels[best]
    }

    /// Merges consecutive words into entities following the BIO scheme.
    private func groupIntoEntities(_ words: [(tokenIDs: [Int], label: String)]) -> [RecognizedEntity] {
        var entities: [RecognizedEntity] = []
        var currentWords: [String] = []
        var currentCategory: EntityCategory?

        func flush() {
            if let category = currentCategory, !currentWords.isEmpty {
                entities.append(RecognizedEntity(text: currentWords.joined(separator: " "), category: category))
            }
            currentWords.removeAll()
            currentCategory = nil
        }

        for word in words {
            let parts = word.label.split(separator: "-", maxSplits: 1)
            guard parts.count == 2, let category = EntityCategory(nerLabel: String(parts[1])) else {
                flush()
                continue
            }
            // A stray "I-" after a different category also starts a new entity.
            if parts[0] == "B" || category != currentCategory {
                flush()
                currentCategory = category
            }
            currentWords.append(tokenizer.decode(tokens: word.tokenIDs))
        }
        flush()
        return entities
    }
}

extension EntityRecognizer {
    /// Tags the message words that belong to a recognized entity.
    ///
    /// Matching is done word by word, so a multi-word entity such as
    /// "mario rossi" tags both "Mario" and "Rossi,". The uncased model returns
    /// lowercased, accent-stripped text, so keys are normalized the same way.
    static func tag(_ tokens: [WordToken], with entities: [RecognizedEntity]) -> [WordToken] {
        var categoryByKey: [String: EntityCategory] = [:]
        for entity in entities {
            for word in entity.text.split(whereSeparator: \.isWhitespace) {
                let core = Pseudonymizer.split(String(word)).core
                guard !core.isEmpty else { continue }
                categoryByKey[Pseudonymizer.normalizedKey(core)] = entity.category
            }
        }

        return tokens.map { token in
            var token = token
            let core = Pseudonymizer.split(token.text).core
            if !core.isEmpty, let category = categoryByKey[Pseudonymizer.normalizedKey(core)] {
                token.category = category
            }
            return token
        }
    }
}
