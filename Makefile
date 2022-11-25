arm64-rpi-image:
	# build image
	cd ci/arm64-rpi && \
	bash arm64-rpi.sh

	# Compute checksum of the raw image
	cd ci/arm64-rpi/packer-builder-arm && \
	sha256sum joininbox-arm64-rpi.img > joininbox-arm64-rpi.img.sha256

	# Compress image
	cd ci/arm64-rpi/packer-builder-arm && \
	gzip -v9 joininbox-arm64-rpi.img

	# Compute checksum of the compressed image
	cd ci/arm64-rpi/packer-builder-arm && \
	sha256sum joininbox-arm64-rpi.img.gz > joininbox-arm64-rpi.img.gz.sha256
