![Docker Version](https://img.shields.io/docker/v/torerodev/torero?sort=semver&label=Latest%20Version&color=ccff00&logo=docker&logoColor=white)
![Docker Pulls](https://img.shields.io/docker/pulls/torerodev/torero?label=Pulls&color=ccff00&logo=docker&logoColor=white)
![Docker Image Size](https://img.shields.io/docker/image-size/torerodev/torero?label=Image%20Size&color=ccff00&logo=google-cloud-storage&logoColor=white)
![Tests](https://img.shields.io/github/actions/workflow/status/torerodev/docker-torero/docker-publish.yml?branch=main&label=Tests&color=ccff00&logo=github-actions&logoColor=white)

## Summary
This repository contains the docker image for [torero](https://torero.dev), packaged in a _ready-to-use_ container with optional [OpenTofu](https://opentofu.org) installation. For more details about _torero_, visit the [official docs](https://docs.torero.dev/en/latest/).

> [!NOTE]
> For questions or _real-time_ feedback, you can connect with us directly in the [Network Automation Forum (NAF) Slack Workspace](https://networkautomationfrm.slack.com/?redir=%2Farchives%2FC075L2LR3HU%3Fname%3DC075L2LR3HU) in the **#tools-torero** channel.

## Features
- Based on [debian-slim](https://hub.docker.com/_/debian) for minimal footprint
- Includes _torero_ installed and ready to go
- Optional [OpenTofu](https://opentofu.org/) installation at runtime
- Optional SSH administration for testing convenience + labs
- Health Check to verify functionality

## Inspiration
Managing and automating a hybrid, _multi-vendor_ infrastrcuture that encompasses _on-premises systems, private and public clouds, edge computing, and colocation environments_ poses significant challenges. How can you experiment to _learn_ without breaking things? How can you test new and innovative products like _torero_ on the test bench without friction to help in your evaluation? How do you test the behavior of changes in lower level environments before making changes to production? I use [containerlab](https://containerlab.dev/) for all of the above! This project makes it easy to insert _torero_ in your _containerlab_ topology file, connect to the container, and run your experiments -- the sky is the limit!

> [!IMPORTANT]
> This project was created for experimenting, labs, tests, and as an exercise to show what is _possible_. It was not built to run in _production_.

## Getting Started
To get started you can use _docker cli_ or _docker compose_.

### docker cli
```bash
docker run -d -p 2222:22 torerodev/torero:latest
```

![docker cli](./img/docker-cli.gif)

### docker compose _(with latest OpenTofu version)_
```bash
---
services:
  torero:
    image: torerodev/torero:latest
    container_name: torero
    ports:
      - "2222:22"  # use when ENABLE_SSH_ADMIN=true
    volumes:
      - ./data:/home/admin/data
    environment:
      - ENABLE_SSH_ADMIN=true  # enable ssh admin at runtime
      - INSTALL_OPENTOFU=true  # enable OpenTofu installation at runtime
      - OPENTOFU_VERSION=1.9.0
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "torero", "version"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 5s
...
```

![docker compose](./img/docker-compose.gif)

### Connecting to the container
You can connect to the container with 'admin' when _ENABLE_SSH_ADMIN=true_ is set during runtime.

```bash
ssh admin@localhost -p 2222 # default password: admin
```

### Environment Variables
The following environment variables can be set at runtime:

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_SSH_ADMIN` | `false` | Enable SSH admin user  |
| `INSTALL_OPENTOFU` | `true`  | Install OpenTofu       |
| `OPENTOFU_VERSION` | `1.9.0` | Set OpenTofu version   |

## Using with ContainerLab
The following _topology_ file will launch a basic [Arista](https://www.arista.com/en/) cEOS _(4.33.2F)_ and _torero_ lab. Both nodes are reachable via SSH using 'admin:admin' for login.

```yaml
---
name: ceos

topology:
  nodes:
    ceos:
      kind: arista_ceos
      image: ceos:4.33.2F
    torero:
      kind: linux
      image: torerodev/torero:latest
      env:
        INSTALL_OPENTOFU: "false" # this flag skips OpenTofu installation at runtime
        ENABLE_SSH_ADMIN: "true"
      binds:
        - $PWD/data:/home/admin/data

  links:
    - endpoints: ["ceos1:eth1", "torero:eth1"]
...
```

## CLI runner script
The _cli-runner.sh_ script provides a convenient way to run, test, and do house cleaning locally when running on your workstation. I use it for quick and dirty testing 🚀

```bash
# build + run
./cli-runner.sh --build --run

# run and immediately ssh into container
./cli-runner.sh --run --ssh

# check status
./cli-runner.sh --status

# stop container
./cli-runner.sh --stop

# start a stopped container
./cli-runner.sh --start

# view logs
./cli-runner.sh --logs

# clean up everything (will prompt before deleting local data)
./cli-runner.sh --clean
```

## Software Licenses

This project incorporates the following software with their respective licenses:

- torero: refer to the [torero license](https://torero.dev/licenses/eula)
- opentofu: [mozilla public license 2.0](https://github.com/opentofu/opentofu/blob/main/LICENSE) 
- debian: [multiple licenses](https://www.debian.org/legal/licenses/)

All modifications and original code in this project are licensed under the apache license 2.0.