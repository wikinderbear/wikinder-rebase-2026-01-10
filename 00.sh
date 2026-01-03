#!/bin/bash
#
# Executed on January 10, 2026 (UTC):
#
# Prerequisite: `git-filter-repo`
#

# Exit immediately if any command fails.
set -xeuo pipefail
IFS=$'\n\t'

command -v git-filter-repo

# TIMESTAMP=$(date -u +'%Y-%m-%d')
TIMESTAMP='2026-01-10'

PRODUCTION_REMOTE='https://github.com/wikinder/wikinder.wiki.git'
WORK_REMOTE="git@github.com:wikinderbear/wikinder-rebase-$TIMESTAMP.git"

BACKUP_BRANCH='backup-before-rebase'
BACKUP_TAG="$BACKUP_BRANCH-$TIMESTAMP"

FIRST_LOG='../01-git-log.txt'
FIRST_REBASE_TODO='../01-git-rebase-todo.txt'
SECOND_LOG='../02-git-log.txt'

# Set the time zone to JST (UTC+9).
export TZ='Asia/Tokyo'

# Clone the bare production repo.
git clone --mirror "$PRODUCTION_REMOTE" production-repo.git

# Create a work repo from the mirror.
git clone --branch master production-repo.git work-repo
cd work-repo
git remote remove origin
git remote add work-remote "$WORK_REMOTE"

# Create a backup branch from master (without switching).
git branch "$BACKUP_BRANCH" master

# Tag the latest commit on the backup branch.
git tag --annotate "$BACKUP_TAG" "$BACKUP_BRANCH" \
  --message="Backup before rebase ($TIMESTAMP)"

# Push the backup branch and tag to the work remote.
git push work-remote "$BACKUP_BRANCH" "$BACKUP_TAG"

# Configure `git log` to match the git rebase todo format.
git config --local log.date iso-strict-local
git config --local format.pretty 'pick %h # "%ad", "%an", "%s"'

git config --local rebase.instructionFormat '"%ad", "%an", "%s"'

# Write the initial log to a file.
git log --reverse > "$FIRST_LOG"

read -rp 'Press Enter to perform the rebase...'

# Perform the first rebase. Automatically recover from the error "you asked to
# amend the most recent commit, but doing so would make it empty" and continue
# rebasing.
git -c sequence.editor="cp '$FIRST_REBASE_TODO'" \
  rebase -i --root --committer-date-is-author-date \
  || { until git commit --amend --allow-empty --no-edit && git rebase --continue; do :; done }

# Write the log after the first rebase.
git log --reverse > "$SECOND_LOG"

read -rp "First rebase complete. $SECOND_LOG created. Press Enter to run git-filter-repo..."

# Restore the committer to match the original author for every commit.
git filter-repo --force --commit-callback '
  commit.committer_name  = commit.author_name
  commit.committer_email = commit.author_email
  commit.committer_date  = commit.author_date
'

# Verify that all commits are in chronological order.
git log --reverse --format='%at' | sort -nc

read -rp "git-filter-repo complete. Press Enter to push master to the work remote..."

# Push master to the work remote.
git push work-remote master

exit 0

# Force push to the production remote.
# cd work-repo
# git remote add production-remote "$PRODUCTION_REMOTE"
# git push production-remote master --force
