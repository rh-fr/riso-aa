FROM alpine

RUN apk add --no-cache tcpdump coreutils

COPY entrypoint.sh /root/entrypoint.sh

ENTRYPOINT [ "/root/entrypoint.sh" ]
