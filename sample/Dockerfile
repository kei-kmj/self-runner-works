FROM alpine:3.20

# helth_check.sh で curl を叩くのでインストール
RUN apk add --no-cache bash curl

WORKDIR /app

COPY helth_check.sh .
RUN chmod +x helth_check.sh

CMD ["./helth_check.sh"]