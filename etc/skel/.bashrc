# shellcheck shell=bash
# Agentarchy's interactive shell, seeded into every new user's home by /etc/skel.
#
# Upstream assumes /etc/skel carries the shipped configs. Agentarchy vendors the shell tree but not
# that mechanism, so before this file existed nothing sourced default/bash/rc: no aliases, no
# functions, and no `starship init`, which meant the themed prompt rendered to disk on every theme
# change and was never read by a shell.

# Non-interactive shells get nothing but the environment, which /etc/profile.d/oal.sh already sets.
[[ $- != *i* ]] && return

[ -r /usr/share/agentarchy/default/bash/rc ] && . /usr/share/agentarchy/default/bash/rc
