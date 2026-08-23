# Set identification from install inputs
if [[ -n ${OAL_USER_NAME//[[:space:]]/} ]]; then
  git config --global user.name "$OAL_USER_NAME"
fi

if [[ -n ${OAL_USER_EMAIL//[[:space:]]/} ]]; then
  git config --global user.email "$OAL_USER_EMAIL"
fi
