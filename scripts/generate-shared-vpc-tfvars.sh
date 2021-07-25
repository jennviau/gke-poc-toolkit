#!/usr/bin/env bash
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# "---------------------------------------------------------"
# "-                                                       -"
# "-  Helper script to generate terraform variables        -"
# "-  file based on gcloud defaults.                       -"
# "-                                                       -"
# "---------------------------------------------------------"

# Stop immediately if something goes wrong
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
# Set Terraform and Script Roots

TERRAFORM_ROOT="${ROOT}/terraform/shared_vpc"
SCRIPT_ROOT="${ROOT}/scripts"

source "${SCRIPT_ROOT}/common.sh"
source "${ROOT}/environment-variables"

TFVARS_FILE="${TERRAFORM_ROOT}/terraform.tfvars"

# Obtain the needed env variables. Variables are only created if they are
# currently empty. This allows users to set environment variables if they
# would prefer to do so.
#
# The - in the initial variable check prevents the script from exiting due
# from attempting to use an unset variable.

[[ -z "${REGION-}" ]] && REGION="$(gcloud config get-value compute/region)"
if [[ -z "${REGION}" ]]; then
		tput setaf 1; echo "" 1>&2
    echo $'ERROR: gcloud cli must be configured with a default region\n\nPlease set your region with \'gcloud config set compute/region REGION\'\nReplace \'REGION\' with the region name like us-west1.' 1>&2
    exit 1;
fi

[[ -z "${PROJECT-}" ]] && PROJECT="$(gcloud config get-value core/project)"
if [[ -z "${PROJECT}" ]]; then
		tput setaf 1; echo "" 1>&2
    echo $'ERROR: gcloud cli must be configured with a default Project\n\nPlease set your project with\n \'gcloud config set core/project PROJECT\'\nReplace \'PROJECT\' with the project name' 1>&2
    exit 1;
fi


# Verify Shared VPC environment variables are set
[[ -z "${SHARED_VPC_NAME-}" ]] && SHARED_VPC_NAME="$(echo $SHARED_VPC_NAME)"
if [[ -z "${SHARED_VPC_NAME}" ]]; then
		tput setaf 1; echo "" 1>&2
		echo $'ERROR: Deploying a shared VPC requires the shared VPC name to be set.\n Please set the Shared VPC name in 'environment-variables'\nAlternatively, changing the value of SHARED_VPC to false will create a standalone VPC in the service project where GKE is deployed.' 1>&2
    exit 1;
fi

[[ -z "${SHARED_VPC_SUBNET_NAME-}" ]] && SHARED_VPC_SUBNET_NAME="$(echo $SHARED_VPC_SUBNET_NAME)"
if [[ -z "${SHARED_VPC_SUBNET_NAME}" ]]; then
    tput setaf 1; echo "" 1>&2        
    	echo $'ERROR:  Creating a shared VPC requires a subnet name to be set.\n\nPlease set \'SHARED_VPC_SUBNET_NAME\' in \'environment-variables\' with the name of the subnet in the shared VPC where GKE is to be deployed.\nAlternatively, changing the value of SHARED_VPC to false will create a standalone VPC in the service project where GKE is deployed.' 1>&2
    exit 1;
fi

[[ -z "${SHARED_VPC_PROJECT_ID-}" ]] && SHARED_VPC_PROJECT_ID="$(echo $SHARED_VPC_PROJECT_ID)"
if [[ -z "${SHARED_VPC_PROJECT_ID}" ]]; then
		tput setaf 1; echo "" 1>&2
   	echo $'ERROR: Creating a shared VPC requires the shared VPC project ID to be set.\n\nPlease set \'SHARED_VPC_PROJECT_ID\' in \'environment-variables\' with the Project ID of the Shared VPC.\nAlternatively, changing the value of SHARED_VPC to false will create a standalone VPC in the service project where GKE is deployed.'
    exit 1;
fi

