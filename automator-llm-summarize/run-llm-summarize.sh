#!/usr/bin/env bash
# Displays the selected LLM model name (from step 1 of the Automator workflow).
# Run from ShowSelectedModel.applescript with the model name as $1.
# Make executable: chmod +x show-selected-model.sh

if [ -z "$1" ]; then
  echo "No model selected."
elif [ -z "$2" ]; then
  echo "No target file specified."
else
  echo "Selected model: $1"
  echo "Target file: $2"
fi
lockFile="/tmp/LLMSummarizeDisplay+$DATE.lock"
touch "$lockFile"
/usr/local/bin/LLMSummarizeDisplay "$1" "$2" "$lockFile"> /dev/null 2>&1
# read -p 'Press Return to close…'
while [ -f "$lockFile" ]; do
  echo "Waiting for lock file to be deleted..."
  sleep 2
done
#exit 0