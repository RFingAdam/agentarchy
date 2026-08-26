#!/bin/bash

# Enable AND start the user systemd units we ship. Runs at first-run rather
# than at finalize-user time because the user manager isn't live during the
# ISO chroot: by first-run the Plasma session is up and
# `systemctl --user enable --now` both writes the correct .wants symlinks
# (based on each unit's [Install]/WantedBy) and starts the services so the
# first session has bluetooth pairing, sleep lock, etc. live immediately
# instead of waiting for the next login. ConditionPath* in the unit files
# keep the enabled units inert on hardware they don't apply to.

set -euo pipefail

systemctl --user daemon-reload
systemctl --user enable --now \
  bt-agent.service \
  oal-recover-internal-monitor.service \
  oal-sleep-lock.service \
  oal-migrate-notify.service \
  oal-fcitx5.service \
  oal-crash-watch.service \
  oal-watch.timer

# install/agent/runtime.sh enables the crash and health watchers as well, because
# nothing runs this directory on a bootstrap install: it is the ISO's path. Both
# are `enable --now` and idempotent, so the overlap costs nothing and neither path
# has to know whether the other ran.
