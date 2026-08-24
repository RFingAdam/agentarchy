# Setup user theme folder and seed the default only when no theme exists yet.
#
# The theme is whatever OAL_DEFAULT_THEME says, not a name hardcoded here. oal-bootstrap.sh applies
# the same variable to KDE, and when the two disagree the machine ends up in two themes at once:
# the colour scheme, icons and wallpaper from one, and all eighteen templated configs -- terminals,
# editors, btop, the shell prompt -- from the other. They agreed only for as long as the default
# happened to be the name written below.
mkdir -p ~/.config/oal/themes

if [[ ! -s $HOME/.local/state/oal/current/theme.name ]]; then
  # iso-chroot and provision-owner both run without a live session to notify.
  if [[ ${OAL_SETUP_CONTEXT:-runtime} != "runtime" ]]; then
    OAL_THEME_HEADLESS=1 oal-theme-set "${OAL_DEFAULT_THEME:-agentarchy}"
    rm -f ~/.config/chromium/SingletonLock # otherwise archiso owns the Chromium singleton
  else
    oal-theme-set "${OAL_DEFAULT_THEME:-agentarchy}"
  fi
fi
oal-theme-set-pi --activate

mkdir -p ~/.config/btop/themes
ln -snf "$HOME/.local/state/oal/current/theme/btop.theme" ~/.config/btop/themes/current.theme
