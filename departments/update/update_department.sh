#!/bin/bash

export HOSTNAME=runai.apps.ocpgpu.octopus.labs
export CLUSTER_NAME=c100

while getopts 'd:n:o:g:' OPTION; do
  case "$OPTION" in
    d)
      export DEPARTMENT_NAME=$OPTARG
      ;;
    n)
      export NEW_NAME=$OPTARG    
      ;;
    g)
      export NEW_GPUS=$OPTARG
      ;;
    o)
      export ALLOW_OVER_QUOTA=$OPTARG
      ;;
    ?)
      echo "script usage: $(basename \$0) [-l] [-h] [-a somevalue]" >&2
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"


#Validy check
[ -z "$DEPARTMENT_NAME" ] && echo "Missing -d <department-name>" && exit 1

HOSTNAME=runai.apps.ocpgpu.octopus.labs

#Token for API
ACCESS_TOKEN=$(curl -X POST "https://${HOSTNAME}/auth/realms/runai/protocol/openid-connect/token" \
	--header "Content-Type: application/x-www-form-urlencoded" \
	--data-urlencode "grant_type=client_credentials" \
	--data-urlencode "scope=openid" \
	--data-urlencode "reponse_type=id_token" \
	--data-urlencode "client_id=demo" \
	--data-urlencode "client_secret=95567da0-eb5f-4a5d-b22b-1f820af118af" \
	--insecure | jq ".access_token" | tr -d '"')

#Get cluster ID by name:
CLUSTER_ID=$(curl -X 'GET' \
  "https://${HOSTNAME}/v1/k8s/clusters" \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${ACCESS_TOKEN}" \
  --insecure | jq ".[] | select(.name == \"${CLUSTER_NAME}\") | .uuid" | tr -d '"')

#Get department
DEPARTMENT=$(curl -X 'GET' \
  "https://${HOSTNAME}/v1/k8s/clusters/$CLUSTER_ID/departments" \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${ACCESS_TOKEN}" \
  --insecure | jq ".[] | select(.name == \"${DEPARTMENT_NAME}\")")

DEPARTMENT_ID=$(echo $DEPARTMENT | jq ".id")

#Change name
[ -z "$NEW_NAME" ] || DEPARTMENT=$(echo $DEPARTMENT | jq ".name |=\"${NEW_NAME}\" ")

#Change GPU count
OVER_QUOTA=$(echo $DEPARTMENT | jq ".resources.gpu.maxAllowed")
if [ -n "$NEW_GPUS" ]
then
	DEPARTMENT=$(echo $DEPARTMENT | jq ".deservedGpus |=${NEW_GPUS} " | jq ".resources.gpu.deserved |=${NEW_GPUS} ")
	[ $OVER_QUOTA -gt 0 ] && DEPARTMENT=$(echo $DEPARTMENT | jq ".resources.gpu.maxAllowed |=${NEW_GPUS} ")
fi

#Change over quota allowence
GPUS=$(echo $DEPARTMENT | jq ".deservedGpus")
[ "$ALLOW_OVER_QUOTA" = "true" ] && DEPARTMENT=$(echo $DEPARTMENT | jq ".resources.gpu.maxAllowed |=-1 ") 
[ "$ALLOW_OVER_QUOTA" = "false" ] && DEPARTMENT=$(echo $DEPARTMENT | jq ".resources.gpu.maxAllowed |=${GPUS} ")

echo $DEPARTMENT_ID
echo $DEPARTMENT | python3 -m json.tool


#Update a department
curl -X 'PUT' \
  "https://$HOSTNAME/v1/k8s/clusters/$CLUSTER_ID/departments/$DEPARTMENT_ID" \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${ACCESS_TOKEN}" \
  --insecure \
  -d "$DEPARTMENT"
