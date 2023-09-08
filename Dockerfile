# build stage
FROM golang:alpine AS build-zscaler
USER root

# To be able to download `ca-certificates` with `apk add` command
COPY ZscalerRootCertificate-2048-SHA256.crt /root/ZscalerRootCertificate-2048-SHA265.crt
RUN cat /root/ZscalerRootCertificate-2048-SHA265.crt >> /etc/ssl/certs/ca-certificates.crt

# Add again root CA with `update-ca-certificates` tool
RUN apk --no-cache add ca-certificates \
    && rm -rf /var/cache/apk/*
COPY ZscalerRootCertificate-2048-SHA256.crt /usr/local/share/ca-certificates
RUN update-ca-certificates

FROM build-zscaler AS build-env
ADD . /go/src/clamav-rest/
RUN cd /go/src/clamav-rest && go build -v

# dockerize stage
FROM alpine AS zscaler
USER root

# To be able to download `ca-certificates` with `apk add` command
COPY ZscalerRootCertificate-2048-SHA256.crt /root/ZscalerRootCertificate-2048-SHA265.crt
RUN cat /root/ZscalerRootCertificate-2048-SHA265.crt >> /etc/ssl/certs/ca-certificates.crt

# Add again root CA with `update-ca-certificates` tool
RUN apk --no-cache add ca-certificates \
    && rm -rf /var/cache/apk/*
COPY ZscalerRootCertificate-2048-SHA256.crt /usr/local/share/ca-certificates
RUN update-ca-certificates

FROM zscaler as deploy
RUN apk --no-cache add clamav clamav-libunrar \
    && mkdir /run/clamav \
    && chown clamav:clamav /run/clamav

RUN sed -i 's/^#Foreground .*$/Foreground true/g' /etc/clamav/clamd.conf \
    && sed -i 's/^#TCPSocket .*$/TCPSocket 3310/g' /etc/clamav/clamd.conf \
    && sed -i 's/^#Foreground .*$/Foreground true/g' /etc/clamav/freshclam.conf

RUN freshclam --quiet

COPY entrypoint.sh /usr/bin/
COPY --from=build-env /go/src/clamav-rest/clamav-rest /usr/bin/

EXPOSE 9000

ENTRYPOINT [ "entrypoint.sh" ]
