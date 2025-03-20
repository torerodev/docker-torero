FROM debian:stable-slim

LABEL maintainer="torerodev <opensource@itential.com>"
LABEL org.opencontainers.image.source="https://github.com/torerodev/docker-torero"
LABEL org.opencontainers.image.description="torero docker image"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# default version
ARG TORERO_VERSION=1.3.0
ENV TORERO_VERSION=${TORERO_VERSION}

# default opentofu version (can be overridden at runtime)
ENV OPENTOFU_VERSION=1.9.0
ENV INSTALL_OPENTOFU=true

# reduce docker image size
ENV DEBIAN_FRONTEND=noninteractive

# copy scripts to image
COPY configure.sh /configure.sh
COPY entrypoint.sh /entrypoint.sh

# make executable, run configuration script
RUN chmod +x /configure.sh && /configure.sh && \
    chmod +x /entrypoint.sh

# expose ssh port
EXPOSE 22

# create volume for persistent data
VOLUME ["/home/admin/data"]

# healthcheck - is torero functional?
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD torero version || exit 1

# set entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# default command
CMD ["/usr/sbin/sshd", "-D"]