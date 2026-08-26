FROM quay.io/fedora/fedora-bootc:44 AS builder

RUN KERNEL_VERSION="$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')" && \
    dnf5 -y install "kernel-devel-${KERNEL_VERSION}" wget && \
    wget -O /etc/yum.repos.d/fedora-nvidia.repo https://negativo17.org/repos/fedora-nvidia.repo && \
    dnf5 install -y nvidia-driver nvidia-driver-cuda && \
    akmods --force --kernels "$KERNEL_VERSION"

FROM quay.io/fedora/fedora-bootc:44 AS final

COPY --from=builder /etc/yum.repos.d/fedora-nvidia.repo /etc/yum.repos.d/

COPY --from=builder /var/cache/akmods/nvidia/kmod-nvidia*.rpm /tmp/nvidia/

COPY 10-nvidia-args.toml nvidia-power.conf nvidia_packages /tmp/sysconfig/

RUN kver="$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')" && \
    dnf5 -y install --setopt=tsflags=nodocs "kernel-modules-extra-${kver}" && \
    dnf5 download --destdir=/tmp/nvidia nvidia-kmod-common nvidia-driver-cuda && \
    rpm -vi --nodeps /tmp/nvidia/nvidia-kmod-common*.rpm && \
    rpm -vi --nodeps /tmp/nvidia/nvidia-driver-cuda*.rpm && \
    mv -v /tmp/sysconfig/10-nvidia-args.toml /usr/lib/bootc/kargs.d/10-nvidia-args.toml && \
    mv -v /tmp/sysconfig/nvidia-power.conf /etc/modprobe.d/ && \
    grep -v '^#' /tmp/sysconfig/nvidia_packages | tr '\n' ' ' | xargs dnf5 install --setopt=tsflags=nodocs -y && \
    dnf5 -y install /tmp/nvidia/kmod-nvidia-*.rpm && \
    rm -rf /tmp/nvidia && \
    dnf5 clean all && \
    rm -rf /var/lib/dnf/* /var/log/* /tmp/* /var/tmp/* /var/cache/*

RUN bootc container lint
