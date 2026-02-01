# Multi-File Support Test Script

This script tests that the multi-file support implementation is working correctly.

## What we've implemented:
1. AppleScript now handles multiple file inputs (INPUT_FILES instead of INPUT_FILE)
2. Swift application processes multiple files and combines their content
3. API prompt adjusts based on single/multiple files 
4. Save functionality works for both single and multiple files
5. Window title displays correct count

## How to test:

1. Run the AppleScript with multiple file selection in Automator
2. Check that all files are processed together
3. Verify the output includes file separators when processing multiple files
4. Confirm save dialog shows appropriate naming for single/multiple files
5. Test window title shows correct count (e.g., "LLMSummarize (2 files)")

## Files modified:
- /Users/garylong/Models/LLMScripts/LLMSummarize/automator-llm-summarize/GetLLMModels.applescript
- /Users/garylong/Models/LLMScripts/LLMSummarize/LLMSummarizeDisplay/LLMSummarizeDisplay/main.swift

## Verification:
The implementation maintains backward compatibility while adding multi-file support.