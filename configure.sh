#!/bin/bash
#
# Copyright 2025 Torero Dev
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
set -euo pipefail

# purpose: configure a debian container with torero, admin user, and ssh during docker build phase

check_version() {
    if [ -z "${TORERO_VERSION:-}" ]; then
        echo "error: torero_version must be set" >&2
        exit 1
    fi
    
    # check if python version is set
    if [ -z "${PYTHON_VERSION:-}" ]; then
        echo "error: python_version must be set" >&2
        exit 1
    fi
}

install_packages() {
    echo "installing dependencies..."
    apt-get update -y || { echo "failed to update package list" >&2; exit 1; }
    
    # Always install core packages
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        tzdata \
        gnupg \
        dirmngr \
        expect \
        jq \
        iputils-ping \
        iproute2 \
        net-tools \
        unzip \
        locales \
        build-essential \
        zlib1g-dev \
        libncurses5-dev \
        libgdbm-dev \
        libnss3-dev \
        libssl-dev \
        libreadline-dev \
        libffi-dev \
        libsqlite3-dev \
        vim \
        wget \
        libbz2-dev \
        || { echo "failed to install core packages" >&2; exit 1; }
        
    # only install ssh-related packages if ssh is enabled
    if [ "${ENABLE_SSH_ADMIN:-false}" = "true" ]; then
        apt-get install -y --no-install-recommends \
            openssh-server \
            sudo || { echo "failed to install SSH packages" >&2; exit 1; }
    fi
}

setup_admin_user() {
    echo "setting up admin user..."
    useradd -m -s /bin/bash admin || { echo "failed to create admin user" >&2; exit 1; }
    
    # only set password if ssh is enabled
    if [ "${ENABLE_SSH_ADMIN:-false}" = "true" ]; then
        echo "admin:admin" | chpasswd || { echo "failed to set admin password" >&2; exit 1; }
        echo "admin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/admin
        chmod 0440 /etc/sudoers.d/admin || { echo "failed to set sudoers permissions" >&2; exit 1; }
    fi
    
    mkdir -p /home/admin/data
    chown admin:admin /home/admin/data
}

configure_ssh() {
    echo "configuring ssh..."
    mkdir -p /var/run/sshd
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
    echo "PermitEmptyPasswords no" >> /etc/ssh/sshd_config
    echo "LoginGraceTime 120" >> /etc/ssh/sshd_config
    
    mkdir -p /home/admin/.ssh
    chmod 700 /home/admin/.ssh
    touch /home/admin/.ssh/authorized_keys
    chmod 600 /home/admin/.ssh/authorized_keys
    chown -R admin:admin /home/admin/.ssh
    
    ssh-keygen -A
}

configure_locale() {
    echo "configuring locale..."
    
    # set up locale
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    locale-gen
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
    
    # add to environment
    echo "export LANG=en_US.UTF-8" >> /etc/profile.d/locale.sh
    echo "export LC_ALL=en_US.UTF-8" >> /etc/profile.d/locale.sh
}

install_torero() {
    local torero_url="https://download.torero.dev/torero-v${TORERO_VERSION}-linux-amd64.tar.gz"
    local torero_tar="/tmp/torero.tar.gz"

    echo "installing torero version ${TORERO_VERSION}..."
    curl -L "$torero_url" -o "$torero_tar" || { echo "failed to download torero" >&2; exit 1; }
    tar -xzf "$torero_tar" -C /tmp || { echo "failed to extract torero" >&2; exit 1; }
    
    mv /tmp/torero /usr/local/bin/torero || { echo "failed to move torero" >&2; exit 1; }
    chmod +x /usr/local/bin/torero || { echo "failed to set torero permissions" >&2; exit 1; }
    
    # simulate eula acceptance on first run
    echo "simulating EULA acceptance for torero..."
    cat > /tmp/accept-eula.exp << 'EOF'
#!/usr/bin/expect -f
set timeout -1
spawn /usr/local/bin/torero
expect "Do you agree to the EULA? (yes/no):"
send "yes\r"
expect eof
EOF
    chmod +x /tmp/accept-eula.exp
    /tmp/accept-eula.exp || { echo "failed to simulate EULA acceptance" >&2; exit 1; }
    
    # clean up expect script
    rm -f "$torero_tar" /tmp/accept-eula.exp
    
    # verify install
    /usr/local/bin/torero version || { echo "torero installation verification failed" >&2; exit 1; }
}

# set up python with specified version
setup_python() {
    # extract major.minor version
    PYTHON_MAJOR_MINOR=$(echo "${PYTHON_VERSION}" | cut -d. -f1,2)
    
    echo "setting up python ${PYTHON_VERSION}..."
    
    # download and extract python
    cd /tmp
    wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz
    tar -xf Python-${PYTHON_VERSION}.tgz
    cd Python-${PYTHON_VERSION}
    
    # configure and install
    ./configure --enable-optimizations
    make -j $(nproc)
    make altinstall
    
    # create symlinks
    ln -sf /usr/local/bin/python${PYTHON_MAJOR_MINOR} /usr/local/bin/python3
    ln -sf /usr/local/bin/python3 /usr/local/bin/python
    ln -sf /usr/local/bin/pip${PYTHON_MAJOR_MINOR} /usr/local/bin/pip3
    ln -sf /usr/local/bin/pip3 /usr/local/bin/pip
    
    # upgrade pip and install essential packages
    python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel virtualenv
    
    # create a virtual environment for admin user
    if [ -d "/home/admin" ]; then
        mkdir -p /home/admin/.venvs
        python3 -m venv /home/admin/.venvs/default
        chown -R admin:admin /home/admin/.venvs
        
        # add activation to .bashrc
        echo 'export PATH="/home/admin/.venvs/default/bin:$PATH"' >> /home/admin/.bashrc
    fi
    
    # clean up
    cd /
    rm -rf /tmp/Python-${PYTHON_VERSION} /tmp/Python-${PYTHON_VERSION}.tgz
    
    # verify installation
    python3 --version
    pip3 --version
}

handle_torero_eula() {
    echo "pre-accepting torero EULA for admin user..."
    mkdir -p /home/admin/.torero.d
    touch /home/admin/.torero.d/.license-accepted
    chmod -R 755 /home/admin/.torero.d
    chown -R admin:admin /home/admin/.torero.d
}

cleanup() {
    echo "cleaning up..."
    apt-get clean
    apt-get autoremove -y
    rm -rf /var/lib/apt/lists/*
    rm -rf /tmp/*
}

create_manifest() {
    echo "creating version manifest..."
    mkdir -p /etc
    cat > /etc/torero-image-manifest.json << EOF
{
  "build_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "tools": {
    "torero": "${TORERO_VERSION}",
    "python": "$(python3 --version 2>&1)"
  },
  "config": {
    "ssh_enabled": "${ENABLE_SSH_ADMIN:-false}"
  }
}
EOF
}

main() {
    check_version
    install_packages
    configure_locale
    setup_admin_user
    setup_python
    
    # only configure ssh if enabled
    if [ "${ENABLE_SSH_ADMIN:-false}" = "true" ]; then
        configure_ssh
        echo "SSH admin access enabled"
    else
        echo "SSH admin access disabled"
    fi
    
    install_torero
    handle_torero_eula  # reinforces .license-accepted after initial run
    create_manifest
    cleanup
    echo "configuration complete!"
}

main