# AppleScript Automation - Lightroom to Statuz

Automatically open Lightroom exports in Statuz. Export photos → files land in folder → Statuz opens with all photos in one post.

## Files

- **`Lightroom-to-Statuz.scpt`** - Compiled, ready to use
- **`lightroom-to-statuz.applescript`** - Source code

## Quick Setup

### Step 1: Get the Script

**Option A: Download directly**
1. Download [`Lightroom-to-Statuz.scpt`](https://github.com/statuz-app/examples/raw/main/lightroom/Lightroom-to-Statuz.scpt)
2. Move it to the Folder Action Scripts folder:
   ```bash
   mkdir -p ~/Library/Scripts/"Folder Action Scripts"
   mv ~/Downloads/Lightroom-to-Statuz.scpt ~/Library/Scripts/"Folder Action Scripts"/
   ```

**Option B: Clone the repository**
```bash
git clone https://github.com/statuz-app/examples.git
cd examples/lightroom
mkdir -p ~/Library/Scripts/"Folder Action Scripts"
cp Lightroom-to-Statuz.scpt ~/Library/Scripts/"Folder Action Scripts"/
```

### Step 2: Create Export Folder

```bash
mkdir ~/Desktop/SocialExport
```

### Step 3: Attach Folder Action

1. Right-click `~/Desktop/SocialExport`
2. Select **Folder Actions Setup**
3. Check ✅ **"Enable Folder Actions"**
4. Click **+** under "Script"
5. Select **"Lightroom-to-Statuz.scpt"**

### Step 4: Test

```bash
cp ~/Pictures/test.jpg ~/Desktop/SocialExport/
```

Statuz should open automatically with the image.

## Lightroom Usage

1. **Select multiple files with shift pressed → Right-click → Export X Files > Export**
2. Tweak your preset, include watermark, etc.
3. Click **Export**
4. Select the export folder you created earlier

Now export → Statuz opens automatically!

## How to Compile

If you modify `lightroom-to-statuz.applescript`:

```bash
osacompile -o Lightroom-to-Statuz.scpt lightroom-to-statuz.applescript
```

Or in **Script Editor**:
1. Open `.applescript` file
2. File → Export
3. File Format: **Script** (`.scpt`)

## How It Works

```applescript
-- macOS calls this when files are added to the watched folder
on adding folder items to this_folder after receiving added_items
  -- Build comma-separated list of file paths
  -- Open Statuz with: statuz://compose?media=file1,file2,file3
end adding folder items to
```

**Key points:**
- Builds comma-separated list of file paths
- Opens URL once (not in a loop)
- Result: ONE composer with all images (up to 4)

## Common Mistake

❌ **Wrong** - Opens multiple composers:
```applescript
repeat with file in files
    tell application "Statuz" to open file
end repeat
```

✅ **Right** - One composer with all files:
```applescript
-- Build list: "file://path1,file://path2"
open location "statuz://compose?media=" & fileList
```

## Variations

### Auto-add hashtags

Edit line 38 in the script:
```applescript
open location "statuz://compose?text=%23Photography&media=" & mediaParam
```

### Save as draft

```applescript
open location "statuz://compose?draft=true&media=" & mediaParam
```

## Troubleshooting

### Can't find "Folder Actions Setup" in context menu

If right-clicking doesn't show Folder Actions Setup, open it directly:

```bash
open "/System/Library/CoreServices/Applications/Folder Actions Setup.app"
```

Or via Spotlight: Cmd+Space → type "Folder Actions Setup" → Enter

Then manually add your folder with the + button.

### Nothing happens

Check folder actions are enabled:
```bash
osascript -e 'tell application "System Events" to get folder actions enabled'
```

Enable if needed:
```bash
osascript -e 'tell application "System Events" to set folder actions enabled to true'
```

### Script not listed in Folder Actions Setup

Make sure it's saved to the correct location:
```bash
ls ~/Library/Scripts/"Folder Action Scripts"/
```

### Did all that and still nothing?

The folder might be cached in a wrong state. Try deataching the script and folder action in Folder Actions Setup and then deleting the folder. Then try the setup again. Or simply try with a new folder to validate this is not a cache issue. If the issue persists, please open an issue on the [GitHub repository](https://github.com/statuz-app/examples/issues).

## More Info

- [Complete Lightroom guide](https://statuz.app/docs/lightroom-automation)
- [URL Scheme docs](https://statuz.app/docs/url-scheme)
- [Other examples](../)

