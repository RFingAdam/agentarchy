# Plasma colour scheme, generated from a theme's colors.toml.
#
# Rendered by bin/oal-theme-render, which supplies the scheme name on top of the palette. The
# vendored template pass (oal-theme-set-templates) also renders every template in this directory into
# the staged theme directory; it knows nothing about scheme names, so its copy of this file keeps that
# one placeholder unsubstituted and nothing reads it. bin/oal-theme-set-kde renders this file itself
# and writes the result where KDE looks for it.
#
# Mapping (from the design spec): background to Window and View, lighter_background to the raised
# surfaces, accent to focus/hover and the active titlebar, red/green/yellow/blue to
# Negative/Positive/Neutral/Link, muted to ForegroundInactive.

[Colors:Button]
BackgroundNormal={{ lighter_background_rgb }}
BackgroundAlternate={{ background_rgb }}
DecorationFocus={{ accent_rgb }}
DecorationHover={{ accent_rgb }}
ForegroundNormal={{ foreground_rgb }}
ForegroundInactive={{ muted_rgb }}
ForegroundActive={{ accent_rgb }}
ForegroundLink={{ blue_rgb }}
ForegroundVisited={{ magenta_rgb }}
ForegroundNegative={{ red_rgb }}
ForegroundNeutral={{ yellow_rgb }}
ForegroundPositive={{ green_rgb }}

[Colors:Complementary]
BackgroundNormal={{ dark_background_rgb }}
BackgroundAlternate={{ darker_background_rgb }}
DecorationFocus={{ accent_rgb }}
DecorationHover={{ accent_rgb }}
ForegroundNormal={{ foreground_rgb }}
ForegroundInactive={{ muted_rgb }}
ForegroundActive={{ accent_rgb }}
ForegroundLink={{ blue_rgb }}
ForegroundVisited={{ magenta_rgb }}
ForegroundNegative={{ red_rgb }}
ForegroundNeutral={{ yellow_rgb }}
ForegroundPositive={{ green_rgb }}

[Colors:Header]
BackgroundNormal={{ lighter_background_rgb }}
BackgroundAlternate={{ background_rgb }}
DecorationFocus={{ accent_rgb }}
DecorationHover={{ accent_rgb }}
ForegroundNormal={{ foreground_rgb }}
ForegroundInactive={{ muted_rgb }}
ForegroundActive={{ accent_rgb }}
ForegroundLink={{ blue_rgb }}
ForegroundVisited={{ magenta_rgb }}
ForegroundNegative={{ red_rgb }}
ForegroundNeutral={{ yellow_rgb }}
ForegroundPositive={{ green_rgb }}

[Colors:Selection]
BackgroundNormal={{ selection_rgb }}
BackgroundAlternate={{ selection_rgb }}
DecorationFocus={{ accent_rgb }}
DecorationHover={{ accent_rgb }}
ForegroundNormal={{ bright_foreground_rgb }}
ForegroundInactive={{ muted_rgb }}
ForegroundActive={{ accent_rgb }}
ForegroundLink={{ blue_rgb }}
ForegroundVisited={{ magenta_rgb }}
ForegroundNegative={{ red_rgb }}
ForegroundNeutral={{ yellow_rgb }}
ForegroundPositive={{ green_rgb }}

[Colors:Tooltip]
BackgroundNormal={{ lighter_background_rgb }}
BackgroundAlternate={{ background_rgb }}
DecorationFocus={{ accent_rgb }}
DecorationHover={{ accent_rgb }}
ForegroundNormal={{ foreground_rgb }}
ForegroundInactive={{ muted_rgb }}
ForegroundActive={{ accent_rgb }}
ForegroundLink={{ blue_rgb }}
ForegroundVisited={{ magenta_rgb }}
ForegroundNegative={{ red_rgb }}
ForegroundNeutral={{ yellow_rgb }}
ForegroundPositive={{ green_rgb }}

[Colors:View]
BackgroundNormal={{ background_rgb }}
BackgroundAlternate={{ dark_background_rgb }}
DecorationFocus={{ accent_rgb }}
DecorationHover={{ accent_rgb }}
ForegroundNormal={{ foreground_rgb }}
ForegroundInactive={{ muted_rgb }}
ForegroundActive={{ accent_rgb }}
ForegroundLink={{ blue_rgb }}
ForegroundVisited={{ magenta_rgb }}
ForegroundNegative={{ red_rgb }}
ForegroundNeutral={{ yellow_rgb }}
ForegroundPositive={{ green_rgb }}

[Colors:Window]
BackgroundNormal={{ background_rgb }}
BackgroundAlternate={{ dark_background_rgb }}
DecorationFocus={{ accent_rgb }}
DecorationHover={{ accent_rgb }}
ForegroundNormal={{ foreground_rgb }}
ForegroundInactive={{ muted_rgb }}
ForegroundActive={{ accent_rgb }}
ForegroundLink={{ blue_rgb }}
ForegroundVisited={{ magenta_rgb }}
ForegroundNegative={{ red_rgb }}
ForegroundNeutral={{ yellow_rgb }}
ForegroundPositive={{ green_rgb }}

[General]
ColorScheme={{ scheme_name }}
Name={{ scheme_name }}
accentColorFromWallpaper=false
shadeSortColumn=true

[KDE]
contrast=4

[WM]
activeBackground={{ accent_rgb }}
activeForeground={{ background_rgb }}
activeBlend={{ accent_rgb }}
inactiveBackground={{ background_rgb }}
inactiveForeground={{ muted_rgb }}
inactiveBlend={{ background_rgb }}
