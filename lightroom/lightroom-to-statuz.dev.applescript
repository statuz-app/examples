-- Lightroom to Statuz: Batch Import with Cloud Sync Support
-- Version 2.0 - Handles cloud-synced files properly

-- Setup:
-- 1. Save to ~/Library/Scripts/Folder Action Scripts/
-- 2. Right-click your export folder -> Folder Actions Setup
-- 3. Attach this script to the folder

-- CONFIGURATION
property FILE_STABILITY_TIMEOUT : 30 -- seconds to wait for file to stabilize
property FILE_CHECK_INTERVAL : 0.5 -- seconds between size checks  
property BATCH_DELAY : 1.5 -- seconds to wait for batch completion
property STATUZ_SCHEME : "statuz-dev://compose?media=" -- use "statuz-dev://compose?media=" for dev builds

-- URL encode a string for use in URL parameters
on urlEncode(theText)
	set theResult to do shell script "python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' " & quoted form of theText
	return theResult
end urlEncode

-- Get file size in bytes using shell (faster than Finder)
on getFileSize(posixPath)
	try
		set sizeStr to do shell script "stat -f%z " & quoted form of posixPath
		return sizeStr as integer
	on error
		return -1
	end try
end getFileSize

-- Check if file is likely a valid image by checking first bytes (JPEG magic bytes, PNG, etc.)
on isValidImageHeader(posixPath)
	try
		-- Check JPEG magic bytes (FFD8FF), PNG (89504E47), GIF (47494638), or HEIC/HEIF container
		set headerHex to do shell script "xxd -l 12 -p " & quoted form of posixPath
		-- JPEG starts with FFD8FF
		if headerHex starts with "ffd8ff" then return true
		-- PNG starts with 89504E47
		if headerHex starts with "89504e47" then return true
		-- GIF starts with GIF8
		if headerHex starts with "47494638" then return true
		-- WebP starts with RIFF....WEBP (52494646 at 0, 57454250 at 8)
		if headerHex starts with "52494646" then
			set webpCheck to do shell script "xxd -s 8 -l 4 -p " & quoted form of posixPath
			if webpCheck is "57454250" then return true
		end if
		-- HEIC/HEIF - ftyp box (....ftyp starting at byte 4)
		if length of headerHex ³ 16 then
			set ftypCheck to text 9 thru 16 of headerHex
			if ftypCheck is "66747970" then return true -- "ftyp" in hex
		end if
		return false
	on error
		return false
	end try
end isValidImageHeader

-- Check if file is a valid video container (MOV/MP4)
on isValidVideoHeader(posixPath)
	try
		-- Check for ftyp box (MOV/MP4 container)
		set headerHex to do shell script "xxd -l 12 -p " & quoted form of posixPath
		-- ftyp at byte 4-7 indicates MP4/MOV container
		if length of headerHex ³ 16 then
			set ftypCheck to text 9 thru 16 of headerHex
			if ftypCheck is "66747970" then return true
		end if
		-- QuickTime MOV can also start with moov or mdat
		if headerHex starts with "00000" then
			set atomType to text 9 thru 16 of headerHex
			if atomType is in {"6d6f6f76", "6d646174", "66726565"} then return true -- moov, mdat, free
		end if
		return false
	on error
		return false
	end try
end isValidVideoHeader

-- Wait for a file to be fully written (size stabilizes and valid header)
on waitForFileStability(posixPath, isVideo)
	set startTime to current date
	set lastSize to -1
	set stableCount to 0
	set requiredStableChecks to 3 -- require 3 consecutive same-size checks
	
	repeat
		-- Check timeout
		if ((current date) - startTime) > FILE_STABILITY_TIMEOUT then
			return false
		end if
		
		set currentSize to my getFileSize(posixPath)
		
		-- File must exist and have non-zero size
		if currentSize ² 0 then
			delay FILE_CHECK_INTERVAL
		else if currentSize = lastSize then
			set stableCount to stableCount + 1
			if stableCount ³ requiredStableChecks then
				-- Size is stable, now validate header
				if isVideo then
					if my isValidVideoHeader(posixPath) then
						return true
					end if
				else
					if my isValidImageHeader(posixPath) then
						return true
					end if
				end if
				-- Header not valid yet, keep waiting
				set stableCount to 0
			end if
			delay FILE_CHECK_INTERVAL
		else
			set lastSize to currentSize
			set stableCount to 0
			delay FILE_CHECK_INTERVAL
		end if
	end repeat
	
	return false
end waitForFileStability

-- Check if path is an image or video
on isVideoFile(posixPath)
	return posixPath ends with ".mp4" or posixPath ends with ".mov" or posixPath ends with ".m4v"
end isVideoFile

on isSupportedMedia(posixPath)
	return posixPath ends with ".jpg" or posixPath ends with ".jpeg" or Â
		posixPath ends with ".png" or posixPath ends with ".gif" or Â
		posixPath ends with ".heic" or posixPath ends with ".webp" or Â
		posixPath ends with ".mp4" or posixPath ends with ".mov" or Â
		posixPath ends with ".m4v"
end isSupportedMedia

-- Folder action handler - called automatically when files are added
on adding folder items to this_folder after receiving added_items
	try
		-- Wait a moment for batch to complete (Lightroom exports multiple files rapidly)
		delay BATCH_DELAY
		
		-- Build list of image/video files that are fully downloaded
		set mediaPaths to {}
		set failedFiles to {}
		
		repeat with fileAlias in added_items
			set posixPath to POSIX path of fileAlias
			set lowerPath to do shell script "echo " & quoted form of posixPath & " | tr '[:upper:]' '[:lower:]'"
			
			-- Only process supported formats
			if my isSupportedMedia(lowerPath) then
				set isVideo to my isVideoFile(lowerPath)
				
				-- Wait for file to be fully written
				if my waitForFileStability(posixPath, isVideo) then
					-- File is stable and valid, add to list
					set encodedPath to my urlEncode(posixPath)
					set end of mediaPaths to "file://" & encodedPath
				else
					-- File failed validation
					set end of failedFiles to posixPath
				end if
			end if
		end repeat
		
		-- Log failed files (visible in Console.app under "Script Editor")
		if (count of failedFiles) > 0 then
			repeat with failedPath in failedFiles
				log "Statuz: Failed to validate file (may still be downloading): " & failedPath
			end repeat
		end if
		
		-- Skip if no valid files
		if (count of mediaPaths) is 0 then
			if (count of failedFiles) > 0 then
				display notification "Some files failed to load. Check Console for details." with title "Statuz Import"
			end if
			return
		end if
		
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
			open location STATUZ_SCHEME & mediaParam
		end tell
		
		-- Optional: Show success notification
		-- display notification ((count of mediaPaths) as text) & " file(s) added to composer" with title "Statuz"
		
	on error errMsg number errNum
		log "Statuz Folder Action Error: " & errMsg & " (" & errNum & ")"
		display notification "Error importing files: " & errMsg with title "Statuz Import Error"
	end try
end adding folder items to
