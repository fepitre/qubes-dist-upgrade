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
    if [ "$releasever" -lt 32 ]; then
        exit 2
    fi
    # Backup R4.0 repository file
    cp /etc/yum.repos.d/qubes-r4.repo /etc/yum.repos.d/qubes-r4.repo.backup
    # We don't have $releasever into so manually replace it
    sed -i 's/r4.0/r4.1/g' /etc/yum.repos.d/qubes-r4.repo
    # Ensure DNF cache is cleaned
    dnf clean all
    # Run upgrade
    if ! dnf distro-sync -y --best --allowerasing; then
        exit 3
    fi
elif [ -e /etc/debian_version ]; then
    releasever="$(awk -F'.' '{print $1}' /etc/debian_version)"
    # Check Debian supported release
    if [ "$releasever" -lt 10 ]; then
        exit 2
    fi
    # Backup R4.0 repository file
    cp /etc/apt/sources.list.d/qubes-r4.list /etc/apt/sources.list.d/qubes-r4.list.backup
    # We don't have $releasever into so manually replace it
    sed -i 's/r4.0/r4.1/g' /etc/apt/sources.list.d/qubes-r4.list
    # Ensure APT cache is cleaned
    apt clean all
    apt update
    # Run upgrade
    if ! apt dist-upgrade -y; then
        exit 3
    fi
fi
