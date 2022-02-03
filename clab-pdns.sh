#!/bin/bash

SERVER=''
DNS_SERVER='localhost'
APIKEY=''
DOMAIN=''
ADD_IPV6=false

HOSTNAME=$(hostname)

# Verify that needed tools are on the computer (jq, curl, containerlab)
if ! [ -x "$(command -v jq)" ] || ! [ -x "$(command -v curl)" ] || ! [ -x "$(command -v containerlab)" ]; then
  # First figure out if it's YUM or DEB
  UPDATER=""
  if [ -f /etc/redhat-release ]; then
    UPDATER="yum install"
  else
    UPDATER="apt install"
  fi
  # Verify that JQ is installed
  if ! [ -x "$(command -v jq)" ]; then
    echo "Installing jq"
    sudo $UPDATER jq
  fi

  # Verify that curl is installed
  if ! [ -x "$(command -v curl)" ]; then
    echo "Installing curl"
    sudo $UPDATER curl
  fi

  # Verify that containerlab is installed
  if ! [ -x "$(command -v containerlab)" ]; then
    echo "Installing containerlab"
    sudo bash -c "$(curl -sL https://get-clab.srlinux.dev)"
  fi

fi

# Get all of the running devices in containerlab
ALL_CLABS=$(containerlab inspect --all -f json)

# Get a list of just the container IDs that will be used to check if a record currently exists
CONTAINER_IDS=$(jq ".[] | .container_id" <<< $ALL_CLABS)

# Empty - will get filled in with existing records that match
DNS_CONTAINER_IDS=""

# Drop all lab A/AAAA records
EXISTING_RECORDS=`curl -H 'Content-Type: application/json' -s -H "X-API-Key: ${APIKEY}" http://${SERVER}/api/v1/servers/${DNS_SERVER}/zones/${DOMAIN} | jq -r ".rrsets[] | select(.type == (\"A\",\"AAAA\"))"`

# Only delete the records if there are any existing A/AAAA records
if [ -n "$EXISTING_RECORDS" ]; then
  DELETE_RECORDS='{"rrsets":[]}'
  while read i; do
    read -ra COMMENT <<< "$(jq -r ".comments[0].content" <<< $i)"

    if [ "$COMMENT" != "null" ]; then


      # Check if the hostname matches the comment and if the container ID doesn't exist anymore
      if [ ${COMMENT[0]} == "$HOSTNAME" ] && [[ ! $CONTAINER_IDS =~ "\"${COMMENT[1]}\"" ]]; then
        
        # do stuff with $i
        RECORD=`echo "$i" | jq '.name'`
        RECORD_TYPE=`echo "$i" | jq '.type'`
        DELETE_RECORDS=`echo "$DELETE_RECORDS" |jq -r ".rrsets += [{\"name\": $RECORD, \"type\": $RECORD_TYPE, \"changetype\": \"DELETE\"}]"`

      else
        # If the hostname and container ID match, add it to this list, this will help prevent updating/recreating a new DNS record later
        DNS_CONTAINER_IDS="\"${COMMENT[1]}\"\n${DNS_CONTAINER_IDS}"
      fi
    fi
  done <<< "$(jq -c '.' <<< $EXISTING_RECORDS)"
  
  # Delete the removed A/AAAA records if there are updates
  if [ "$DELETE_RECORDS" != "{\"rrsets\":[]}" ]; then
    curl -s -H 'Content-Type: application/json' -X PATCH --data "${DELETE_RECORDS}" -H "X-API-Key: ${APIKEY}" http://${SERVER}/api/v1/servers/${DNS_SERVER}/zones/${DOMAIN} | jq
  fi
fi


NEW_RECORDS='{"rrsets":[]}'

input="/etc/hosts"
START_STRING="-START ######"
END_STRING="-END ######"
CLAB_NODES=false
CHANGES=false

# Read the /etc/hosts file
while IFS= read -r line
do
  # Start of CLAB Nodes list
  if [[ "$line" == *"$START_STRING" ]]; then
    CLAB_NODES=true
    LAB_NAME=$(grep -oP '(?<=CLAB-).*(?=-START)' <<< $line | awk '{print tolower($0)}')
  # END OF CLAB_NODES list
  elif [[ "$line" == *"$END_STRING" ]]; then
    CLAB_NODES=false
  else
    if [ "$CLAB_NODES" = true ]; then
      read -a strarr <<< "$line"
      IP_ADDR=${strarr[0]}
      
      # Get the container ID
      CONTAINER_ID=`jq -r ".[] | select(.name == \"${strarr[1]}\") | .container_id" <<< $ALL_CLABS`

      COMMENT="$HOSTNAME $CONTAINER_ID"

      # CLAB node name to DNS record name = 
      # clab-<lab>-<name> to <name>.<lab>.<domain>

      # Strip out clab- from the node name (if it exists)
      NODE=$(sed 's/clab-//' <<< ${strarr[1]})

      # If the lab name is in the node name, we want that at the end for DNS
      if [[ "$NODE" == "$LAB_NAME-"* ]]; then
        NODE=$(grep -oP "(?<=$LAB_NAME-).*" <<< ${NODE})
        NODE="$NODE.$LAB_NAME"
      else
        NODE=$(grep -oP "(?<=$LAB_NAME-).*" <<< ${NODE})
      fi

      NODE="$NODE.$DOMAIN."

      if [[ ! $DNS_CONTAINER_IDS =~ "\"${CONTAINER_ID}\"" ]]; then
        # Have it setup to create AAAA records, but I'm not currently routing them in the home network since I'm a loser so, we skip those records
        if [[ ${IP_ADDR} == *"."* || "$ADD_IPV6" = true  ]]; then
          if [[ ${IP_ADDR} == *":"* ]]; then
            TYPE="AAAA"
          else
            TYPE="A"
          fi
          NEW_RECORDS=`echo "$NEW_RECORDS" |jq ".rrsets += 
            [
              {
                \"name\": \"$NODE\",
                \"type\": \"$TYPE\",
                \"ttl\": \"60\",
                \"changetype\": \"REPLACE\",
                \"records\": [
                  {
                    \"content\": \"${IP_ADDR}\",
                    \"disabled\": false
                  }
                ],
                \"comments\": [
                  {
                    \"account\": \"\",
                    \"content\": \"${COMMENT}\"
                  }
                ]
              }
            ]"`
        fi
      fi
    fi
  fi
done < "$input"

if [ "$NEW_RECORDS" != "{\"rrsets\":[]}" ]; then
  curl -s -H 'Content-Type: application/json' -X PATCH --data "${NEW_RECORDS}" -H "X-API-Key: ${APIKEY}" http://${SERVER}/api/v1/servers/${DNS_SERVER}/zones/${DOMAIN} | jq .
fi