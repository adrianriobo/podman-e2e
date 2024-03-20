# podman-backend-e2e

wrapper on top of podman upstream e2e tests to run podman functional testing on top of a podman remote deployment.

Tests will run against one backend which offers podman functionality (through VM): `podman` , `crc-podman`, `crc-microshift` or `crc-openshift`

## overview

The container is based on [deliverest](https://github.com/adrianriobo/deliverest) for handling the remote execution.

An uses set of functional tests defined by [podman upstream](https://github.com/containers/podman/tree/main/test/e2e) with some [code adapatations](https://github.com/adrianriobo/podman/commit/c4eb6ebdca431ea5df51576764b651f97d80c6e9).

## Usage

### windows amd64 with podman backend (install and start)

```bash
PODMAN_VERSION=5.0.0
podman run --rm -it --name podman-backend-e2e \
    -e TARGET_HOST=$(cat host) \
    -e TARGET_HOST_USERNAME=$(cat username) \
    -e TARGET_HOST_KEY_PATH=/data/id_rsa \
    -e TARGET_FOLDER=podman-backend-e2e \
    -e TARGET_RESULTS=podman-backend-e2e-results.xml \
    -e OUTPUT_FOLDER=/data \
    -v $PWD:/data:z \
    quay.io/rhqp/podman-backend-e2e:v${PODMAN_VERSION}-windows-amd64 \
        podman-backend-e2e/run.ps1 -podmanVersion "${PODMAN_VERSION}" \
            -targetFolder podman-backend-e2e \
            -backend podman \
            -podmanInstall 'true' \
            -podmanStart 'true' \
            -junitResultsFilename podman-backend-e2e-results.xml
```

### darwin arm64 with crc podman backend (install and start)

```bash
PODMAN_VERSION=5.0.0
podman run -d --name podman-backend-e2e-darwin-m1 \
    -e TARGET_HOST=$(cat host) \
    -e TARGET_HOST_USERNAME=$(cat username) \
    -e TARGET_HOST_KEY_PATH=/data/id_rsa \
    -e TARGET_FOLDER=podman-backend-e2e \
    -e TARGET_RESULTS=podman-backend-e2e-results.xml \
    -e OUTPUT_FOLDER=/data \
    -e DEBUG=true \
    -v $PWD:/data:z \
    quay.io/rhqp/podman-backend-e2e:v${PODMAN_VERSION}-darwin-arm64 \
        PODMAN_VERSION="${PODMAN_VERSION}" \
        TARGET_FOLDER=podman-backend-e2e \
        BACKEND=crc-podman \
        JUNIT_RESULTS_FILENAME=podman-backend-e2e-results.xml \
        ARCH=arm64 \
        podman-backend-e2e/run.sh
```

### darwin amd64 with crc microshift backend

```bash
PODMAN_VERSION=5.0.0
# Here we need to pass the pullsecret to spin the microshift cluster
podman run -d --name podman-backend-e2e-darwin-m1 \
    -e TARGET_HOST=$(cat host) \
    -e TARGET_HOST_USERNAME=$(cat username) \
    -e TARGET_HOST_KEY_PATH=/data/id_rsa \
    -e TARGET_FOLDER=podman-backend-e2e \
    -e TARGET_RESULTS=podman-backend-e2e-results.xml \
    -e OUTPUT_FOLDER=/data \
    -e DEBUG=true \
    -v $PWD:/data:z \
    -v $PWD/pullsecret:/opt/podman-backend-e2e/pullsecret:z \
    quay.io/rhqp/podman-backend-e2e:v${PODMAN_VERSION}-darwin-arm64 \
        PODMAN_VERSION="${PODMAN_VERSION}" \
        TARGET_FOLDER=podman-backend-e2e \
        BACKEND=crc-microshift \
        JUNIT_RESULTS_FILENAME=podman-backend-e2e-results.xml \
        ARCH=amd64 \
        PULLSECRET_FILENAME=pullsecret \
        podman-backend-e2e/run.sh
```

### windows amd64 with crc microshift openshift backend

```bash
PODMAN_VERSION=5.0.0
podman run --rm -it --name podman-backend-e2e \
    -e TARGET_HOST=$(cat host) \
    -e TARGET_HOST_USERNAME=$(cat username) \
    -e TARGET_HOST_KEY_PATH=/data/id_rsa \
    -e TARGET_FOLDER=podman-backend-e2e \
    -e TARGET_RESULTS=podman-backend-e2e-results.xml \
    -e OUTPUT_FOLDER=/data \
    -e DEBUG=true \
    -v $PWD:/data:z \
    -v $PWD/pullsecret:/opt/podman-backend-e2e/pullsecret:z \
    quay.io/rhqp/podman-backend-e2e:v${PODMAN_VERSION}-windows-amd64 \
        podman-backend-e2e/run.ps1 -podmanVersion "${PODMAN_VERSION}" \
            -targetFolder podman-backend-e2e \
            -backend crc-openshift \
            -junitResultsFilename podman-backend-e2e-results.xml \
            -pullsecretFilename pullsecret
```

## podman preparation

```bash
VERSION=5.0.0

git fetch upstream
git branch -D custom
git checkout -b custom v${VERSION}
git checkout podman-backend-e2e
commit=$(git log -n 1 | grep commit | awk '{ print $2 }')
git checkout custom
git cherry-pick $commit
# solve conflicts if any

git branch -D podman-backend-e2e
git checkout -b podman-backend-e2e
git push -f origin podman-backend-e2e
git tag v${VERSION}-multi-e2e
git push origin v${VERSION}-multi-e2e
```