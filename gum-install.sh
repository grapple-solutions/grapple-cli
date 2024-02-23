#!/bin/bash

# Ensure gum is installed: https://github.com/charmbracelet/gum

RED='\033[0;31m'
NC='\033[0m' # No Color

exit_on_interrupt() {
    echo; echo -e "${RED}Script interrupted by user. Exiting...${NC}" >&2
    exit 130
}

prompt_for_input_with_validation() {
    local prompt=$1
    local placeholder=$2
    local regex=$3
    local error_message=$4
    local default_value=$5  # Added parameter for default value
    local input=""

    while [[ ! $input =~ $regex ]]; do
        input=$(gum input --prompt "$prompt" --placeholder "$placeholder" --value "$default_value") || exit_on_interrupt
        if [[ ! $input =~ $regex ]]; then
            echo -e "${RED}$error_message${NC}" >&2
        fi
    done
    echo "$input"
}

# list of regexes used for validation
ip_regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
email_regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
dns_regex="^[A-Za-z0-9]([-A-Za-z0-9]*[A-Za-z0-9])?(\.[A-Za-z0-9]([-A-Za-z0-9]*[A-Za-z0-9])?)*\.[A-Za-z]{2,}$"
non_empty_regex=".+" 


# Prompt for GRAPPLE_DNS, CIVO_CLUSTER_ID, etc. using gum
GRAPPLE_DNS=$(prompt_for_input_with_validation "Enter GRAPPLE_DNS: " "Valid DNS name is required" "$dns_regex" "Invalid DNS name format. Please try again.") || exit $?
CIVO_CLUSTER_ID=$(prompt_for_input_with_validation "Enter CIVO_CLUSTER_ID: " "Provide an ID for the cluster" "$non_empty_regex" "Input cannot be empty.") || exit $?
CIVO_CLUSTER_NAME=$(prompt_for_input_with_validation "Enter CIVO_CLUSTER_NAME: " "Provide an name for the cluster" "$non_empty_regex" "Input cannot be empty.") || exit $?
CIVO_REGION=$(prompt_for_input_with_validation "Enter CIVO_REGION: " "Provide the region for the cluster" "$non_empty_regex" "Input cannot be empty.") || exit $?
CIVO_MASTER_IP=$(prompt_for_input_with_validation "Enter CIVO_MASTER_IP: " "Provide the IP of the master node - valide IPv4 is required" "$ip_regex" "Invalid IP address format. Please try again.") || exit $?
CIVO_EMAIL_ADDRESS=$(prompt_for_input_with_validation "Enter CIVO_EMAIL_ADDRESS: " "Provide the email address to be used - valide email address is required" "$email_regex" "Invalid email address format. Please try again.") || exit $?
GRAPPLE_VERSION=$(prompt_for_input_with_validation "Enter GRAPPLE_VERSION: " "Provide Grapple version" "$non_empty_regex" "Input cannot be empty.") || exit $? # not sure if both GRAPPLE_VERSION & VERSION are needed

NS=$(prompt_for_input_with_validation "Enter namespace: " "grapple-demo-namspace" "$non_empty_regex" "Namespace cannot be empty.") || exit $?
TESTNS=$(prompt_for_input_with_validation "Enter namespace for test case: " "grapple-test-demo-namspace: " "$non_empty_regex" "Namespace for test case cannot be empty.") || exit $?
TESTNSDB=$(prompt_for_input_with_validation "Enter namespace for test case with DB: " "grapple-testdb-demo-namspace" "$non_empty_regex" "Namespace for test case with DB cannot be empty.") || exit $?
awsregistry=$(prompt_for_input_with_validation "Enter id of the AWS registry (default: p7h7z5g3): " "Leave it empty if you want to use default value: 'p7h7z5g3'" "$non_empty_regex" "AWS registry ID cannot be empty." "p7h7z5g3") || exit $?
VERSION=$(prompt_for_input_with_validation "Enter version of the grapple solution framework: " "Semver version is expected. Default value if empty: 0.2.0" "$non_empty_regex" "Version cannot be empty." "0.2.0") || exit $?

# The script then proceeds to dynamically generate values-override.yaml with user inputs
cat <<EOF > ./values-override.yaml
# Default values for grsf-init.

clusterdomain: ${GRAPPLE_DNS}.grapple-demo.com

