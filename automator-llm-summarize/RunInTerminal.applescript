-- Run the Clack prompt + create-folder script in Terminal.
-- Use this script inside Automator: Application → Run AppleScript (paste this).
--
-- IMPORTANT: Set SCRIPT_DIR below to the full path of the automator-llm-summarize
-- directory (where prompt-and-create-folder.mjs and node_modules live).

set SCRIPT_DIR to "/Users/garylong/Models/LLMScripts/LLMSummarize/automator-llm-summarize"

on run {input, parameters}
	tell application "Terminal"
		activate
		do script "cd " & quoted form of SCRIPT_DIR & " && node prompt-and-create-folder.mjs; echo ''; read -p 'Press Return to close…'"
	end tell
	return input
end run
