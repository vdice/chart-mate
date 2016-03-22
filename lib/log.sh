function xtrace-on {
  if [[ -z "${former_xtrace_status}" ]]; then
    export _former_xtrace_status="${-//[^x]/}"
  fi
  set -x
}

function xtrace-off {
  if [[ -z "${former_xtrace_status}" ]]; then
    export _former_xtrace_status="${-//[^x]/}"
  fi
  set +x
}

function xtrace-reset {
  if [[ -n "${former_xtrace_status}" ]]; then
    unset _former_xtrace_status
    set -x
  else
    unset _former_xtrace_status
    set +x
  fi
}

function log-lifecycle {
  rerun_log "${bldblu}==> ${@}...${txtrst}"
}

function log-info {
  rerun_log "-----> ${@}"
}

function log-warn {
  rerun_log warn " !!!   ${@}"
}
