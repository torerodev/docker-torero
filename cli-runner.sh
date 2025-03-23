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

# config
CONTAINER_NAME="torero-local"
IMAGE_NAME="torero-local:latest"
SSH_PORT=2222
DATA_DIR="$PWD/torero-data"
TORERO_VERSION="1.3.0"
OPENTOFU_VERSION="1.6.2"
REPO_DIR="$PWD"

# fancy colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# display usage information
usage() {
    echo -e "${BLUE}Usage:${NC} $0 [OPTIONS]"
    echo
    echo -e "${BLUE}Options:${NC}"
    echo "  --build         Build a new Docker image locally"
    echo "  --run           Run the container (builds image if it doesn't exist)"
    echo "  --ssh           SSH into the running container"
    echo "  --logs          View container logs"
    echo "  --status        Display status of the container"
    echo "  --stop          Stop the container"
    echo "  --start         Start an existing but stopped container"
    echo "  --restart       Restart the container"
    echo "  --destroy       Remove the container"
    echo "  --clean         Remove the container, image, and data directory"
    echo "  --help          Display this help message"
    echo
    echo -e "${BLUE}Configuration:${NC}"
    echo "  TORERO_VERSION=${TORERO_VERSION}"
    echo "  OPENTOFU_VERSION=${OPENTOFU_VERSION}"
    echo "  DATA_DIR=${DATA_DIR}"
    echo "  SSH_PORT=${SSH_PORT}"
    echo
    echo -e "${BLUE}Examples:${NC}"
    echo "  $0 --build --run    # Build image and run container"
    echo "  $0 --run --ssh      # Run container and SSH into it"
    echo "  $0 --clean          # Remove container, image, and data directory"
    echo
}

# build docker image
build_image() {
    echo -e "${BLUE}Building Docker image ${IMAGE_NAME}...${NC}"
    docker build -t "$IMAGE_NAME" \
        --build-arg TORERO_VERSION="$TORERO_VERSION" \
        "$REPO_DIR"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully built image: ${IMAGE_NAME}${NC}"
        return 0
    else
        echo -e "${RED}Failed to build Docker image.${NC}"
        return 1
    fi
}

# check if image exists
check_image() {
    if docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        return 0
    else
        echo -e "${YELLOW}Image ${IMAGE_NAME} does not exist.${NC}"
        return 1
    fi
}

run_container() {

    # build image if it doesn't exist
    if ! check_image; then
        echo -e "${YELLOW}Image not found, building it now...${NC}"
        build_image || return 1
    fi

    # is container already running?
    if docker ps -q --filter "name=$CONTAINER_NAME" | grep -q .; then
        echo -e "${YELLOW}Container ${CONTAINER_NAME} is already running.${NC}"
        display_container_info
        return 0
    fi

    # does container exist, but stopped?
    if docker ps -qa --filter "name=$CONTAINER_NAME" | grep -q .; then
        echo -e "${YELLOW}Container ${CONTAINER_NAME} exists but is stopped. Starting it...${NC}"
        docker start "$CONTAINER_NAME"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Container started successfully.${NC}"
            display_container_info
            return 0
        else
            echo -e "${RED}Failed to start container.${NC}"
            return 1
        fi
    fi

    # does data dir exist? if not, create
    mkdir -p "$DATA_DIR"
    echo -e "${BLUE}Created data directory at: ${DATA_DIR}${NC}"

    # run new container
    echo -e "${BLUE}Starting new Torero container with OpenTofu ${OPENTOFU_VERSION}...${NC}"
    docker run -d \
        --name "$CONTAINER_NAME" \
        -p "$SSH_PORT:22" \
        -v "$DATA_DIR:/home/admin/data" \
        -e INSTALL_OPENTOFU=true \
        -e OPENTOFU_VERSION="$OPENTOFU_VERSION" \
        "$IMAGE_NAME"

    # check if container started successfully
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Container started successfully.${NC}"
        echo -e "${BLUE}Waiting for services to initialize...${NC}"
        sleep 3
        display_container_info
        return 0
    else
        echo -e "${RED}Failed to start container.${NC}"
        return 1
    fi
}

