FROM ubuntu:24.04
WORKDIR /tmp
ARG VERSION=1.8.0
RUN apt update && apt install -y wget rsyslog-gssapi curl jq
RUN wget https://fastdl.mongodb.org/tools/mongosync/mongosync-ubuntu2004-x86_64-${VERSION}.tgz && \
    tar -xzf mongosync-ubuntu2004-x86_64-${VERSION}.tgz && \
    cp mongosync-ubuntu2004-x86_64-${VERSION}/bin/mongosync /usr/local/bin/ && \
    rm -rf mongosync-ubuntu2004-x86_64-${VERSION}.tgz mongosync-ubuntu2004-x86_64-${VERSION} && \
    mongosync -v
COPY ./migrate.sh /usr/local/bin/migrate.sh
RUN chmod +x /usr/local/bin/migrate.sh
CMD [ "/usr/local/bin/migrate.sh" ]