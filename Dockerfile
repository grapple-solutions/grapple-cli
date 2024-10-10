
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

USER root

# installing dns utils, for host package (bind)
RUN if [ "$TARGETARCH" = "arm64" ]; then apt update --allow-insecure-repositories -y && apt install -y dnsutils; fi

USER user

# install kubectl for arm64 using curl as it was not working with brew...
RUN brew install gum && \
	# installing dns utils, for host package (bind)
	if [ "$TARGETARCH" != "arm64" ]; then brew install kubectl helm bind; fi && \
	if [ "$TARGETARCH" = "arm64" ]; then curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"; chmod +x kubectl; sudo mv kubectl /usr/bin; fi && \
	if [ "$TARGETARCH" = "arm64" ]; then curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && chmod 700 get_helm.sh && ./get_helm.sh; fi && \
	brew cleanup --prune=all

# non-mandatory installation of tools to speed up the usage of the CLI in the image...
# install yq for arm64 using curl as it was not working with brew...
RUN brew tap civo/tools && brew install civo && brew cleanup --prune=all
RUN brew install jq && \
	if [ "$TARGETARCH" != "arm64" ]; then brew install yq; fi && \
	if [ "$TARGETARCH" = "arm64" ]; then curl -L https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_arm64.tar.gz | tar xz -C .; sudo mv yq_linux_arm64 /usr/bin/yq; fi && \
	brew cleanup --prune=all

# install gettext (for grpl example deploy)
RUN echo "installing gettext for grpl example deploy" && \
	if [ "$TARGETARCH" != "arm64" ]; then brew install gettext; brew cleanup --prune=all; fi && \
	if [ "$TARGETARCH" = "arm64" ]; then sudo apt-get install gettext; sudo rm -rf /var/lib/apt/lists/*; fi
 
# ARG GRAPPLE_CLI_VERSION=0.2.63
ARG HOMEBREW_GITHUB_API_TOKEN=""
ARG GRAPPLE_CLI_VERSION
RUN export HOMEBREW_GITHUB_API_TOKEN=${HOMEBREW_GITHUB_API_TOKEN} && brew tap grapple-solutions/grapple && brew install grapple-cli && brew cleanup --prune=all

#RUN grpl version

# USER root