[[ -z "${POD_IP_RANGE_NAME-}" ]] && POD_IP_RANGE_NAME="$(echo $POD_IP_RANGE_NAME)"
if [[ -z "${POD_IP_RANGE_NAME}" ]]; then
		tput setaf 1; echo "" 1>&2
   	echo $'ERROR: Creating a shared VPC requires a secondary IP range be created on the subnet and configured with the pod IP range for the cluster.\n\nPlease set \'POD_IP_RANGE_NAME\'in \'environment-variables\' with the name of the secondary IP range created for pod IPs.\nAlternatively, changing the value of SHARED_VPC to false will create a standalone VPC in the service project where GKE is deployed.'
    exit 1;
fi

[[ -z "${SERVICE_IP_RANGE_NAME-}" ]] && SERVICE_IP_RANGE_NAME="$(echo $SERVICE_IP_RANGE_NAME)"
if [[ -z "${SERVICE_IP_RANGE_NAME}" ]]; then
		tput setaf 1; echo "" 1>&2
   	echo $'ERROR: creating a shared VPC requires a secondary IP range be created on the subnet and configured with the service IP range for the cluster\n\nPlease set \'SERVICE_IP_RANGE_NAME\'in \'environment-variables\' with the name of the secondary IP range created for service IPs.\nAlternatively, changing the value of SHARED_VPC to false will create a standalone VPC in the service project where GKE is deployed.'
    exit 1;
fi

# Verify if the target Shared VPC already exists
#  - If it does, query admin for corrective action
if [[ "$(gcloud compute networks describe $SHARED_VPC_NAME --project $SHARED_VPC_PROJECT_ID -q 2>/dev/null | grep name | sed 's/^.*: //')" =~ "$SHARED_VPC_NAME" ]]; then
		    tput setaf 1; echo "" 1>&2
        read -p $'ERROR: a shared VPC named ${SHARED_VPC_NAME} already exists in host project $SHARED_VPC_PROJECT_ID.\n\nIf this is from a previous deployment of this template, please select yes(y) to continue or no(n) to cancel and correct the issue:' yn; tput sgr0 
    case $yn in
        [Yy]* ) echo "the deployment will attempt to leverage the existing Shared VPC";exit ;;
        [Nn]* ) echo "to resolve this conflict either delete the existing Shared VPC, choose a different project/VPC name or deploy to the existing Shared VPC";exit ;;
        * ) echo "ERROR: Incorrect input. Cancelling execution";exit 1;;
    esac
else
    echo "create shared VPC" 1>&2
fi

if [[ "${STATE}" = "gcs" ]]; then
   STATE="gcs"
else
   STATE="local"
fi
# If Terraform is run without this file, the user will be prompted for values.
# This check verifies if the file exists and prompts user for deletion
# We don't want to overwrite a pre-existing tfvars file
if [[ -f "${TFVARS_FILE}" ]]
then
    while true; do
		    tput setaf 3; echo "" 1>&2
        read -p $'WARNING: Found an existing terraform.tfvars file, indicating a previous execution.\n\nThis file needs to be removed before a new deployment.\nSelect yes(y) to delete or no(n) to cancel execution: ' yn ; tput sgr0 
        case $yn in
            [Yy]* ) echo "Deleting and recreating terraform.tfvars"; rm ${TFVARS_FILE}; break;;
            [Nn]* ) echo "Cancelling execution";exit ;;
            * ) echo "Incorrect input. Cancelling execution";exit 1;;
        esac
    done
fi

# Write out all the values we gathered into a tfvars file so you don't
# have to enter the values manually
cat > ${TFVARS_FILE} <<-EOF
project_id												= "${PROJECT}"
region														= "${REGION}"
shared_vpc_name										= "${SHARED_VPC_NAME}"
shared_vpc_subnet_name						= "${SHARED_VPC_SUBNET_NAME}"
shared_vpc_project_id							= "${SHARED_VPC_PROJECT_ID}"
shared_vpc_ip_range_pods_name			= "${POD_IP_RANGE_NAME}"
shared_vpc_ip_range_services_name	= "${SERVICE_IP_RANGE_NAME}"
EOF
