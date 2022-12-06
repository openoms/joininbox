SHELL = /bin/bash
GITHUB_USER = $(shell git remote -v | grep origin | head -1 | cut -d/ -f4)
CURRENT_BRANCH = $(shell git rev-parse --abbrev-ref HEAD)

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
