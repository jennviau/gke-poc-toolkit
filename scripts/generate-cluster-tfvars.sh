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
TERRAFORM_ROOT="${ROOT}/terraform/cluster_build"
SCRIPT_ROOT="${ROOT}/scripts"


# shellcheck source=scripts/common.sh

source "${SCRIPT_ROOT}/common.sh"
source "${ROOT}/environment-variables"

# Set Terraform Variables file

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

[[ -z "${ZONE-}" ]] && ZONE="$(gcloud config get-value compute/zone)"
if [[ -z "${ZONE}" ]]; then
    tput setaf 1; echo "" 1>&2
    echo $'ERROR: gcloud cli must be configured with a default zone\n\nPlease set your zone with \'gcloud config set compute/zone ZONE\'\nReplace \'ZONE\' with the zone name like us-west1-a.' 1>&2
    exit 1;
fi

[[ -z "${GOVERNANCE_PROJECT-}" ]] && GOVERNANCE_PROJECT="$(gcloud config get-value core/project)"
if [[ -z "${GOVERNANCE_PROJECT}" ]]; then
    tput setaf 1; echo "" 1>&2
    echo $'ERROR: This script requires a project for governance resources.\nPlease update the GOVERNANCE_PROJECT information in `environment-variables`' 1>&2
    exit 1;
fi

# This check verifies if the PUBLIC_CLUSTER boolean value has been set to true
#  - If set to true, the cluster master endpoint is exposed as a public endpoint and the bastion host is not created
#  - If not set, the boolean value defaults to false and access to the the cluster master endpoint is limited to a bastion host

[[ -z "${PUBLIC_CLUSTER-}" ]] && PUBLIC_CLUSTER="$(echo $PUBLIC_CLUSTER)"
if [[ ${PUBLIC_CLUSTER} == true ]]; then
    PRIVATE="false"
    CLUSTER_TYPE="public"
    echo $'INFO: Creating Cluster with a Public Endpoint; cluster master endpoint will be exposed as a public endpoint' 1>&2
else
    PRIVATE="true"
    CLUSTER_TYPE="private"
    echo $'INFO: Creating Cluster with a Private Endpoint; access will be limited to the bastion host' 1>&2
fi

if [[ -z ${AUTH_IP} ]] && [ "${PRIVATE}" != "true" ]; then
    tput setaf 1; echo "" 1>&2
    echo $'ERROR: Public IP Address required for Bastion Access.\nPlease set your public IP address `environment-variables' 1>&2
    exit 1
fi

# This check verifies if the WINDOWS_CLUSTER boolean value has been set to true
#  - If set to true, a Windows GKE cluster is created
#  - If not set, the boolean value defaults to false and a linux GKE cluster is created
[[ -z "${WINDOWS_CLUSTER-}" ]] && WINDOWS_CLUSTER="$(echo $WINDOWS_CLUSTER)"
if [[ ${WINDOWS_CLUSTER} == true ]]; then
    WINDOWS="true"
    echo "INFO: Creating GKE cluster with Windows Nodes" 1>&2
else
    WINDOWS="false"
    echo "INFO: Creating a GKE cluster with Linux Nodes" 1>&2
fi

# This check verifies if the PREEMPTIBLE_NODES boolean value has been set to true
#  - If set to true, deploy GKE cluster with preemptible nodes
#  - If not set, the boolean value defaults to false and the cluster deploys with traditional node types

[[ -z "${PREEMPTIBLE_NODES-}" ]] && PREEMPTIBLE_NODES="$(echo $PREEMPTIBLE_NODES)"
if [[ ${PREEMPTIBLE_NODES} == true ]]; then
    PREEMPTIBLE="true"
    echo "INFO: Creating GKE cluster with preemptible nodes" 1>&2
else
    PREEMPTIBLE="false"
fi

# This check verifies if the SHARED_VPC boolean value has been set to true
#  - If set to true, additional variables are required to deployed to an existing shared VPC
#  - If not set, the boolean value defaults to false and GKE is deployed to an standalone VPC

[[ -z "${SHARED_VPC-}" ]] && SHARED_VPC="$(echo $SHARED_VPC)"
if [[ ${SHARED_VPC} == true ]]; then
    echo "INFO: Creating GKE cluster in shared VPC ${SHARED_VPC}" 1>&2

    [[ -z "${SHARED_VPC_NAME-}" ]] && SHARED_VPC_NAME="$(echo $SHARED_VPC_NAME)"
    if [[ -z "${SHARED_VPC_NAME}" ]]; then
    	tput setaf 1; echo "" 1>&2
			echo $'ERROR: Deploying to a shared VPC requires the shared VPC name to be set.\n Please set the Shared VPC name in 'environment-variables'\nAlternatively, changing the value of SHARED_VPC to false will create a standalone VPC in the service project where GKE is deployed.' 1>&2
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
    	echo $'ERROR:  Deploying to a shared VPC requires a subnet name to be set.\n\nPlease set \'SHARED_VPC_SUBNET_NAME\' in \'environment-variables\' with the name of the subnet in the shared VPC where GKE is to be deployed.\nAlternatively, changing the value of SHARED_VPC to false will create a standalone VPC in the service project where GKE is deployed.' 1>&2
    exit 1;
fi

