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

FROM openjdk:14-alpine AS base

LABEL maintainer="jouni.tuominen@aalto.fi"

RUN apk add --update pwgen bash wget ca-certificates findutils coreutils ruby && rm -rf /var/cache/apk/*

# Update below according to https://jena.apache.org/download/
ENV FUSEKI_SHA512 c0b9ab61a57f2c0e027f9d1a07710a22e672eb87730a6460b0869f6a6997a2628703bd99b1590bccd38bdc2a0f78d7be17890b4b88f65ef5518c882c8736a6b3
ENV FUSEKI_VERSION 4.0.0
ENV JENA_SHA512 20706c955faebd2f090ce741a3b836016b75f86135e658d5d8cceb00a36b800f4e6158238bbfb7751bf13c1167d60236c49fbc7e099cd2e4c357bf36fe3323ca
ENV JENA_VERSION 4.0.0

ENV MIRROR http://www.eu.apache.org/dist/
ENV ARCHIVE http://archive.apache.org/dist/

# Config and data
ENV FUSEKI_BASE /fuseki-base

# Fuseki installation
ENV FUSEKI_HOME /jena-fuseki

ENV JENA_HOME /jena
ENV JENA_BIN $JENA_HOME/bin

WORKDIR /tmp
# sha512 checksum
RUN echo "$FUSEKI_SHA512  fuseki.tar.gz" > fuseki.tar.gz.sha512
# Download/check/unpack/move Fuseki in one go (to reduce image size)
RUN wget -O fuseki.tar.gz $MIRROR/jena/binaries/apache-jena-fuseki-$FUSEKI_VERSION.tar.gz || \
    wget -O fuseki.tar.gz $ARCHIVE/jena/binaries/apache-jena-fuseki-$FUSEKI_VERSION.tar.gz && \
    sha512sum -c fuseki.tar.gz.sha512 && \
    tar zxf fuseki.tar.gz && \
    mv apache-jena-fuseki* $FUSEKI_HOME && \
    rm fuseki.tar.gz* && \
    cd $FUSEKI_HOME && rm -rf fuseki.war

# Get tdbloader2 from Jena
# sha512 checksum
RUN echo "$JENA_SHA512  jena.tar.gz" > jena.tar.gz.sha512
# Download/check/unpack/move Jena in one go (to reduce image size)
RUN wget -O jena.tar.gz $MIRROR/jena/binaries/apache-jena-$JENA_VERSION.tar.gz || \
    wget -O jena.tar.gz $ARCHIVE/jena/binaries/apache-jena-$JENA_VERSION.tar.gz && \
    sha512sum -c jena.tar.gz.sha512 && \
    tar zxf jena.tar.gz && \
	mkdir -p $JENA_BIN && \
	mv apache-jena*/lib $JENA_HOME && \
	mv apache-jena*/bin/tdbloader2* $JENA_BIN && \
    rm -rf apache-jena* && \
    rm jena.tar.gz*

# As "localhost" is often inaccessible within Docker container,
# we'll enable basic-auth with a random admin password
# (which we'll generate on start-up)
COPY shiro.ini /jena-fuseki/shiro.ini
COPY docker-entrypoint.sh /
RUN chmod 755 /docker-entrypoint.sh

# SeCo extensions
COPY silk-arq-1.0.0-SNAPSHOT-with-dependencies.jar /javalibs/

# Fuseki config
ENV ASSEMBLER $FUSEKI_BASE/configuration/assembler.ttl
COPY assembler.ttl $ASSEMBLER
ENV CONFIG $FUSEKI_BASE/config.ttl
COPY fuseki-config.ttl $CONFIG
RUN mkdir -p $FUSEKI_BASE/databases

# Set permissions to allow fuseki to run as an arbitrary user
RUN chgrp -R 0 $FUSEKI_BASE \
    && chmod -R g+rwX $FUSEKI_BASE

# Tools for loading data
ENV JAVA_CMD java -cp "$FUSEKI_HOME/fuseki-server.jar:/javalibs/*"
ENV TDBLOADER $JAVA_CMD tdb.tdbloader --desc=$ASSEMBLER
ENV TDBLOADER2 $JENA_BIN/tdbloader2 --loc=$FUSEKI_BASE/databases/tdb
ENV TDB2TDBLOADER $JAVA_CMD tdb2.tdbloader --desc=$ASSEMBLER
ENV TEXTINDEXER $JAVA_CMD jena.textindexer --desc=$ASSEMBLER
ENV TDBSTATS $JAVA_CMD tdb.tdbstats --desc=$ASSEMBLER
ENV TDB2TDBSTATS $JAVA_CMD tdb2.tdbstats --desc=$ASSEMBLER

WORKDIR /jena-fuseki
EXPOSE 3030
USER 9008

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["java", "-cp", "*:/javalibs/*", "org.apache.jena.fuseki.cmd.FusekiCmd"]
