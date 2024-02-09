#!/bin/bash

# Validate required envs as params
mandatory_params () {
    local validate=1

    [[ -z "${TARGET_FOLDER+x}" ]] \
        && echo "TARGET_FOLDER required" \
        && validate=0

    [[ -z "${JUNIT_RESULTS_FILENAME+x}" ]] \
        && echo "JUNIT_RESULTS_FILENAME required" \
        && validate=0

    return $validate
}
 
backend_crc_podman () {
    PODMAN_BINARY="$HOME/.crc/bin/oc/podman"

    crc config set preset podman
    crc setup
    crc start
    eval $(crc podman-env)    
}

backend_crc_microshift () {

    [[ -z "${PULLSECRET_FILENAME+x}" ]] \
        && exit 1

    PODMAN_BINARY="$HOME/.crc/bin/oc/podman"

    crc config set preset microshift
    crc setup
    crc start -p "${TARGET_FOLDER}/${PULLSECRET_FILENAME}"
    eval $(crc podman-env)    
}

backend_crc_openshift () {

    [[ -z "${PULLSECRET_FILENAME+x}" ]] \
        && exit 1

    PODMAN_BINARY="$HOME/.crc/bin/oc/podman"

    crc config set preset openshift
    crc setup
    crc start -p "${TARGET_FOLDER}/${PULLSECRET_FILENAME}"
    eval $(crc podman-env)    
}

backend_podman () {

    [[ -z "${PODMAN_VERSION+x}" ]] \
        && exit 1

    PODMAN_BINARY="/opt/podman/bin/podman"

    # Install podman
    if [[ ${PODMAN_INSTALL} == "true" ]]
    then
        pushd ${TARGET_FOLDER}
        curl -kL https://github.com/containers/podman/releases/download/v${PODMAN_VERSION}/podman-installer-macos-${ARCH}.pkg -o podman-installer-macos.pkg
        sudo installer -pkg podman-installer-macos.pkg -target /
        popd
        PATH=$PATH:/opt/podman/bin/podman
    fi

    # Start podman machine
    if [[ ${PODMAN_START} == "true" ]]
    then    
        export CONTAINERS_MACHINE_PROVIDER=${PODMAN_PROVIDER}
        # this is a workaround until applehv is GA as so vfkit will be included within the podman installer
        # TODO remove once applehv GA
        if [[ ${PODMAN_PROVIDER} == 'applehv' ]]
        then
            pushd ${TARGET_FOLDER}
            curl -LO https://github.com/crc-org/vfkit/releases/download/v0.5.0/vfkit
            chmod +x vfkit
            popd    
            sudo ln -s ${HOME}/${TARGET_FOLDER}/vfkit /usr/local/bin/vfkit
        fi
        ${PODMAN_BINARY} machine init ${PODMAN_OPTS}   
        ${PODMAN_BINARY} machine start

        if [[ ${MONITORING_ENABLE} == 'true' ]]
        then
            # Run node exporter on the target host

            # Run node exporter on the target machine
            # we need to run the binary otherwise tests will destroy the container
            # ${PODMAN_BINARY} machine ssh 'podman run -d -p 9200:9100 -v "/:/host:ro,rslave" quay.io/prometheus/node-exporter:latest --path.rootfs=/host'
            # Also this approach is not working with applehv until podman 5.0 
            # https://github.com/containers/podman/pull/21207/commits/83fa4843f6fe4e98db3e2310d62f729c2eca63b7
            ${PODMAN_BINARY} machine ssh 'curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz'
            ${PODMAN_BINARY} machine ssh 'tar -xzvf node_exporter-1.7.0.linux-amd64.tar.gz --strip-components 1'
            # https://github.com/prometheus/node_exporter?tab=readme-ov-file#perf-collector
            ${PODMAN_BINARY} machine ssh 'sudo sysctl -w kernel.perf_event_paranoid=0'
            ${PODMAN_BINARY} machine ssh 'nohup ./node_exporter --web.listen-address=:52200 > nohup.out 2> nohup.err < /dev/null &'
            # https://github.com/containers/gvisor-tap-vsock?tab=readme-ov-file#port-forwarding
            ${PODMAN_BINARY} machine ssh "curl gateway.containers.internal/services/forwarder/expose -X POST -d '{\"local\":\":52200\",\"remote\":\"192.168.127.2:52200\"}'"
        fi
    fi
}

cleanup_backend_podman () {

    PODMAN_BINARY="/opt/podman/bin/podman"

    if [[ ${PODMAN_START} == "true" ]]
    then
        # Stop podman machine
        ${PODMAN_BINARY} machine stop
        ${PODMAN_BINARY} machine rm -f
    fi
    # Fix for applehv not GA with podman
    # TODO remove once applehv GA
    sudo rm -rf /usr/local/bin/vfkit
}

cleanup_backend_crc_podman () {

    crc stop
    crc cleanup
}

# PODMAN_VERSION should be set
# TARGET_FOLDER should be set
# JUNIT_RESULTS_FILENAME should be set
if [[ ! mandatory_params ]]; then
    exit 1
fi
# Default backend podman
BACKEND="${BACKEND:-"podman"}"
# Check if podman backend should be installed, default false.
PODMAN_INSTALL="${PODMAN_INSTALL:-"false"}"
# Check if podman machine should be started, default false.
PODMAN_START="${PODMAN_START:-"false"}"
# Set the podman machine provider (qemu or applehv)
PODMAN_PROVIDER="${PODMAN_PROVIDER:-"qemu"}"
# Passing possible options for the podman machine init (i.e --rootful --user-mode-networking)
PODMAN_OPTS="${PODMAN_OPTS:-""}"
# If enable it will run node exporter insde the guest machine
MONITORING_ENABLE="${MONITORING_ENABLE:-"false"}"

# Prepare the backend
case "${BACKEND}" in
  podman)
    backend_podman
    ;;

  crc-podman)
    backend_crc_podman
    ;;

  crc-microshift)
    backend_crc_microshift
    ;;

  crc-openshift)
    backend_crc_openshift
    ;;

  *)
    echo "${BACKEND} is not supported"
    exit 1 
    ;;
esac

# Prepare run e2e
export PODMAN_BINARY=$PODMAN_BINARY
mkdir "${TARGET_FOLDER}/tmp"
export TMPDIR="$HOME/${TARGET_FOLDER}/tmp"
export E2E_JUNIT_OUTPUTFILE="${TARGET_FOLDER}/${JUNIT_RESULTS_FILENAME}"

# Run e2e
export PATH="$PATH:$HOME/${TARGET_FOLDER}"
podman-backend-e2e | tee ${TARGET_FOLDER}/podman-backend-e2e.log

# Cleanup backed
case "${BACKEND}" in
  podman)
    cleanup_backend_podman
    ;;

  crc-podman|crc-microshift|crc-openshift)
    cleanup_backend_crc_podman
    ;;

  *)
    echo "${BACKEND} is not supported"
    exit 1 
    ;;
esac