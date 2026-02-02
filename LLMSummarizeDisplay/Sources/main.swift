import Cocoa
import Foundation

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

func makeMarkdownScrollView(markdown: String) -> NSScrollView {
    let textView = NSTextView()
    textView.isEditable = false
    textView.isSelectable = true
    textView.usesAdaptiveColorMappingForDarkAppearance = true
    textView.drawsBackground = true
    textView.textContainerInset = NSSize(width: 18, height: 18)
    textView.font = NSFont.systemFont(ofSize: 14)

    // 🔑 CRITICAL: enable proper wrapping
    textView.textContainer?.widthTracksTextView = true
    textView.textContainer?.heightTracksTextView = false
    textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                              height: CGFloat.greatestFiniteMagnitude)
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false

    if #available(macOS 12.0, *) {
        if let attributed = try? NSAttributedString(markdown: markdown) {
            textView.textStorage?.setAttributedString(attributed)
        }
    } else {
        textView.string = markdown
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
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
        let scroll = makeMarkdownScrollView(markdown: markdown)
        applyAppearance(darkModeEnabled, to: scroll)
        windowRef?.contentView = scroll
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
        modeButton.title = darkModeEnabled ? "Dark Mode" : "Light Mode"
    }
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
            "content": "Summarize in Markdown:\n\n\(combined)"
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

let rootView = NSView()
rootView.translatesAutoresizingMaskIntoConstraints = false
window.contentView = rootView

let scrollView = makeMarkdownScrollView(markdown: markdownContent)
scrollView.translatesAutoresizingMaskIntoConstraints = false

let buttonStack = NSStackView()
buttonStack.orientation = .horizontal
buttonStack.spacing = 10
buttonStack.translatesAutoresizingMaskIntoConstraints = false

let saveButton = NSButton(title: "Save Markdown", target: SaveHandler.self, action: #selector(SaveHandler.saveMarkdownAction))
let copyButton = NSButton(title: "Copy", target: CopyHandler.self, action: #selector(CopyHandler.copyAction))
let retryButton = NSButton(title: "Retry", target: RetryHandler.self, action: #selector(RetryHandler.retryAction))
modeButton = NSButton(title: "Light Mode", target: DarkModeHandler.self, action: #selector(DarkModeHandler.toggleDarkMode))
let closeButton = NSButton(title: "Close", target: CloseHandler.self, action: #selector(CloseHandler.closeWindowAction))

[saveButton, copyButton, retryButton, modeButton, closeButton].forEach {
    buttonStack.addArrangedSubview($0)
}

rootView.addSubview(scrollView)
rootView.addSubview(buttonStack)

NSLayoutConstraint.activate([
    // Buttons at top
    buttonStack.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 12),
    buttonStack.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 12),

    // Scroll view below buttons
    scrollView.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 12),
    scrollView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
    scrollView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
    scrollView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
])

window.center()
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
app.run()