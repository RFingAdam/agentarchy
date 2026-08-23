# The CLI tools mise manages belong to the agent layer, which a later phase owns. Installing them
# here downloads a Node toolchain and a dozen packages over the network on every install, so
# oal-bootstrap.sh sets OAL_SKIP_MISE=1 by default. Skip cleanly if mise is not installed either --
# it is not in Agentarchy's package lists yet, and its absence is not an install failure.
if [[ ${OAL_SKIP_MISE:-0} == 1 ]]; then
  echo "skipping mise.sh: OAL_SKIP_MISE=1"
  exit 0
fi
if ! command -v mise >/dev/null; then
  echo "skipping mise.sh: mise is not installed"
  exit 0
fi

oal-mise-install codex
oal-mise-install claude
oal-mise-install crush
oal-mise-install antigravity-cli agy
oal-mise-install gh
oal-mise-install copilot
oal-mise-install opencode
oal-mise-install npm:playwright playwright
oal-mise-install pi
oal-mise-install github:can1357/oh-my-pi omp
oal-mise-install npm:@xai-official/grok grok
oal-mise-install npm:@kitlangton/ghui ghui
oal-mise-install aqua:modem-dev/hunk hunk
oal-mise-install github:basecamp/hey-cli hey
