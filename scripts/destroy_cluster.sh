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

# Do not set errexit as it makes partial deletes impossible
set -o nounset
set -o pipefail

# Locate the root directory
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# Set Terraform and Script Roots

TERRAFORM_ROOT="${ROOT}/terraform/cluster_build"
SCRIPT_ROOT="${ROOT}/scripts"

# shellcheck source=scripts/common.sh
source "${SCRIPT_ROOT}/common.sh"
source "${ROOT}/environment-variables"

# Tear down Terraform-managed resources and remove generated tfvars

if [ "$STATE" == gcs ]; then 
  cd ${TERRAFORM_ROOT}
	terraform init -input=false -backend-config="bucket=$BUCKET"
  terraform state rm "module.kms"
  terraform destroy -input=false -auto-approve
  rm -f "${TERRAFORM_ROOT}/terraform.tfvars"
  gsutil -m rm -r gs://$BUCKET
fi
if [ "$STATE" == local ]; then
	cd ${TERRAFORM_ROOT}
 	terraform init -input=false
 	terraform state rm "module.kms"
  terraform destroy -input=false -auto-approve
 	rm -f "${TERRAFORM_ROOT}/terraform.tfvars"
  rm -f "${TERRAFORM_ROOT}/terraform.tfstate"
fi

