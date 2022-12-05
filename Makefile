SHELL = /bin/bash
GITHUB_USER = $(shell git remote -v | grep origin | head -1 | cut -d/ -f4)
CURRENT_BRANCH = $(shell git rev-parse --abbrev-ref HEAD)

amd64-image:
	cd ci/amd64 && \
	bash packer.build.amd64.sh $(GITHUB_USER) $(CURRENT_BRANCH)

	cd ci/amd64/builds/packer-debian-11.5-amd64-qemu && \
	sha256sum debian-11.5-amd64.qcow2 > debian-11.5-amd64.qcow2.sha256

	cd ci/amd64/builds/packer-debian-11.5-amd64-qemu && \
	gzip -v9 debian-11.5-amd64.qcow2

	cd ci/amd64/builds/packer-debian-11.5-amd64-qemu && \
	sha256sum debian-11.5-amd64.qcow2.gz > debian-11.5-amd64.qcow2.gz.sha256
