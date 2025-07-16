kubectl delete sa cluster1-cluster0 -n kube-federation-system --context cluster1
kubectl delete clusterrolebinding kubefed-controller-manager:cluster1-cluster0 --context cluster1
kubectl delete sa cluster1-cluster0 -n kube-federation-system --context cluster0
kubectl delete clusterrolebinding kubefed-controller-manager:cluster1-cluster0 --context cluster0
kubectl -n kube-federation-system delete FederatedTypeConfig --all
helm --namespace kube-federation-system uninstall kubefed