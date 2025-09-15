FROM golang:1.24-alpine AS build

# Define the architecture build argument
ARG ARCH

# Set environment variables dynamically based on architecture
ENV GOOS=linux \
    GOARCH=${ARCH}

# Set the working directory inside the container
WORKDIR /app

# Copy the project files
COPY go.mod go.sum ./
COPY main.go ./
COPY cmd ./cmd

# Download dependencies
RUN go mod download

# Build the Go application
RUN go build -o /app/bin/mutate-webhook main.go

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
