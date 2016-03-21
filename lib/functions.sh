# Shell functions for the chart-mate module.
#/ usage: source RERUN_MODULE_DIR/lib/functions.sh command
#

# Read rerun's public functions
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

# - - -
# Your functions declared here.
# - - -

source ${RERUN_MODULE_DIR}/lib/gke.sh
source ${RERUN_MODULE_DIR}/lib/helm.sh
source ${RERUN_MODULE_DIR}/lib/deis.sh

function exit-trap {
  set +e

  log-warn "Retrieving information about the kubernetes/deis cluster before exiting..."

  local timestamp="$(date +%Y-%m-%d+%H:%M:%S)"

  if command -v kubectl &> /dev/null; then
    mkdir -p "logs"

    kubectl get po,rc,svc -a --namespace=deis &> "logs/statuses-${timestamp}.log"

    local components="deis-router deis-builder deis-database deis-minio deis-registry deis-router deis-controller"
    local component
    for component in ${components}; do
      kubectl describe po -l app=${component} --namespace=deis &> "logs/${component}-describe-${timestamp}.log"
    done

    mv k8s-events.log logs
  fi
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

function log-lifecycle {
  rerun_log "${bldblu}==> ${@}...${txtrst}"
}

function log-info {
  rerun_log "--> ${@}"
}

function log-warn {
  rerun_log warn "--> ${@}"
}

function save-environment {
  log-lifecycle "Environment saved as ${K8S_CLUSTER_NAME}"

  mkdir -p "${HOME}/.chart-mate"
  cat > "${HOME}/.chart-mate/env" <<EOF
export K8S_CLUSTER_NAME="${K8S_CLUSTER_NAME}"
EOF
}

function load-environment {
  if [ -f "${HOME}/.chart-mate/env" ]; then
    source "${HOME}/.chart-mate/env"
  fi
}

function delete-environment {
  rm -f "${HOME}/.chart-mate/env"
}

function bumpver-if-set {
  local chart="${1}"
  local component="${2}"
  local version="${3}"

  if [ ! -z "${version}" ]; then
    local version_bumper="${RERUN_MODULE_DIR}/lib/chart-version-bumper.sh"
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
  local namespace="${2:-deis}"
  local status

  log-lifecycle "Waiting for pod exit code..." 1>&2

  local timeout_secs=15
  local increment_secs=5
  local waited_time=0

  local command_output
  while [ ${waited_time} -lt ${timeout_secs} ]; do

    command_output="$(kubectl get po "${name}" -a --namespace="${namespace}" -o json | jq -r '.status.containerStatuses[0].state.terminated.exitCode')"
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

    command_output="$(curl -s -o /dev/null -w '%{http_code}' "${url}")"
    if [ "${command_output}" -eq 401 ]; then
      log-info "Endpoint responding at ${url}."
      return 0
    fi

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
