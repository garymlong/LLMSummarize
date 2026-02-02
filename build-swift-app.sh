#!/bin/bash

# Build LLMSummarizeDisplay app from Swift source
cd /Users/garylong/Models/LLMScripts/LLMSummarize/LLMSummarizeDisplay

# Create build directory if it doesn't exist
mkdir -p build

# Compile the Swift application
xcrun swiftc \
    -o LLMSummarizeDisplay \
    -sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk \
    -target x86_64-apple-macos10.15 \
    Sources/main.swift \
    -framework Cocoa \
    -framework WebKit \
    -framework UniformTypeIdentifiers

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "Swift application built successfully"
    
    # Create a symlink to /usr/local/bin if needed
    sudo ln -sf "$(pwd)/LLMSummarizeDisplay" "/usr/local/bin/LLMSummarizeDisplay"
    
    echo "Built and installed LLMSummarizeDisplay to /usr/local/bin/"
else
    echo "Build failed!"
    exit 1
fi