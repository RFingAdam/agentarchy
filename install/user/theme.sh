# Setup user theme folder and seed the default only when no theme exists yet.
mkdir -p ~/.config/oal/themes

if [[ ! -s $HOME/.local/state/oal/current/theme.name ]]; then
  # iso-chroot and provision-owner both run without a live session to notify.
  if [[ ${OAL_SETUP_CONTEXT:-runtime} != "runtime" ]]; then
    OAL_THEME_HEADLESS=1 oal-theme-set "Tokyo Night"
    rm -f ~/.config/chromium/SingletonLock # otherwise archiso owns the Chromium singleton
  else
    oal-theme-set "Tokyo Night"
  fi
fi
oal-theme-set-pi --activate

mkdir -p ~/.config/btop/themes
ln -snf "$HOME/.local/state/oal/current/theme/btop.theme" ~/.config/btop/themes/current.theme
