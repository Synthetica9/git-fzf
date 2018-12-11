#!/usr/bin/env bash

set -euo pipefail

STRIP_REFLOG='grep "[0-9a-f]+" --perl-regexp --only-matching | head -n 1 | xargs git rev-parse'
STRIP_STATUS_PORCELAIN='cut -c 4-'

PREVIEWCOMMIT="echo \"{}\" | $STRIP_REFLOG | xargs git show --color=always"
PREVIEWCHANGE="echo {} | $STRIP_STATUS_PORCELAIN | xargs git diff --color=always"
LOG_FORMAT="format:%C(auto,yellow)%h %C(auto,blue)%>(12)%ad %C(auto,green)%<(18) %aN%C(auto,reset)%s%C(auto,red)% gD% D"

function fzfCommit { fzf --ansi --preview="$PREVIEWCOMMIT" --tiebreak=index; }

function gitLogLike {
  subcommand=$1
  shift
  git $subcommand --color=always --format="$LOG_FORMAT" --date=relative $@
}

function errorWith {
  echo $@ > /dev/stderr
  exit 1
}

if [ $# -lt 1 ];
then
  echo "No subcommand specified!" > /dev/stderr
  exit 1
fi


subcommand=$1
shift
temp=$(mktemp)
case $subcommand in
  "reflog"|"log")
    gitLogLike $subcommand $@ | fzfCommit | eval $STRIP_REFLOG
    ;;
  "add")
    git status --porcelain > $temp
    [ -s $temp ] || errorWith "No unstaged changes, nothing to add"
    cat $temp | fzf --multi --preview="$PREVIEWCHANGE" | eval "$STRIP_STATUS_PORCELAIN" | xargs -- git $subcommand --
    ;;
  "reset")
    git diff --name-only --cached > $temp
    [ -s $temp ] || errorWith "No changes staged, nothing to reset"
    cat $temp | fzf --multi --preview="git diff --color=always {}" | xargs git $subcommand --
    ;;
  *)
    errorWith "Unknown command '$subcommand'"
    ;;
esac
