#!/bin/bash

# Validate required envs as params
mandatory_params () {
    local validate=1

    [[ -z "${PODMAN_VERSION+x}" ]] \
        && echo "PODMAN_VERSION required" \
        && validate=0

    [[ -z "${TARGET_FOLDER+x}" ]] \
        && echo "TARGET_FOLDER required" \
        && validate=0

    [[ -z "${JUNIT_RESULTS_FILENAME+x}" ]] \
        && echo "JUNIT_RESULTS_FILENAME required" \
        && validate=0

    return $validate
}

backend_crc () {
    PODMAN_BINARY="$HOME/.crc/bin/oc/podman"

    crc config set preset podman
    crc setup
    crc start
    eval $(crc podman-env)    
}

backend_podman () {
    PODMAN_BINARY="/opt/podman/bin/podman"

    # Install podman
    curl -kL https://github.com/containers/podman/releases/download/v${PODMAN_VERSION}/podman-installer-macos-${ARCH}.pkg -o podman-installer-macos.pkg
    sudo installer -pkg podman-installer-macos.pkg -target /
    PATH=$PATH:/opt/podman/bin/podman
    
    # Start podman machine
    ${PODMAN_BINARY} machine init
    ${PODMAN_BINARY} machine start
}

# PODMAN_VERSION should be set
# TARGET_FOLDER should be set
# JUNIT_RESULTS_FILENAME should be set
if [[ ! mandatory_params ]]; then
    exit 1
fi
BACKEND="${BACKEND:-"podman-machine"}"
if [ "${BACKEND}" == "crc" ]; then
    backend_crc 
else
    backend_podman
fi

# Prepare run e2e
export PODMAN_BINARY=$PODMAN_BINARY
mkdir "${TARGET_FOLDER}/tmp"
export TMPDIR="$HOME/${TARGET_FOLDER}/tmp"
export E2E_JUNIT_OUTPUTFILE="${TARGET_FOLDER}/${JUNIT_RESULTS_FILENAME}"

# Run e2e
export PATH="$PATH:$HOME/${TARGET_FOLDER}"
rpmamp-e2e
