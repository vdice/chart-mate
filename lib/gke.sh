function gke::install {
  log-lifecycle "Installing GCE command line tools"
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
