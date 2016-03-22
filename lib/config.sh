PLATFORM="$(uname | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

# helm configuration
export HELM_ARTIFACT_REPO="${HELM_ARTIFACT_REPO:-helm-ci}"
export WORKFLOW_CHART="${WORKFLOW_CHART:-workflow-dev}"
export HELM_HOME="${MY_HOME}/.helm"

# cluster defaults
GOOGLE_SDK_DIR="${HOME}/google-cloud-sdk"
CLUSTER_NAME="${CLUSTER_NAME:-helm-testing}"
GCLOUD_PROJECT_ID="${GCLOUD_PROJECT_ID:-${CLUSTER_NAME}}"
K8S_ZONE="${K8S_ZONE:-us-central1-b}"
K8S_CLUSTER_NAME="${K8S_CLUSTER_NAME:-${GCLOUD_PROJECT_ID}-$(openssl rand -hex 2)}"

# chart mate defaults
CHART_MATE_ENV_ROOT="${CHART_MATE_HOME}/${K8S_CLUSTER_NAME}"
BIN_DIR="${CHART_MATE_ENV_ROOT}/.bin"
export SECRETS_DIR="${CHART_MATE_ENV_ROOT}"

# timing defaults
export HEALTHCHECK_TIMEOUT_SEC=120

# credentials
export GCLOUD_CREDENTIALS_FILE="${GCLOUD_CREDENTIALS_FILE:-${HOME}/.secrets/helm-testing-creds.json}"
if [ ! -z "${JENKINS_URL}" ]; then
  # Running in Jenkins
  mkdir -p "${HOME}/.secrets/"
  echo ${GCLOUD_CREDENTIALS} > "${GCLOUD_CREDENTIALS_FILE}"
  export DEIS_LOG_DIR="${WORKSPACE}/logs/${BUILD_NUMBER}"
else
  # Not running in Jenkins
  export DEIS_LOG_DIR="${CHART_MATE_HOME}/logs"
fi
mkdir -p "${DEIS_LOG_DIR}"

# path setup
export PATH="${CHART_MATE_ENV_ROOT}/.bin:${GOOGLE_SDK_DIR}/bin:$PATH"

# color variables
txtund=$(tput sgr 0 1)          # Underline
txtbld=$(tput bold)             # Bold
bldred=${txtbld}$(tput setaf 1) #  red
bldblu=${txtbld}$(tput setaf 4) #  blue
bldwht=${txtbld}$(tput setaf 7) #  white
txtrst=$(tput sgr0)             # Reset

pass="${bldblu}-->${txtrst}"
warn="${bldred}-->${txtrst}"
ques="${bldblu}???${txtrst}"
