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
set -euo pipefail

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# Set Terraform and Script Roots

TERRAFORM_ROOT="${ROOT}/terraform/security"
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
project_id						= "${PROJECT}"
zone									= "${ZONE}"
region								= "${REGION}"
governance_project_id	= "${GOVERNANCE_PROJECT}"
cluster_name					= "${CLUSTER_TYPE}-endpoint-cluster"
EOF
