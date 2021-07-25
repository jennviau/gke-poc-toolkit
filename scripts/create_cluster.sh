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

# Bash safeties: exit on error, no unset variables, pipelines can't hide errors
set -o errexit
set -o pipefail
# Locate the root directory
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# Set Terraform and Script Roots

TERRAFORM_ROOT="${ROOT}/terraform/cluster_build"
SCRIPT_ROOT="${ROOT}/scripts"

# shellcheck source=scripts/common.sh
source "${SCRIPT_ROOT}/common.sh"
source "${ROOT}/environment-variables"

# Generate the variables to be used by Terraform
source "${SCRIPT_ROOT}/generate-cluster-tfvars.sh"

# Initialize and run Terraform
if [ "$STATE" == gcs ]; then
  BUCKET="${PROJECT}-${CLUSTER_TYPE}-state" 
  cat > ${TERRAFORM_ROOT}/backend.tf <<-EOF  
	terraform {
		backend "gcs" {
		}
	}
	EOF

		if [[ $(gsutil ls | grep "$BUCKET/") ]]; then
		echo "state $BUCKET exists"
		else
		gsutil mb gs://$BUCKET
		fi
	
  cd ${TERRAFORM_ROOT}  
	terraform init -input=true -backend-config="bucket=$BUCKET"
	terraform apply -input=false -auto-approve
  echo -e "BUCKET=${BUCKET}" >> ${ROOT}/environment-variables 
  GET_CREDS="$(terraform output  get_credentials)" 
  
fi
if [ "$STATE" == local ]; then
	cd ${TERRAFORM_ROOT}
 	terraform init -input=false
 	terraform apply -input=false -auto-approve
 	GET_CREDS="$(terraform output --state="${TERRAFORM_ROOT}/terraform.tfstate get_credentials")"
fi

