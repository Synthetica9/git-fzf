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

# https://stackoverflow.com/a/50371710/2872678
# create coprocess with 2 descriptors so we can read and write to them
coproc CAT { cat ; }

# creme de la creme of this solution - use function to both collect and select elements
function option {
  echo "$1" >&${CAT[1]}
  echo "$1"
}


subcommand=$1
shift
temp=$(mktemp)
case $subcommand in
  $(option reflog)|$(option log))
    gitLogLike $subcommand $@ | fzfCommit | eval $STRIP_REFLOG
    ;;
  $(option add)|$(option checkout))
    git status --porcelain > $temp
    [ -s $temp ] || errorWith "No unstaged changes, nothing to add"
    cat $temp | fzf --multi --preview="$PREVIEWCHANGE" | eval "$STRIP_STATUS_PORCELAIN" | xargs -- git $subcommand --
    ;;
  $(option reset))
    git diff --name-only --cached > $temp
    [ -s $temp ] || errorWith "No changes staged, nothing to reset"
    cat $temp | fzf --multi --preview="git diff --color=always {}" | xargs git $subcommand --
    ;;
  *)
    echo "Unknown command '$subcommand'" >> /dev/stderr

    # close writing descriptor
    exec {CAT[1]}>&-
    #read colected options into an array
    mapfile -t OPTIONS <&${CAT[0]}

    echo "Available options are: [ ${OPTIONS[@]} ]"
    ;;
esac
