#!/bin/bash

export HOSTNAME=runai.apps.ocpgpu.octopus.labs
export CLUSTER_NAME=c100
export USERS='[]'
export PROJECT_GROUPS='[]'
export DEPARTMENT_NAME=default

while getopts 'p:d:g:u:t:h' OPTION; do
  case "$OPTION" in
    p)
      export PROJECT=$OPTARG
      ;;
    d)
      export DEPARTMENT_NAME=$OPTARG
      ;;
    g)
      export GPUS=$OPTARG
      ;;
    u)
      export USERS=$OPTARG
      ;;
    t) 
      export PROJECT_GROUPS=$OPTARG
      ;;
    h)
      echo "Script usage ./create_project.sh [-p <project-name>] [-d <department-name>] [-g <gpu-count>] [-u <array-of-users>] [-t <array-of-groups>] [-h]
      -p The name of the project to create, Flag is required.
             Usage: -p ofekh

      -d The name of the department to assign the project to, Flag is optional, if unset, will be default.
             Usage: -d mlops

      -g Amount of GPUs to allocate to the project, Flag is required.
             Usage: -g 5

      -u Array of users with access rights to the project, Flag is optional, if unset, will be an empty list.
             Usage: -u '[\"ofekh\"]'
	            -u '[\"ofekh\",\"tommerz\"]'

      -t Array of groups with access rights to the project, Flag is optional, if unset, will be an empty list..
             Usage: -t '[\"mlaas\"]'
                    -t '[\"mlaas\",\"splunk\"]'

      -h To get help and description of how to use the script, Flag is optional.
             Usage: -h

Examples:
./create_project.sh -p ofekh -d mlops -g 5 -u '[\"ofekh\"]' -t '[]' 
./create_project.sh -p ofekh -g 5 -u '[\"ofekh\",\"tommerz\"]' -t '[\"mlaas\",\"splunk\"]"
      exit 1
      ;;
    ?)
      echo "Script usage ./create_project.sh [-p <project-name>] [-d <department-name>] [-g <gpu-count>] [-u <array-of-users>] [-t <array-of-groups>] [-h]
      -p The name of the project to create, Flag is required.
             Usage: -p ofekh

      -d The name of the department to assign the project to, Flag is optional, if unset, will be default.
             Usage: -d mlops

      -g Amount of GPUs to allocate to the project, Flag is required.
             Usage: -g 5

      -u Array of users with access rights to the project, Flag is optional, if unset, will be an empty list.
             Usage: -u '[\"ofekh\"]'
                    -u '[\"ofekh\",\"tommerz\"]'

      -t Array of groups with access rights to the project, Flag is optional, if unset, will be an empty list.
             Usage: -t '[\"mlaas\"]'
                    -t '[\"mlaas\",\"splunk\"]'

      -h To get help and description of how to use the script, Flag is optional.
             Usage: -h

Examples:
./create_project.sh -p ofekh -d mlops -g 5 -u '[\"ofekh\"]'
./create_project.sh -p ofekh -g 5 -u '[\"ofekh\",\"tommerz\"]' -t '[\"mlaas\",\"splunk\"]"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

#Validity check
[ -z "$PROJECT" ] && echo "Missing -p <project-name>" && exit 1

[ -z "$GPUS" ] && echo "Missing -g <gpu-count>" && exit 1

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

#Get department ID by name
export DEPARTMENT_ID=$(curl -X 'GET' \
  "https://${HOSTNAME}/v1/k8s/clusters/$CLUSTER_ID/departments" \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${ACCESS_TOKEN}" \
  --insecure | jq ".[] | select(.name == \"${DEPARTMENT_NAME}\") | .id " | tr -d '"')

TEMPLATE="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/project.template"

PAYLOAD=$(cat $TEMPLATE | envsubst)

#Create a project
curl -X 'POST' \
  "https://${HOSTNAME}/v1/k8s/clusters/$CLUSTER_ID/projects" \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${ACCESS_TOKEN}" \
  --insecure \
  -d "$PAYLOAD"
