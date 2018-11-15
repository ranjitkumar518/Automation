#!/bin/bash

ENV=$1
AWS_PROFILE=$2
REGION=$3
SERVICE=pricing

sh failover_dns.sh $ENV $AWS_PROFILE private $REGION $SERVICE
sh failover_dns.sh $ENV $AWS_PROFILE public $REGION $SERVICE
