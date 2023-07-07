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
        curl -kL https://github.com/containers/podman/releases/download/v${PODMAN_VERSION}/podman-installer-macos-${ARCH}.pkg -o podman-installer-macos.pkg
        sudo installer -pkg podman-installer-macos.pkg -target /
        PATH=$PATH:/opt/podman/bin/podman
    fi

    if [[ ${PODMAN_START} == "true" ]]
    then
        # Start podman machine
        ${PODMAN_BINARY} machine init
        ${PODMAN_BINARY} machine start
    fi
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
podman-backend-e2e
