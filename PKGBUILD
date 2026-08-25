# Maintainer: Adam <https://github.com/RFingAdam>
#
# Packages this checkout as the `agentarchy` package: the whole tree lands in
# /usr/share/agentarchy and every user-facing bin/oal-* script is symlinked onto PATH.
#
# The tree is taken from the directory this PKGBUILD lives in (override with AGENTARCHY_SRC).
# Deliberately not a git+file:// source: oal-bootstrap.sh runs makepkg from a checkout that was
# rsynced onto the target with .git excluded, so a git source would fail in exactly the case that
# matters. Copying the working tree also means what you built is what you are looking at.

pkgname=agentarchy
pkgver=0.0.1.dev
pkgrel=1
pkgdesc="Arch + KDE Plasma 6 desktop with an agent-first oal-* toolchain"
arch=('any')
url="https://github.com/RFingAdam/agentarchy"
license=('MIT')
depends=('bash' 'git' 'jq' 'gum')
makedepends=('git')
options=('!strip')
source=()

_src="${AGENTARCHY_SRC:-$startdir}"

pkgver() {
  cd "$_src"
  if git rev-parse --git-dir >/dev/null 2>&1; then
    git describe --long --tags 2>/dev/null | sed 's/^v//; s/\([^-]*-g\)/r\1/; s/-/./g' ||
      printf 'r%s.%s' "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
  else
    # No git: a bootstrap-time checkout that arrived over rsync. pacman forbids '-' in pkgver.
    tr -d '[:space:]' < version | tr '-' '.'
  fi
}

prepare() {
  rm -rf -- "${srcdir:?}/$pkgname"
  mkdir -p "$srcdir/$pkgname"
  # Scratch that must never reach a package: git metadata, the VM harness's disk images, the sync
  # staging tree, the SDD ledger, and makepkg's own output if someone built in place before.
  tar -C "$_src" -cf - \
    --exclude=.git --exclude=.vm --exclude=.vm-cache --exclude=.sync \
    --exclude=.superpowers --exclude=pkg --exclude=src --exclude='*.pkg.tar.zst' \
    . | tar -C "$srcdir/$pkgname" -xf -
}

package() {
  cd "$srcdir/$pkgname"
  local share="$pkgdir/usr/share/$pkgname"

  install -d "$share"
  for d in agent bin config default themes applications agents install etc migrations; do
    [[ -d $d ]] || continue
    cp -a "$d" "$share/"
  done

  install -Dm644 version "$share/version"
  # Shipped so an installed system can still tell vendored files from native ones.
  install -Dm644 upstream/VENDORED-FILES.txt "$share/upstream/VENDORED-FILES.txt"
  # The one file under etc/ an installed system cannot work without: it is what puts OAL_PATH into a
  # login shell, and vendored commands read it to find their own tree. The rest of etc/ (units,
  # sudoers, sysctl, some of it still Hyprland-shaped) is a per-file decision that Phase 4 owns, so
  # it ships under /usr/share/agentarchy/etc where those decisions can be made against real files.
  install -Dm644 etc/profile.d/oal.sh "$pkgdir/etc/profile.d/oal.sh"

  # config/ is ~/.config, seeded through /etc/skel -- which is upstream's whole delivery model for
  # per-user defaults: useradd -m copies it for a new user, and oal-reinstall-configs replays it over
  # an existing one with `cp -af /etc/skel/. ~/`. Agentarchy vendored the config trees and never
  # populated skel, so none of it reached a home directory: ghostty, kitty, alacritty and foot each
  # `include` a file the theme engine renders on every theme change, and those includes were in
  # configs nobody had.
  #
  # .bashrc is deliberately not here. /etc/skel/.bashrc belongs to the `bash` package and shipping
  # one is a hard file conflict; oal-bootstrap.sh appends the source line instead.
  install -d "$pkgdir/etc/skel/.config"
  cp -a config/. "$pkgdir/etc/skel/.config/"

  # Our own desktop entries go where a desktop environment actually looks. applications/ is copied
  # into /usr/share/agentarchy above, which is where the vendored web-app shortcuts belong -- they
  # name browsers and services this distribution does not install, and putting them in the launcher
  # would advertise applications that are not there. oal-menu.desktop is different: the dock pins it
  # by id, so a copy only under /usr/share/agentarchy is a launcher that draws a blank icon and does
  # nothing when clicked.
  install -Dm644 applications/oal-menu.desktop "$pkgdir/usr/share/applications/oal-menu.desktop"

  install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
  install -Dm644 NOTICE "$pkgdir/usr/share/licenses/$pkgname/NOTICE"

  # oal-dev-* is repo tooling: it resolves the repo root by looking for upstream/PIN above itself,
  # which does not exist on an installed system. It is dropped from the package entirely, not just
  # left off PATH, so nobody finds it in /usr/share and wonders why it fails.
  rm -f "$share"/bin/oal-dev-*

  install -d "$pkgdir/usr/bin"
  local f name
  for f in "$share"/bin/*; do
    [[ -f $f ]] || continue
    name="${f##*/}"
    ln -sf "/usr/share/$pkgname/bin/$name" "$pkgdir/usr/bin/$name"
  done
}
