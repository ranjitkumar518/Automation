#!/usr/bin/env bash
env=prf1
activemqelb="ep-activemq-prf1"
epdbcluster="prf1-ep-aurora56"
activemqdbcluster="prf1-activemq-aurora56-replica1-cluster"
entldbcluster="prf1-entitlement-aurora56-replica1-cluster"
epdbinstance="prf1-ep-aurora56-us-east-2b"
activemqdbinstance="prf1-activemq-aurora56-replica1"
entldbinstance="prf1-entitlement-aurora56-replica1"
elblist="ep-activemq ep-cortex ep-cortex-ro ep-integration ep-searchmaster ep-searchslave ep-cmserver webs-account webs-order webs-catalog webs-entitlement"
