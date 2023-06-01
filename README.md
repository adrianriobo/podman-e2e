# prmamp-e2e

wrapper on top of podman upstream e2e tests to run them mostly on non linux environments with podman machine

## overview

The container is based on [deliverest](https://github.com/adrianriobo/deliverest) for handling the remote execution

## Usage

### windows amd64

```bash
podman run --rm -it --name prmamp-e2e \
    -e TARGET_HOST=$(cat host) \
    -e TARGET_HOST_USERNAME=$(cat username) \
    -e TARGET_HOST_KEY_PATH=/data/id_rsa \
    -e TARGET_FOLDER=prmamp-e2e \
    -e TARGET_RESULTS=prmamp-e2e-results.xml \
    -e OUTPUT_FOLDER=/data \
    -v $PWD:/data:z \
    quay.io/rhqp/prmamp-e2e:v4.4.4-windows-amd64 \
        prmamp-e2e/run.ps1 -podmanVersion '4.4.4' \
            -targetFolder prmamp-e2e \
            -backend crc \
            -junitResultsFilename prmamp-e2e-results.xml
```

### darwin arm64

```bash
podman run -d --name prmamp-e2e-darwin-m1 \
    -e TARGET_HOST=$(cat host) \
    -e TARGET_HOST_USERNAME=$(cat username) \
    -e TARGET_HOST_KEY_PATH=/data/id_rsa \
    -e TARGET_FOLDER=prmamp-e2e \
    -e TARGET_RESULTS=prmamp-e2e-results.xml \
    -e OUTPUT_FOLDER=/data \
    -e DEBUG=true \
    -v $PWD:/data:z \
    quay.io/rhqp/prmamp-e2e:v4.4.4-darwin-arm64 \
        PODMAN_VERSION='4.4.4' \
        TARGET_FOLDER=prmamp-e2e \
        BACKEND=podman-machine \
        JUNIT_RESULTS_FILENAME=prmamp-e2e-results.xml \
        ARCH=arm64 \
        prmamp-e2e/run.sh
```
