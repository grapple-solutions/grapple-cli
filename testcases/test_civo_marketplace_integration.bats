#!/usr/bin/env bats

CLUSTERNAME="marketplace-test"
FAILED=false

setup() {
  SCRIPT_DIR=$(dirname "$(readlink -f "$BATS_TEST_FILENAME")")
  . "$SCRIPT_DIR/../utils/constants"
}

check_previous_test_failed() {
  if [ -f /tmp/failed_flag ]; then
    FAILED=$(cat /tmp/failed_flag) # Read the FAILED flag
  else
    FAILED=""
  fi
  if [ "$FAILED" = "true" ]; then
    skip "Previous test failed"
  fi
}

@test "Check if cluster exists" {
  rm -f /tmp/failed_flag
  run civo k8s show "$CLUSTERNAME"
  if [ "$status" -eq 0 ]; then
    run civo k8s delete "$CLUSTERNAME" -y
    if [ "$status" -ne 0 ]; then
      echo "true" > /tmp/failed_flag # Set FAILED to true
    fi
  fi
}

@test "Create the cluster" {
  check_previous_test_failed
  run civo k8s create "$CLUSTERNAME" --size=g4c.kube.small --nodes=2 --applications=traefik2-nodeport,civo-cluster-autoscaler,metrics-server,grapple-solution-framework --wait --save --switch -y
  if [ "$status" -ne 0 ]; then
    echo "true" > /tmp/failed_flag # Set FAILED to true
  fi
  [ "$status" -eq 0 ] # Ensure cluster creation succeeds
}

# Test: Wait for Grapple to be ready
@test "Wait for Grapple to be ready" {
  check_previous_test_failed
  while ! kubectl get -n grpl-system configuration.pkg.crossplane.io grpl 2>/dev/null; do
    echo -n "."
    sleep 2
  done
  sleep 5
  run kubectl wait -n grpl-system configuration.pkg.crossplane.io grpl --for condition=Healthy=True --timeout=300s
  if [ "$status" -ne 0 ]; then
    echo "true" > /tmp/failed_flag # Set FAILED to true
  fi
  [ "$status" -eq 0 ]
}

# Test: Deploy example application
@test "Deploy example application" {
  check_previous_test_failed
  if [ "$DB_MYSQL_DISCOVERY_BASED" = "" ] || [ "$EXTERNAL_DB" = "" ]; then
    echo "true" > /tmp/failed_flag
    skip "DB_MYSQL_DISCOVERY_BASED or EXTERNAL_DB is not set"
  fi
  run grpl e d --GRAS_TEMPLATE=$DB_MYSQL_DISCOVERY_BASED --DB_TYPE=$EXTERNAL_DB
  if [ "$status" -ne 0 ]; then
    echo "true" > /tmp/failed_flag # Set FAILED to true
  fi
  [ "$status" -eq 0 ]
}

# Test: Wait for example readiness
@test "Wait for example readiness" {
  check_previous_test_failed
  run kubectl rollout status -n grpl-disc-ext deploy grpl-disc-ext-gras-mysql-grapi --timeout=300s
  run kubectl rollout status -n grpl-disc-ext deploy grpl-disc-ext-gras-mysql-gruim --timeout=300s
  if [ "$status" -ne 0 ]; then
    echo "true" > /tmp/failed_flag # Set FAILED to true
  fi
  [ "$status" -eq 0 ]
}

# Test: Test the UI
@test "Test the UI" {
  check_previous_test_failed
  base_url=$(kubectl get muim -n grpl-disc-ext grpl-disc-ext-gras-mysql-gruim -o jsonpath="{.spec.remoteentry}" 2>/dev/null | awk -F/ 'OFS="/" {$NF=""; sub(/\/$/, ""); print}')
  if [[ -z "$base_url" ]]; then
    echo "true" > /tmp/failed_flag # Set FAILED to true
  fi
  [ -n "$base_url" ]

  STATUS=$(curl -o /dev/null -s -w "%{http_code}\n" "$base_url")
  if [ "$STATUS" -ne 200 ]; then
    exit 1
  fi
  [ "$STATUS" -eq 200 ]
}

# Test: Destroy the cluster
@test "Destroy the cluster" {
  check_previous_test_failed
  run civo k8s delete "$CLUSTERNAME" -y
  if [ "$status" -ne 0 ]; then
    echo "true" > /tmp/failed_flag # Set FAILED to true
  fi
  [ "$status" -eq 0 ]
}
