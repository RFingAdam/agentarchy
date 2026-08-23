# Content rewrites applied to vendored text files by bin/oal-dev-sync-upstream (sed -E).
# Order matters: URL rules first, then paths, then words, then prose.

# upstream URLs (must precede the word rules, which would otherwise produce oal.org)
s#https?://(www\.)?omarchy\.org[^ )"'\`>]*#https://github.com/RFingAdam/agentarchy#g
s#https?://(learn\.omacom\.io|manuals\.omamix\.org)[^ )"'\`>]*#https://github.com/RFingAdam/agentarchy/tree/main/docs#g

# paths
s#/usr/share/omarchy#/usr/share/agentarchy#g
s#\.config/omarchy#.config/oal#g
s#\.local/state/omarchy#.local/state/oal#g
s#\.local/share/omarchy#.local/share/oal#g
s#\.cache/omarchy#.cache/oal#g
s#/etc/omarchy#/etc/oal#g

# env vars and commands
s#OMARCHY_#OAL_#g
s#omarchy-#oal-#g

# snake_case namespace: shell functions/vars (omarchy_log_line, _omarchy_complete) and the
# on-disk artefacts the tree names after itself (omarchy_resume.conf, omarchy_speaker_tuning,
# omarchy_linux.efi). '_' is a word character, so \bomarchy\b below never reaches these.
s#omarchy_#oal_#g

# bare command / package / namespace word
s#\bomarchy\b#oal#g

# prose
s#Omarchy#Agentarchy#g
s#OMARCHY#AGENTARCHY#g
