# -----------------------------------------------------------------------------
# Stage 0: Base – Install common dependencies
# -----------------------------------------------------------------------------
FROM node:22 AS base
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .

# -----------------------------------------------------------------------------
# Stage 1: Lint – Run ESLint and generate a report (non-fatal)
# -----------------------------------------------------------------------------
FROM base AS lint
RUN mkdir -p reports && npm run lint -- -f checkstyle -o reports/eslint-report.xml || true

# -----------------------------------------------------------------------------
# Stage 2: Test – Run unit/integration tests and generate a JUnit report
# -----------------------------------------------------------------------------
FROM base AS test
RUN mkdir -p reports && npm test -- --reporter mocha-junit-reporter --reporter-options mochaFile=reports/test-results.xml

# -----------------------------------------------------------------------------
# Stage 3: Meteor Build – Build the Meteor app using server-only option
# -----------------------------------------------------------------------------
FROM base AS meteor-build
RUN curl https://install.meteor.com/?release=3.0 | sh
RUN meteor --version
RUN meteor build output --directory --server-only

# -----------------------------------------------------------------------------
# Stage 4: Artifact – Prepare the bundle for production
# -----------------------------------------------------------------------------
FROM node:22 AS artifact-builder
COPY --from=meteor-build /app/output/bundle /app/bundle
WORKDIR /app/bundle/programs/server
RUN npm install --omit=dev

# -----------------------------------------------------------------------------
# Stage 5: Final – Create a minimal, secure runtime image
# -----------------------------------------------------------------------------
FROM node:22-alpine AS final
RUN apk add --no-cache bash ca-certificates \
	&& addgroup -S appgroup \
	&& adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=artifact-builder /app/bundle ./bundle
COPY entrypoint.sh /docker/entrypoint.sh
RUN chmod +x /docker/entrypoint.sh && chown -R appuser:appgroup /app
EXPOSE 3000
USER appuser
ENTRYPOINT ["/docker/entrypoint.sh"]
CMD ["node", "bundle/main.js"]