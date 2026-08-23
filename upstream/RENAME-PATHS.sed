# Path/filename renames applied to upstream paths by bin/oal-dev-sync-upstream (sed -E).
# Kept out of the script so bin/ never has to spell the upstream project name.
s#omarchy-#oal-#g
s#(^|/)omarchy(/|$)#\1oal\2#g
