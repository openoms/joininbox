SHELL = /bin/bash
GITHUB_USER = $(shell git remote -v | grep origin | head -1 | cut -d/ -f4)
CURRENT_BRANCH = $(shell git rev-parse --abbrev-ref HEAD)

amd64-image:
	cd ci/amd64 && \
	bash packer.build.amd64.sh $(GITHUB_USER) $(CURRENT_BRANCH)

	cd ci/amd64/builds/joininbox-amd64-debian-11.5-qemu && \
	sha256sum joininbox-amd64-debian-11.5.qcow2 > joininbox-amd64-debian-11.5.qcow2.sha256

	cd ci/amd64/builds/joininbox-amd64-debian-11.5-qemu && \
	gzip -v9 joininbox-amd64-debian-11.5.qcow2

	cd ci/amd64/builds/joininbox-amd64-debian-11.5-qemu && \
	sha256sum joininbox-amd64-debian-11.5.qcow2.gz > joininbox-amd64-debian-11.5.qcow2.gz.sha256
