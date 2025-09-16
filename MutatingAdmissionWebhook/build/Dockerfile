FROM golang:1.24-alpine AS build

# Define the architecture build argument
ARG ARCH

# Set environment variables dynamically based on architecture
ENV GOOS=linux \
    GOARCH=${ARCH}

# Set the working directory inside the container
WORKDIR /app

# Copy the single Go file
COPY main.go .

# Build the Go application, enabling Go modules and using the single file
RUN go mod init my-project.dev/mutate-webhook && go mod tidy && go build -o /app/bin/mutate-webhook .

# Runtime Stage
FROM alpine:latest AS runtime

# Install runtime dependencies
RUN apk add --no-cache ca-certificates

# Set the working directory inside the container
WORKDIR /app

# Copy the binary from the builder stage
COPY --from=build /app/bin/mutate-webhook /app/mutate-webhook

# Expose both the HTTPS (443) and HTTP (8080) ports
EXPOSE 443
EXPOSE 8080

# Set up the default entrypoint. It will try to run with certs.
# The `CMD` is what can be overridden.
ENTRYPOINT ["/app/mutate-webhook"]
