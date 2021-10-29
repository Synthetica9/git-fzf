#!/usr/bin/env bash

set -euo pipefail

# Check that the FZF binary exists:
which fzf > /dev/null || (echo "fzf not found" && exit 1)

STRIP_REFLOG='grep "[0-9a-f]+" --perl-regexp --only-matching | head -n 1 | xargs git rev-parse'
STRIP_STATUS_PORCELAIN='cut -c 4-'
STRIP_BRANCH='cut -c 3-'

PREVIEWCOMMIT="echo \"{}\" | $STRIP_REFLOG | xargs git show --diff-merges=1 --color=always"
PREVIEWCHANGE="echo {} | $STRIP_STATUS_PORCELAIN | xargs git diff --color=always --"
PREVIEWBRANCH="echo {} | $STRIP_BRANCH | xargs git log -n 1000 --color=always"
LOG_FORMAT="format:%C(auto,yellow)%h %C(auto,blue)%>(14)%ad %C(auto,green)%<(18) %aN%C(auto,reset)%s%C(auto,red)% gD% D"

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
  echo "No subcommand specified! See:"
  echo
  echo "    git fzf help"
  exit 1
fi > /dev/stderr

# Check we are actually in a git repo
git rev-parse --is-inside-work-tree > /dev/null

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
  $(option branch))
    git branch --color=always $@ | fzf --ansi --preview="$PREVIEWBRANCH" | $STRIP_BRANCH
    ;;
  $(option remote))
    git remote $@ | fzf --ansi --preview="git remote show -n {}"
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
  $(option diff))
    git diff --name-only > $temp
    [ -s $temp ] || errorWith "No changes"
    cat $temp | fzf --multi --preview="git diff --color=always {}"
    ;;
  *)
    if [ "$subcommand" != "help" ];
    then
      echo "Unknown command '$subcommand'" >> /dev/stderr
    fi

    # close writing descriptor
    exec {CAT[1]}>&-
    #read colected options into an array
    mapfile -t OPTIONS <&${CAT[0]}

    echo "Available options are: [ ${OPTIONS[@]} ]" >> /dev/stderr

    exit 1
    ;;
esac
