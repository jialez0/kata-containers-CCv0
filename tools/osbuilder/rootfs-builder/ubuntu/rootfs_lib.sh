# Copyright (c) 2018 Yash Jain, 2022 IBM Corp.
#
# SPDX-License-Identifier: Apache-2.0

build_rootfs() {
	local rootfs_dir=$1
	local multistrap_conf=multistrap.conf

	[ -z "$rootfs_dir" ] && die "need rootfs"
	[ "$rootfs_dir" = "/" ] && die "rootfs cannot be slash"

	# For simplicity's sake, use multistrap for foreign and native bootstraps.
	cat > "$multistrap_conf" << EOF
[General]
cleanup=true
aptsources=Ubuntu
bootstrap=Ubuntu

[Ubuntu]
source=$REPO_URL
keyring=ubuntu-keyring
suite=focal
packages=$PACKAGES $EXTRA_PKGS
EOF
	multistrap -a "$DEB_ARCH" -d "$rootfs_dir" -f "$multistrap_conf"
	rm -rf "$rootfs_dir/var/run"
	ln -s /run "$rootfs_dir/var/run"
	for file in /etc/{resolv.conf,ssl/certs/ca-certificates.crt}; do
		mkdir -p "$rootfs_dir$(dirname $file)"
		cp --remove-destination "$file" "$rootfs_dir$file"
	done

	# Reduce image size and memory footprint by removing unnecessary files and directories.
	rm -rf $rootfs_dir/usr/share/{bash-completion,bug,doc,info,lintian,locale,man,menu,misc,pixmaps,terminfo,zsh}

	if [ "${AA_KBC}" == "eaa_kbc" ] && [ "${ARCH}" == "x86_64" ]; then
		cat << EOF | chroot "$rootfs_dir"
mkdir /sgx_debian_local_repo_ubuntu20.04
git clone https://github.com/jialez0/sgx_debian_local_repo_ubuntu20.04 /sgx_debian_local_repo_ubuntu20.04
echo 'deb [trusted=yes arch=amd64] file:///sgx_debian_local_repo_ubuntu20.04 focal main' >> /etc/apt/sources.list
echo 'deb https://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse' >> /etc/apt/sources.list
apt-get update
apt-get install -y g++ gcc pkgconf libprotobuf-c1 build-essential automake autoconf libtool wget libssl-dev
apt-get install -y --no-install-recommends libsgx-urts libsgx-dcap-default-qpl libtdx-attest libtdx-attest-dev libsgx-dcap-quote-verify-dev
ln -s /usr/lib/x86_64-linux-gnu/libtdx_attest.so.1.14.100.3 /usr/lib/libtdx_attest.so
mkdir /rats-tls
git clone -b 2022-poc https://github.com/jialez0/rats-tls /rats-tls
cd /rats-tls
cmake -DRATS_TLS_BUILD_MODE="tdx" -DBUILD_SAMPLES=on -H. -Bbuild
make -C build install
EOF
	fi
}
