# Stage 1: Builder – Copy the locally built bundle and install server dependencies
FROM node:22 AS builder

# Copy the bundle from the build context (which must include "output/bundle")
COPY output/bundle /app/bundle

# Set the working directory to the server folder inside the bundle
WORKDIR /app/bundle/programs/server
# Install production dependencies (omit dev dependencies if needed)
RUN npm install --omit=dev

# Stage 2: Final – Create a minimal, secure runtime image
FROM node:22-alpine
RUN apk add --no-cache bash ca-certificates \
	&& addgroup -S appgroup \
	&& adduser -S appuser -G appgroup
WORKDIR /app
# Copy the built bundle from the builder stage into the final image
COPY --from=builder /app/bundle ./bundle
# Copy the entrypoint script (assumed to be in the "tirta" folder) into the image
COPY titra/entrypoint.sh /docker/entrypoint.sh
# Ensure the entrypoint script is executable and adjust ownership so appuser can access all files
RUN chmod +x /docker/entrypoint.sh && chown -R appuser:appgroup /app
EXPOSE 3000
USER appuser
ENTRYPOINT ["/docker/entrypoint.sh"]
CMD ["node", "bundle/main.js"]