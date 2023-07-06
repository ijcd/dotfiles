# To fix the " gpg: WARNING: unsafe permissions on homedir '/home/path/to/user/.gnupg' " error
# Make sure that the .gnupg directory and its contents is accessibile by your user.
chown -R $(whoami) ~/.gnupg/

# Correct access rights for .gnupg and subfolders:
find ~/.gnupg/ -type f -exec chmod 600 {} \;
find ~/.gnupg/ -type d -exec chmod 700 {} \;
