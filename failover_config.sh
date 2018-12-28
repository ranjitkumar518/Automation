#!/usr/bin/env bash
env=prf1
activemqelb="mp-activemq-prf1"
mpdbcluster="prf1-mp-aurora56"
activemqdbcluster="prf1-activemq-aurora56-replica1-cluster"
entldbcluster="prf1-entitle-aurora56-replica1-cluster"
mpdbinstance="prf1-mp-aurora56-us-east-2b"
activemqdbinstance="prf1-activemq-aurora56-replica1"
entldbinstance="prf1-entitle-aurora56-replica1"
elblist="mp-activemq mp-cortex mp-cortex-ro mp-integration mp-searchmaster mp-searchslave mp-cmserver webs-accountant webs-ordering webs-catalogs webs-entitle"