[[ -z "${SHARED_VPC_PROJECT_ID-}" ]] && SHARED_VPC_PROJECT_ID="$(echo $SHARED_VPC_PROJECT_ID)"
if [[ -z "${SHARED_VPC_PROJECT_ID}" ]]; then
    tput setaf 1; echo "" 1>&2
   	echo $'ERROR: Deploying to a shared VPC requires the shared VPC project ID to be set.\n\nPlease set \'SHARED_VPC_PROJECT_ID\' in \'environment-variables\' with the Project ID of the Shared VPC.\nAlternatively, changing the value of SHARED_VPC to false will create a standalone VPC in the service project where GKE is deployed.'
    exit 1;
fi

[[ -z "${POD_IP_RANGE_NAME-}" ]] && POD_IP_RANGE_NAME="$(echo $POD_IP_RANGE_NAME)"
if [[ -z "${POD_IP_RANGE_NAME}" ]]; then
    tput setaf 1; echo "" 1>&2
   	echo $'ERROR: Deploying to a shared VPC requires a secondary IP range be created on the subnet and configured with the pod IP range for the cluster.\n\nPlease set \'POD_IP_RANGE_NAME\'in \'environment-variables\' with the name of the secondary IP range created for pod IPs.\nAlternatively, changing the value of SHARED_VPC to false will create a standalone VPC in the service project where GKE is deployed.'
    exit 1;
fi

[[ -z "${SERVICE_IP_RANGE_NAME-}" ]] && SERVICE_IP_RANGE_NAME="$(echo $SERVICE_IP_RANGE_NAME)"
if [[ -z "${SERVICE_IP_RANGE_NAME}" ]]; then
    tput setaf 1; echo "" 1>&2
   	echo $'ERROR: Deploying to a shared VPC requires a secondary IP range be created on the subnet and configured with the service IP range for the cluster\n\nPlease set \'SERVICE_IP_RANGE_NAME\'in \'environment-variables\' with the name of the secondary IP range created for service IPs.\nAlternatively, changing the value of SHARED_VPC to false will create a standalone VPC in the service project where GKE is deployed.'
    exit 1;
fi

    # Verify if the target shared VPC subnet exists and we have access to it - If not, fail the test
    #  - Perform same test for both the pod and service secondary subnets
    if [ "$(gcloud compute networks subnets describe $SHARED_VPC_SUBNET_NAME --region $REGION --project $SHARED_VPC_PROJECT_ID | grep name | sed 's/^.*: //')" != "$SHARED_VPC_SUBNET_NAME" ]; then
		    tput setaf 1; echo "" 1>&2
        echo $'ERROR: Shared VPC subnet ${SHARED_VPC_SUBNET_NAME} does not exist in region ${REGION} or you do not have access.\n\nPlease resolve this issue before continuing.' 1>&2
        exit 1;
    elif [ "$(gcloud compute networks subnets describe $SHARED_VPC_SUBNET_NAME --region $REGION --project $SHARED_VPC_PROJECT_ID | grep $POD_IP_RANGE_NAME | sed 's/^.*: //')" != "$POD_IP_RANGE_NAME" ]; then
		    tput setaf 1; echo "" 1>&2
        echo $'ERROR: Secondary subnetwork ${POD_IP_RANGE_NAME} does not exist in shared VPC subnet ${SHARED_VPC_SUBNET_NAME} in region ${REGION} or you do not have access.\n\nPlease resolve this issue before continuing' 1>&2
        exit 1;
    elif [ "$(gcloud compute networks subnets describe $SHARED_VPC_SUBNET_NAME --region $REGION --project $SHARED_VPC_PROJECT_ID | grep $SERVICE_IP_RANGE_NAME | sed 's/^.*: //')" != "$SERVICE_IP_RANGE_NAME" ]; then
		    tput setaf 1; echo "" 1>&2
				echo $'ERROR: Secondary subnetwork ${SERVICE_IP_RANGE_NAME} does not exist in shared VPC subnet ${SHARED_VPC_SUBNET_NAME} in region ${REGION} or you do not have access.\n\nPlease resolve this issue before continuing' 1>&2
        exit 1;
    fi
else 
    SHARED_VPC="false"
    echo "INFO: Creating the GKE cluster in standalone VPC" 1>&2
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
	project_id 													= "${PROJECT}"
	governance_project_id               = "${GOVERNANCE_PROJECT}"
	region                              = "${REGION}"
	private_endpoint                    = "${PRIVATE}"
	cluster_name                        = "${CLUSTER_TYPE}-endpoint-cluster"
	vpc_name                            = "${CLUSTER_TYPE}-cluster-network"
	subnet_name                         = "${CLUSTER_TYPE}-cluster-subnet"
	node_pool                           = "${CLUSTER_TYPE}-node-pool"
	zone                                = "${ZONE}"
	auth_ip                             = "${AUTH_IP}"
	windows_nodepool                    = "${WINDOWS}"
	preemptible_nodes                   = "${PREEMPTIBLE}"
	shared_vpc                          = "${SHARED_VPC}"
	shared_vpc_name                     = "${SHARED_VPC_NAME}"
	shared_vpc_subnet_name              = "${SHARED_VPC_SUBNET_NAME}"
	shared_vpc_project_id               = "${SHARED_VPC_PROJECT_ID}"
	shared_vpc_ip_range_pods_name       = "${POD_IP_RANGE_NAME}"
	shared_vpc_ip_range_services_name   = "${SERVICE_IP_RANGE_NAME}"
EOF
