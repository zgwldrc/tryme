FROM openjdk:8-slim-stretch
RUN apt-get update ; apt-get install -y --fix-missing procps iputils-ping telnet iproute2 curl
ARG PKG_NAME
ARG CI_COMMIT_SHA
ENV CI_COMMIT_SHA ${CI_COMMIT_SHA}

ADD ${PKG_NAME} /app.jar
EXPOSE 8080
VOLUME /tmp
ENTRYPOINT [ \
    "java", "-Djava.security.egd=file:/dev/./urandom", \
    "-XX:+HeapDumpOnOutOfMemoryError", \
    "-XX:HeapDumpPath=/tmp/dump.hprof", \
    "-Xms1024m", \
    "-Xmx2048m", \
    "-jar", "/app.jar" \
]
