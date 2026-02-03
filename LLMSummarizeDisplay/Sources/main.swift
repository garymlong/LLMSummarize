import Cocoa
import Foundation
import MarkdownKit

// MARK: - Globals

var markdownContent: String = ""
var originalFileURLs: [URL] = []
var windowRef: NSWindow?
var modeButton: NSButton!
var darkModeEnabled = false

// Ensure GUI works when launched from Automator
if ProcessInfo.processInfo.environment["TERM"] == nil {
    setenv("CG_SESSION_EVENT_ID", "1", 1)
}

// MARK: - Markdown Rendering

class MarkdownSubreddit: MarkdownLink {

  private static let regex = "(^|\\s|\\W)(/?r/(\\w+)/?)"

  override var regex: String {
    return MarkdownSubreddit.regex
  }

  override func match(_ match: NSTextCheckingResult, attributedString: NSMutableAttributedString) {
    let subredditName = attributedString.attributedSubstring(from: match.range(at: 3)).string
    let linkURLString = "http://reddit.com/r/\(subredditName)"
    formatText(attributedString, range: match.range, link: linkURLString)
    addAttributes(attributedString, range: match.range) //Removed the extra 'link' argument
  }

}

open class MarkdownCodeEscaping: MarkdownElement {

    fileprivate static let regex = "(?<!\\\\)(?:\\\\\\\\)*+(`+)(.*?[^`].*?)(\\1)(?!`)"

    open var regex: String {
        return MarkdownCodeEscaping.regex
    }

    open func regularExpression() throws -> NSRegularExpression {
        return try NSRegularExpression(pattern: regex, options: .dotMatchesLineSeparators)
    }

    open func match(_ match: NSTextCheckingResult, attributedString: NSMutableAttributedString) {
        let range = match.range(at: 2)
        // escaping all characters
        let matchString = attributedString.attributedSubstring(from: range).string
        let escapedString = [UInt16](matchString.utf16)
            .map { (value: UInt16) -> String in String(format: "%04x", value) }
            .reduce("") { (string: String, character: String) -> String in
                return "\(string)\(character)"
        }
        attributedString.replaceCharacters(in: range, with: escapedString)
    }
}

func makeMarkdownScrollView(markdown: String) -> NSScrollView {
    let textView = NSTextView()
    textView.isEditable = false
    textView.isSelectable = true
    textView.usesAdaptiveColorMappingForDarkAppearance = true
    textView.drawsBackground = true
    textView.textContainerInset = NSSize(width: 18, height: 18)
    // 🔑 CRITICAL: enable proper wrapping
    textView.textContainer?.widthTracksTextView = true
    textView.textContainer?.heightTracksTextView = false
    textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                              height: CGFloat.greatestFiniteMagnitude)
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false

    //let markdownParser = MarkdownParser(customElements: [MarkdownSubreddit()])
    //let markdownParser = MarkdownParser(customElements: [MarkdownCodeEscaping()])
    let markdownParser = MarkdownParser(font: NSFont.systemFont(ofSize:16))
    // Custom elements
    /// Bold
    markdownParser.bold.color = NSColor.cyan
    /// Header
    markdownParser.header.color = NSColor.black
    /// List
    markdownParser.list.color = NSColor.black
    /// Quote
    markdownParser.quote.color = NSColor.gray
    /// Link
    markdownParser.link.color = NSColor.blue
    markdownParser.automaticLink.color = NSColor.blue
    /// Italic
    markdownParser.italic.color = NSColor.gray
    /// Code
    markdownParser.code.font = NSFont.systemFont(ofSize: 14)
    markdownParser.code.textHighlightColor = NSColor.black
    markdownParser.code.textBackgroundColor = NSColor.lightGray
     
    if let attributedString = try? markdownParser.parse(markdown) {
        print("Successfully parsed markdown with MarkdownKit")
        textView.textStorage?.setAttributedString(attributedString)
    } else {
        print("Failed to parse markdown with MarkdownKit")
        textView.string = markdown // Fallback for unparsable markdown
    }
    
    let scrollView = NSScrollView()
    scrollView.documentView = textView
    scrollView.hasVerticalScroller = true
    scrollView.autoresizingMask = [.width, .height]
    return scrollView
}


func applyAppearance(_ isDark: Bool, to view: NSView) {
    view.appearance = NSAppearance(
        named: isDark ? .darkAqua : .aqua
    )
}

// MARK: - Actions

