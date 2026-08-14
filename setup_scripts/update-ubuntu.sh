#
# Ubuntu specific update steps, sourced from update-add.sh
#
# sudo will prompt for a password unless LABTAINER_SUDO_PASSWORD is set,
# which is intended only for unattended builds of Labtainer VM images.
#
labtainer_sudo() {
    if [[ -n "$LABTAINER_SUDO_PASSWORD" ]]; then
        echo "$LABTAINER_SUDO_PASSWORD" | sudo -S "$@"
    else
        sudo "$@"
    fi
}
#
# Get the sudo credential with a visible prompt, the subsequent sudo commands
# suppress their output and would otherwise appear to hang.
#
labtainer_prime_sudo() {
    if sudo -n true 2>/dev/null; then
        return 0
    fi
    if [[ -n "$LABTAINER_SUDO_PASSWORD" ]]; then
        echo "$LABTAINER_SUDO_PASSWORD" | sudo -S -v
    else
        echo "The Labtainers update installs packages, please provide your password below."
        sudo -v
    fi
}
#
# Wait for other package managers (e.g., unattended upgrades) to release the
# dpkg lock rather than deleting the lock and risking a corrupt package database.
#
wait_dpkg_lock() {
    local waited=0
    local max_wait=300
    labtainer_prime_sudo || return 1
    while [[ $waited -lt $max_wait ]]; do
        if ! sudo -n fuser /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
            return 0
        fi
        if [[ $waited -eq 0 ]]; then
            echo "Waiting for another package manager to release the dpkg lock..."
        fi
        sleep 5
        waited=$((waited + 5))
    done
    echo "The dpkg lock is still held after $max_wait seconds, another package"
    echo "manager may be running.  Please try the update again later."
    return 1
}
labtainer_apt_get() {
    wait_dpkg_lock || return 1
    labtainer_sudo env DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 "$@"
}
labtainer_apt_get update || return 1
# msc ubuntu breakage
labtainer_apt_get install -y --reinstall libappstream4 || return 1
labtainer_apt_get update || return 1
if [ ! -d "$HOME/headless-labtainers" ]; then
    labtainer_apt_get install -y containerd || return 1
fi
#---Use virtual python environment to avoid Ubuntu lockdown
if [ ! -d /opt/labtainer/venv/bin ]; then
    haspip3=$(dpkg -l python3-pip)
    if [ -z "$haspip3" ]; then
        echo "Need to install python3-pip package, will sudo apt-get"
        labtainer_apt_get install -y python3-pip || return 1
    fi
    labtainer_apt_get install -y python3-venv || return 1
    labtainer_sudo mkdir -p /opt/labtainer/venv || return 1
    labtainer_sudo python3 -m venv /opt/labtainer/venv || return 1
    labtainer_sudo ln -s /opt/labtainer/venv/bin/python /opt/labtainer/python3 || return 1
    #-- downgrade requests and urllib packages due to docker python module bug
    labtainer_sudo /opt/labtainer/venv/bin/python3 -m pip install 'requests<2.29.0' 'urllib3<2.0' || return 1
    labtainer_sudo /opt/labtainer/venv/bin/python3 -m pip install netaddr parse python-dateutil docker || return 1
fi
return 0
