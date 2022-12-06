SHELL = /bin/bash
GITHUB_USER = $(shell git remote -v | grep origin | head -1 | cut -d/ -f4)
CURRENT_BRANCH = $(shell git rev-parse --abbrev-ref HEAD)

amd64-image:
	# build image
	cd ci/amd64 && \
	bash packer.build.amd64-debian.sh $(GITHUB_USER) $(CURRENT_BRANCH)

	# Compute checksum of the raw image
	cd ci/amd64/builds/joininbox-amd64-debian-11.5-qemu && \
	sha256sum joininbox-amd64-debian-11.5.qcow2 > joininbox-amd64-debian-11.5.qcow2.sha256

	# Compress image
	cd ci/amd64/builds/joininbox-amd64-debian-11.5-qemu && \
	gzip -v9 joininbox-amd64-debian-11.5.qcow2

	# Compute checksum of the compressed image
	cd ci/amd64/builds/joininbox-amd64-debian-11.5-qemu && \
	sha256sum joininbox-amd64-debian-11.5.qcow2.gz > joininbox-amd64-debian-11.5.qcow2.gz.sha256

arm64-rpi-image:
	# build image
	cd ci/arm64-rpi && \
	bash arm64-rpi.sh $(GITHUB_USER) $(CURRENT_BRANCH)

	# Compute checksum of the raw image
	cd ci/arm64-rpi && \
	sha256sum joininbox-arm64-rpi.img > joininbox-arm64-rpi.img.sha256

	# Compress image
	cd ci/arm64-rpi && \
	gzip -v9 joininbox-arm64-rpi.img

	# Compute checksum of the compressed image
	cd ci/arm64-rpi && \
	sha256sum joininbox-arm64-rpi.img.gz > joininbox-arm64-rpi.img.gz.sha256
