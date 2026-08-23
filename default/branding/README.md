# Branding assets

Placeholders. Phase 1 needs *something* where the vendored greeter, boot splash and terminal logo
point (see `upstream/EXCLUDED-ASSETS.md` for why those references exist and are empty); Phase 2
replaces these with real artwork and per-theme variants.

Everything here is generated, so regenerate rather than hand-edit. The wordmark is DejaVu Sans Bold,
which is in the base package list, so the PNG and a terminal running `oal-show-logo` look related:

```bash
magick -background none -fill white -font DejaVu-Sans-Bold -pointsize 96 -kerning 6 \
  label:agentarchy -bordercolor none -border 24 default/branding/logo.png

cp default/branding/logo.png default/plymouth/logo.png     # boot splash sprite
cp default/branding/logo.png default/sddm/oal/logo.png     # greeter Image source

magick -size 480x270 xc:'#1a1b26' \( default/branding/logo.png -resize 380x \) \
  -gravity center -composite default/plymouth/preview-unlock.png

for ext in copy-url yt-dlp; do
  magick -size 128x128 xc:none -fill '#7aa2f7' -draw 'roundrectangle 8,8 120,120 18,18' \
    -fill '#1a1b26' -font DejaVu-Sans-Bold -pointsize 64 -gravity center -annotate +0+0 "${ext:0:1}" \
    "default/chromium/extensions/$ext/icon.png"
done
```

`logo.txt` is the terminal wordmark (`bin/oal-show-logo`), written by hand in half-block characters
so it renders in any monospace font without a Nerd Font glyph.

The three PNGs are byte-identical copies rather than symlinks on purpose: Plymouth's theme directory
is copied into the initramfs, and a symlink pointing outside it would break there.
