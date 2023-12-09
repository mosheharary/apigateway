#!/bin/bash
LOG_DATE_FORMAT='+%Y-%m-%d_%H:%M:%S'

function itlog() {
    d=$(date ${LOG_DATE_FORMAT})    
    echo -e "${d} [INFO] $@"
}

function wtlog() {
    d=$(date ${LOG_DATE_FORMAT})    
    echo -e "${d} [WARN] $@"
}

function etlog() {
    d=$(date ${LOG_DATE_FORMAT})    
    echo -e "${d} [ERROR] $@"
}

function die() {
    d=$(date ${LOG_DATE_FORMAT})    
    echo -e "${d} [FATAL] $_last_command"
    exit 1
}

display_usage() {
  echo "Usage: $0 [-a|--apply] [-d|--destroy] --aws_key <aws_key> --aws_secret <aws_secret> --account_id <account_id> --aws_region <aws_region> --customer_name <customer_name>"
  echo "  -a, --apply     terragrunt apply"
  echo "  -d, --destroy   terragrunt destroy"
  echo "  --aws_key         AWS_ACCESS_KEY_ID or export environment AWS_ACCESS_KEY_ID"
  echo "  --aws_secret      AWS_ACCESS_KEY_ID or export environment AWS_SECRET_ACCESS_KEY"
  echo "  --account_id      the AWS account ID to use , if not set get it using aws cli"
  echo "  --aws_region      the AWS region to use , if not set use us-east-1"
  echo "  --customer_name   the customer_name to use , if not set , use: demo"
  echo "  -h|--help         Disply help"
  exit 1
}

if [ "$#" -eq 0 ]; then
  display_usage
fi

boolean_destroy=false
boolean_apply=false
account_id=""
aws_region="us-east-1"
customer_name="demo"
lock_id=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    -a|--apply)
      boolean_apply=true  
      ;;
    -d|-destroy)
      boolean_param=true
      ;;
    --aws_key)
      shift
      if [ -n "$1" ]; then
        aws_key="$1"
      else
        if [ ! -z "${AWS_ACCESS_KEY_ID}"];then
            aws_key=AWS_ACCESS_KEY_ID
        else
            etlog "Error: Missing value for parameter --aws_key or environment AWS_ACCESS_KEY_ID"
            display_usage
        fi
      fi
      ;;      
    --aws_secret)
      shift
      if [ -n "$1" ]; then
        aws_secret="$1"
      else
        if [ ! -z "${AWS_SECRET_ACCESS_KEY}"];then
            aws_secret=$AWS_SECRET_ACCESS_KEY
        else
            etlog "Error: Missing value for parameter --aws_secret or environment AWS_SECRET_ACCESS_KEY"
            display_usage
        fi
      fi
      ;;      
    --account_id)
      shift
      if [ -n "$1" ]; then
        account_id="$1"
      else
        die "Missing value for parameter --account_id"
      fi
      ;;      

    --aws_region)
      shift
      if [ -n "$1" ]; then
        aws_region="$1"
      else
        die "Missing value for parameter --aws_region"
      fi
      ;;      

    --customer_name)
      shift
      if [ -n "$1" ]; then
        customer_name="$1"
      else
        die "Missing value for parameter --customer_name"
      fi
      ;;      
    --lock_id)
      shift
      if [ -n "$1" ]; then
        lock_id="$1"
      else
        die "Missing value for parameter --lock_id"
      fi
      ;;      
    --h|-help)
      display_usage
      ;;
    *)
      echo "Error: Unknown option $1"
      display_usage
      ;;
  esac
  shift
done

terragrunt --version > /dev/null 2>&1
if [ $? -ne 0 ];then 
    die "terragrunt is not installed"
fi

terraform --version > /dev/null 2>&1
if [ $? -ne 0 ];then 
    die "terraform is not installed"
fi

if [ -z "${account_id}" ];then
    aws --version > /dev/null 2>&1
    if [ $? -ne 0 ];then 
        die "aws cli is not installed , can not get the account ID"
    fi
    jq --version > /dev/null 2>&1
    if [ $? -ne 0 ];then 
        die "jq is not installed , can not get the account ID"
    fi
fi



zip -h  > /dev/null 2>&1
if [ $? -ne 0 ];then 
    die "zip is not installed , we need it to zip the lambda file"
fi


terragrunt --version
terraform --version
jq --version

if [ -z "${account_id}" ];then
    account_id=$(aws sts get-caller-identity|jq -r .Account)
fi

itlog "Using:"
itlog "account_id=${account_id}"
itlog "aws_region=${aws_region}"
itlog "customer_name=${customer_name}"
if [ -z "${account_id}" ];then
    die "Can not get the account id"
fi

test -d ${PWD}/customers/${customer_name} && rm -rf ${PWD}/customers/${customer_name} 
cp -rf ${PWD}/customers/template ${PWD}/customers/${customer_name}
sed s/123456789/${account_id}/g -i ${PWD}/customers/${customer_name}/account.hcl 
sed s/_AWS_REGION_/${aws_region}/g -i ${PWD}/customers/${customer_name}/region.hcl
sed s/_CUSTOMER_NAME_/${customer_name}/g -i ${PWD}/customers/${customer_name}/customer.hcl

pushd $PWD
cd ./modules/apigateway
test -f hello_world_lambda.zip && rm -rf hello_world_lambda.zip
zip hello_world_lambda.zip hello_world_lambda.py

popd
pushd $PWD

cd customers/${customer_name}/staging
terragrunt init -backend=true -force-copy --terragrunt-non-interactive
if [ ! -z "${lock_id}" ];then
  terragrunt force-unlock -force ${lock_id} --terragrunt-log-level debug --terragrunt-debug
  popd
  rm -rf customers/${customer_name}
  rm -rf modules/apigateway/hello_world_lambda.zip
  exit 0
fi

terragrunt refresh

if [ "${boolean_apply}" == "true" ];then 
    terragrunt apply  -var="customer_name=${customer_name}" -auto-approve
fi

if [ "${boolean_destroy}" == "true" ];then 
    terragrunt destroy -var="customer_name=${customer_name}"
fi
popd

rm -rf customers/${customer_name}
rm -rf modules/apigateway/hello_world_lambda.zip

