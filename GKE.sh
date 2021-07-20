#!/bin/sh
echo "run gcloud config set project <projectname> beforehand"

#setting up variables 
REGION=us-central1
ZONE=${REGION}-b
PROJECT=$(gcloud config get-value project)
CLUSTER=gke-load-test
TARGET=${PROJECT}.appspot.com
SCOPE="https://www.googleapis.com/auth/cloud-platform"

#information for overwritting cluster nomenclature below 

#Trying with custom version
git clone https://github.com/ImmLearning/GKE-locust.git
cd GKE-locust

#creating the GKE cluster 
gcloud container clusters create $CLUSTER \
   --zone $ZONE \
   --scopes $SCOPE \
   --enable-autoscaling --min-nodes "3" --max-nodes "10" \
#   --enable-autoscaling --min-nodes "$1" --max-nodes "$2" \
   --scopes=logging-write,storage-ro \
   --addons HorizontalPodAutoscaling,HttpLoadBalancing
   
#connecting to the cluster 
gcloud container clusters get-credentials $CLUSTER \
   --zone $ZONE \
   --project $PROJECT
   
#building the docker image 
gcloud builds submit \
    --tag gcr.io/$PROJECT/locust-tasks:latest docker-image

#checking if tagged and present 
gcloud container images list | grep locust-tasks

#deploying sample application on docker engine 
gcloud app deploy sample-webapp/app.yaml \
  --project=$PROJECT
  
#Replace the target host and project ID with the deployed endpoint and project ID in the locust-master-controller.yaml and locust-worker-controller.yaml files
sed -i -e "s/\[TARGET_HOST\]/$TARGET/g" kubernetes-config/locust-master-controller.yaml
sed -i -e "s/\[TARGET_HOST\]/$TARGET/g" kubernetes-config/locust-worker-controller.yaml
sed -i -e "s/\[PROJECT_ID\]/$PROJECT/g" kubernetes-config/locust-master-controller.yaml
sed -i -e "s/\[PROJECT_ID\]/$PROJECT/g" kubernetes-config/locust-worker-controller.yaml

#Deploying locust master and worker nodes 
kubectl apply -f kubernetes-config/locust-master-controller.yaml
kubectl apply -f kubernetes-config/locust-master-service.yaml
kubectl apply -f kubernetes-config/locust-worker-controller.yaml

#verifying the deployments and services 
kubectl get pods -o wide
kubectl get deployments 
kubectl get services

#running loop watch for max 120 sec to assign - ext ip 
timeout -k 120 60 kubectl get svc locust-master --watch

#getting external Ip attached and echo it 
EXTERNAL_IP=$(kubectl get svc locust-master -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
echo "locust external ip below"
echo $EXTERNAL_IP

   