# Themes, Backgrounds, and Fonts

Read this before changing themes, backgrounds, fonts, or theme colors.

## Theme Commands

```bash
oal theme list              # Show available themes
oal theme current           # Show current theme
oal theme set <name>        # Apply theme ("Tokyo Night" and "tokyo-night" both work)
oal theme bg next           # Cycle background
oal theme install <url>     # Install from git repo
```

## Making a New Theme

1. Create a directory under `~/.config/oal/themes`.
2. See how an existing theme is done via `/usr/share/agentarchy/themes/catppuccin`.
3. Download a matching background (or several) from the internet and put them in `~/.config/oal/themes/<name-of-new-theme>/backgrounds/`.
4. When done with the theme, run `oal theme set "Name of new theme"`.

Additional user backgrounds for any theme (stock or custom) go in
`~/.config/oal/backgrounds/<theme-slug>/`.

## Customizing a Stock Theme

Never edit stock themes under `/usr/share/agentarchy/themes/` — changes are lost
on update. Two safe options:

**Overlay (preferred for small tweaks):** create a user theme directory with
the SAME slug containing only the files you want to change. When the theme is
applied, the stock theme is copied first and your files win on top:

```bash
mkdir -p ~/.config/oal/themes/catppuccin
cp /usr/share/agentarchy/themes/catppuccin/colors.toml ~/.config/oal/themes/catppuccin/
# Edit the copied colors.toml, then re-apply:
oal theme set catppuccin
```

**Fork:** copy the whole stock theme under a new name for a fully independent
variant:

```bash
cp -r /usr/share/agentarchy/themes/catppuccin ~/.config/oal/themes/catppuccin-custom
# Edit ~/.config/oal/themes/catppuccin-custom/, then:
oal theme set catppuccin-custom
```

## Fonts

```bash
oal font list               # Available fonts
oal font current            # Current font
oal font set <name>         # Change font
```
