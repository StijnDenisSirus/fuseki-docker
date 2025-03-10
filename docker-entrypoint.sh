#!/bin/bash
#   Licensed to the Apache Software Foundation (ASF) under one or more
#   contributor license agreements.  See the NOTICE file distributed with
#   this work for additional information regarding copyright ownership.
#   The ASF licenses this file to You under the Apache License, Version 2.0
#   (the "License"); you may not use this file except in compliance with
#   the License.  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

set -e

if [ ! -f "$FUSEKI_BASE/shiro.ini" ] ; then
  # First time
  echo "###################################"
  echo "Initializing Apache Jena Fuseki"
  echo ""
  cp "$FUSEKI_HOME/shiro.ini" "$FUSEKI_BASE/shiro.ini"
  if [ -z "$ADMIN_PASSWORD" ] ; then
    ADMIN_PASSWORD=$(pwgen -s 15)
    echo "Randomly generated admin password:"
    echo ""
    echo "admin=$ADMIN_PASSWORD"
  fi
  if [ -z "$USER_PASSWORD" ] ; then
    USER_PASSWORD=$(pwgen -s 15)
    echo "Randomly generated user password:"
    echo ""
    echo "user=$USER_PASSWORD"
  fi
  echo ""
  echo "###################################"
fi

if [ -z "$ADMIN_USERNAME" ] ; then
  ADMIN_USERNAME="admin"
fi

if [ -z "$USER_USERNAME" ] ; then
  USER_USERNAME="user"
fi

if [ -n "$ADMIN_PASSWORD" ] ; then  
  sed -i "s/^adminuser=.*/$ADMIN_USERNAME=$ADMIN_PASSWORD, admin/" "$FUSEKI_BASE/shiro.ini"
fi

if [ -n "$USER_PASSWORD" ] ; then
  sed -i "s/^reguser=.*/$USER_USERNAME=$USER_PASSWORD, user/" "$FUSEKI_BASE/shiro.ini"
fi

test "${ENABLE_DATA_WRITE}" = true && sed -i 's/\(fuseki:serviceReadGraphStore\)/#\1/' $ASSEMBLER && sed -i 's/#\s*\(fuseki:serviceReadWriteGraphStore\)/\1/' $ASSEMBLER
test "${ENABLE_UPDATE}" = true && sed -i 's/#\s*\(fuseki:serviceUpdate\)/\1/' $ASSEMBLER
test "${ENABLE_SHACL}" = true && sed -i -E 's/#\s*(fuseki:endpoint\s*\[\s*fuseki:operation\s+fuseki:shacl.+$)/\1/' $ASSEMBLER
test "${QUERY_TIMEOUT}" && sed -i "s/\(ja:cxtName\s*\"arq:queryTimeout\"\s*;\s*ja:cxtValue\s*\)\"[0-9]*\"/\1\"$QUERY_TIMEOUT\"/" $CONFIG

# Execute parent entrypoint to use system CA certificates
if [ -n "$USE_SYSTEM_CA_CERTS" ] ; then
  source /__cacert_entrypoint.sh
else
  exec "$@"
fi