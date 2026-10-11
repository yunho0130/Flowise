# Railway-specific Flowise 3.1.4 image. The upstream 3.1.4 image contains an
# unpinned npm install layer that can actually ship flowise@3.1.2.
# Keep this as a single existing service with its existing SQLite volume.
ARG NODE_VERSION=20
FROM node:${NODE_VERSION}-alpine AS build

RUN apk add --no-cache git python3 py3-pip make g++ build-base cairo-dev pango-dev
ENV PUPPETEER_SKIP_DOWNLOAD=true

ARG FLOWISE_VERSION=3.1.4
RUN npm install -g "flowise@${FLOWISE_VERSION}" \
    && npm --prefix "$(npm root -g)/flowise" dedupe

# connect-sqlite3 0.9.17 changed its API and crashes Flowise's session store.
# Keep all post-install changes in one command: a later npm install can undo pins.
RUN npm --prefix "$(npm root -g)/flowise" install --no-save \
    connect-sqlite3@0.9.16 \
    vm2@3.11.6 \
    @smithy/eventstream-codec@4.5.2

# Fail the build if npm changed a pinned version while resolving the tree.
RUN M="$(npm root -g)/flowise" \
    && test "$(node -p "require('$M/package.json').version")" = "$FLOWISE_VERSION" \
    && test "$(node -p "require('$M/node_modules/connect-sqlite3/package.json').version")" = "0.9.16" \
    && test "$(node -p "require('$M/node_modules/vm2/package.json').version")" = "3.11.6" \
    && node -e "require.resolve('@smithy/eventstream-codec', { paths: ['$M'] })"

FROM node:${NODE_VERSION}-alpine
RUN apk add --no-cache chromium git python3 py3-pip make g++ build-base cairo-dev pango-dev curl su-exec
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
COPY --from=build /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=build /usr/local/bin /usr/local/bin
RUN chown -R node:node /usr/local/lib/node_modules /usr/local/bin
COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod 0755 /usr/local/bin/railway-entrypoint.sh
EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
CMD ["flowise", "start"]
