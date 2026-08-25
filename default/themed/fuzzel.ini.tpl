# fuzzel, generated from a theme's colors.toml. The nineteenth themed template.
#
# Backs oal-menu-select, so the menu is the same colours as the desktop it sits on. fuzzel has no
# include directive, so oal-menu-select passes --config rather than this file being pointed at from
# a real one the way ghostty and kitty are.
#
# Colours are RRGGBBAA here, not #RRGGBB, which is why every value uses the _strip form with an
# alpha byte appended.

[main]
font=monospace:size=11
line-height=22
horizontal-pad=18
vertical-pad=14
inner-pad=8
width=45
lines=12
terminal=ghostty -e

[colors]
background={{ background_strip }}f2
text={{ foreground_strip }}ff
match={{ accent_strip }}ff
selection={{ selection_strip }}ff
selection-text={{ bright_foreground_strip }}ff
selection-match={{ accent_strip }}ff
border={{ muted_strip }}ff

[border]
width=2
radius=8
