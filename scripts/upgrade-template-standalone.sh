#!/usr/bin/bash

# Frédéric Pierret (fepitre) frederic.pierret@qubes-os.org
# Exit codes:
# 0: OK
# 1: General errors
# 2: Unsupported distribution
# 3: Upgrade failed

set -ex

if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run with root permissions" 
   exit 1
fi

if [ -e /etc/fedora-release ]; then
    releasever="$(awk '{print $3}' /etc/fedora-release)"
    # Check Fedora supported release
    if [ "$releasever" -lt 37 ]; then
        exit 2
    fi
    # Backup R4.1 repository file
    cp /etc/yum.repos.d/qubes-r4.repo /etc/yum.repos.d/qubes-r4.repo.bak
    # We don't have $releasever into so manually replace it
    sed -i 's/r4.1/r4.2/g' /etc/yum.repos.d/qubes-r4.repo
    sed -i 's/4-primary/4.2-primary/g' /etc/yum.repos.d/qubes-r4.repo
    # Ensure DNF cache is cleaned
    dnf clean all
    # Run upgrade
    if ! dnf distro-sync -y --best --allowerasing; then
        exit 3
    fi
    dnf swap -y --allowerasing pulseaudio pipewire-pulseaudio

elif [ -e /etc/debian_version ]; then
    releasever="$(awk -F'.' '{print $1}' /etc/debian_version)"
    # Check Debian supported release
    if [ "$releasever" -lt 11 ]; then
        exit 2
    fi
    # Backup R4.1 repository file
    cp /etc/apt/sources.list.d/qubes-r4.list /etc/apt/sources.list.d/qubes-r4.list.bak
    # We don't have $releasever into so manually replace it
    sed -i 's/r4.1/r4.2/g' /etc/apt/sources.list.d/qubes-r4.list
    sed -i 's/arch=amd64/arch=amd64\ signed-by=\/usr\/share\/keyrings\/qubes-archive-keyring-4.2.gpg/g' /etc/apt/sources.list.d/qubes-r4.list
    export DEBIAN_FRONTEND=noninteractive
    # Ensure APT cache is cleaned
    apt-get clean
    apt-get update -o Dpkg::Options::="--force-confdef"

    # restaring qrexec-agent would interrupt the update
    cat > /usr/sbin/policy-rc.d <<EOF
#!/bin/sh
[ "\$1" = "--quiet" ] && shift
case "\$1" in
qubes-qrexec-agent.service) exit 101;; # Action forbidden by policy
*) exit 104;; # Action allowed
esac
EOF
    chmod 755 /usr/sbin/policy-rc.d
    trap "rm -f /usr/sbin/policy-rc.d" EXIT
    # Run upgrade, without installing "recommended" packages - that would
    # un-minimal an minimal template
    if ! apt-get dist-upgrade -y --no-install-recommends -o Dpkg::Options::="--force-confdef"; then
        exit 3
    fi
fi
