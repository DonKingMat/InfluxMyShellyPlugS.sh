#!/bin/bash

if [ "$1" = "debug" ] ; then DEBUG=1 ; else DEBUG=0 ; fi

JQ=`which jq`
CURL=`which curl`
PIDOF=`which pidof`
TIMEOUT=`which timeout`

# Exit if still runs
if [ $($PIDOF -x "$0" | wc -w) -ne 2 ] ; then exit ; fi

source /home/pi/SlackMySteckdose/influx.conf
#INFLUXRASPI=10.10.10.7:8086
#INFLUXRASPIORG=InfluxORG
#INFLUXRASPIBUCKET=InfluxBuck
#INFLUXRASPITOKEN=***==

PW="*******"
PLUGS=(130 131 132 133 134 135 136 137 138 139)
EPOCH=$(date +%s)

for PLUG in $(echo ${PLUGS[*]}) ; do

  # Script-Sprung, wenn die Dose nicht erreichbar ist
  $TIMEOUT 1 bash -c "cat < /dev/null > /dev/tcp/10.10.10.${PLUG}/80 2> /dev/null" || continue

  URL="http://10.11.12.${PLUG}/rpc/Shelly.GetStatus"
  SHELLY=$($CURL -s -s --digest -u admin:${PW} http://10.10.10.${PLUG}/rpc/Shelly.GetDeviceInfo | $JQ -r '.name')
  if [ "$SHELLY" == "null" ] ; then
    SHELLY=$($CURL -s -s --digest -u admin:${PW} http://10.10.10.${PLUG}/rpc/Shelly.GetDeviceInfo | $JQ -r '.mac')
  fi

  JSON=$($CURL -s -s --digest -u admin:${PW} $URL)

  SPANNUNG=$(echo $JSON | $JQ -r '."switch:0".voltage')
  WATT=$(echo $JSON | $JQ -r '."switch:0".apower')
  TEMPERATUR=$(echo $JSON | $JQ -r '."switch:0".temperature.tC')

if [ $DEBUG -eq 0 ] ; then
  $CURL --request POST "http://${INFLUXRASPI}/api/v2/write?org=${INFLUXRASPIORG}&bucket=${INFLUXRASPIBUCKET}&precision=s" --header "Authorization: Token ${INFLUXRASPITOKEN}" --data-raw "${SHELLY} Spannung=${SPANNUNG} ${EPOCH}"
  $CURL --request POST "http://${INFLUXRASPI}/api/v2/write?org=${INFLUXRASPIORG}&bucket=${INFLUXRASPIBUCKET}&precision=s" --header "Authorization: Token ${INFLUXRASPITOKEN}" --data-raw "${SHELLY} Watt=${WATT} ${EPOCH}"
  $CURL --request POST "http://${INFLUXRASPI}/api/v2/write?org=${INFLUXRASPIORG}&bucket=${INFLUXRASPIBUCKET}&precision=s" --header "Authorization: Token ${INFLUXRASPITOKEN}" --data-raw "${SHELLY} Temperatur=${TEMPERATUR} ${EPOCH}"
fi

if [ $DEBUG -eq 1 ] ; then
echo "${SHELLY} Spannung=${SPANNUNG} ${EPOCH}"
echo "${SHELLY} Watt=${WATT} ${EPOCH}"
echo "${SHELLY} Temperatur=${TEMPERATUR} ${EPOCH}"
echo $PLUG
echo " "
fi

done
