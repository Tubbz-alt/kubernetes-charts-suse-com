#!/usr/bin/env bats

load test_helper

setup() {
  if [[ "$BATS_TEST_NUMBER" -eq 1 ]]; then
    echo '# Install rsyslog server'
    pushd $BATS_TEST_DIRNAME/helpers/rsyslog-server
    kubectl create --filename="rsyslog-server-configmap.yaml","rsyslog-server-secret.yaml","rsyslog-server-deployment.yaml","rsyslog-server-service.yaml" 
    popd

    echo '# Install rsyslog logging agent'
    pushd $BATS_TEST_DIRNAME/..
    helm install . \
        --set server.protocol=tcp \
        --set logs.osSystem.enabled=true \
        --set logs.kubernetesSystem.enabled=false \
        --set logs.kubernetesControlPlane.enabled=false \
        --set logs.kubernetesUserNamespaces.enabled=false \
        --wait
    popd
  fi
}

@test "Test os system log - os/kernel" {
    local podName=`kubectl get pods --namespace=default -lapp=rsyslog-server -o jsonpath='{.items[0].metadata.name}'`
    local count=0

    until [[ $count -ge $maxRetry ]]
    do
        kubectl exec -it $podName --namespace=default -- grep -q 'os/kernel' /var/log/messages-tcp-rfc5424 && break
        count=$[$count+1]
        sleep $sleep
    done

    [[ $count -lt $maxRetry ]]
}

@test "Test os system log - os/wicked" {
    local podName=`kubectl get pods --namespace=default -lapp=rsyslog-server -o jsonpath='{.items[0].metadata.name}'`
    local count=0

    until [[ $count -ge $maxRetry ]]
    do
        kubectl exec -it $podName --namespace=default -- grep -q 'os/wicked' /var/log/messages-tcp-rfc5424 && break
        count=$[$count+1]
        sleep $sleep
    done

    [[ $count -lt $maxRetry ]]
}

@test "Test os system log - os/zypper" {
    local podName=`kubectl get pods --namespace=default -lapp=rsyslog-server -o jsonpath='{.items[0].metadata.name}'`
    local count=0

    until [[ $count -ge $maxRetry ]]
    do
        kubectl exec -it $podName --namespace=default -- grep -q 'os/zypper' /var/log/messages-tcp-rfc5424 && break
        count=$[$count+1]
        sleep $sleep
    done

    [[ $count -lt $maxRetry ]]
}

teardown() {
  if [[ "${#BATS_TEST_NAMES[@]}" -eq "$BATS_TEST_NUMBER" ]]; then
    echo '# Delete rsyslog logging agent'
    local releaseName=`helm list | grep log-agent-rsyslog | awk '{print $1}'`
    helm delete --purge $releaseName

    echo '# Delete rsyslog server'
    kubectl delete --namespace=default service rsyslog-server
    kubectl delete --namespace=default deployment rsyslog-server
    kubectl delete --namespace=default secret rsyslog-server
    kubectl delete --namespace=default configmap rsyslog-server
  fi
}
