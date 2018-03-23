# mysql-k8s-demo

Commands to get cluster setup and run demo.

## build image

We build an image with all of the data to make it easy:

```bash
export LOADER_IMAGE="quay.io/dotmesh/mysql-k8s-demo-loader:latest"
docker build -t $LOADER_IMAGE testdb
docker login quay.io
docker push $LOADER_IMAGE
```

## make clusters

First we make some clusters:

```bash
gcloud auth login
gcloud config set project dotmesh-production
gcloud container clusters create demo-onprem \
  --image-type=ubuntu \
  --tags=dotmesh,cloud-move-demo \
  --zone=europe-west1-b \
  --num-nodes=1 \
  --machine-type=n1-standard-4 \
  --cluster-version=1.7.12-gke.1
gcloud container clusters create demo-cloud \
  --image-type=ubuntu \
  --tags=dotmesh,cloud-move-demo \
  --zone=us-east1-b \
  --num-nodes=1 \
  --machine-type=n1-standard-4 \
  --cluster-version=1.7.12-gke.1
```

Open firewalls for phpmyadmin:

```bash
gcloud compute firewall-rules create phpmyadmin-ingress \
  --allow tcp:30001 \
  --target-tags=cloud-move-demo
```

On each cluster - then we install dotmesh:

```bash
gcloud container clusters get-credentials --zone=europe-west1-b demo-onprem
gcloud container clusters get-credentials --zone=us-east1-b demo-cloud

# do this following for both clusters above

kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole cluster-admin \
  --user "$(gcloud config get-value core/account)"
export ADMIN_PASSWORD=apples
export ADMIN_API_KEY=apples
kubectl create namespace dotmesh
echo -n $ADMIN_PASSWORD > dotmesh-admin-password.txt
echo -n $ADMIN_API_KEY > dotmesh-api-key.txt
kubectl create secret generic dotmesh \
  --from-file=./dotmesh-admin-password.txt \
  --from-file=./dotmesh-api-key.txt -n dotmesh
rm -f dotmesh-admin-password.txt dotmesh-api-key.txt
kubectl apply -f https://get.dotmesh.io/yaml/etcd-operator-clusterrole.yaml
kubectl apply -f https://get.dotmesh.io/yaml/etcd-operator-dep.yaml
sleep 10
kubectl apply -f https://get.dotmesh.io/yaml/dotmesh-etcd-cluster.yaml
kubectl apply -f https://get.dotmesh.io/unstable/master/yaml/dotmesh-k8s-1.7.yaml
```

We then need to restart the kubelet - wait for everything to settle before:

```bash
gcloud container clusters get-credentials --zone=europe-west1-b demo-onprem
for node in $(kubectl get no | tail -n +2 | awk '{print $1}'); do
  gcloud compute ssh --zone=europe-west1-b $node --command "sudo systemctl restart kubelet"
done
gcloud container clusters get-credentials --zone=us-east1-b demo-cloud
for node in $(kubectl get no | tail -n +2 | awk '{print $1}'); do
  gcloud compute ssh --zone=us-east1-b $node --command "sudo systemctl restart kubelet"
done
```

## add dm remotes

Add dm remote for onprem:

```bash
export ONPREM_IP=$(gcloud container clusters get-credentials --zone=europe-west1-b demo-onprem && kubectl get no -o wide | tail -n 1 | awk '{print $6}')
export CLOUD_IP=$(gcloud container clusters get-credentials --zone=us-east1-b demo-cloud && kubectl get no -o wide | tail -n 1 | awk '{print $6}')
dm remote add onprem admin@$ONPREM_IP
dm remote add cloud admin@$CLOUD_IP
# password is apples
```

## deploy to onprem

Deploy the stack:

```bash
gcloud container clusters get-credentials --zone=europe-west1-b demo-onprem
kubectl create ns mysql-k8s-demo
kubectl apply -f manifests
```

Do an initial "empty state" commit:

```bash
dm remote switch onprem
dm commit -m "empty state"
```

Insert the initial data:

```bash
export LOADER_POD=$(kubectl get pod -l app=loader -n mysql-k8s-demo -o name | sed 's/pods\///')
kubectl exec -ti -n mysql-k8s-demo $LOADER_POD bash create-data.sh
```

View PHPMyAdmin:

```bash
open http://$ONPREM_IP:30001
```

Commit bulk data:

```bash
dm commit -m "bulk dataset"
```

Push bulk data:

```bash
dm push cloud mysql-dot
```

Check cloud volume:

```bash
dm remote switch cloud
dm list
dm remote switch onprem
```

Add secondary data:

```bash
export LOADER_POD=$(kubectl get pod -l app=loader -n mysql-k8s-demo -o name | sed 's/pods\///')
kubectl exec -ti -n mysql-k8s-demo $LOADER_POD bash add-data.sh
```

Shutdown current MySQL:

```bash
gcloud container clusters get-credentials --zone=europe-west1-b demo-onprem
kubectl delete deployment -n mysql-k8s-demo mysql
```

Commit secondary data:

```bash
dm commit -m "secondary dataset"
```

Push secondary data:

```bash
dm push cloud mysql-dot
```

Start stack on cloud:

```bash
gcloud container clusters get-credentials --zone=us-east1-b demo-cloud
kubectl create ns mysql-k8s-demo
kubectl apply -f manifests
```

Check phpmyadmin on cloud - data has arrived (with minimal downtime):

```bash
open http://$CLOUD_IP:30001
```










