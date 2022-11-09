#!/bin/bash

while getopts 'p:c:r:h' OPTION; do
  case "$OPTION" in
    p)
      export RUNAI_PROJECT=$OPTARG
      ;;
    c)
      export CPU=$OPTARG
      ;;
    r)
      export RAM=$OPTARG
      ;;
    h)
	     echo "Script usage ./create_quota.sh [-p <project-name>] [-c <cpu-count>] [-r <ram-amount>] [-h]
      -p The name of the project to create a quota for, Flag is required.
             Usage: -p ofek

      -c Amount of CPUs to set the quota to be, Flag is required.
             Usage: -c 5

      -r Amount of RAM to set the quota to be, Use bit numeric values, such as Gi/Ki/Mi, Flag is required.
             Usage: -r 5Gi

      -h To get help and description of how to use the script, Flag is optional.
             Usage: -h

Examples:
./create_quota -p ofek -c 120 -r 5Gi "
      exit 1
      ;;
    ?)
      echo "Script usage ./create_quota.sh [-p <project-name>] [-c <cpu-count>] [-r <ram-amount>] [-h]
      -p The name of the project to create a quota for, Flag is required.
             Usage: -p ofek

      -c Amount of CPUs to set the quota to be, Flag is required.
             Usage: -c 5

      -r Amount of RAM to set the quota to be, Use bit numeric values, such as Gi/Ki/Mi, Flag is required.
             Usage: -r 5Gi

      -h To get help and description of how to use the script, Flag is optional. 
             Usage: -h

Examples:
./create_quota.sh -p ofek -c 120 -r 5Gi "
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

[ -z "$RUNAI_PROJECT" ] && echo "Missing -p <project-name>" && exit 1

[ -z "$CPU" ] && echo "Missing -c <cpu-count>" && exit 1

[ -z "$RAM" ] && echo "Missing -r <ram-amount>" && exit 1

oc login --token=eyJhbGciOiJSUzI1NiIsImtpZCI6Ik03cWx5VVQtQlZwMU82ajV2ZTZLRDdzanJpMC1fMEdkclFsaXFhd3VwekEifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJydW5haS1vZmVrIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6ImFwaS10b2tlbi1oNnNkbiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJhcGkiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiJkMzBiOTc4NS05MDU4LTQxYTMtYWRmZi1hYmVkNzFhYzljMjEiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6cnVuYWktb2ZlazphcGkifQ.b-cddOAAW95aL0YoaGdgWBb5hoROkQjjqZvzYPKrqBT1zc8oY0p04gzZ9nxjcUWq-B-SRON_eI_SEcoMyHu0o9pkYBDmGC-eiZ9Uu8pB7rVDtj7w767CJosljG29YINFD6GxrvU0n2pe4iR7VTimk-B8zm-hTDZjEkOvwb8EX3rHf__6XIqOZKXpEojWwf7dyobTEi1qEw7nc5i29t-1TNadlXUaNyiq5IEuwpWm_HlTRp-LnCJSz7wQX5IJQR7xV_L0pcWUX3PFZCz2zYeCBHSmXfQBnBqdx-D0lahiZriAzWSq7w__aKJi5uB7SHPd0GhDRqtxV4cWmsX8SBYG8aMhQCkB0TFnPfP9S2K9Xg-ANDAY5VomKxCff7m-nLyzxl6HbVS8X7-F8ineHpHa1FKOeY3oQkz5sgwMJxGdGoH5YYLj4lURvt04XVlfc_LRTkaWFUFDRYxrv_3aQHJakcaSRQHKKNePefaebzmgI2C00TxoUxfL1Py2Djt8pCDqRwMnUn-Z6mOAm6wZTymSVekmoqRG_GhK-T-oOE_E57e5BOlzREEOFBJ8nEmAvPJ6L4gGThygJSmOlJgONBfnXOylBpkYJ2lU1-Qq2M1ild7hAKOQCOVKZf0MALh4pS_wAXvTwut8e93FgDdAyPnFvhAGZrcAhgMYrVNdAGMoQqo --server=https://api.ocpgpu.octopus.labs:6443

TEMPLATE="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/quota.template"
QUOTA="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/quota.yaml"

cat $TEMPLATE |  envsubst > $QUOTA

oc create -f $QUOTA -n "runai-$RUNAI_PROJECT"
