## Summary
This repository contains the docker image for [torero](https://torero.dev), packaged in a _ready-to-use_ container with optional [OpenTofu](https://opentofu.org) installation. For more details about _torero_, visit the [official docs](https://docs.torero.dev/en/latest/).

> [!NOTE]
> For questions or _real-time_ feedback, you can connect with us directly in the [Network Automation Forum (NAF) Slack Workspace](https://networkautomationfrm.slack.com/?redir=%2Farchives%2FC075L2LR3HU%3Fname%3DC075L2LR3HU) in the **#tools-torero** channel.

## Features
- Based on [debian-slim](https://hub.docker.com/_/debian) for minimal footprint
- Includes _torero_ installed and ready to go
- Optional [OpenTofu](https://opentofu.org/) installation at runtime
- Health Check to verify functionality

## Inspiration
Managing and automating a hybrid, _multi-vendor_ infrastrcuture that encompasses _on-premises systems, private and public clouds, edge computing, and colocation environments_ poses significant challenges. How can you experiment to _learn_ without breaking things? How can you test new and innovative products like _torero_ on the test bench without friction to help in your evaluation? How do you test the behavior of changes in lower level environments before making changes to production? I use [containerlab](https://containerlab.dev/) for all of the above! This project makes it easy to insert _torero_ in your _containerlab_ topology file, connect to the container, and run your experiments -- the sky is the limit!

> [!IMPORTANT]
> This project was created for experimenting, labs, tests, and as an exercise to show what is _possible_. It was not built to run in _production_. As such, easy access via _SSH_ is provided with default _'admin:admin'_.

## Supported Tags
- `1.3.0`, `latest` - torero version 1.3.0
- additional version tags as they become available

## Usage

### Basic Usage

```bash
docker run -d -p 2222:22 torerodev/torero:1.3.0
```

### With OpenTofu _(installed at runtime)_

```bash
docker run -d -p 2222:22 \
  -e INSTALL_OPENTOFU=true \
  -e OPENTOFU_VERSION=1.9.0 \
  torerodev/torero:1.3.0
```

### Without OpenTofu

```bash
docker run -d -p 2222:22 \
  -e INSTALL_OPENTOFU=false \
  torerodev/torero:1.3.0
```

### Connecting to the container

```bash
ssh admin@localhost -p 2222
# default password: admin
```

### With Persistence

```bash
docker run -d -p 2222:22 \
  -v ./data:/home/admin/data \
  torerodev/torero:1.3.0
```

## Using with containerlab
Example containerlab topology file:

```yaml
---
name: torero-lab
topology:
  nodes:
    torero-node:
      kind: linux
      image: torerodev/torero:1.3.0
      env:
        INSTALL_OPENTOFU: "true"
        OPENTOFU_VERSION: "1.9.0"
      binds:
        - ./data:/home/admin/data
      mgmt_ipv4: 172.20.20.2
...
```

## Environment Variables

The following environment variables can be set at runtime:

| Variable | Default | Description |
|----------|---------|-------------|
| `INSTALL_OPENTOFU` | `true`  | Whether to install OpenTofu    |
| `OPENTOFU_VERSION` | `1.9.0` | Version of OpenTofu to install |

## building the image

### Building a single version

```bash
make build

# or specify version:
make build TORERO_VERSION=1.3.0
```

Building without make:

```bash
docker build -t torerodev/torero:1.3.0 \
  --build-arg TORERO_VERSION=1.3.0 .
```

### Building multiple versions

```bash
make build-all TORERO_VERSIONS="1.2.0 1.3.0"
```

## CLI runner script
Who doesn't love typing less? The _cli-runner.sh_ script provides a convenient way to run, test, and do house cleaning locally when running on your workstation. I use it for quick and dirty testing 🚀 It takes the following arguments:

```bash
# build + run
./torero-local.sh --build --run

# run and immediately ssh into container
./torero-local.sh --run --ssh

# check status
./torero-local.sh --status

# stop container
./torero-local.sh --stop

# start a stopped container
./torero-local.sh --start

# view logs
./torero-local.sh --logs

# clean up everything (will prompt before deleting local data)
./torero-local.sh --clean
```

## Software Licenses

This project incorporates the following software with their respective licenses:

- torero: refer to the [torero license](https://torero.dev/licenses/eula)
- opentofu: [mozilla public license 2.0](https://github.com/opentofu/opentofu/blob/main/LICENSE) 
- debian: [multiple licenses](https://www.debian.org/legal/licenses/)

All modifications and original code in this project are licensed under the apache license 2.0.