#!/usr/bin/env bash

cd "$(dirname $0)"

if [ ! -d "$(pwd)/.rerun" ]; then
  git clone https://github.com/rerun/rerun.git .rerun
fi

export PATH="$(pwd)/.rerun:${PATH}"
export RERUN_MODULES="$(pwd)/.rerun/modules:${CODE_DIR}/rerun-modules"
