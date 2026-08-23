# Content rewrites applied to vendored text files by bin/oal-dev-sync-upstream (sed -E).
# Order matters: URL rules first, then paths, then words, then prose.

# upstream URLs (must precede the word rules, which would otherwise rewrite the host itself)
s#https?://(www\.)?omarchy\.org[^ )"'\`>]*#https://github.com/RFingAdam/agentarchy#g
s#https?://(learn\.omacom\.io|manuals\.omamix\.org)[^ )"'\`>]*#https://github.com/RFingAdam/agentarchy/tree/main/docs#g

# Subdomain hosts (pkgs./logs./mirror./stable-mirror./rc-mirror.omarchy.org) are not matched by the
# rule above, and the bare-word rule below would forge a real, resolvable host under the same
# .org domain, which someone could register.
# Retarget them at the reserved .invalid TLD: it can never resolve and reads as a placeholder.
# Sits after the two rules above so plain omarchy.org / www.omarchy.org keep mapping to the repo.
s#([a-z0-9-]+\.)+omarchy\.org#\1agentarchy.invalid#g

# upstream repo slug: clone/fork/issue targets must point at ours, not a fabricated
# basecamp/<newname> that does not exist
s#basecamp/omarchy#RFingAdam/agentarchy#g

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
