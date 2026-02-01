import Cocoa
import WebKit
import UniformTypeIdentifiers
import Foundation


// Global variables for saving functionality
var markdownContent: String = ""
var originalFileURLs: [URL] = []
var windowRef: NSWindow?

// Ensure we can connect to the window server when launched from non-terminal contexts
// This is critical for Automator workflows
if ProcessInfo.processInfo.environment["TERM"] == nil {
    // Running outside of a terminal - ensure proper GUI setup
    setenv("CG_SESSION_EVENT_ID", "1", 1)
}

// Class to handle save action for menu and button
class SaveHandler: NSObject {
    @objc static func saveMarkdownAction() {
        guard let window = windowRef, !markdownContent.isEmpty else { return }
        
        let savePanel = NSSavePanel()
        savePanel.title = "Save Summary as Markdown"
        if let mdType = UTType(filenameExtension: "md") {
            savePanel.allowedContentTypes = [mdType]
        }
        savePanel.canCreateDirectories = true
        
        // Set default location to original file's folder and default filename
        if let firstURL = originalFileURLs.first {
            savePanel.directoryURL = firstURL.deletingLastPathComponent()
            if originalFileURLs.count == 1 {
                let stem = firstURL.deletingPathExtension().lastPathComponent
                savePanel.nameFieldStringValue = "\(stem)_summary.md"
            } else {
                savePanel.nameFieldStringValue = "combined_summary.md"
            }
        }
        
        savePanel.beginSheetModal(for: window) { result in
            if result == .OK, let url = savePanel.url {
                do {
                    try markdownContent.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "Save Failed"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .critical
                    alert.runModal()
                }
            }
        }
    }
}

// Class to hancle copy action for button
class CopyHandler: NSObject {
    @objc static func copyAction() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(markdownContent, forType: .string)
    }
}

// Class to handle close action for button
class CloseHandler: NSObject {
    @objc static func closeWindowAction() {
        windowRef?.close()
        exit(0)
    }
}

class WebViewDelegate: NSObject, WKNavigationDelegate {
    var onLoad: (() -> Void)?
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("WebView finished loading successfully")
        onLoad?()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("WebView failed to load: \(error)")
        let alert = NSAlert()
        alert.messageText = "Failed to load content"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.runModal()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("WebView failed provisional navigation: \(error)")
    }
}

func run(_ cmd: String, input: Data? = nil) throws -> Data {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/bash")
    task.arguments = ["-c", cmd]

    let stdin = Pipe()
    let stdout = Pipe()
    let stderr = Pipe()

    task.standardInput = stdin
    task.standardOutput = stdout
    task.standardError = stderr

    try task.run()

    if let input = input {
        stdin.fileHandleForWriting.write(input)
    }
    stdin.fileHandleForWriting.closeFile()

    task.waitUntilExit()

    let err = stderr.fileHandleForReading.readDataToEndOfFile()
    if !err.isEmpty {
        let msg = String(decoding: err, as: UTF8.self)
        print("Command error:", msg)
    }

    return stdout.fileHandleForReading.readDataToEndOfFile()
}

guard CommandLine.arguments.count >= 3 else {
    print("Error: Insufficient arguments. Usage: LLMSummarizeDisplay <model> <file1> [file2] ...")
    exit(1)
}

print("Starting LLMSummarize with arguments: \(CommandLine.arguments[1]) \(CommandLine.arguments[2])")

// If we have 3 or more arguments, the first one is the model name
let selectedModel = CommandLine.arguments[1]
let filePaths = Array(CommandLine.arguments.dropFirst(2))
let fileURLs = filePaths.map { URL(fileURLWithPath: $0) }
print("Using pre-selected model: \(selectedModel)")
print("Processing \(fileURLs.count) files: \(filePaths.joined(separator: ", "))")

var combinedText = ""
var fileContents: [(url: URL, content: String)] = []
for fileURL in fileURLs {
    do {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        fileContents.append((url: fileURL, content: content))
        if fileURLs.count > 1 {
            combinedText += "\n\n--- File: \(fileURL.lastPathComponent) ---\n\n"
        }
        combinedText += content
    } catch {
        print("Error reading file \(fileURL.path): \(error)")
        exit(1)
    }
}

print("Combined file content length: \(combinedText.count) characters")

print("Selected model: \(selectedModel)")

let payload: [String: Any] = [
    "model": selectedModel,
    "messages": [[
        "role": "user",
        "content": "Summarize \(fileURLs.count == 1 ? "this file" : "these \(fileURLs.count) files") concisely in Markdown:\n\n\(combinedText)"
    ]]
]

let payloadData = try JSONSerialization.data(withJSONObject: payload)

print("Sending request to local API...")

let responseData = try run("""
curl -s http://localhost:11434/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d @-
""", input: payloadData)

print("Received response, length: \(responseData.count) bytes")

