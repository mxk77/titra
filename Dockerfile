# Stage 1: Local Builder – Copy the locally built bundle
FROM busybox AS localbuilder
# Expecting that the meteor build stage has placed the bundle in output/bundle
COPY output/bundle /bundle

# Stage 2: Final – Create a minimal, secure runtime image
FROM node:22-alpine
RUN apk add --no-cache bash ca-certificates \
	&& addgroup -S appgroup \
	&& adduser -S appuser -G appgroup
WORKDIR /app
# Copy the locally built bundle from the previous stage
COPY --from=localbuilder /bundle ./bundle
# Copy the entrypoint script and fix permissions
COPY entrypoint.sh /docker/entrypoint.sh
RUN chmod +x /docker/entrypoint.sh && chown -R appuser:appgroup /app
EXPOSE 3000
USER appuser
ENTRYPOINT ["/docker/entrypoint.sh"]
CMD ["node", "bundle/main.js"]