# display container information
display_container_info() {
    local container_id=$(docker ps -q --filter name=$CONTAINER_NAME)
    
    if [ -n "$container_id" ]; then
        echo -e "${BLUE}Container ID:${NC} $container_id"
        echo -e "${BLUE}SSH access:${NC} ssh admin@localhost -p $SSH_PORT (password: admin)"
        echo -e "${BLUE}Data directory:${NC} $DATA_DIR"
        echo -e "${BLUE}OpenTofu version:${NC} $OPENTOFU_VERSION"
        echo -e "${BLUE}Container status:${NC} $(docker inspect -f '{{.State.Status}}' $CONTAINER_NAME)"
        
        # get IP of container
        local container_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $CONTAINER_NAME)
        echo -e "${BLUE}Container IP:${NC} $container_ip"
    else
        echo -e "${YELLOW}Container ${CONTAINER_NAME} is not running.${NC}"
    fi
}

# ssh to container
ssh_to_container() {
    if ! docker ps -q --filter "name=$CONTAINER_NAME" | grep -q .; then
        echo -e "${RED}Container ${CONTAINER_NAME} is not running.${NC}"
        return 1
    fi

    echo -e "${BLUE}Connecting to container via SSH...${NC}"
    ssh admin@localhost -p "$SSH_PORT"
}

# display container logs
show_logs() {
    if ! docker ps -qa --filter "name=$CONTAINER_NAME" | grep -q .; then
        echo -e "${RED}Container ${CONTAINER_NAME} does not exist.${NC}"
        return 1
    fi

    echo -e "${BLUE}Container logs:${NC}"
    docker logs "$CONTAINER_NAME"
}

# stop container
stop_container() {
    if ! docker ps -q --filter "name=$CONTAINER_NAME" | grep -q .; then
        echo -e "${YELLOW}Container ${CONTAINER_NAME} is not running.${NC}"
        return 0
    fi

    echo -e "${BLUE}Stopping container ${CONTAINER_NAME}...${NC}"
    docker stop "$CONTAINER_NAME"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Container stopped successfully.${NC}"
        return 0
    else
        echo -e "${RED}Failed to stop container.${NC}"
        return 1
    fi
}

# start container
start_container() {
    if docker ps -q --filter "name=$CONTAINER_NAME" | grep -q .; then
        echo -e "${YELLOW}Container ${CONTAINER_NAME} is already running.${NC}"
        return 0
    fi

    if ! docker ps -qa --filter "name=$CONTAINER_NAME" | grep -q .; then
        echo -e "${YELLOW}Container ${CONTAINER_NAME} does not exist. Will create new one.${NC}"
        run_container
        return $?
    fi

    echo -e "${BLUE}Starting container ${CONTAINER_NAME}...${NC}"
    docker start "$CONTAINER_NAME"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Container started successfully.${NC}"
        display_container_info
        return 0
    else
        echo -e "${RED}Failed to start container.${NC}"
        return 1
    fi
}

# destroy container
destroy_container() {
    if docker ps -q --filter "name=$CONTAINER_NAME" | grep -q .; then
        echo -e "${BLUE}Stopping container ${CONTAINER_NAME}...${NC}"
        docker stop "$CONTAINER_NAME"
    fi

    if docker ps -qa --filter "name=$CONTAINER_NAME" | grep -q .; then
        echo -e "${BLUE}Removing container ${CONTAINER_NAME}...${NC}"
        docker rm "$CONTAINER_NAME"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Container removed successfully.${NC}"
        else
            echo -e "${RED}Failed to remove container.${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}Container ${CONTAINER_NAME} does not exist.${NC}"
    fi
    
    return 0
}

# clean up
clean_environment() {
    echo -e "${BLUE}Cleaning up Torero environment...${NC}"
    
    # destroy container & remove image
    destroy_container
    
    if docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        echo -e "${BLUE}Removing image ${IMAGE_NAME}...${NC}"
        docker rmi "$IMAGE_NAME"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Image removed successfully.${NC}"
        else
            echo -e "${RED}Failed to remove image.${NC}"
        fi
    else
        echo -e "${YELLOW}Image ${IMAGE_NAME} does not exist.${NC}"
    fi
    
    # remove data directory?
    if [ -d "$DATA_DIR" ]; then
        echo -e "${YELLOW}Do you want to remove the data directory ${DATA_DIR}? [y/N]${NC}"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            echo -e "${BLUE}Removing data directory...${NC}"
            rm -rf "$DATA_DIR"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Data directory removed successfully.${NC}"
            else
                echo -e "${RED}Failed to remove data directory.${NC}"
            fi
        else
            echo -e "${BLUE}Keeping data directory.${NC}"
        fi
    fi
    
    echo -e "${GREEN}Cleanup complete.${NC}"
}