let jsonAny = try JSONSerialization.jsonObject(with: responseData)
guard
    let json = jsonAny as? [String: Any],
    let choices = json["choices"] as? [[String: Any]],
    let first = choices.first,
    let message = first["message"] as? [String: Any],
    let markdown = message["content"] as? String
else {
    let errorMsg = "Unexpected API response:\n\(String(decoding: responseData, as: UTF8.self))"
    print(errorMsg)
    let alert = NSAlert()
    alert.messageText = "API Error"
    alert.informativeText = errorMsg
    alert.alertStyle = .critical
    alert.runModal()
    fatalError(errorMsg)
}

print("Got markdown content, length: \(markdown.count) characters")

let htmlData = try run(
    "pandoc -f markdown -t html --standalone",
    input: markdown.data(using: .utf8)
)

let html = String(decoding: htmlData, as: UTF8.self)
print("Generated HTML, length: \(html.count) characters")

// Store values for save functionality
originalFileURLs = fileURLs
markdownContent = markdown

print("Setting up NSApplication...")

// Create the app with proper activation
let app = NSApplication.shared
app.setActivationPolicy(.regular)

// Create menu bar with File menu
let mainMenu = NSMenu()
let fileMenuItem = NSMenuItem()
fileMenuItem.title = "File"
let fileMenu = NSMenu(title: "File")
let saveMenuItem = NSMenuItem(
    title: "Save as Markdown...",
    action: #selector(SaveHandler.saveMarkdownAction),
    keyEquivalent: "s"
)
let copyMenuItem = NSMenuItem(
    title: "Copy",
    action: #selector(CopyHandler.copyAction),
    keyEquivalent: "c"
)
copyMenuItem.target = CopyHandler.self
saveMenuItem.target = SaveHandler.self
fileMenu.addItem(saveMenuItem)
fileMenu.addItem(copyMenuItem)
fileMenuItem.submenu = fileMenu
mainMenu.addItem(fileMenuItem)
app.mainMenu = mainMenu

// Configure web view preferences
let config = WKWebViewConfiguration()
config.preferences.setValue(true, forKey: "developerExtrasEnabled")

let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
    styleMask: [.titled, .closable, .resizable, .miniaturizable],
    backing: .buffered,
    defer: false
)

window.title = "LLMSummarize (\(fileURLs.count == 1 ? "1 file" : "\(fileURLs.count) files"))"

let webViewDelegate = WebViewDelegate()
let webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
webView.autoresizingMask = [.width, .height]
webView.navigationDelegate = webViewDelegate

window.contentView?.addSubview(webView)

// Store window reference for save dialog
windowRef = window

// Add save button to top-right corner
// Note: macOS coordinates have y=0 at bottom, so we position near the top
let contentBounds = window.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 900, height: 700)
let buttonWidth: CGFloat = 150
let buttonHeight: CGFloat = 28
let buttonMargin: CGFloat = 8
let saveButton = NSButton(frame: NSRect(
    x: contentBounds.width - buttonWidth - buttonMargin,
    y: contentBounds.height - buttonHeight - buttonMargin,
    width: buttonWidth,
    height: buttonHeight
))
saveButton.title = "Save as Markdown"
saveButton.bezelStyle = .rounded
saveButton.autoresizingMask = [.minXMargin, .maxYMargin]
saveButton.target = SaveHandler.self
saveButton.action = #selector(SaveHandler.saveMarkdownAction)
window.contentView?.addSubview(saveButton)

// Add copy button to top-right corner
let copyButton = NSButton(frame: NSRect(
    x: contentBounds.width - buttonWidth - buttonMargin,
    y: contentBounds.height - 2*buttonHeight - 2*buttonMargin,
    width: buttonWidth,
    height: buttonHeight
))
copyButton.title = "Copy Markdown"
copyButton.bezelStyle = .rounded
copyButton.autoresizingMask = [.minXMargin, .maxYMargin]
copyButton.target = CopyHandler.self
copyButton.action = #selector(CopyHandler.copyAction)
window.contentView?.addSubview(copyButton)

// Add close button to top-left corner
let closeButton = NSButton(frame: NSRect(
    x: buttonMargin,
    y: contentBounds.height - buttonHeight - buttonMargin,
    width: buttonWidth,
    height: buttonHeight
))
closeButton.title = "Close"
closeButton.bezelStyle = .rounded
closeButton.autoresizingMask = [.maxXMargin, .maxYMargin]
closeButton.target = CloseHandler.self
closeButton.action = #selector(CloseHandler.closeWindowAction)
window.contentView?.addSubview(closeButton)

window.center()
window.makeKeyAndOrderFront(nil)

// Show window before loading content
window.orderFrontRegardless()

print("Loading HTML content...")
webView.loadHTMLString(html, baseURL: nil)

print("Activating app...")
app.activate(ignoringOtherApps: true)

print("Running app...")
app.run()
