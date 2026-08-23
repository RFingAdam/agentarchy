# Capture and Sharing

Read this before taking screenshots or screen recordings, extracting text from
the screen, or sharing files with other machines.

## Screenshots

```bash
oal screenshot                            # Interactive smart-region flow
oal capture screenshot region             # Select a region
oal capture screenshot windows            # Pick a window
oal capture screenshot fullscreen save    # Full screen, straight to disk (no editor)
```

The first argument picks the mode (`smart|region|windows|fullscreen`), the
second what happens with it (`slurp|copy|save`). `save` skips the annotation
editor and prints the saved path. Screenshots land in the configured Pictures
directory (override with `OAL_SCREENSHOT_DIR`).

## Screen Recording

```bash
oal screenrecord --fullscreen             # Start recording the full screen
# ...exercise whatever you want on film...
oal screenrecord --stop-recording         # Stop; prints the saved path
```

Optional flags: `--with-desktop-audio`, `--with-microphone-audio`,
`--with-webcam` (plus `--webcam-device=` and `--webcam-size=`), and
`--resolution=<size>`. Without `--fullscreen` a region picker opens first.
Recordings land in the configured Videos directory (override with
`OAL_SCREENRECORD_DIR`). Resize a live webcam overlay with
`oal capture webcam resize <smaller|larger|reset|small|medium|large>`.

If recording fails to start, rerun with `OAL_SCREENRECORD_DEBUG=true` to
collect a log at `/tmp/oal-screenrecord.log` worth attaching to a bug
report.

## Text Capture (OCR)

```bash
oal capture text    # Select a region; extracted text goes to the clipboard
```

## Sharing Files

```bash
oal share clipboard               # Share the clipboard via LocalSend
oal share file <path...>          # Share files with nearby devices
oal share folder <path>           # Share a folder

oal tailscale send <machine> <file...>    # Taildrop to a tailnet machine
oal tailscale receive [directory]         # Save incoming Taildrop files
```

Shrink large captures before sharing them:

```bash
oal transcode <input> [format] [resolution]   # Re-encode pictures/videos for sharing
```
