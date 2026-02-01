# Multi-File Support Plan Improvements

## Current Limitations
- AppleScript converts input to a single string, losing multi-file information
- Swift app expects exactly 2 arguments (model + single file)
- File processing, API calls, and save functionality are all designed for single files

## Required Changes

### 1. GetLLMModels.applescript Changes
Line 11: Replace single file extraction
```
# CURRENT:
set INPUT_FILE to input as text
# NEEDED:
set INPUT_FILES to input  # Keep as list
```

Line 34-35: Handle file list conversion  
```
# CURRENT:
set targetFileHFS to INPUT_FILE
set modelName to trimmed
# NEEDED:
set targetFileHFSList to INPUT_FILES
set modelName to trimmed
```

Line 44-46: Update Terminal command to pass multiple files
```
# CURRENT:
set posixPathString to POSIX path of file targetFileHFS
do script "/usr/local/bin/LLMSummarizeDisplay " & quoted form of modelName & " " & quoted form of posixPathString in myTab
# NEEDED:
set posixPathList to {}
repeat with fileRef in targetFileHFSList
    set end of posixPathList to POSIX path of file fileRef
end repeat
set allPathsString to ""
repeat with i from 1 to count of posixPathList
    if i = 1 then
        set allPathsString to quoted form of item i of posixPathList
    else
        set allPathsString to allPathsString & " " & quoted form of item i of posixPathList
    end if
end repeat
do script "/usr/local/bin/LLMSummarizeDisplay " & quoted form of modelName & " " & allPathsString in myTab
```

### 2. LLMSummarizeDisplay/main.swift Changes

Lines 8-11: Update global variables
```
# CURRENT:
var markdownContent: String = ""
var originalFileURL: URL?
var windowRef: NSWindow?
# NEEDED:
var markdownContent: String = ""
var originalFileURLs: [URL] = []
var windowRef: NSWindow?
```

Lines 169-181: Update argument parsing
```
# CURRENT:
let selectedModel: String
if CommandLine.arguments.count >= 3 {
    selectedModel = CommandLine.arguments[1]
    print("Using pre-selected model: \(selectedModel)")
} else {
    // Error handling
}
let fileURL = URL(fileURLWithPath: CommandLine.arguments[2])
# NEEDED:
guard CommandLine.arguments.count >= 3 else {
    print("Error: Insufficient arguments. Usage: LLMSummarizeDisplay <model> <file1> [file2] ...")
    exit(1)
}
let selectedModel = CommandLine.arguments[1]
let filePaths = Array(CommandLine.arguments.dropFirst(2))
let fileURLs = filePaths.map { URL(fileURLWithPath: $0) }
print("Using pre-selected model: \(selectedModel)")
print("Processing \(fileURLs.count) files: \(filePaths.joined(separator: ", "))")
```

Lines 184: Update file reading
```
# CURRENT:
let fileText = try String(contentsOf: fileURL, encoding: .utf8)
# NEEDED:
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
```

Lines 193-199: Update API payload
```
# CURRENT:
let payload: [String: Any] = [
    "model": selectedModel,
    "messages": [[
        "role": "user",
        "content": "Summarize this text concisely in Markdown:\n\n\(fileText)"
    ]]
]
# NEEDED:
let payload: [String: Any] = [
    "model": selectedModel,
    "messages": [[
        "role": "user",
        "content": "Summarize \(fileURLs.count == 1 ? \"this file\" : \"these \(fileURLs.count) files\") concisely in Markdown:\n\n\(combinedText)"
    ]]
]
```

Lines 242-243: Update global storage
```
# CURRENT:
originalFileURL = fileURL
markdownContent = markdown
# NEEDED:
originalFileURLs = fileURLs
markdownContent = markdown
```

Lines 31-36: Update save functionality
```
# CURRENT:
if let originalURL = originalFileURL {
    savePanel.directoryURL = originalURL.deletingLastPathComponent()
    let stem = originalURL.deletingPathExtension().lastPathComponent
    savePanel.nameFieldStringValue = "\(stem)_summary.md"
}
# NEEDED:
if let firstURL = originalFileURLs.first {
    savePanel.directoryURL = firstURL.deletingLastPathComponent()
    if originalFileURLs.count == 1 {
        let stem = firstURL.deletingPathExtension().lastPathComponent
        savePanel.nameFieldStringValue = "\(stem)_summary.md"
    } else {
        savePanel.nameFieldStringValue = "combined_summary.md"
    }
}
```

Line 285: Update window title
```
# CURRENT:
window.title = "LLMSummarize"
# NEEDED:
window.title = "LLMSummarize (\(fileURLs.count == 1 ? \"1 file\" : \"\(fileURLs.count) files\"))"
```

## Additional Improvements

### Enhanced Error Handling
- Add proper error handling for file operations in Swift application
- Validate file types before processing (only process text-based files)
- Implement timeout handling for API calls

### Memory Management
- For very large files, consider streaming content instead of loading entire files into memory
- Add progress indicators for long-running operations

### UI Enhancements
- Show progress bar when processing multiple files
- Display list of files being processed in the window title
- Add file type validation to prevent processing binary files

### API Response Handling
- Handle API errors gracefully with user-friendly messages
- Implement retry logic for failed API calls
- Add timeout mechanism for API responses