# Configuration
config:
  clusterdomain: ${GRAPPLE_DNS}.grapple-demo.com
  grapiversion: "0.0.1"
  gruimversion: "0.0.1"
  ssl: "true"
  sslissuer: "letsencrypt-grapple-demo"
  CIVO_CLUSTER_ID: ${CIVO_CLUSTER_ID}
  CIVO_CLUSTER_NAME: ${CIVO_CLUSTER_NAME}
  CIVO_REGION: ${CIVO_REGION}
  CIVO_EMAIL_ADDRESS: ${CIVO_EMAIL_ADDRESS}
  CIVO_MASTER_IP: ${CIVO_MASTER_IP}
  GRAPPLE_DNS: ${GRAPPLE_DNS}
  GRAPPLE_VERSION: ${GRAPPLE_VERSION}
# Additional configurations omitted for brevity
EOF

cat ./values-override.yaml

# Use gum to confirm before proceeding
gum confirm "Proceed with deployment using the values above?" || exit


# Define helm_deploy function with version selection via gum
helm_deploy() {
    i=$1
    v=$(gum choose --header "Select version for $i" "latest" "stable" "custom" --selected "custom")
    if [ "$v" == "custom" ]; then
      v=$(gum input --placeholder "Enter custom version for $i")
    fi
    version="--version ${v}"

    echo "Deploying $i with version $version"
    helm upgrade --install $i oci://public.ecr.aws/${awsregistry}/$i -n ${NS} ${version} --create-namespace -f ./values-override.yaml
}

kubectl run grpl-dns-aws-route53-upsert-${GRAPPLE_DNS} --image=grpl/dns-aws-route53-upsert --env="GRAPPLE_DNS=${GRAPPLE_DNS}" --env="CIVO_MASTER_IP=${CIVO_MASTER_IP}" --restart=Never

echo 
echo ----

helm_deploy grsf-init 

if gum confirm "Deploy grsf-init?"; then
    helm_deploy grsf-init
fi

echo "wait for cert-manager to be ready"
if helm get -n kube-system notes traefik >/dev/null 2>&1; then 
    CRD=Middleware && echo "wait for $CRD to be deployed:" && until kubectl explain $CRD >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "$CRD deployed"
fi
if kubectl get deploy -n grpl-system grsf-init-cert-manager >/dev/null 2>&1; then 
    kubectl wait deployment -n ${NS} grsf-init-cert-manager --for condition=Available=True --timeout=300s
    CRD=ClusterIssuer && echo "wait for $CRD to be deployed:" && until kubectl explain $CRD >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "$CRD deployed"
fi

# remove the DNS job again
kubectl delete po grpl-dns-aws-route53-upsert-${GRAPPLE_DNS} 

echo "wait for crossplane to be ready"
if kubectl get deploy -n grpl-system crossplane >/dev/null 2>&1; then 
    CRD=Provider && echo "wait for $CRD to be deployed:" && until kubectl explain $CRD >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "$CRD deployed"
fi

echo "wait for external-secrets to be ready"
if kubectl get deploy -n grpl-system grsf-init-external-secrets-webhook >/dev/null 2>&1; then 
    CRD=ExternalSecrets && echo "wait for $CRD to be deployed:" && until kubectl explain $CRD >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "$CRD deployed"
    echo "wait for external-secrets to be ready"
    kubectl wait deployment -n ${NS} grsf-init-external-secrets-webhook --for condition=Available=True --timeout=300s
fi 


echo 
echo ----
echo "Ready for grsf deployment"

if gum confirm "Deploy grsf?"; then
    helm_deploy grsf
fi

echo "wait for providerconfigs to be ready"
sleep 10
if kubectl get -n ${NS} $(kubectl get deploy -n ${NS} -o name | grep provider-civo) >/dev/null 2>&1; then 
    kubectl wait -n ${NS} provider.pkg.crossplane.io/provider-civo --for condition=Healthy=True --timeout=300s
    echo "wait for provider-civo to be ready"
    CRD=providerconfigs.civo.crossplane.io  && echo "wait for $CRD to be deployed:" && until kubectl explain $CRD >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "$CRD deployed"
fi 

for i in $(kubectl get pkg -n ${NS} -o name); do 
    kubectl wait -n ${NS} $i --for condition=Healthy=True --timeout=300s;
done
if kubectl get -n ${NS} $(kubectl get deploy -n ${NS} -o name | grep provider-helm) >/dev/null 2>&1; then 
    CRD=providerconfigs.helm.crossplane.io  && echo "wait for $CRD to be deployed:" && until kubectl explain $CRD >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "$CRD deployed"
