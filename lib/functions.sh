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

function load-config {
  load-environment
  source "${RERUN_MODULE_DIR}/lib/config.sh"
}

function move-files {
  helm doctor # need proper ~/.helm directory structure and config.yml

  log-info "Staging chart directory"
  rsync -av . ${HOME}/.helm/cache/charts/ --exclude='.git/'
}

function helm::setup {
  # Uses HELM_ARTIFACT_REPO to determine which repository to grab helm from

  log-lifecycle "Installing helm into $(pwd)/.bin"

  mkdir -p .bin
  (
    cd .bin
    curl -s https://get.helm.sh | bash
  )
  export PATH="$(pwd)/.bin:${PATH}"
}

function helm::get-changed-charts {
  git diff --name-only HEAD origin/HEAD -- charts \
    | cut -d/ -f 1-2 \
    | sort \
    | uniq
}

function ensure-dirs-exist {
  local dirs="${@}"
  local pruned

  # ensure directories exist and just output directory name
  for dir in ${dirs}; do
    if [ -d ${dir} ]; then
      pruned+="$(basename "${dir}")\n"
    fi
  done

  echo -e "${pruned}"
}

function generate-test-plan {
  ensure-dirs-exist "$(helm::get-changed-charts)"
}

function get-all-charts {
  local chartlist="$(find . -name Chart.yaml)"
  local cleanedlist=""

  if [ -z "${TEST_CHARTS:-}" ]; then
    local chart
    for chart in ${chartlist}; do
      cleanedlist+="$(basename $(dirname ${chart})) "
    done
  else
    cleanedlist="${TEST_CHARTS}"
  fi

  echo "${cleanedlist}"
}

function helm::test-chart {
  log-warn "Start: ${1}"
  .bin/helm fetch "${1}"
  .bin/helm install "${1}"
  helm::healthcheck "${1}"
  .bin/helm uninstall -y "${1}"
  log-warn "Done: ${1}"
}

function helm::test {
  local test_plan

  test_plan="$(get-all-charts)"

  log-lifecycle "Running test plan"
  log-info "Charts to be tested:"
  echo "${test_plan}"

  local plan
  for plan in ${test_plan}; do
    helm::test-chart ${plan}
  done
}

function helm::is-pod-running {
  local name="${1}"

  if kubectl get pods "${name}" &> /dev/null; then
    log-info "Looking for pod named ${name}"
    local jq_name_query=".status.phase"
    kubectl get pods ${name} -o json | jq -r "${jq_name_query}" | grep -q "Running" && return 0
  fi

  log-info "Looking for label: app=${name}"
  local jq_app_label_query=".items[] | select(.metadata.labels.app == \"${name}\") | .status.phase"
  kubectl get pods -o json | jq -r "${jq_app_label_query}" | grep -q "Running" && return 0

  log-info "Looking for label: provider=${name}"
  local jq_provider_label_query=".items[] | select(.metadata.labels.provider == \"${name}\") | .status.phase"
  kubectl get pods -o json | jq -r "${jq_provider_label_query}" | grep -q "Running" && return 0

  log-info "Looking for label: name=${name}"
  local jq_provider_label_query=".items[] | select(.metadata.labels.name == \"${name}\") | .status.phase"
  kubectl get pods -o json | jq -r "${jq_provider_label_query}" | grep -q "Running" && return 0
}

function helm::healthcheck {
  WAIT_TIME=1
  log-lifecycle "Checking: ${1}"
  until helm::is-pod-running "${1}"; do
    sleep 1
     (( WAIT_TIME += 1 ))
     if [ ${WAIT_TIME} -gt ${HEALTHCHECK_TIMEOUT_SEC} ]; then
      return 1
    fi
  done
  log-lifecycle "Checked!: ${1}"
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

function gke::install {
  if [ ! -d "${GOOGLE_SDK_DIR}" ]; then
    export CLOUDSDK_CORE_DISABLE_PROMPTS=1
    curl https://sdk.cloud.google.com | bash
  fi

  export PATH="${GOOGLE_SDK_DIR}/bin:$PATH"
  gcloud -q components update kubectl
}

function gke::login {
  if [ -f ${GCLOUD_CREDENTIALS_FILE} ]; then
    gcloud -q auth activate-service-account --key-file "${GCLOUD_CREDENTIALS_FILE}"
  else
    log-warn "No credentials file located at ${GCLOUD_CREDENTIALS_FILE}"
    log-warn "You can set this via GCLOUD_CREDENTIALS_FILE"
    return 1
  fi
}

function gke::config {
  gcloud -q config set project "${GCLOUD_PROJECT_ID}"
  gcloud -q config set compute/zone "${K8S_ZONE}"
}

function gke::create-cluster {
  log-lifecycle "Creating cluster ${K8S_CLUSTER_NAME}"
  gcloud -q container clusters create "${K8S_CLUSTER_NAME}"
  gcloud -q config set container/cluster "${K8S_CLUSTER_NAME}"
  gcloud -q container clusters get-credentials "${K8S_CLUSTER_NAME}"
}

function gke::destroy {
  log-lifecycle "Destroying cluster ${K8S_CLUSTER_NAME}"
  if command -v gcloud &>/dev/null; then
    gcloud -q container clusters delete "${K8S_CLUSTER_NAME}" --no-wait
  else
    rerun_log error "gcloud executable not found in PATH. Could not destroy ${K8S_CLUSTER_NAME}"
  fi
}

function gke::setup {
  gke::install
  gke::login
  gke::config
}

function save-environment {
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
