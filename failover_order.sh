TMPFILE=$(mktemp /tmp/temporary-file.XXXXXXXX)

usage () {
	echo "Usage: $0 env current_region failover_region eg: $0 prf us-west-2 us-east-2"
	exit 1
	}

[[ $# -eq 0 ]] && usage

CURRENT_REGION=$2
FAILOVER_REGION=$3
SERVICE=order
exit_status=$?

read_config() {
configfile="./$1/failover_config.sh"
	if [ -f ${configfile} ]; then
		echo "Reading the config file $configfile..."
		source $configfile
	else
		echo "Unable to locate the config file $configfile, Exiting.."
		exit
	fi
}

#Promote Read Replica
promote_readreplica() {
        Echo "Promoting $1 Read Replica to Master DB"
        aws rds promote-read-replica-db-cluster --db-cluster-identifier $1 --region $FAILOVER_REGION
}

#Check if RDS instance is back online
db_available() {
	echo "Waiting for $1 instance to be available..."
	aws rds wait db-instance-available --db-instance-identifier $1 --region $FAILOVER_REGION
	echo "$1 is available now!!"
}

activemq_healthcheck() {
	aws elb describe-instance-health --load-balancer-name $activemqelb  --query 'InstanceStates[*].{id:InstanceId,state:State}' --region $FAILOVER_REGION --output table > ${TMPFILE}
}

activemq_bringup() {
	echo "Checking $1 ActiveMQ instance in $2 region if any instance is already in service........."
	activemq_healthcheck
	cat ${TMPFILE}
	if grep -q InService "$TMPFILE"; then
		echo "Found InService ActiveMQ instance existing already..not restarting" 
	else
		echo "Instances are out of rotation..proceeding with the restarts......"
		instance=$(aws elb describe-instance-health --load-balancer-name ep-activemq-prf1  --query 'InstanceStates[*].InstanceId' --region $FAILOVER_REGION --output text | head -1)
		echo $instance
		activemqip=$(aws ec2 describe-instances --instance-ids  $instance --query 'Reservations[].Instances[].PrivateIpAddress' --region $FAILOVER_REGION --output text)
		echo "Instances are out of rotation..proceeding with the ActiveMQ restart on instanceid:$instance IP:$activemqip......"
		ssh $activemqip "sudo service activemq restart"
		if [ $exit_status -eq 0 ]; then
			echo "Restart has been completed......waiting 45 seconds for the instance to come InService......."
			sleep 45
			activemq_healthcheck
			cat ${TMPFILE}
		else
			echo "Restart command was not successful"
		fi
	fi
}

#Convert to MultiAZ master
convertdb_multiaz() {
	echo "Converting Master DB availability to Multi-AZ"
	aws rds modify-db-instance --db-instance-identifier $1 --multi-az --apply-immediately --region $FAILOVER_REGION
}

autoscale_to1() {
    agname=`aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[*].AutoScalingGroupName[]' --region $FAILOVER_REGION | grep -i $1 | grep $2 | sed 's/\"//g' | sed 's/\,//g'`
    agcount=`echo $agname | wc -l`
    if [ $agcount -ne 1 ]; then
    echo "More than one Autoscaling Group or No Autoscaling group found in $FAILOVER_REGION, verify and scale up manually"
    else
        echo "Scaling Up $agname in $FAILOVER_REGION to 1"
        aws autoscaling update-auto-scaling-group --auto-scaling-group-name $agname --min-size 1 --max-size 1 --desired-capacity 1 --region $FAILOVER_REGION
    fi
}

autoscale_to0() {
    agname=`aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[*].AutoScalingGroupName[]' --region $CURRENT_REGION | grep -i $1 | grep $2 | sed 's/\"//g' | sed 's/\,//g'`
    agcount=`echo $agname | wc -l`
    if [ $agcount -ne 1 ]; then
    echo "More than one Autoscaling Group or No Autoscaling group found in $CURRENT_REGION, verify and scale Down manually"
    else
        echo "Scaling Down $agname to 0 in $CURRENT_REGION"
        aws autoscaling update-auto-scaling-group --auto-scaling-group-name $agname --min-size 0 --max-size 0 --desired-capacity 0 --region $CURRENT_REGION
    fi
}

#In Service Status
inservice_check () {
	for i in $elblist
	do
		echo "$i elb status:"
		aws elb describe-instance-health --load-balancer-name $i-$env  --query 'InstanceStates[*].{id:InstanceId,state:State}' --region $FAILOVER_REGION --output table
	done
	}

read_config $1
#inservice_check

#Public DNS Switch
#./failover_dns.sh $1 default public $3 orderstage1

#dns validation check using nslookup or host
#remove security group from current rds instance to prevent any new writes
#handle how to stop traffic of the existing db connections which still writes to the db

################Scaledown Current Region################
#autoscale_to0 $env searchmaster
#autoscale_to0 $env integration
#autoscale_to0 $env cmserver
#autoscale_to0 $env activemq

##########Scale Up Activemq in Failover Region##########
#autoscale_to1 $env activemq

#Manually Verify if replication is caught up in failover region cluster

#########Promotion of the DBs in Failover Region########
#promote_readreplica $epdbcluster
#promote_readreplica $activemqdbcluster
#promote_readreplica $entldbcluster

########################################################
#todo
#Reboot entitlement and epdb
#####################RDS DNS Switch#####################
#./failover_dns.sh $1 default private $3 orderstage1

######DB availability check and bring up activemq######
#db_available $activemqdbinstance
#activemq_healthcheck
#activemq_bringup
#db_available $epdbinstance
#db_available $entldbinstance

##############Scale Up the Failover region##############

#autoscale_to1 $env searchmaster
#autoscale_to1 $env integration
#autoscale_to1 $env cmserver

##################Switch Search master##################
#./failover_dns.sh $1 default private $3 orderstage2

inservice_check

#Scale down current region

#todo
#Add exit status
#cortex restack, which stage?
