FROM ubuntu:24.04
WORKDIR /tmp
ARG VERSION=1.8.0
RUN apt update && apt install -y wget rsyslog-gssapi
RUN wget https://fastdl.mongodb.org/tools/mongosync/mongosync-ubuntu2004-x86_64-${VERSION}.tgz && \
    tar -xzf mongosync-ubuntu2004-x86_64-${VERSION}.tgz && \
    cp mongosync-ubuntu2004-x86_64-${VERSION}/bin/mongosync /usr/local/bin/ && \
    mongosync -v
ENTRYPOINT [ "mongosync" ]