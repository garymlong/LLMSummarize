import Cocoa
import WebKit
import UniformTypeIdentifiers
import Foundation


// Global variables for saving functionality
var markdownContent: String = ""
var originalFileURLs: [URL] = []
var windowRef: NSWindow?
var darkModeEnabled: Bool = false

// Ensure we can connect to the window server when launched from non-terminal contexts
// This is critical for Automator workflows
if ProcessInfo.processInfo.environment["TERM"] == nil {
    // Running outside of a terminal - ensure proper GUI setup
    setenv("CG_SESSION_EVENT_ID", "1", 1)
}


func getStylesFilePath() -> String? {
    // This is the correct way to get resource from bundle
    if let url = Bundle.main.url(forResource: "styles", withExtension: "css") {
        print("Found styles.css at: \(url.path)")
        return url.path
    } else {
        print("styles.css not found in bundle (attempting fallback)")
        // Try to find it in the Styles directory as a fallback
        if let url = Bundle.main.url(forResource: "Styles/styles", withExtension: "css") {
            print("Found styles.css at fallback path: \(url.path)")
            return url.path
        }
        // Try alternative resource names that might work
        print("Trying alternative resource names...")
        if let url = Bundle.main.url(forResource: "styles", withExtension: "css", subdirectory: "Styles") {
            print("Found styles.css at subdirectory path: \(url.path)")
            return url.path
        }
        print("styles.css NOT FOUND in bundle")
        return nil
    }
}


// Class to handle save action for menu and button
class SaveHandler: NSObject {
    @objc static func saveMarkdownAction() {
        guard let window = windowRef, !markdownContent.isEmpty else { return }
        
        let savePanel = NSSavePanel()
        savePanel.title = "Save Summary as Markdown"
        // For older macOS versions, use a simple approach without UTType
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

// Class to handle copy action for button
class CopyHandler: NSObject {
    @objc static func copyAction() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(markdownContent, forType: .string)
    }
}

// Class to handle retry action for button
class RetryHandler: NSObject {
    @objc static func retryAction() {
        // TODO: Implement retry logic
        let selectedModel = CommandLine.arguments[1]
        let filePaths = Array(CommandLine.arguments.dropFirst(2))
        let markdown = try? getMarkdownSummary(selectedModel: selectedModel, filePaths: filePaths)
        guard let markdown = markdown else {
            print("Error getting markdown summary")
            return
        }
        
        let cssFile = getStylesFilePath()
        
        guard let cssFile = cssFile else {
            print("Error: Could not find styles.css file")
            return
        }

let cssFile = getStylesFilePath()
        
guard let cssFile = cssFile else {
    print("Error: Could not find styles.css file")
    exit(1)
}

markdownContent = markdown
let cssFile = getStylesFilePath()
        
guard let cssFile = cssFile else {
    print("Error: Could not find styles.css file")
    return
}

let htmlData = try? run(
    "pandoc -f markdown -t html --standalone --css=" + cssFile,
    input: markdown.data(using: .utf8)
)
    } catch {
        print("Failed to read CSS file for retry: \(error)")
    }
}
        guard let htmlData = htmlData else {
            print("Error running pandoc")
            return
        }
        let html = String(decoding: htmlData, as: UTF8.self)
        webView.loadHTMLString(html, baseURL: nil)
    }
}

// Class to handle close action for button
class CloseHandler: NSObject {
    @objc static func closeWindowAction() {
        windowRef?.close()
        exit(0)
    }
}

// Class to handle dark mode toggle
class DarkModeHandler: NSObject {
    @objc static func toggleDarkMode() {
        darkModeEnabled.toggle()
        print("Dark mode enabled:", darkModeEnabled)
        updateModeButton()
        
        // Inject JavaScript to update the body class
        let script = """
        function setDarkMode(enabled) {
            if (enabled) {
                document.body.classList.add('dark-mode');
                document.body.classList.remove('light-mode');
            } else {
                document.body.classList.add('light-mode');
                document.body.classList.remove('dark-mode');
            }
        }
        setDarkMode(\(darkModeEnabled));
        """
        
        webViewRef?.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("Error executing dark mode script: \(error)")
            }
        }
    }
    
    static func updateModeButton() {
        modeButton.title = darkModeEnabled ? "Dark Mode" : "Light Mode"
    }
}

