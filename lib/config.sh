PLATFORM="$(uname | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

export HELM_ARTIFACT_REPO="${HELM_ARTIFACT_REPO:-helm-ci}"
CLUSTER_NAME="${CLUSTER_NAME:-helm-testing}"
GOOGLE_SDK_DIR="${HOME}/google-cloud-sdk"
SKIP_DESTROY=${SKIP_DESTROY:-false}
export HEALTHCHECK_TIMEOUT_SEC=120

GCLOUD_PROJECT_ID="${GCLOUD_PROJECT_ID:-${CLUSTER_NAME}}"
K8S_ZONE="${K8S_ZONE:-us-central1-b}"
K8S_CLUSTER_NAME="${K8S_CLUSTER_NAME:-${GCLOUD_PROJECT_ID}-$(openssl rand -hex 2)}"

CHART_MATE_ENV_ROOT="${HOME}/.chart-mate/${K8S_CLUSTER_NAME}"
BIN_DIR="${CHART_MATE_ENV_ROOT}/.bin"
export SECRETS_DIR="${CHART_MATE_ENV_ROOT}"

# Text color variables
txtund=$(tput sgr 0 1)          # Underline
txtbld=$(tput bold)             # Bold
bldred=${txtbld}$(tput setaf 1) #  red
bldblu=${txtbld}$(tput setaf 4) #  blue
bldwht=${txtbld}$(tput setaf 7) #  white
txtrst=$(tput sgr0)             # Reset

pass="${bldblu}-->${txtrst}"
warn="${bldred}-->${txtrst}"
ques="${bldblu}???${txtrst}"

export GCLOUD_CREDENTIALS_FILE="${GCLOUD_CREDENTIALS_FILE:-${HOME}/.secrets/helm-testing-creds.json}"

if [ ! -z "${JENKINS_URL}" ]; then
  mkdir -p "${HOME}/.secrets/"
  echo ${GCLOUD_CREDENTIALS} > "${GCLOUD_CREDENTIALS_FILE}"
fi

export PATH="${CHART_MATE_ENV_ROOT}/.bin:${GOOGLE_SDK_DIR}/bin:$PATH"

export WORKFLOW_CHART="${WORKFLOW_CHART:-workflow-dev}"


if [ -z "${WORKSPACE}" ]; then
  export DEIS_LOG_DIR="${WORKSPACE}/logs/${BUILD_NUMBER}"
else
  export DEIS_LOG_DIR="${HOME}/logs/${BUILD_NUMBER}"
fi

mkdir -p ${DEIS_LOG_DIR}
