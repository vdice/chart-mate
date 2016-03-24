#/ usage: source RERUN_MODULE_DIR/lib/functions.sh command
#

. $RERUN || {
  echo >&2 "ERROR: Failed sourcing rerun function library: \"$RERUN\""
  return 1
}

# Check usage. Argument should be command name.
[[ $# = 1 ]] || rerun_option_usage

# Source the option parser script.
#
if [[ -r $RERUN_MODULE_DIR/commands/$1/options.sh ]]
then
  . $RERUN_MODULE_DIR/commands/$1/options.sh || {
      rerun_die "Failed loading options parser."
  }
fi

export MY_HOME="${WORKSPACE:-${HOME}}"
export CHART_MATE_HOME="${MY_HOME}/.chart-mate"

trap "error-trap" ERR

source ${RERUN_MODULE_DIR}/lib/log.sh
source ${RERUN_MODULE_DIR}/lib/gke.sh
source ${RERUN_MODULE_DIR}/lib/helm.sh
source ${RERUN_MODULE_DIR}/lib/deis.sh

function retrieve-deis-info {
  set +e

  log-info "Retrieving information about the kubernetes/deis cluster before exiting..."

  if command -v kubectl &> /dev/null; then
    echo "--------------------------" >> "${DEIS_LOG_DIR}/statuses.log"
    date >> "${DEIS_LOG_DIR}/statuses.log"
    kubectl get po,rc,svc -a -o wide --namespace=deis >> "${DEIS_LOG_DIR}/statuses.log"
    echo "--------------------------" >> "${DEIS_LOG_DIR}/statuses.log"

    local components="deis-builder deis-database deis-minio deis-registry deis-router deis-controller"
    local component
    for component in ${components}; do
      local podname=$(kubectl get po --namespace=deis | awk '{print $1}' | grep "${component}")
      kubectl describe po "${podname}" --namespace=deis &> "${DEIS_LOG_DIR}/${component}.describe"
      log-info "Retrieving logs from ${podname}" >> "${DEIS_LOG_DIR}/${component}.log"
      kubectl logs "${podname}" --namespace=deis >> "${DEIS_LOG_DIR}/${component}.log"
      log-info "Retrieving previous instance logs from ${podname}" >> "${DEIS_LOG_DIR}/${component}.log"
      kubectl logs "${podname}" -p --namespace=deis >> "${DEIS_LOG_DIR}/${component}.log"
    done

    # exclude deis | kube-system namespace and anything that doesn't
    # start with an alphanumeric char (saw events without namespaces)
    # egrep -v "^(deis|kube-system|[^[:alnum:]])" "${K8S_EVENT_LOG}" | \
    #   awk '/ Pod / { printf "%s %s : %s\n", $1, $5, $0 }' | sort | uniq

    log-info "Describing all pods seen during test"
    egrep -v "^(deis|kube-system|[^[:alnum:]])" "${K8S_EVENT_LOG}" | \
      awk -v deis_log_dir=${DEIS_LOG_DIR} '/ Pod / { printf "kubectl describe pod %s --namespace=%s &> %s/%s.describe.log\n", $5, $1, deis_log_dir, $5 }' | \
      sort | uniq > ${DEIS_LOG_DIR}/test-pod-describe.sh
    sh ${DEIS_LOG_DIR}/test-pod-describe.sh

    log-info "Fetching pod logs from test run..."
    egrep -v "^(deis|kube-system|[^[:alnum:]])" "${K8S_EVENT_LOG}" | \
      awk -v deis_log_dir=${DEIS_LOG_DIR} '/ Pod / { printf "kubectl logs %s --namespace=%s &> %s/%s.log\n", $5, $1, deis_log_dir, $5 }' | \
      sort | uniq > ${DEIS_LOG_DIR}/test-pod-logs.sh
    sh ${DEIS_LOG_DIR}/test-pod-logs.sh
  fi
}

function error-trap {
  backtrace
  exit 1
}

function backtrace {
  xtrace-off
  local -i start=$(( ${1:-0} + 1 ))
  local -i end=${#BASH_SOURCE[@]}

  echo
  local -i i=0
  local -i j=0
  for ((i=start; i < end; i++)); do
    j=$(( i - 1 ))
    local function="${FUNCNAME[$i]}"
    local file="${BASH_SOURCE[$i]}"
    local line="${BASH_LINENO[$j]}"
    printf "${_magenta}%35s() ${_cyan}%s${_normal}:%d\n" \
      "${function}" "${file}" "${line}"
  done
  xtrace-reset
}

function load-config {
  load-environment
  source "${RERUN_MODULE_DIR}/lib/config.sh"
}

function move-files {
  helm doctor # need proper ~/.helm directory structure and config.yml

  log-info "Staging chart directory"
  rsync -av . ${HOME}/.helm/cache/charts/ --exclude='.git/'
}

function save-environment {
  log-lifecycle "Environment saved as ${K8S_CLUSTER_NAME}"

  mkdir -p "${CHART_MATE_HOME}"
  cat > "${CHART_MATE_HOME}/env" <<EOF
export K8S_CLUSTER_NAME="${K8S_CLUSTER_NAME}"
EOF
}

function load-environment {
  if [ -f "${CHART_MATE_HOME}/env" ]; then
    source "${CHART_MATE_HOME}/env"
  fi
}

function delete-environment {
  rm -f "${CHART_MATE_HOME}/env"
}

function bumpver-if-set {
  local chart="${1}"
  local component="${2}"
  local version="${3}"

  if [ ! -z "${version}" ]; then
    local version_bumper="${RERUN_MODULE_DIR}/bin/chart-version-bumper.sh"
    "${version_bumper}" "${chart}" "${component}" "${version}"
  else
    echo "No version set for ${chart}: ${component}"
  fi
}

function check_platform_arch {
  local supported="linux-amd64 linux-i386 darwin-amd64 darwin-i386"

  if ! echo "${supported}" | tr ' ' '\n' | grep -q "${PLATFORM}-${ARCH}"; then
    cat <<EOF

${PROGRAM} is not currently supported on ${PLATFORM}-${ARCH}.

See https://github.com/deis/${PROGRAM} for more information.

EOF
  fi
}

function download-jq {
  if ! command -v jq &>/dev/null; then
    log-lifecycle "Installing jq into ${BIN_DIR}"

    local platform
    if [ "${PLATFORM}" == "linux" ]; then
      platform="linux64"
    else
      platform="osx-amd64"
    fi

    mkdir -p "${BIN_DIR}"
    curl -Ls "https://github.com/stedolan/jq/releases/download/jq-1.5/jq-${platform}" > "${BIN_DIR}/jq"
    chmod +x "${BIN_DIR}/jq"
  fi
}

function get_latest_version {
  local name="${1}"
  local url="${2}"

  local version
  version="$(curl -sI "${url}" | grep "Location:" | sed -n "s%.*${name}/%%;s%/view.*%%p" )"

  if [ -z "${version}" ]; then
    echo "There doesn't seem to be a version of ${name} avaiable at ${url}." 1>&2
    return 1
  fi

  url_decode "${version}"
}

function url_decode {
  local url_encoded="${1//+/ }"
  printf '%b' "${url_encoded//%/\\x}"
}

function download-chart-mate {
  RERUN_MODULES_REPO="${RERUN_MODULES_REPO:-"rerun-modules"}"
  CHART_MATE_REPO_URL="https://bintray.com/sgoings/${RERUN_MODULES_REPO}/chart-mate/_latestVersion"
  CHART_MATE_URL_BASE="https://dl.bintray.com/sgoings/${RERUN_MODULES_REPO}"

  VERSION="$(get_latest_version "chart-mate" "${CHART_MATE_REPO_URL}")"

  echo "Downloading chart-mate from Bintray (${VERSION})..."
  curl -Ls "${CHART_MATE_URL_BASE}/rerun-${VERSION}" > rerun
  chmod +x rerun
}

function check-all-pods-running {
  local namespace="${1:-deis}"

  kubectl --namespace="${namespace}" get pods -o json | jq -r ".items[].status.phase" | grep -v "Succeeded" | grep -qv "Running"
}

function check-pod-running {
  local name="${1}"
  local namespace="${2:-deis}"

  kubectl --namespace="${namespace}" get pods "${name}" -o json | jq -r ".status.phase" | grep -v "Succeeded" | grep -qv "Running"
}

function wait-for-pod {
  local name="${1}"

  log-lifecycle "Waiting for ${name} to be running"

  local timeout_secs=180
  local increment_secs=1
  local waited_time=0

  local command_output
  while [ ${waited_time} -lt ${timeout_secs} ]; do

    if ! check-pod-running "${name}"; then
      log-lifecycle "${name} is running!"
      return 0
    fi

    sleep ${increment_secs}
    (( waited_time += ${increment_secs} ))

    if [ ${waited_time} -ge ${timeout_secs} ]; then
      log-warn "${name} pod didn't start."
      return 1
    fi

    echo -n . 1>&2
  done
}

function wait-for-all-pods {
  local name="${1}"

  log-lifecycle "Waiting for all pods to be running"

  local timeout_secs=180
  local increment_secs=1
  local waited_time=0

  local command_output
  while [ ${waited_time} -lt ${timeout_secs} ]; do

    if ! check-all-pods-running "${name}"; then
      log-lifecycle "All pods are running!"
      return 0
    fi

    sleep ${increment_secs}
    (( waited_time += ${increment_secs} ))

    if [ ${waited_time} -ge ${timeout_secs} ]; then
      log-warn "Not all pods started."
      return 1
    fi

    echo -n . 1>&2
  done
}

function return-pod-exit-code {
  local name="${1}"
  local container="${2}"
  local namespace="${3:-deis}"
  local status

  log-lifecycle "Waiting for pod exit code..." 1>&2

  local timeout_secs=15
  local increment_secs=5
  local waited_time=0

  local command_output
  while [ ${waited_time} -lt ${timeout_secs} ]; do

    command_output="$(kubectl get po "${name}" -a --namespace="${namespace}" -o json | jq -r '.status.containerStatuses[0].state.terminated.exitCode')"
    if [ "${container}" != "" ]; then
      command_output="$(kubectl get po "${name}" -a --namespace="${namespace}" -o json | jq -r --arg container "${container}" '.status.containerStatuses[] | select(.name==$container) | .state.terminated.exitCode')"
    fi
    if [ "${command_output}" != "null" ]; then
      echo ${command_output}
      return 0
    fi

    sleep ${increment_secs}
    (( waited_time += ${increment_secs} ))

    if [ ${waited_time} -ge ${timeout_secs} ]; then
      log-warn "Exit code not returned." 1>&2
      return 1
    fi

    echo -n . 1>&2
  done
}

function wait-for-http-status {
  local url="${1}"
  local status="${2}"

  log-lifecycle "Checking endpoint ${url} for expected HTTP status code"

  local timeout_secs=180
  local increment_secs=5
  local waited_time=0

  local command_output
  while [ ${waited_time} -lt ${timeout_secs} ]; do

    set -x
    command_output="$(curl -sS -o /dev/null -w '%{http_code}' "${url}")"
    if [ "${command_output}" == "401" ]; then
      set +x
      log-info "Endpoint responding at ${url}."
      return 0
    fi
    set +x

    sleep ${increment_secs}
    (( waited_time += ${increment_secs} ))

    if [ ${waited_time} -ge ${timeout_secs} ]; then
      log-warn "Endpoint is unresponsive at ${url}"
      echo
      return 1
    fi

    echo -n . 1>&2
  done
}