class SaveHandler: NSObject {
    @objc static func saveMarkdownAction() {
        guard let window = windowRef else { return }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.title = "Save Summary as Markdown"

        if let first = originalFileURLs.first {
            panel.directoryURL = first.deletingLastPathComponent()
            panel.nameFieldStringValue =
                originalFileURLs.count == 1
                ? "\(first.deletingPathExtension().lastPathComponent)_summary.md"
                : "combined_summary.md"
        }

        panel.beginSheetModal(for: window) { result in
            guard result == .OK, let url = panel.url else { return }
            try? markdownContent.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

class CopyHandler: NSObject {
    @objc static func copyAction() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdownContent, forType: .string)
    }
}

class RetryHandler: NSObject {
    @objc static func retryAction() {
        let model = CommandLine.arguments[1]
        let files = Array(CommandLine.arguments.dropFirst(2))
        guard let markdown = try? getMarkdownSummary(selectedModel: model, filePaths: files) else {
            return
        }
        markdownContent = markdown
        let newContentView = setupContentView(with: markdown)
        windowRef?.contentView = newContentView
    }
}

class CloseHandler: NSObject {
    @objc static func closeWindowAction() {
        NSApp.terminate(nil)
    }
}

class DarkModeHandler: NSObject {
    @objc static func toggleDarkMode() {
        darkModeEnabled.toggle()
        applyAppearance(darkModeEnabled, to: windowRef!.contentView!)
        windowRef?.appearance = NSAppearance(named: darkModeEnabled ? .darkAqua : .aqua)
        modeButton.title = darkModeEnabled ? "Dark Mode" : "Light Mode"
    }
}

func setupContentView(with markdown: String) -> NSView {
    let rootView = NSView()
    rootView.translatesAutoresizingMaskIntoConstraints = false
    let scrollView = makeMarkdownScrollView(markdown: markdown)
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    let buttonStack = NSStackView()
    buttonStack.orientation = .horizontal
    buttonStack.spacing = 10
    buttonStack.translatesAutoresizingMaskIntoConstraints = false
    let saveButton = NSButton(title: "Save Markdown", target: SaveHandler.self, action: #selector(SaveHandler.saveMarkdownAction))
    let copyButton = NSButton(title: "Copy", target: CopyHandler.self, action: #selector(CopyHandler.copyAction))
    let retryButton = NSButton(title: "Retry", target: RetryHandler.self, action: #selector(RetryHandler.retryAction))
    modeButton = NSButton(title: darkModeEnabled ? "Dark Mode" : "Light Mode", target: DarkModeHandler.self, action: #selector(DarkModeHandler.toggleDarkMode))
    let closeButton = NSButton(title: "Close", target: CloseHandler.self, action: #selector(CloseHandler.closeWindowAction))
    [saveButton, copyButton, retryButton, modeButton, closeButton].forEach {
        buttonStack.addArrangedSubview($0)
    }
    rootView.addSubview(scrollView)
    rootView.addSubview(buttonStack)
    NSLayoutConstraint.activate([
        buttonStack.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 12),
        buttonStack.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 12),
        scrollView.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 12),
        scrollView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
        scrollView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
        scrollView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
    ])
    applyAppearance(darkModeEnabled, to: rootView)
    return rootView
}

// MARK: - LLM Call

func run(_ cmd: String, input: Data? = nil) throws -> Data {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/bash")
    task.arguments = ["-c", cmd]

    let stdin = Pipe()
    let stdout = Pipe()
    task.standardInput = stdin
    task.standardOutput = stdout

    try task.run()

    if let input = input {
        stdin.fileHandleForWriting.write(input)
    }
    stdin.fileHandleForWriting.closeFile()

    task.waitUntilExit()
    return stdout.fileHandleForReading.readDataToEndOfFile()
}

func getMarkdownSummary(selectedModel: String, filePaths: [String]) throws -> String {
    let urls = filePaths.map(URL.init(fileURLWithPath:))
    originalFileURLs = urls

    var combined = ""
    for url in urls {
        let content = try String(contentsOf: url)
        if urls.count > 1 {
            combined += "\n\n--- File: \(url.lastPathComponent) ---\n\n"
        }
        combined += content
    }

    let payload: [String: Any] = [
        "model": selectedModel,
        "messages": [[
            "role": "user",
            "content": "Summarize and output in Markdown format:\n\n\(combined)"
        ]]
    ]

    let data = try JSONSerialization.data(withJSONObject: payload)

    let response = try run("""
    curl -s http://localhost:11434/v1/chat/completions \
      -H 'Content-Type: application/json' \
      -d @-
    """, input: data)

    let json = try JSONSerialization.jsonObject(with: response) as? [String: Any]
    let markdown = ((json?["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any])?["content"] as? String

    return markdown ?? ""
}

// MARK: - App Setup

guard CommandLine.arguments.count >= 3 else {
    print("Usage: LLMSummarizeDisplay <model> <file...>")
    exit(1)
}

let model = CommandLine.arguments[1]
let files = Array(CommandLine.arguments.dropFirst(2))
markdownContent = try getMarkdownSummary(selectedModel: model, filePaths: files)

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 1100, height: 850),
    styleMask: [.titled, .closable, .resizable],
    backing: .buffered,
    defer: false
)

window.title = "LLMSummarize"
windowRef = window

let contentView = setupContentView(with: markdownContent)
window.contentView = contentView

window.center()
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
app.run()
