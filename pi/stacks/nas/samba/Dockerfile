FROM alpine:3.24
RUN apk add --no-cache samba tzdata
RUN addgroup -g 1000 vansh && adduser -u 1000 -G vansh -D -H -s /bin/false vansh
EXPOSE 445/tcp
CMD ["smbd", "-F", "--no-process-group"]
