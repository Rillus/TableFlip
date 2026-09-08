FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# System dependencies: MySQL server (the app's datastore), Node.js 22, plus the
# git/curl/sudo tooling Cloud Agents rely on. Kept in the image because these are
# slow, stable dependencies that should not be reinstalled on every boot.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        gnupg \
        sudo \
        mysql-server \
    && install -d /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# The `ubuntu` user ships with the base image (UID 1000). Give it passwordless
# sudo so the start script can manage the MySQL service.
RUN echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu \
    && chmod 0440 /etc/sudoers.d/ubuntu

USER ubuntu
