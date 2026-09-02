# Set identification from install inputs.
#
# OAL_USER_NAME and OAL_USER_EMAIL come from the setup form, which only the ISO path asks. Nothing
# on the bootstrap path sets either, so both are normally absent and this step does nothing -- which
# is correct, and now says so rather than relying on an unset variable expanding to empty.
name="${OAL_USER_NAME:-}"
email="${OAL_USER_EMAIL:-}"

if [[ -n ${name//[[:space:]]/} ]]; then
  git config --global user.name "$name"
fi

if [[ -n ${email//[[:space:]]/} ]]; then
  git config --global user.email "$email"
fi
