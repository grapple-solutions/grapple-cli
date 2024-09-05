
FROM rgpeach10/brew-arm:pr-76

### old docker building process as backup
##FROM ubuntu:latest
##
##RUN apt-get update && \
##    apt-get install build-essential curl file git ruby-full locales sudo snapd --no-install-recommends -y && \
##    rm -rf /var/lib/apt/lists/*
##
##RUN localedef -i en_US -f UTF-8 en_US.UTF-8
##
##RUN useradd -m -s /bin/bash linuxbrew && \
##    echo 'linuxbrew ALL=(ALL) NOPASSWD:ALL' >>/etc/sudoers
##
##USER linuxbrew
##RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install.sh)"
##
##USER root
##ENV PATH="/home/linuxbrew/.linuxbrew/bin:${PATH}"
##
##USER linuxbrew
### end: old docker building process as backup

ARG TARGETPLATFORM
ARG TARGETARCH
ENV OSTYPE darwin23.0

# install kubectl for arm64 using curl as it was not working with brew...
RUN brew install gum && \
	if [ "$TARGETARCH" != "arm64" ]; then brew install kubectl; fi && \
	if [ "$TARGETARCH" = "arm64" ]; then curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"; chmod +x kubectl; sudo mv kubectl /usr/bin; fi && \
	brew install helm && brew cleanup --prune=all

# non-mandatory installation of tools to speed up the usage of the CLI in the image...
# install yq for arm64 using curl as it was not working with brew...
RUN brew tap civo/tools && brew install civo && brew cleanup --prune=all
RUN brew install jq && \
	if [ "$TARGETARCH" != "arm64" ]; then brew install yq; fi && \
	if [ "$TARGETARCH" = "arm64" ]; then curl -L https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_arm64.tar.gz | tar xz -C .; sudo mv yq_linux_arm64 /usr/bin/yq; fi && \
	brew cleanup --prune=all
 
# ARG GRAPPLE_CLI_VERSION=0.2.63
ARG HOMEBREW_GITHUB_API_TOKEN=""
ARG GRAPPLE_CLI_VERSION
RUN export HOMEBREW_GITHUB_API_TOKEN=${HOMEBREW_GITHUB_API_TOKEN} && brew tap grapple-solutions/grapple && brew install grapple-cli && brew cleanup --prune=all

#RUN grpl version

# USER root

