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

## test locally

To test the stack locally without k8s:

```bash
export MYSQL_ROOT_PASSWORD=apples
docker run --name mysql -d -e MYSQL_ROOT_PASSWORD mysql:5.6
docker run --name myadmin -e PMA_HOST=mysql -e PMA_USER=root -e PMA_PASSWORD=$MYSQL_ROOT_PASSWORD -d --link mysql:mysql -p 8080:80 phpmyadmin/phpmyadmin
docker run --name mysql-client -d --link mysql:mysql $LOADER_IMAGE
docker exec -ti mysql-client bash create-data.sh
docker exec -ti mysql-client bash add-data.sh
```

## make cluster

First we make a cluster on GKE:

```bash
gcloud auth login
gcloud config set project dotmesh-production
gcloud config set compute/region europe-west1
gcloud config set compute/zone europe-west1-b
gcloud container clusters create mysql-k8s-demo \
  --image-type=ubuntu \
  --tags=dotmesh \
  --machine-type=n1-standard-4 \
  --cluster-version=1.7.12-gke.1
```

Then we install dotmesh:

```bash
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
kubectl apply -f https://get.dotmesh.io/yaml/dotmesh-etcd-cluster.yaml
kubectl apply -f https://get.dotmesh.io/unstable/master/yaml/dotmesh-k8s-1.7.yaml
```

## deploy

Make the namespace and deploy:

```bash
kubectl create ns mysql-k8s-demo
kubectl apply -f manifests
```

Add initial data:

```bash
export LOADER_POD=$(kubectl get pod -l app=loader -n mysql-k8s-demo -o name | sed 's/pods\///')
kubectl exec -ti -n mysql-k8s-demo $LOADER_POD bash create-data.sql
```

Add new data:

```bash
kubectl exec -ti -n mysql-k8s-demo $LOADER_POD bash add-data.sql
```











