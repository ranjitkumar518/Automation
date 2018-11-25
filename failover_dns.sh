#!/bin/bash

ENV=$1
AWS_PROFILE=$2
ZONE_TYPE=$3
REGION=$4
SERVICE=$5

# User Action Required: Update below ZONE_ID values as per the AWS account

if [ "$ZONE_TYPE" = "public" ]
then
    # Verify this value as Route 53 Public Hosted Zone ID of correct AWS account
    ZONE_ID="Z2UE4966K7SC50"
    DOMAIN_SUFFIX="ecom.a.abc.com"
else
    # Verify this value as Route 53 Private Hosted Zone ID of correct AWS account
    ZONE_ID="ZPHXTU1K8KPJK"
    DOMAIN_SUFFIX="ecom.a.abc.net"
fi

# More advanced options below
# The Time-To-Live of this recordset
TTL=30

# Change this if you want
COMMENT="ICP Failover to $REGION"

# Change to AAAA if using an IPv6 address
TYPE="CNAME"

LOGFILE="./$ENV/logs/failover-$ZONE_TYPE-$REGION-$ENV.log"

echo "Switching the DNS entries to $REGION in $ZONE_TYPE zone $ZONE_ID"

while read line
do
	RECORDSET=$(echo $line | awk '{split($0,a,","); print a[1]}')
	VALUE=$(echo $line | awk '{split($0,a,","); print a[2]}')

	TMPFILE=$(mktemp /tmp/temporary-file.XXXXXXXX)
    cat > ${TMPFILE} << EOF
    {
      "Comment":"$COMMENT",
      "Changes":[
        {
          "Action":"UPSERT",
          "ResourceRecordSet":{
            "ResourceRecords":[
              {
                "Value":"$VALUE"
              }
            ],
            "Name":"$RECORDSET",
            "Type":"$TYPE",
            "TTL":$TTL
          }
        }
      ]
    }
EOF

	# Update the Hosted Zone record
    aws --profile $AWS_PROFILE route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch file://"$TMPFILE" >> "$LOGFILE"

done < ./$ENV/${ZONE_TYPE}-dns-${REGION}-${ENV}-${SERVICE}.csv

echo "" >> "$LOGFILE"

echo "Triggered the DNS change, sleeping 5 seconds..."
sleep 5

echo "Validating new values of DNS entries"
aws --profile $AWS_PROFILE route53 list-resource-record-sets --hosted-zone-id $ZONE_ID --query "ResourceRecordSets[*].[Name,ResourceRecords]" --output json | jq -c '.[]' | grep $ENV | grep $DOMAIN_SUFFIX | grep -v "green"
# Clean up
rm -rf /tmp/temporary-file*
