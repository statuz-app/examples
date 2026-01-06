-- Lightroom to Statuz: Batch Import

-- Setup:
-- 1. Save to ~/Library/Scripts/Folder Action Scripts/
-- 2. Right-click your export folder -> Folder Actions Setup
-- 3. Attach this script to the folder

-- Folder action handler - called automatically when files are added
-- this_folder: the watched folder (alias)
-- added_items: list of files that were just added (list of aliases)
on adding folder items to this_folder after receiving added_items
	try
		-- Build list of image/video files
		set mediaPaths to {}
		repeat with fileAlias in added_items
			set posixPath to POSIX path of fileAlias
			-- Only include supported formats
			if posixPath ends with ".jpg" or posixPath ends with ".jpeg" or Â
				posixPath ends with ".png" or posixPath ends with ".gif" or Â
				posixPath ends with ".heic" or posixPath ends with ".webp" or Â
				posixPath ends with ".mp4" or posixPath ends with ".mov" or Â
				posixPath ends with ".m4v" then
				set end of mediaPaths to "file://" & posixPath
			end if
		end repeat
		
		-- Skip if no supported files
		if (count of mediaPaths) is 0 then return
		
		-- Limit to 4 images per post (Statuz maximum)
		if (count of mediaPaths) > 4 then
			set mediaPaths to items 1 thru 4 of mediaPaths
		end if
		
		-- Build comma-separated list
		set AppleScript's text item delimiters to ","
		set mediaParam to mediaPaths as text
		set AppleScript's text item delimiters to ""
		
		-- Open Statuz with all images in one post
		tell application "System Events"
			open location "statuz://compose?media=" & mediaParam
		end tell
	end try
end adding folder items to