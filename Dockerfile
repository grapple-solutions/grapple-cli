
FROM ubuntu:latest

RUN apt-get update && \
    apt-get install build-essential curl file git ruby-full locales sudo snapd --no-install-recommends -y && \
    rm -rf /var/lib/apt/lists/*

RUN localedef -i en_US -f UTF-8 en_US.UTF-8

RUN useradd -m -s /bin/bash linuxbrew && \
    echo 'linuxbrew ALL=(ALL) NOPASSWD:ALL' >>/etc/sudoers

USER linuxbrew
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install.sh)"

USER root
ENV PATH="/home/linuxbrew/.linuxbrew/bin:${PATH}"

USER linuxbrew
ENV OSTYPE darwin23.0

RUN brew install gum kubectl helm && brew cleanup --prune=all

# non-mandatory installation of tools to speed up the usage of the CLI in the image...
RUN brew tap civo/tools && brew install civo && brew cleanup --prune=all
RUN brew install jq yq && brew cleanup --prune=all
 
# ARG GRAPPLE_CLI_VERSION=0.2.63
ARG HOMEBREW_GITHUB_API_TOKEN=""
ARG GRAPPLE_CLI_VERSION
RUN export HOMEBREW_GITHUB_API_TOKEN=${HOMEBREW_GITHUB_API_TOKEN} && brew tap grapple-solutions/grapple && brew install grapple-cli && brew cleanup --prune=all

#RUN grpl version

# USER root

