# Set default XCompose that is triggered with CapsLock
tee ~/.XCompose >/dev/null <<EOF
# Run oal-restart-xcompose to apply changes

# Include fast emoji access
include "/usr/share/agentarchy/default/xcompose"
EOF

# Identification, only if the install actually collected any. These read OAL_USER_NAME and
# OAL_USER_EMAIL, which only the ISO's setup form ever sets -- so on a bootstrap install they were
# empty, and the two sequences below were written anyway. Pressing them inserted "". A compose
# sequence that types nothing is worse than one that is not bound at all, because the first time you
# use it you assume you mistyped it.
name="${OAL_USER_NAME:-}"
email="${OAL_USER_EMAIL:-}"
if [[ -n ${name//[[:space:]]/} || -n ${email//[[:space:]]/} ]]; then
  {
    echo
    echo "# Identification"
    [[ -n ${name//[[:space:]]/} ]] && echo "<Multi_key> <space> <n> : \"$name\""
    [[ -n ${email//[[:space:]]/} ]] && echo "<Multi_key> <space> <e> : \"$email\""
  } >>~/.XCompose
fi
