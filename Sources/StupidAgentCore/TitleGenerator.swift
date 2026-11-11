import Foundation
import PiAgent
import PiAI

/// Names a conversation from its first message with one short request to the conversation's model.
public enum TitleGenerator {
    static let instructions = """
    You name chat conversations. Reply with only a short title, at most six words, for the conversation that starts \
    with the user's message. No quotes, no markdown, no punctuation at the end.
    """

    /// A title, or nil when the model fails or answers with nothing usable; the conversation then keeps the title it
    /// took from its first message.
    public static func generate(firstMessage: String, model: Model, options: StreamOptions, streamFunction: StreamFunction = defaultStreamFunction) async -> String? {
        var options = options
        // Thinking off and a small budget: this is a label, not an answer.
        options.reasoning = nil
        options.maxTokens = 100
        options.toolChoice = nil
        let excerpt = firstMessage.count > 2000 ? String(firstMessage.prefix(2000)) : firstMessage
        let context = TranscriptContext(normalizing: Context(systemPrompt: instructions, messages: [.user(UserMessage(text: excerpt))]))
        let message = await streamFunction(model, context, options).result()
        guard message.stopReason == .stop || message.stopReason == .length else { return nil }
        return clean(message.text)
    }

    /// The first line of the answer without quotes, markdown or a trailing period, at most 60 characters.
    static func clean(_ text: String) -> String? {
        guard let line = text.split(whereSeparator: \.isNewline).lazy.map({ $0.trimmingCharacters(in: .whitespaces) }).first(where: { !$0.isEmpty }) else { return nil }
        var title = line
        for prefix in ["Title:", "title:", "#"] where title.hasPrefix(prefix) {
            title = String(title.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }
        let wrappers = CharacterSet(charactersIn: "\"'“”‘’`*_")
        title = title.trimmingCharacters(in: wrappers.union(.whitespaces))
        while let last = title.last, ".!?:;,".contains(last) { title.removeLast() }
        title = title.trimmingCharacters(in: wrappers.union(.whitespaces))
        guard !title.isEmpty else { return nil }
        return title.count > 60 ? String(title.prefix(60)).trimmingCharacters(in: .whitespaces) + "…" : title
    }
}
