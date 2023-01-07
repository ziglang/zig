FROM alpine:3.13

RUN rm -f /sbin/init
COPY init /sbin/init

RUN echo auto lo > /etc/network/interfaces
RUN echo iface lo inet loopback >> /etc/network/interfaces
