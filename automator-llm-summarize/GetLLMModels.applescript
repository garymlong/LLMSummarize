-- Run the Clack prompt to select LLM model in Terminal and call the localLLM model to summarize the input file
-- Use this script inside Automator: Application → Run AppleScript (paste this).
-- Writes the selected model to a temp file; this script polls for it and returns the value.
--
-- IMPORTANT: Set SCRIPT_DIR below to the full path of the automator-llm-summarize
-- directory (where prompt-llm-select.mjs and node_modules live).

on run {input, parameters}
	
	set SCRIPT_DIR to "/Users/garylong/Models/LLMScripts/LLMSummarize/automator-llm-summarize"
	set INPUT_FILE to input as text
	set RESULT_FILE to "/tmp/llm-selected-model.txt"
	set POLL_TIMEOUT to 120
	#display dialog "Received: " & INPUT_FILE
	
	tell application "Terminal"
		activate
		set myTab to do script "cd " & quoted form of SCRIPT_DIR & " && export LLM_RESULT_FILE=" & quoted form of RESULT_FILE & " && node prompt-llm-select.mjs; echo ''; read -p 'Press Return to close…'"
		
		set elapsed to 0
		repeat while elapsed is less than POLL_TIMEOUT
			delay 1
			set elapsed to elapsed + 1
			try
				set fileExists to do shell script "test -f " & quoted form of RESULT_FILE & " && echo 1 || true"
				if fileExists is "1" then
					set resultContents to do shell script "cat " & quoted form of RESULT_FILE
					do shell script "rm -f " & quoted form of RESULT_FILE
					set astid to AppleScript's text item delimiters
					set AppleScript's text item delimiters to {return, linefeed}
					set trimmed to (text items of resultContents) as text
					set AppleScript's text item delimiters to astid
					#return {INPUT_FILE, trimmed}
					set targetFileHFS to INPUT_FILE
					set modelName to trimmed
					set elapsed to POLL_TIMEOUT
				end if
			on error
				-- keep polling
			end try
		end repeat
		
		
		set posixPathString to POSIX path of file targetFileHFS
		#do script "cd " & quoted form of SCRIPT_DIR & " && ./run-llm-summarize.sh " & quoted form of modelName & " " & quoted form of posixPathString in myTab
		do script "/usr/local/bin/LLMSummarizeDisplay " & quoted form of modelName & " " & quoted form of posixPathString in myTab
		delay 1
		set W_ to windows of application "Terminal"
		repeat until busy of (item 1 of W_) is false
		end repeat
		close window 1
	end tell
end run
