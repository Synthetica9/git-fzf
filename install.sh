#!/usr/bin/env bash

set -euxo pipefail

git config --global alias.fzf "!f() { $(pwd)/git-fzf.sh \$@ }; f"
