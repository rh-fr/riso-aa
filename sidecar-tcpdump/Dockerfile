FROM debian:stretch

RUN apt-get update && apt-get install tcpdump coreutils procps -y

COPY entrypoint.sh /root/entrypoint.sh

ENTRYPOINT [ "/root/entrypoint.sh" ]
