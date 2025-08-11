FROM alpine:3.18

RUN apk add --no-cache ca-certificates curl bash unzip gettext procps

ENV XRAY_VERSION=1.8.6
WORKDIR /opt/xray

RUN curl -fsSL "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip" -o /tmp/xray.zip \
    && unzip /tmp/xray.zip -d /opt/xray \
    && rm /tmp/xray.zip \
    && chmod +x /opt/xray/xray

COPY config.template.json /etc/xray/config.json
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 443/tcp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
