# First stage. Building a binary
# -----------------------------------------------------------------------------
FROM golang:1.18-alpine AS builder

# Download the source code
RUN apk add --no-cache git
RUN git clone https://github.com/Ondrashek/Threadfin.git /src

WORKDIR /src

RUN git checkout main
RUN git pull
RUN go mod tidy && go mod vendor
RUN go build threadfin.go

# Second stage. Creating an image
# -----------------------------------------------------------------------------
#ARG USE_NVIDIA=0
#FROM ${USE_NVIDIA:+nvidia/cuda:12.1.1-base-ubuntu22.04}${USE_NVIDIA:-ubuntu:22.04}
FROM alpine:latest

ARG BUILD_DATE
ARG VCS_REF
ARG THREADFIN_PORT=34400
ARG THREADFIN_VERSION

LABEL org.label-schema.build-date="{$BUILD_DATE}" \
      org.label-schema.name="Threadfin" \
      org.label-schema.description="Dockerized Threadfin" \
      org.label-schema.url="https://hub.docker.com/r/ondrashekz/threadfin/" \
      org.label-schema.vcs-ref="{$VCS_REF}" \
      org.label-schema.vcs-url="https://github.com/Threadfin/Threadfin" \
      org.label-schema.vendor="Threadfin" \
      org.label-schema.version="{$THREADFIN_VERSION}" \
      org.label-schema.schema-version="1.0" \
      DISCORD_URL="https://discord.gg/bEPPNP2VG8"

ENV THREADFIN_BIN=/home/threadfin/bin
ENV THREADFIN_CONF=/home/threadfin/conf
ENV THREADFIN_HOME=/home/threadfin
ENV THREADFIN_TEMP=/tmp/threadfin
ENV THREADFIN_CACHE=/home/threadfin/cache
ENV THREADFIN_UID=31337
ENV THREADFIN_GID=31337
ENV THREADFIN_USER=threadfin
ENV THREADFIN_BRANCH=main
ENV THREADFIN_DEBUG=0
ENV THREADFIN_PORT=34400
ENV THREADFIN_LOG=/var/log/threadfin.log

# Add binary to PATH
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$THREADFIN_BIN

# Set working directory
WORKDIR $THREADFIN_HOME

RUN apk update
RUN apk upgrade
RUN apk add --no-cache ca-certificates
RUN apk add curl
RUN apk add ffmpeg
RUN apk add vlc

RUN apk update && apk add --no-cache tzdata
ENV TZ=America/New_York
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN mkdir $THREADFIN_BIN

# Copy built binary from builder image
COPY --chown=${THREADFIN_UID} --from=builder [ "/src/threadfin", "${THREADFIN_BIN}/" ]

# Set binary permissions
RUN chmod +rx $THREADFIN_BIN/threadfin
RUN mkdir $THREADFIN_HOME/cache

# Create working directories for Threadfin
RUN mkdir $THREADFIN_CONF
RUN chmod a+rwX $THREADFIN_CONF
RUN mkdir $THREADFIN_TEMP
RUN chmod a+rwX $THREADFIN_TEMP
RUN sed -i 's/geteuid/getppid/' /usr/bin/vlc

RUN mkdir /lib64 && ln -s /lib/libc.musl-x86_64.so.1 /lib64/ld-linux-x86-64.so.2

# Configure container volume mappings
VOLUME $THREADFIN_CONF
VOLUME $THREADFIN_TEMP

EXPOSE $THREADFIN_PORT

# Run the Threadfin executable
ENTRYPOINT ${THREADFIN_BIN}/threadfin -port=${THREADFIN_PORT} -config=${THREADFIN_CONF} -debug=${THREADFIN_DEBUG}
