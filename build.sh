#!/usr/bin/env bash

set -eo pipefail

cd "$(dirname "$0")"

temp_dir="tmp"
rerun_bin=""

function install-rerun {
  if [ -d ${temp_dir} ]; then
    return 0
  fi

  mkdir -p "${temp_dir}"

  curl -Lo "${temp_dir}/rerun.zip" https://github.com/rerun/rerun/zipball/master

  (
    cd "${temp_dir}"
    unzip rerun.zip
  )
}

rerun_bin="$(find ${temp_dir} -name rerun)"
rerun_dir="$(dirname ${rerun_bin})"

export PATH="${rerun_dir}:${PATH}"
export RERUN_MODULES="$(dirname $(pwd)):${rerun_dir}/modules"

mkdir -p build

rerun stubbs:archive --modules chart-mate -f build/rerun
