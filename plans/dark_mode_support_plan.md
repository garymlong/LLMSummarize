# Dark Mode Support Plan for LLMSummarizeDisplay

## Overview
This plan outlines the implementation of dark/light mode toggle functionality for the WKWebView in the LLMSummarizeDisplay macOS application.

## TODO List

1. ✅ Add dark mode toggle buttons below retry button in main.swift
2. ✅ Modify HTML generation to include dark theme CSS styles  
3. ✅ Implement JavaScript for dynamic dark mode switching
4. ✅ Update WKWebView configuration for dark mode support
5. ⬜ Test dark/light mode toggle functionality

## Implementation Details

### 1. Dark/light mode toggle buttons
- Position two buttons (Dark Mode/Light Mode) below the retry button
- Buttons will be side-by-side with appropriate spacing
- Will use NSButton with rounded bezel style

### 2. HTML content modification  
- Add comprehensive CSS for both light and dark themes
- Style all HTML elements including headers, code blocks, tables, links, etc.
- Implement JavaScript functions to dynamically switch themes

### 3. JavaScript implementation
- Create `window.setDarkMode()` function to apply theme
- Implement `window.toggleDarkMode()` for switching between modes  
- Add localStorage persistence for theme preference
- Handle button label updates based on current theme

### 4. WKWebView configuration
- Configure WKWebView with appropriate preferences for dark mode
- Ensure themes are applied correctly when content loads
- Handle theme changes during WebView lifecycle

## File Modifications
- `/Users/garylong/Models/LLMScripts/LLMSummarize/LLMSummarizeDisplay/LLMSummarizeDisplay/main.swift`

## Testing Requirements
- Verify buttons appear in correct position
- Confirm theme toggle functionality works
- Test persistence of theme preference
- Ensure existing functionality remains intact