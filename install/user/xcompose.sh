# Set default XCompose that is triggered with CapsLock
tee ~/.XCompose >/dev/null <<EOF
# Run oal-restart-xcompose to apply changes

# Include fast emoji access
include "/usr/share/agentarchy/default/xcompose"

# Identification
<Multi_key> <space> <n> : "$OAL_USER_NAME"
<Multi_key> <space> <e> : "$OAL_USER_EMAIL"
EOF
