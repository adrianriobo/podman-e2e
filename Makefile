PODMAN_VERSION ?= 4.8.2
CONTAINER_MANAGER ?= podman

# Image URL to use all building/pushing image targets
IMG ?= quay.io/rhqp/podman-backend-e2e:v${PODMAN_VERSION}
TKN_IMG ?= quay.io/rhqp/podman-backend-e2e-tkn:v${PODMAN_VERSION}

TOOLS_DIR := tools
include tools/tools.mk

# Build the container image
.PHONY: oci-build-multi-manifest
oci-build-multi-manifest: 
	${CONTAINER_MANAGER} manifest create ${IMG}
	${CONTAINER_MANAGER} build -t podman-backend:windows-amd64 -f oci/Containerfile --build-arg=OS=windows --build-arg=ARCH=amd64 oci
	${CONTAINER_MANAGER} manifest add ${IMG} --os windows --arch amd64 containers-storage:localhost/podman-backend:windows-amd64
	${CONTAINER_MANAGER} build -t podman-backend:darwin-amd64 -f oci/Containerfile --build-arg=OS=darwin --build-arg=ARCH=amd64 oci
	${CONTAINER_MANAGER} manifest add ${IMG} --os darwin --arch amd64 containers-storage:localhost/podman-backend:darwin-amd64

# Push the container image
.PHONY: oci-push-multi-manifest
oci-push-multi-manifest:
	${CONTAINER_MANAGER} push ${IMG}

.PHONY: oci-clean-multi-manifest
oci-clean-multi-manifest:
	${CONTAINER_MANAGER} rmi localhost/podman-backend:windows-amd64
	${CONTAINER_MANAGER} rmi localhost/podman-backend:darwin-amd64
	${CONTAINER_MANAGER} rmi ${IMG}      

# Build the container image
.PHONY: oci-build
oci-build: 
	${CONTAINER_MANAGER} build -t ${IMG}-${OS}-${ARCH} -f oci/Containerfile --build-arg=OS=${OS} --build-arg=ARCH=${ARCH} oci

# Build the container image
.PHONY: oci-push
oci-push: 
	${CONTAINER_MANAGER} push ${IMG}-${OS}-${ARCH}

# Create tekton task bundle
.PHONY: tkn-push
tkn-push: install-out-of-tree-tools
	$(TOOLS_BINDIR)/tkn bundle push $(TKN_IMG) -f tkn/task.yaml