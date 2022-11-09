#!/bin/bash

export HOSTNAME=runai.apps.ocpgpu.octopus.labs
export CLUSTER_NAME=c100
export ALLOW_OVER_QUOTA=false 

while getopts 'd:g:ohp:' OPTION; do
  case "$OPTION" in
    d)
      export DEPARTMENT_NAME=$OPTARG
      ;;
    g)
      export GPUS=$OPTARG
      ;;
    o)
      ALLOW_OVER_QUOTA=true
      export MAX_GPUS=-1
      ;;
    p)
      export PROJECTS=$OPTARG
      ;;
    h)
      echo "Script usage ./create_department.sh [-d <department-name>] [-g <gpu-count>] [-o] [-h]
      -d The name of the department to create, Flag is required.
             Usage: -d mlops

      -g Amount of GPUs to allocate to the department, Flag is required.
             Usage: -g 5

      -o Add this flag to allow the department to use over-quota
             Usage: -o

      -p List of projects to create under the department, Flag is optional.
             Usage: -p 'proj1 proj2 proj3'

      -h To get help and description of how to use the script, Flag is optional.
             Usage: -h

Examples:
./create_department.sh -d mlops -g 2 -o
./create_department.sh -d mlops -g 3 -p 'proj2 proj3'"
      exit 1
      ;;
    ?)
      echo "Script usage ./create_department.sh [-d <department-name>] [-g <gpu-count>] [-o] [-h]
      -d The name of the department to create, Flag is required.
             Usage: -d mlops

      -g Amount of GPUs to allocate to the department, Flag is required.
             Usage: -g 5

      -o Add this flag to allow the department to use over-quota
             Usage: -o

      -p List of projects to create under the department, Flag is optional.
             Usage: -p 'proj1 proj2 proj3'

      -h To get help and description of how to use the script, Flag is optional.
             Usage: -h

Examples:
./create_department.sh -d mlops -g 2 -o
./create_department.sh -d mlops -g 3 -p 'proj2 proj3'"
  esac
done
shift "$(($OPTIND -1))"

#Validity check
[ -z "$DEPARTMENT_NAME" ] && echo "Missing -d <department-name>" && exit 1

[ -z "$GPUS" ] && echo "Missing -g <gpu-count>" && exit 1

[ -z "$MAX_GPUS" ] && export MAX_GPUS=$GPUS

[ -n "$PROJECTS" ] && export PROJECTS=( $PROJECTS )

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

TEMPLATE="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/department.template"

PAYLOAD=$(cat $TEMPLATE | envsubst)

#Create a department
curl -X 'POST' \
  "https://$HOSTNAME/v1/k8s/clusters/$CLUSTER_ID/departments" \
  --header 'accept: application/json' \
  --header 'Content-Type: application/json' \
  --header "Authorization: Bearer ${ACCESS_TOKEN}" \
  --insecure \
  -d "$PAYLOAD"

for i in "${PROJECTS[@]}"
do
   :
   ../../project/create/create_project.sh -p $i -g 1 -d $DEPARTMENT_NAME
done
