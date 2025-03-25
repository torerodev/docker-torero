#!/bin/bash
#
# Copyright 2025 torerodev
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
set -eo pipefail

install_opentofu() {
    if [[ "${INSTALL_OPENTOFU}" == "false" ]]; then
        echo "skipping opentofu installation as INSTALL_OPENTOFU=false"
        return 0
    fi

    if command -v tofu &> /dev/null; then
        INSTALLED_VERSION=$(tofu version | grep -oP "v\K[0-9]+\.[0-9]+\.[0-9]+" | head -1)
        if [[ "${INSTALLED_VERSION}" == "${OPENTOFU_VERSION}" ]]; then
            echo "opentofu ${OPENTOFU_VERSION} is already installed"
            return 0
        else
            echo "replacing opentofu ${INSTALLED_VERSION} with ${OPENTOFU_VERSION}"
        fi
    else
        echo "installing opentofu version ${OPENTOFU_VERSION}..."
    fi

    local arch="amd64"
    local os="linux"
    local opentofu_url="https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/tofu_${OPENTOFU_VERSION}_${os}_${arch}.zip"
    local opentofu_zip="/tmp/opentofu.zip"

    curl -L "$opentofu_url" -o "$opentofu_zip" || { 
        echo "warning: failed to download opentofu v${OPENTOFU_VERSION}" >&2 
        return 1
    }
    
    mkdir -p /tmp/opentofu
    unzip -q "$opentofu_zip" -d /tmp/opentofu || { 
        echo "warning: failed to extract opentofu" >&2 
        return 1
    }
    
    mv /tmp/opentofu/tofu /usr/local/bin/tofu || { 
        echo "warning: failed to move opentofu" >&2 
        return 1
    }
    
    rm -f "$opentofu_zip"
    rm -rf /tmp/opentofu
    
    chmod +x /usr/local/bin/tofu || { 
        echo "warning: failed to set opentofu permissions" >&2 
        return 1
    }
    
    /usr/local/bin/tofu version || { 
        echo "warning: opentofu installation verification failed" >&2 
        return 1
    }

    if [ -f "/etc/torero-image-manifest.json" ]; then
        if command -v jq &> /dev/null; then
            jq ".tools.opentofu = \"${OPENTOFU_VERSION}\"" /etc/torero-image-manifest.json > /tmp/manifest.json
            mv /tmp/manifest.json /etc/torero-image-manifest.json
        else
            echo "jq not found, skipping manifest update"
        fi
    fi

    echo "opentofu ${OPENTOFU_VERSION} installation complete"
    return 0
}

configure_dns() {
    echo "configuring DNS at runtime..."
    echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" > /etc/resolv.conf
}

# check if ssh access is needed but not configured at build time
setup_ssh_runtime() {
    if [ "${ENABLE_SSH_ADMIN}" = "true" ]; then

        # check if ssh is already set up
        if [ ! -f "/etc/ssh/sshd_config" ] || ! grep -q "PermitRootLogin" /etc/ssh/sshd_config; then
            echo "SSH was not enabled at build time but requested at runtime. Installing SSH..."
            apt-get update -y
            apt-get install -y --no-install-recommends openssh-server sudo
            
            # set up admin user
            if ! id admin &>/dev/null; then
                useradd -m -s /bin/bash admin
            fi
            echo "admin:admin" | chpasswd
            echo "admin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/admin
            chmod 0440 /etc/sudoers.d/admin
            
            # configure ssh
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
            
            # update manifest
            if [ -f "/etc/torero-image-manifest.json" ] && command -v jq &> /dev/null; then
                jq '.config.ssh_enabled = "true"' /etc/torero-image-manifest.json > /tmp/manifest.json
                mv /tmp/manifest.json /etc/torero-image-manifest.json
            fi
            
            echo "SSH access enabled at runtime"
        fi
    fi
}

configure_dns
setup_ssh_runtime
install_opentofu || echo "opentofu installation failed, continuing without it"
exec "$@"