# check container status
check_status() {
    echo -e "${BLUE}Checking status for container ${CONTAINER_NAME}...${NC}"
    
    if docker ps -q --filter "name=$CONTAINER_NAME" | grep -q .; then
        echo -e "${GREEN}Container is running.${NC}"
        display_container_info
    elif docker ps -qa --filter "name=$CONTAINER_NAME" | grep -q .; then
        echo -e "${YELLOW}Container exists but is stopped.${NC}"
        echo -e "${BLUE}Container ID:${NC} $(docker ps -qa --filter name=$CONTAINER_NAME)"
        echo -e "${BLUE}Data directory:${NC} $DATA_DIR"
        echo -e "${BLUE}To start it, run:${NC} $0 --start"
    else
        echo -e "${YELLOW}Container does not exist.${NC}"
        echo -e "${BLUE}To create it, run:${NC} $0 --run"
    fi
    
    # check image
    if docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        echo -e "${GREEN}Image ${IMAGE_NAME} exists.${NC}"
        echo -e "${BLUE}Image details:${NC}"
        docker image inspect "$IMAGE_NAME" --format '{{.Id}} - Created: {{.Created}} - Size: {{.Size}} bytes'
    else
        echo -e "${YELLOW}Image ${IMAGE_NAME} does not exist.${NC}"
        echo -e "${BLUE}To build it, run:${NC} $0 --build"
    fi
}

# restart container
restart_container() {
    echo -e "${BLUE}Restarting container ${CONTAINER_NAME}...${NC}"
    
    if docker ps -qa --filter "name=$CONTAINER_NAME" | grep -q .; then
        docker restart "$CONTAINER_NAME"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Container restarted successfully.${NC}"
            display_container_info
            return 0
        else
            echo -e "${RED}Failed to restart container.${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}Container ${CONTAINER_NAME} does not exist. Creating a new one...${NC}"
        run_container
        return $?
    fi
}

# process args
if [ $# -eq 0 ]; then
    usage
    exit 0
fi

# parse args
SHOULD_BUILD=false
SHOULD_RUN=false
SHOULD_SSH=false
SHOULD_LOGS=false
SHOULD_STATUS=false
SHOULD_STOP=false
SHOULD_START=false
SHOULD_RESTART=false
SHOULD_DESTROY=false
SHOULD_CLEAN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --build)
            SHOULD_BUILD=true
            shift
            ;;
        --run)
            SHOULD_RUN=true
            shift
            ;;
        --ssh)
            SHOULD_SSH=true
            shift
            ;;
        --logs)
            SHOULD_LOGS=true
            shift
            ;;
        --status)
            SHOULD_STATUS=true
            shift
            ;;
        --stop)
            SHOULD_STOP=true
            shift
            ;;
        --start)
            SHOULD_START=true
            shift
            ;;
        --restart)
            SHOULD_RESTART=true
            shift
            ;;
        --destroy)
            SHOULD_DESTROY=true
            shift
            ;;
        --clean)
            SHOULD_CLEAN=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# logical order for actions
if [ "$SHOULD_CLEAN" = true ]; then
    clean_environment
    exit $?
fi

if [ "$SHOULD_DESTROY" = true ]; then
    destroy_container
    exit $?
fi

if [ "$SHOULD_BUILD" = true ]; then
    build_image || exit $?
fi

if [ "$SHOULD_STOP" = true ]; then
    stop_container || exit $?
fi

if [ "$SHOULD_START" = true ]; then
    start_container || exit $?
fi

if [ "$SHOULD_RESTART" = true ]; then
    restart_container || exit $?
fi

if [ "$SHOULD_RUN" = true ]; then
    run_container || exit $?
fi

if [ "$SHOULD_STATUS" = true ]; then
    check_status || exit $?
fi

if [ "$SHOULD_LOGS" = true ]; then
    show_logs || exit $?
fi

if [ "$SHOULD_SSH" = true ]; then
    ssh_to_container || exit $?
fi

# no flags, what's my status?
if [ "$SHOULD_BUILD" = false ] && [ "$SHOULD_RUN" = false ] && [ "$SHOULD_SSH" = false ] && \
   [ "$SHOULD_LOGS" = false ] && [ "$SHOULD_STATUS" = false ] && [ "$SHOULD_STOP" = false ] && \
   [ "$SHOULD_START" = false ] && [ "$SHOULD_RESTART" = false ] && [ "$SHOULD_DESTROY" = false ] && \
   [ "$SHOULD_CLEAN" = false ]; then
    check_status
fi

exit 0