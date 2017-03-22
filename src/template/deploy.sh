#!/bin/bash
set -e # Exit with nonzero exit code if anything fails

LAUNCH_FOLDER="{{release}}"
SOURCE_FOLDER="{{source}}"

SOURCE_BRANCH="master"
TARGET_BRANCH="gh-pages"

ENCRYPTION_LABEL="{{apikey}}"
COMMIT_AUTHOR_EMAIL="{{email}}"

if [ "$SOURCE_FOLDER" == "" -o "$ENCRYPTION_LABEL" == "" -o "$COMMIT_AUTHOR_EMAIL" == "" ]; then
  echo "Invalid deploy setting; exiting."
  exit 0
fi

echo "Start to deploy, please wait..."

# Save some useful information
REPO=`git config remote.origin.url`
SSH_REPO=${REPO/https:\/\/github.com\//git@github.com:}
SHA=`git rev-parse --verify HEAD`

# Clone the existing gh-pages for this repo into out/
# Create a new empty branch if gh-pages doesn't exist yet (should only happen on first deply)
rm -rf $LAUNCH_FOLDER
git clone $REPO $LAUNCH_FOLDER
cd $LAUNCH_FOLDER
git checkout -b $TARGET_BRANCH

# Clean out existing contents
# Move file to prerelease folder
cd ..
rm -rf $LAUNCH_FOLDER/* || exit 0
cp -rf $SOURCE_FOLDER/* $LAUNCH_FOLDER || exit 0

# Now let's go have some fun with the cloned repo
git config user.name "Travis CI"
git config user.email "$COMMIT_AUTHOR_EMAIL"

# If there are no changes to the compiled out (e.g. this is a README update) then just bail.
if [ -z `git diff --exit-code` ]; then
  echo "No changes to the output on this push; exiting."
  exit 0
fi

# Commit the "changes", i.e. the new version.
# The delta will show diffs between new and old versions.
cd $LAUNCH_FOLDER
git add .
git commit -m "Deploy to GitHub Pages: ${SHA}"

# # Get the deploy key by using Travis's stored variables to decrypt deploy_key.enc
ENCRYPTED_KEY_VAR="encrypted_${ENCRYPTION_LABEL}_key"
ENCRYPTED_IV_VAR="encrypted_${ENCRYPTION_LABEL}_iv"
ENCRYPTED_KEY=${!ENCRYPTED_KEY_VAR}
ENCRYPTED_IV=${!ENCRYPTED_IV_VAR}

openssl aes-256-cbc -K $ENCRYPTED_KEY -iv $ENCRYPTED_IV -in deploy_key.enc -out deploy_key -d
chmod 600 deploy_key
eval `ssh-agent -s`
ssh-add deploy_key.enc

# Now that we're all set up, we can push.
git push $SSH_REPO $TARGET_BRANCH
