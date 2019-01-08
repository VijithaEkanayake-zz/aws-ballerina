#!bin/bash

OUTPUT_DIR=$2
echo $OUTPUT_DIR

cluster_name="ballerina-http-scenario2-try1-cluster"
retry_attempts=3
config_file=~/.kube/config
echo $retry_attempts


while [ "$STATUS" != "ACTIVE" ] && [ $retry_attempts -gt 0 ]
do
    eksctl create cluster --name "$cluster_name" --region us-east-1 --nodes-max 3 --nodes-min 1 --node-type t2.small --zones=us-east-1a,us-east-1b,us-east-1d
    if [ $? -ne 0 ]; then
         echo "Waiting for service role.."
         aws cloudformation wait stack-create-complete --stack-name=EKS-$cluster_name-ServiceRole
         echo "Waiting for vpc.."
         aws cloudformation wait stack-create-complete --stack-name=EKS-$cluster_name-VPC
         echo "Waiting for Control Plane.."
         aws cloudformation wait stack-create-complete --stack-name=EKS-$cluster_name-ControlPlane
         echo "Waiting for node-group.."
         aws cloudformation wait stack-create-complete --stack-name=EKS-$cluster_name-DefaultNodeGroup
    else
        #if the cluster creation is succesful , any existing config files are removed
        if [ -f "$config_file" ];then
            rm $config_file
        fi

        #Configure the security group of nodes to allow traffic from outside
        node_security_group=$(aws ec2 describe-security-groups --filter Name=tag:aws:cloudformation:logical-id,Values=NodeSecurityGroup --query="SecurityGroups[0].GroupId" --output=text)
        aws ec2 authorize-security-group-ingress --group-id $node_security_group --protocol tcp --port 0-65535 --cidr 0.0.0.0/0
    fi
    STATUS=$(aws eks describe-cluster --name $cluster_name --query="[cluster.status]" --output=text)
    echo "Status is "$STATUS
    retry_attempts=$(($retry_attempts-1))
    echo "attempts left : "$retry_attempts
done

#if the status is not active by this phase the cluster creation has failed, hence exiting the script in error state
if [ "$STATUS" != "ACTIVE" ];then
    echo "state is not active"
    exit 1
fi

# Check if config file exists, if it does not exist create the config file
if [ ! -f "$config_file" ];then
    echo "config file does not exist"
    eksctl utils write-kubeconfig --name $cluster_name --region us-east-1
fi

whoami
echo $HOME

echo "current context"
kubectl config current-context
echo "all available contexts"
kubectl config get-contexts
echo "view kubectl configurations"
kubectl config view

infra_properties=$OUTPUT_DIR/infrastructure.properties
testplan_properties=$OUTPUT_DIR/testplan-props.properties

echo $kube_master
echo $OUTPUT_DIR
echo "KUBERNETES_MASTER=$kube_master" > $OUTPUT_DIR/k8s.properties
echo "ClusterName=$cluster_name" >> $OUTPUT_DIR/infrastructure.properties
