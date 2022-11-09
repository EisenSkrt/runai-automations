#!/bin/bash

HOSTNAME=runai.apps.ocpgpu.octopus.labs

export PROJECT_NAME=$1
export CLUSTER_NAME=$2

[ -z "$DEPARTMENT_NAME" ] && export DEPARTMENT_NAME=default 

#Aquire access token
ACCESS_TOKEN=$(curl -X POST "https://${HOSTNAME}/auth/realms/runai/protocol/openid-connect/token" \
	--header "Content-Type: application/x-www-form-urlencoded" \
	--data-urlencode "grant_type=client_credentials" \
	--data-urlencode "scope=openid" \
	--data-urlencode "reponse_type=id_token" \
	--data-urlencode "client_id=demo" \
	--data-urlencode "client_secret=95567da0-eb5f-4a5d-b22b-1f820af118af" \
	--insecure | jq ".access_token" | tr -d '"')

#Get cluster ID by name
CLUSTER_ID=$(curl -X GET \
  "https://${HOSTNAME}/v1/k8s/clusters" \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${ACCESS_TOKEN}" \
  --insecure | jq ".[0] | select(.name == \"${CLUSTER_NAME}\") | .uuid" | tr -d '"')

PROJECT_ID=$(curl -X 'GET' \
  "https://${HOSTNAME}/v1/k8s/clusters/$CLUSTER_ID/projects" \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${ACCESS_TOKEN}" \
  --insecure | jq ".[] | select(.name == \"${PROJECT_NAME}\") | .id " | tr -d '"')

curl -X 'DELETE' \
  "https://${HOSTNAME}/v1/k8s/clusters/$CLUSTER_ID/projects/$PROJECT_ID" \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${ACCESS_TOKEN}" \
  --insecure