fi 
if kubectl get -n ${NS} $(kubectl get deploy -n ${NS} -o name | grep provider-kubernetes) >/dev/null 2>&1; then 
    CRD=providerconfigs.kubernetes.crossplane.io  && echo "wait for $CRD to be deployed:" && until kubectl explain $CRD >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "$CRD deployed"
fi 


echo 
echo ----

if gum confirm "Deploy grsf-config?"; then
    helm_deploy grsf-config 
fi


if gum confirm "Deploy grsf-integration?"; then
    helm_deploy grsf-integration
fi

cho 
echo ----
echo "enable ssl"
kubectl apply -f ./clusterissuer.yaml

echo "check all crossplane packages are ready"
for i in $(kubectl get pkg -o name); do kubectl wait --for=condition=Healthy $i; done

if [ "${EDITION}" = "grpl-basic-dbfile" ] || [ "${EDITION}" = "grpl-basic-all" ]; then

  echo 
  echo ----
  echo "deploy test case: dbfile"

  echo "check xrds are available"
  CRD=grapi && echo "wait for $CRD to be deployed:" && until kubectl explain $CRD >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "$CRD deployed"
  CRD=compositegrappleapis && echo "wait for $CRD to be deployed:" && until kubectl explain $CRD >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "$CRD deployed"
  CRD=composition/grapi.grsf.grpl.io && echo "wait for $CRD to be deployed:" && until kubectl get $CRD >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "$CRD deployed"
  CRD=composition/muim.grsf.grpl.io && echo "wait for $CRD to be deployed:" && until kubectl get $CRD >/dev/null 2>&1; do echo -n .; sleep 1; done && echo "$CRD deployed"

  helm upgrade --install ${TESTNS} oci://public.ecr.aws/${awsregistry}/gras-deploy -n ${TESTNS} -f ./test.yaml --create-namespace 

  while ! kubectl get po -n ${TESTNS} -l app.kubernetes.io/name=grapi 2>/dev/null | grep grapi; do echo -n .; sleep 1; done

  sleep 10

  if [ "$(kubectl get -n ${TESTNS} $(kubectl get po -n ${TESTNS} -l app.kubernetes.io/name=grapi -o name) --template '{{(index .status.initContainerStatuses 0).ready}}')" = "false" ]; then
    kubectl cp -n ${TESTNS} ./db.json $(kubectl get po -n ${TESTNS} -l app.kubernetes.io/name=grapi -o name | sed "s,pod/,,g"):/tmp/db.json -c init-db
  fi

  # wait for the grapi of the first test case to be deployed
  # while ! kubectl wait deployment -n ${TESTNS} ${TESTNS}-${TESTNS}-grapi --for condition=Progressing=True 2>/dev/null; do echo -n .; sleep 2; done

fi


if [ "${EDITION}" = "grpl-basic-db" ] || [ "${EDITION}" = "grpl-basic-all" ]; then

  curl -fsSL https://kubeblocks.io/installer/install_cli.sh | bash
  sleep 2

  if ! kbcli cluster list 2>/dev/null; then 
    kbcli kubeblocks install --set image.registry="docker.io"
  fi

  echo 
  echo ----
  echo "deploy test case: db"

  for i in $(kubectl get clusterversion -o name); do 
    kubectl get $i -o yaml | sed "s,infracreate-registry.cn-zhangjiakou.cr.aliyuncs.com,docker.io,g" | kubectl apply -f -; 
  done

  kubectl create ns ${TESTNSDB} 2>/dev/null || true

  kubectl apply -n ${TESTNSDB} -f ./db.yaml

  sleep 10 

  kubectl rollout status -n ${TESTNSDB} --watch --timeout=600s sts grappledb-mysql

  sleep 5 

  helm upgrade --install ${TESTNSDB} oci://public.ecr.aws/${awsregistry}/gras-deploy -n ${TESTNSDB} -f ./testdb.yaml --create-namespace 

  while ! kubectl get po -n ${TESTNSDB} -l app.kubernetes.io/name=grapi 2>/dev/null | grep grapi; do echo -n .; sleep 1; done

  sleep 30

  if [ "$(kubectl get -n ${TESTNSDB} $(kubectl get po -n ${TESTNSDB} -l app.kubernetes.io/name=grapi -o name) --template '{{(index .status.initContainerStatuses 0).ready}}')" = "false" ]; then
    kubectl cp -n ${TESTNSDB} ./classicmodelsid.tgz $(kubectl get po -n ${TESTNSDB} -l app.kubernetes.io/name=grapi -o name | sed "s,pod/,,g"):/tmp/classicmodelsid.tgz -c init-db
  fi

fi
