#!/bin/sh
#how to execute this command run as below line no 3 - without the comment offcourse - da 
#wget -O - https://raw.githubusercontent.com/ImmLearning/GCP/main/GKE.sh | bash


echo "run gcloud config set project <projectname> beforehand"
echo "set these variables beforehand the region and the cluster name REGION=us-central1;ZONE=${REGION}-b;CLUSTER=gke-load-testv8;TARGET=${PROJECT}.appspot.com and SCOPE"

#setting up variables 
#REGION=us-central1
#ZONE=${REGION}-b
#ZONE=${REGION}-b
PROJECT=$(gcloud config get-value project)
#CLUSTER=gke-load-testv5
#TARGET=${PROJECT}.appspot.com
#SCOPE="https://www.googleapis.com/auth/cloud-platform"

#information for overwritting cluster nomenclature below 

#Trying with custom version
git clone https://github.com/ImmLearning/GKE-locust.git
cd GKE-locust

#creating the GKE cluster 
gcloud container clusters create $CLUSTER \
   --zone $ZONE \
   --scopes $SCOPE \
#   --enable-autoscaling --min-nodes "3" --max-nodes "10" \
   --enable-autoscaling --min-nodes "$1" --max-nodes "$2" \
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
#if already deployed then no need to redeploy as its just a sample application
#gcloud --quiet app deploy sample-webapp/app.yaml \
#  --project=$PROJECT
  
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
#echo $EXTERNAL_IP
echo "${EXTERNAL_IP}:8089"
echo "open above IP in browser and start load test"

   
