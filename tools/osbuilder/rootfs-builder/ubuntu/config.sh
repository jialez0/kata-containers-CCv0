# Copyright (c) 2018 Yash Jain, 2022 IBM Corp.
#
# SPDX-License-Identifier: Apache-2.0

OS_NAME=ubuntu
# This should be Ubuntu's code name, e.g. "focal" (Focal Fossa) for 20.04
OS_VERSION=${OS_VERSION:-focal}
PACKAGES="chrony iptables"
[ "$AGENT_INIT" = no ] && PACKAGES+=" init"
[ "$KATA_BUILD_CC" = yes ] && PACKAGES+=" cryptsetup-bin e2fsprogs"
[ "$SECCOMP" = yes ] && PACKAGES+=" libseccomp2"
[ "$SKOPEO" = yes ] && PACKAGES+=" libgpgme11"
REPO_URL=http://ports.ubuntu.com

case "$ARCH" in
	aarch64) DEB_ARCH=arm64;;
	ppc64le) DEB_ARCH=ppc64el;;
	s390x) DEB_ARCH="$ARCH";;
	x86_64) DEB_ARCH=amd64; REPO_URL=http://archive.ubuntu.com/ubuntu;;
	*) die "$ARCH not supported"
esac

if [ "${AA_KBC}" == "eaa_kbc" ] && [ "${ARCH}" == "x86_64" ]; then
	PACKAGES+=" apt git cmake make"
	AA_KBC_EXTRAS="
RUN apt-get update; \
    apt-get install -y dialog apt-utils; \
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections; \
    apt-get install -y -q;\
    apt-get install -y g++ gcc pkgconf libprotobuf-c1 build-essential automake autoconf libtool wget libssl-dev cmake; \
	mkdir /sgx_debian_local_repo_ubuntu20.04; \
	git clone https://github.com/jialez0/sgx_debian_local_repo_ubuntu20.04 /sgx_debian_local_repo_ubuntu20.04; \
	echo 'deb [trusted=yes arch=amd64] file:///sgx_debian_local_repo_ubuntu20.04 focal main' >> /etc/apt/sources.list; \
	apt-get update; \
	apt-get install -y --no-install-recommends libsgx-urts libsgx-dcap-default-qpl libtdx-attest libtdx-attest-dev libsgx-dcap-quote-verify-dev; \
	ln -s /usr/lib/x86_64-linux-gnu/libtdx_attest.so.1.14.100.3 /usr/lib/libtdx_attest.so; \
	mkdir /rats-tls; \
	git clone -b 2022-poc https://github.com/jialez0/rats-tls /rats-tls; \
	cd /rats-tls; \
	cmake -DRATS_TLS_BUILD_MODE=\"tdx\" -DBUILD_SAMPLES=on -H. -Bbuild; \
	make -C build install
"
fi

if [ "$(uname -m)" != "$ARCH" ]; then
	case "$ARCH" in
		ppc64le) cc_arch=powerpc64le;;
		x86_64) cc_arch=x86-64;;
		*) cc_arch="$ARCH"
	esac
	export CC="$cc_arch-linux-gnu-gcc"
fi
