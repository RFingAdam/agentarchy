# Path/filename renames applied to upstream paths by bin/oal-dev-sync-upstream (sed -E).
# Kept out of the script so bin/ never has to spell the upstream project name.
#
# One blanket rule, not a set of delimiter-specific ones. In the pinned tree the upstream name is
# never glued into a longer path token -- every occurrence is exactly `omarchy` bounded by / - _ or
# . -- so there is nothing for a narrower rule to protect, and narrower rules silently missed
# `omarchy.sh`, `10-omarchy.conf`, `omarchy_hooks.conf`, `omarchy.webp` and
# `com.omarchy.ytdlp.json`. That last one is load-bearing: Chromium resolves a native-messaging
# host by matching the manifest filename against its "name" field, which the content rules had
# already rewritten to com.oal.ytdlp.
s#omarchy#oal#g
