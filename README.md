# mysql-k8s-demo

A demo of running MySQL with a large dataset using dotmesh and  Kubernetes.

You will need a `kubectl` running against a running cluster with [dotmesh installed](https://docs.dotmesh.com/install-setup/kubernetes/).

## run app

First - create the namespace:

```bash
kubectl create ns mysql-k8s-demo
```

Deploy manifests:

```bash
kubectl apply -f manifests
```

Insert initial data:

```bash
export LOADER_POD=$(kubectl get pod -l app=loader -n mysql-k8s-demo -o name | sed 's/pods\///')
kubectl exec -ti -n mysql-k8s-demo $LOADER_POD bash create-data.sql
```

Add additional data:

```bash
kubectl exec -ti -n mysql-k8s-demo $LOADER_POD bash add-data.sql
```

