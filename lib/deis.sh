function deis::healthcheck {
  wait-for-all-pods "deis"

  local successes
  while [[ ${successes} -lt 5 ]]; do
    wait-for-http-status "http://deis.$(deis::get-router-ip).xip.io/v2/" 200
    let successes+=1
    log-info "Successfully interacted with Deis platform ${successes} time(s)."
    sleep 5
  done

}

function deis::get-router-ip {
  local ip="null"

  log-lifecycle "Ensuring non-null router ip" 1>&2

  local timeout_secs=180
  local increment_secs=5
  local waited_time=0

  local command_output
  while [ ${waited_time} -lt ${timeout_secs} ]; do

    command_output="$(kubectl --namespace=deis get svc deis-router -o json | jq -r ".status.loadBalancer.ingress[0].ip")"
    if [ ! -z ${command_output} ] && [ ${command_output} != "null" ]; then
      echo "${command_output}"
      return 0
    fi

    sleep ${increment_secs}
    (( waited_time += ${increment_secs} ))

    if [ ${waited_time} -ge ${timeout_secs} ]; then
      log-warn "Router never exposed public IP"
      echo
      return 1
    fi

    echo -n . 1>&2
  done
}