class WebViewDelegate: NSObject, WKNavigationDelegate {
    var onLoad: (() -> Void)?
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("WebView finished loading successfully")
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

func getMarkdownSummary(selectedModel: String, filePaths: [String]) throws -> String {
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
            throw error
        }
    }

    print("Combined file content length: \(combinedText.count) characters")

    print("Selected model: \(selectedModel)")

    let payload: [String: Any] = [
        "model": selectedModel,
        "messages": [[
            "role": "user",
            "content": "Summarize \(fileURLs.count == 1 ? "this file" : "these \(fileURLs.count) files") concisely in Markdown:\n\n\(combinedText)",
        ]],
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
        exit(1)
    }
    return markdown
}

let selectedModel = CommandLine.arguments[1]
let filePaths = Array(CommandLine.arguments.dropFirst(2))
let fileURLs = filePaths.map { URL(fileURLWithPath: $0) }
print("Using pre-selected model: \(selectedModel)")
print("Processing \(fileURLs.count) files: \(filePaths.joined(separator: ", "))")

let markdown = try getMarkdownSummary(selectedModel: selectedModel, filePaths: filePaths)

print("Got markdown content, length: \(markdown.count) characters")

let cssFile = getStylesFilePath()
        
guard let cssFile = cssFile else {
    print("Error: Could not find styles.css file")
    exit(1)
}

// Generate HTML without external CSS first
var htmlData = try? run(
    "pandoc -f markdown -t html --standalone --css=" + cssFile,
    input: markdown.data(using: .utf8)
)

// If we have a CSS file, embed it in the HTML
if let cssPath = getStylesFilePath() {
    do {
        let cssContent = try String(contentsOfFile: cssPath)
        if var htmlString = String(data: htmlData ?? Data(), encoding: .utf8) {
            // Insert CSS into the <head> section of the HTML
            let cssStyle = "<style>\n\(cssContent)\n</style>"
            htmlString = htmlString.replacingOccurrences(of: "</head>", with: "\(cssStyle)</head>")
            
            // Add body class for initial mode - make sure we're not duplicating
            if !htmlString.contains("class=\"") {
                // Check if there's a <body> tag, otherwise add it to the html tag
                if htmlString.contains("<body") {
                    htmlString = htmlString.replacingOccurrences(of: "<body", with: "<body class=\"\(darkModeEnabled ? "dark-mode" : "light-mode")\">")
                } else {
                    // No body tag - likely a standalone HTML without body, add it to the html tag
                    htmlString = htmlString.replacingOccurrences(of: "<html", with: "<html class=\"\(darkModeEnabled ? "dark-mode" : "light-mode")\">")
                }
            }
            
            htmlData = htmlString.data(using: .utf8)
        }
    } catch {
        print("Failed to read CSS file: \(error)")
    }
}

guard let htmlData = htmlData else {
    print("Error running pandoc or no output data")
    exit(1) // Terminate the program
}

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
// Set targets with version check
#if compiler(>=5.7)
if #available(macOS 11.0, *) {
    saveMenuItem.target = SaveHandler.self
} else {
    // For older macOS versions, don't set target or handle differently
}
#else
saveMenuItem.target = SaveHandler.self
#endif
let copyMenuItem = NSMenuItem(
    title: "Copy",
    action: #selector(CopyHandler.copyAction),
    keyEquivalent: "c"
)
let retryMenuItem = NSMenuItem(
    title: "Retry",
    action: #selector(RetryHandler.retryAction),
    keyEquivalent: "r"
)
retryMenuItem.target = RetryHandler.self
copyMenuItem.target = CopyHandler.self
saveMenuItem.target = SaveHandler.self
fileMenu.addItem(saveMenuItem)
fileMenu.addItem(copyMenuItem)
fileMenu.addItem(retryMenuItem)
fileMenuItem.submenu = fileMenu
mainMenu.addItem(fileMenuItem)
app.mainMenu = mainMenu

// Set targets for other menu items with version check
#if compiler(>=5.7)
if #available(macOS 11.0, *) {
    retryMenuItem.target = RetryHandler.self
    copyMenuItem.target = CopyHandler.self
    saveMenuItem.target = SaveHandler.self
} else {
    // For older macOS versions, don't set targets
}
#else
retryMenuItem.target = RetryHandler.self
copyMenuItem.target = CopyHandler.self
saveMenuItem.target = SaveHandler.self
#endif

