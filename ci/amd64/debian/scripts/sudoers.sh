#!/bin/sh -eux

# Only add the secure path line if it is not already present
grep -q 'secure_path' /etc/sudoers \
  || sed -i -e '/Defaults\s\+env_reset/a Defaults\tsecure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' /etc/sudoers;

# Set up password-less sudo for the joinmarket user
echo 'joinmarket ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/99_joinmarket;
chmod 440 /etc/sudoers.d/99_joinmarket;
