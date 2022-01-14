# vim: ft=make syntax=make softtabstop=2 tabstop=2 shiftwidth=2 fenc=utf-8 expandtab

PWD ?= $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
ifeq ($(UNAME),Darwin)
	SHELL := /opt/local/bin/bash
	OS_X  := true
else ifneq (,$(wildcard /etc/redhat-release))
	OS_RHEL := true
else
	OS_DEB  := true
	SHELL := /bin/bash
endif
bold := $(shell tput bold)
sgr0 := $(shell tput sgr0)
THIS_FILE := $(firstword $(MAKEFILE_LIST))
SELF_DIR := $(dir $(THIS_FILE))
PROJECT_NAME := $(notdir $(CURDIR))
SUBMODULES:=$(notdir $(patsubst %/,%,$(dir $(wildcard ./*/Makefile))))

#  ────────────────────────────────────────────────────────────────────
.DEFAULT_GOAL := default
# ────────────────────────────────────────────────────────────────────────────────
.PHONY: $(shell egrep -o '^[a-zA-Z_-]+:' $(MAKEFILE_LIST) | sed 's/://')
.SILENT: $(shell egrep -o '^[a-zA-Z_-]+:' $(MAKEFILE_LIST) | sed 's/://')
default:
	@$(MAKE) --no-print-directory -f $(MAKEFILE_LIST) $(shell \
		awk -F':' \
		'/^[a-zA-Z0-9][^$$#\/\t=]*:([^=]|$$)/ \
		{\
			split($$1,A,/ /);\
			for(i in A)\
			print A[i]\
		}' $(MAKEFILE_LIST) \
		| sort -u \
		| fzf ; \
	)

# Add the following 'help' target to your Makefile
# And add help text after each target name starting with '\#\#'
help:			## Show this help
	@printf "$$(fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/\s.*##//')\n"

clean: 		## clean
	@echo "[INFO] Make Clean"
	[ -r ".bash.env" ] && source ".bash.env" ; terraform destroy -auto-approve && \
	rm -rf .terraform* *.tfstate.* terraform.tfstate

get:			## Get the Terraform modules.
	@echo "[INFO] Geting Terraform modules"
	[ -r ".bash.env" ] && source ".bash.env" ;terraform get

fmt:			## Format Terraform configuration files.
	@echo "[INFO] Formatting terraform configuration files"
	[ -r ".bash.env" ] && source ".bash.env" ; terraform fmt -recursive -write=true

init:			## Initialize terraform
	@echo "[INFO] Initiliazing remote state management"
	[ -r ".bash.env" ] && source ".bash.env" ; terraform init

validate:		## Validate Terraform configuration.
	@echo "[INFO] Validating terraform configuration files"
	[ -r ".bash.env" ] && source ".bash.env" ; terraform validate

plan:			## Plan changes to infrastructure.
	@echo "[INFO] Planning changes to infrastructure"
	[ -r ".bash.env" ] && source ".bash.env" ; terraform plan

refresh:		## Refresh the remote state with existing infrastructure.
	@echo "[INFO] Refreshing remote state file"
	[ -r ".bash.env" ] && source ".bash.env" ; terraform refresh

apply:			## Apply the changes in plan.
	@echo "[INFO] Applying changes"
	[ -r ".bash.env" ] && source ".bash.env" ; terraform apply -auto-approve || terraform apply -auto-approve

output:			## See the output.
	@echo "[INFO] See output"
	[ -r ".bash.env" ] && source ".bash.env" ; terraform output -json

destroy: clean		## Destroy the infrastructure.
	@echo "[INFO] Destroying infrastructure"

tflint: ## Runs essential checks with tflint.
	@echo "[INFO] Running static analysis with TFLint"
	[ -r ".bash.env" ] && source ".bash.env" ; tflint --init && tflint $(SELF_DIR)

tfsec: ## Analyze code for potential security issues with tfsec.
	@echo "[INFO] Running static analysis with TFsec"
	[ -r ".bash.env" ] && source ".bash.env" ; tfsec $(SELF_DIR)

terrascan: ## Detect compliance and security violations across Infrastructure as Code with Terrascan.
	@echo "[INFO] Running static analysis with Terrascan"
	[ -r ".bash.env" ] && source ".bash.env" ; terrascan scan -d $(SELF_DIR) -i terraform

checkov: ## Security and compliance misconfigurations analysis with Checkov using graph-based scanning.
	@echo "[INFO] Running static analysis with Checkov"
	[ -r ".bash.env" ] && source ".bash.env" ; checkov -d $(SELF_DIR) --skip-check CKV_DOCKER_* --quiet

lint: tflint tfsec terrascan checkov ## Meta target for running all static analysis and linter targets
	@echo "[INFO] Deploying Terraform"

run: get fmt init validate plan refresh apply output	## Meta target for running all deployment related targets.
	@echo "[INFO] Deploying Terraform"
