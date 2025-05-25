#!/bin/bash

# Uninstall all Helm releases related to Prometheus across all namespaces
echo "🔍 Searching for Prometheus-related Helm releases..."
helm list -A -o json | jq -r '.[] | select(.name | test("prometheus")) | "\(.name) \(.namespace)"' | while read release ns; do
  echo "  🔥 Uninstalling Helm release '$release' in namespace '$ns'"
  helm uninstall "$release" -n "$ns"
done

sleep 30

# Delete all resource types containing "prometheus" in the name
for TYPE in deploy svc pod pvc configmap secret statefulset daemonset replicaset serviceaccount job cronjob ingress role rolebinding; do
  echo "🔍 Checking $TYPE resources for prometheus-related names..."
  kubectl get $TYPE --all-namespaces --no-headers 2>/dev/null | grep prometheus | awk '{print $1, $2}' | while read ns name; do
    echo "  🔥 Deleting $TYPE $name in namespace $ns"
    kubectl delete $TYPE "$name" -n "$ns" --ignore-not-found
  done
done

# Delete cluster-wide roles and bindings
for TYPE in clusterrole clusterrolebinding; do
  echo "🔍 Checking $TYPE for prometheus-related names..."
  kubectl get $TYPE --no-headers 2>/dev/null | grep prometheus | awk '{print $1}' | while read name; do
    echo "  🔥 Deleting $TYPE $name"
    kubectl delete $TYPE "$name" --ignore-not-found
  done
done

# Delete webhook configurations
for TYPE in mutatingwebhookconfiguration validatingwebhookconfiguration; do
  echo "🔍 Checking $TYPE for prometheus-related names..."
  kubectl get $TYPE --no-headers 2>/dev/null | grep prometheus | awk '{print $1}' | while read name; do
    echo "  🔥 Deleting $TYPE $name"
    kubectl delete $TYPE "$name" --ignore-not-found
  done
done

#!/bin/bash

echo "🔍 Searching for Prometheus-related Helm releases..."
helm list -A -o json | jq -r '.[] | select(.name | test("prometheus")) | "\(.name) \(.namespace)"' | while read release ns; do
  echo "  🔥 Uninstalling Helm release '$release' in namespace '$ns'"
  helm uninstall "$release" -n "$ns"
done

sleep 30

for TYPE in deploy svc pod pvc configmap secret statefulset daemonset replicaset serviceaccount job cronjob ingress role rolebinding; do
  echo "🔍 Checking $TYPE resources for prometheus-related names..."
  kubectl get $TYPE --all-namespaces --no-headers 2>/dev/null | grep prometheus | awk '{print $1, $2}' | while read ns name; do
    echo "  🔥 Deleting $TYPE $name in namespace $ns"
    kubectl delete $TYPE "$name" -n "$ns" --ignore-not-found
  done
done

for TYPE in clusterrole clusterrolebinding; do
  echo "🔍 Checking $TYPE for prometheus-related names..."
  kubectl get $TYPE --no-headers 2>/dev/null | grep prometheus | awk '{print $1}' | while read name; do
    echo "  🔥 Deleting $TYPE $name"
    kubectl delete $TYPE "$name" --ignore-not-found
  done
done

for TYPE in mutatingwebhookconfiguration validatingwebhookconfiguration; do
  echo "🔍 Checking $TYPE for prometheus-related names..."
  kubectl get $TYPE --no-headers 2>/dev/null | grep prometheus | awk '{print $1}' | while read name; do
    echo "  🔥 Deleting $TYPE $name"
    kubectl delete $TYPE "$name" --ignore-not-found
  done
done

for TYPE in servicemonitor podmonitor prometheusrule alertmanager prometheus thanosruler; do
  echo "🔍 Checking $TYPE for prometheus-related names..."
  kubectl get "$TYPE" --all-namespaces --no-headers 2>/dev/null | grep prometheus | awk '{print $1, $2}' | while read ns name; do
    echo "  🔥 Deleting $TYPE $name in namespace $ns"
    kubectl delete "$TYPE" "$name" -n "$ns" --ignore-not-found
  done
done
