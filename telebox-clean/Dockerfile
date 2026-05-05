FROM node:24-bookworm-slim

WORKDIR /opt/telebox-runtime

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates openssh-client \
 && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY entrypoint.sh /usr/local/bin/telebox-entrypoint.sh
RUN chmod +x /usr/local/bin/telebox-entrypoint.sh

ENV TELEBOX_REPO=https://github.com/TeleBoxOrg/TeleBox.git \
    TELEBOX_BRANCH=main \
    TELEBOX_WORKSPACE=/workspace \
    TELEBOX_DATA=/data \
    TZ=Asia/Shanghai

ENTRYPOINT ["/usr/local/bin/telebox-entrypoint.sh"]
CMD ["npm", "start"]
