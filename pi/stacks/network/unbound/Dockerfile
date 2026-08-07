FROM alpine:3.24
RUN apk add --no-cache unbound ca-certificates
EXPOSE 5053/udp 5053/tcp
CMD ["unbound", "-d", "-c", "/etc/unbound/unbound.conf"]
