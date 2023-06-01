# podman-backend-e2e

wrapper on top of podman upstream e2e tests to run podman functional testing on top of a podman remote deployment. The backend offering the podman functionality
can be selected among `crc` or `podman-machine`

## overview

The container is based on [deliverest](https://github.com/adrianriobo/deliverest) for handling the remote execution.

## Usage

### windows amd64

```bash
PODMAN_VERSION=4.4.4
podman run --rm -it --name prmamp-e2e \
    -e TARGET_HOST=$(cat host) \
    -e TARGET_HOST_USERNAME=$(cat username) \
    -e TARGET_HOST_KEY_PATH=/data/id_rsa \
    -e TARGET_FOLDER=prmamp-e2e \
    -e TARGET_RESULTS=prmamp-e2e-results.xml \
    -e OUTPUT_FOLDER=/data \
    -v $PWD:/data:z \
    quay.io/rhqp/podman-backend-e2e:v${PODMAN_VERSION}-windows-amd64 \
        prmamp-e2e/run.ps1 -podmanVersion "${PODMAN_VERSION}" \
            -targetFolder prmamp-e2e \
            -backend crc \
            -junitResultsFilename prmamp-e2e-results.xml
```

### darwin arm64

```bash
PODMAN_VERSION=4.4.4
podman run -d --name prmamp-e2e-darwin-m1 \
    -e TARGET_HOST=$(cat host) \
    -e TARGET_HOST_USERNAME=$(cat username) \
    -e TARGET_HOST_KEY_PATH=/data/id_rsa \
    -e TARGET_FOLDER=prmamp-e2e \
    -e TARGET_RESULTS=prmamp-e2e-results.xml \
    -e OUTPUT_FOLDER=/data \
    -e DEBUG=true \
    -v $PWD:/data:z \
    quay.io/rhqp/podman-backend-e2e:v${PODMAN_VERSION}-darwin-arm64 \
        PODMAN_VERSION="${PODMAN_VERSION}" \
        TARGET_FOLDER=prmamp-e2e \
        BACKEND=podman-machine \
        JUNIT_RESULTS_FILENAME=prmamp-e2e-results.xml \
        ARCH=arm64 \
        prmamp-e2e/run.sh
```
