#!/bin/bash

export HOSTNAME=runai.apps.ocpgpu.octopus.labs
export CLUSTER_NAME=c100

while getopts 'd:n:o:g:p:h' OPTION; do
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
    p)
      export PROJECTS=$OPTARG
      ;;
    h)
      echo "Sciprt usage: ./update_department [-d <department-name>] [-n <new-department-name>] [-g <new-gpu-count>] [-o <allow-over-quota>] [-p <projects-to-create-under-department>] [-h]
      -d The current name of the department you are looking to edit, Flag is required.
            Usage: -d mlops

      -n The new name you'd like to assign to the department, Flag is optional.
            Usage: -n new-name

      -g The new GPU quota you'd like to assign to the department, Flag is optional.
            Usage: -g 42

      -o Whether you'd like to change the over-quota permissions for the department, and what you'd like to change it to, Flag is optional.
            Usage: -o false
	           -o true
	 
      -p List of projects to create and link to this department, Projects will be created with a default of 1 GPU, Flag is optional.
            Usage: -p 'proj1 proj2 proj3'

      -h To get help and description of how to use the script, Flag is optional.
             Usage: -h

Examples:
./update_department.sh -d mlops -n mlops-new
./update_department.sh -d mlops -g 3
./update_department.sh -d mlops -o true
./update_department.sh -d mlops -p 'new-proj1 new-proj2
./update_department.sh -d mlops -n mlops-new -g 3 -o false -p 'api-new api-new-proj'"
      exit 1
      ;;
    ?)
      echo "Sciprt usage: ./update_department [-d <department-name>] [-n <new-department-name>] [-g <new-gpu-count>] [-o <allow-over-quota>] [-p <projects-to-create-under-department>] [-h]
      -d The current name of the department you are looking to edit, Flag is required.
            Usage: -d mlops

      -n The new name you'd like to assign to the department, Flag is optional.
            Usage: -n new-name

      -g The new GPU quota you'd like to assign to the department, Flag is optional.
            Usage: -g 42

      -o Whether you'd like to change the over-quota permissions for the department, and what you'd like to change it to, Flag is optional.
            Usage: -o false
                   -o true

      -p List of projects to create and link to this department, Projects will be created with a default of 1 GPU, Flag is optional.
            Usage: -p 'proj1 proj2 proj3'

      -h To get help and description of how to use the script, Flag is optional.
             Usage: -h

Examples:
./update_department.sh -d mlops -n mlops-new
./update_department.sh -d mlops -g 3
./update_department.sh -d mlops -o true
./update_department.sh -d mlops -p 'new-proj1 new-proj2
./update_department.sh -d mlops -n mlops-new -g 3 -o false -p 'api-new api-new-proj'"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"


#Validy check
[ -z "$DEPARTMENT_NAME" ] && echo "Missing -d <department-name>" && exit 1

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
  
for i in "${PROJECTS[@]}"
do
   :
   ../../project/create/create_project.sh -p $i -g 1 -d $DEPARTMENT_NAME
done
