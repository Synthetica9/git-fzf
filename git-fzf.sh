#!/usr/bin/env bash

set -euo pipefail

STRIP_REFLOG='grep "[0-9a-f]+" --perl-regexp --only-matching | head -n 1 | xargs git rev-parse'
PREVIEWCOMMIT="echo \"{}\" | $STRIP_REFLOG | xargs git show --color=always"
LOG_FORMAT="format:%C(auto,yellow)%h %C(auto,blue)%>(12)%ad %C(auto,green)%<(18) %aN%C(auto,reset)%s%C(auto,red)% gD% D"

function fzfCommit { fzf --ansi --preview="$PREVIEWCOMMIT" --tiebreak=index; }

function gitLogLike {
  subcommand=$1
  shift
  git $subcommand --color=always --format="$LOG_FORMAT" --date=relative $@
}

if [ $# -lt 1 ];
then
  echo "No subcommand specified!" > /dev/stderr
  exit 1
fi


subcommand=$1
shift
case $subcommand in
  "reflog"|"log")
    gitLogLike $subcommand $@ | fzfCommit | eval $STRIP_REFLOG
    ;;
  *)
    echo "Unknown command '$subcommand'" > /dev/stderr
    exit 1
    ;;
esac
