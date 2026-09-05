#!/bin/sh
# Repo-local git askpass helper: answers https credential prompts using the
# authenticated GitHub CLI (gh) token. Contains no secrets.
# Configured per-repo via: git config core.askPass "<abs path to this file>"
case "$1" in
  *Username*) echo "wangyuhao0831-max" ;;
  *) exec gh auth token ;;
esac