// Configure web view preferences with dark mode support
let config = WKWebViewConfiguration()
config.preferences.setValue(true, forKey: "developerExtrasEnabled")

// Add custom CSS and JavaScript for theme switching
let userContentController = WKUserContentController()

// JavaScript to handle dark mode toggle
let darkModeScript = """
function setDarkMode(enabled) {
    if (enabled) {
        document.body.classList.add('dark-mode');
        document.body.classList.remove('light-mode');
    } else {
        document.body.classList.add('light-mode');
        document.body.classList.remove('dark-mode');
    }
}

// Set initial mode
setDarkMode(\(darkModeEnabled));
"""

userContentController.addUserScript(WKUserScript(source: darkModeScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
config.userContentController = userContentController

let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 1200, height: 900),
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

// Create a global variable to hold the webView for theme updates
var webViewRef: WKWebView?

// Add save button to top-right corner
// Note: macOS coordinates have y=0 at bottom, so we position near the top
let contentBounds = window.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 1200, height: 900)
let buttonWidth: CGFloat = 150
let buttonHeight: CGFloat = 28
let buttonMargin: CGFloat = 8

// Add mode toggle button
let modeButton = NSButton(frame: NSRect(
    x: contentBounds.width - buttonWidth - buttonMargin,
    y: contentBounds.height - buttonHeight - buttonMargin,
    width: 100,
    height: 28
))
modeButton.title = "Light Mode"
modeButton.bezelStyle = .rounded
modeButton.autoresizingMask = [.minXMargin, .maxYMargin]
modeButton.target = DarkModeHandler.self
modeButton.action = #selector(DarkModeHandler.toggleDarkMode)
window.contentView?.addSubview(modeButton)

// Add save button to top-right corner
let saveButton = NSButton(frame: NSRect(
    x: contentBounds.width - buttonWidth - buttonMargin,
    y: contentBounds.height - 2*buttonHeight - 2*buttonMargin,
    width: buttonWidth,
    height: buttonHeight
))
saveButton.title = "Save as Markdown"
saveButton.bezelStyle = .rounded
saveButton.autoresizingMask = [.minXMargin, .maxYMargin]
saveButton.target = SaveHandler.self
saveButton.action = #selector(SaveHandler.saveMarkdownAction)
window.contentView?.addSubview(saveButton)

// Add version check for button targets as well
#if compiler(>=5.7)
if #available(macOS 11.0, *) {
    saveButton.target = SaveHandler.self
    copyButton.target = CopyHandler.self
    retryButton.target = RetryHandler.self
} else {
    // For older macOS versions, don't set targets or handle differently
}
#else
saveButton.target = SaveHandler.self
copyButton.target = CopyHandler.self
retryButton.target = RetryHandler.self
#endif

// Add copy button to top-right corner
let copyButton = NSButton(frame: NSRect(
    x: contentBounds.width - buttonWidth - buttonMargin,
    y: contentBounds.height - 3*buttonHeight - 3*buttonMargin,
    width: buttonWidth,
    height: buttonHeight
))
copyButton.title = "Copy Markdown"
copyButton.bezelStyle = .rounded
copyButton.autoresizingMask = [.minXMargin, .maxYMargin]
copyButton.target = CopyHandler.self
copyButton.action = #selector(CopyHandler.copyAction)
window.contentView?.addSubview(copyButton)

// Add retry button to top-right corner
let retryButton = NSButton(frame: NSRect(
    x: contentBounds.width - buttonWidth - buttonMargin,
    y: contentBounds.height - 4*buttonHeight - 4*buttonMargin,
    width: buttonWidth,
    height: buttonHeight
))
retryButton.title = "Retry"
retryButton.bezelStyle = .rounded
retryButton.autoresizingMask = [.minXMargin, .maxYMargin]
retryButton.target = RetryHandler.self
retryButton.action = #selector(RetryHandler.retryAction)
window.contentView?.addSubview(retryButton)

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

// Store webView reference for theme updates
webViewRef = webView

// Set initial body class for dark mode
let initialScript = """
document.body.classList.add('\(darkModeEnabled ? "dark-mode" : "light-mode")');
"""
webView.evaluateJavaScript(initialScript) { result, error in
    if let error = error {
        print("Error setting initial body class: \(error)")
    }
}

// Make sure webView is accessible to RetryHandler
webView.loadHTMLString(html, baseURL: nil)

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
