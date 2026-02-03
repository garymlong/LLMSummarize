#!/bin/bash
echo "Starting build process..."

# Update dependencies (important after adding a new package)
swift package update

# Build the project in release mode for better performance
swift build -c release

# Copy the executable to the current directory
cp .build/arm64-apple-macosx/release/LLMSummarizeDisplay ./LLMSummarizeDisplay

echo "Build process complete!"

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "Swift application built successfully"
    
    # Create a symlink to /usr/local/bin if needed
    #sudo ln -sf "$(pwd)/LLMSummarizeDisplay" "/usr/local/bin/LLMSummarizeDisplay"
    
    #echo "Built and installed LLMSummarizeDisplay to /usr/local/bin/"

    echo "Built LLMSummarizeDisplay to $(pwd)/LLMSummarizeDisplay"
else
    echo "Build failed!"
    exit 1
fi