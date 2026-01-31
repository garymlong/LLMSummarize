-- Second step of the LLM model selection workflow.
-- Receives the selected model name from GetLLMModels and displays it in Terminal.
-- Use in Automator: Run AppleScript, with "Pass input" from the previous action.
--
-- IMPORTANT: Set SCRIPT_DIR below to the full path of the automator-llm-summarize
-- directory (where show-selected-model.sh lives).

on run {input, parameters}
	
	#set INPUT_DIR to item 1 of input
	#set LLM_MODEL to item 2 of input
	#display dialog "Second script received: " & LLM_MODEL
	
	set SCRIPT_DIR to "/Users/garylong/Models/LLMScripts/LLMSummarize/automator-llm-summarize"
	
	
	set modelName to ""
	if input is not {} then
		if (class of input) is list then
			set targetFileHFS to item 1 of input
			set modelName to item 2 of input
		else
			display dialog "Invalid input to LLMSummarize "
		end if
	end if
	
	set posixPathString to POSIX path of file targetFileHFS
	
	#tell application "Terminal"
	#	activate
	#	set myTab to do script "cd " & quoted form of SCRIPT_DIR & " && ./run-llm-summarize.sh " & quoted form of modelName & " " & quoted form of posixPathString & " echo ''; read -p 'Press Return to close…'"
	-- Wait until the command is done (optional, but often necessary)
	# repeat until not busy of myTab
	# 	delay 4
	# end repeat
	-- Close the window containing the tab
	#close (window of myTab)
	#end tell
end run
