amd64-image:
	cd ci/amd64 && \
	bash packer.build.amd64.sh

	cd builds/packer-debian-11.5-amd64-qemu && \
	sha256sum debian-11.5-amd64.qcow2 > debian-11.5-amd64.qcow2.sha256

	cd builds/packer-debian-11.5-amd64-qemu && \
	gzip -v9 debian-11.5-amd64.qcow2

	cd builds/packer-debian-11.5-amd64-qemu && \
	sha256sum debian-11.5-amd64.qcow2.gz > debian-11.5-amd64.qcow2.gz.sha256
