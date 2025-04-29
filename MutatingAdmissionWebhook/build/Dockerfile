FROM golang:1.24-alpine AS build

# Define the architecture build argument
ARG ARCH

# Set environment variables dynamically based on architecture
ENV GOOS=linux \
    GOARCH=${ARCH}

RUN echo ${ARCH}
# Install necessary build tools
RUN apk add --no-cache git

# Set the working directory inside the container
WORKDIR /app

# Copy the Go module files into the container
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy the rest of the application code
COPY . .

# Build the Go application
RUN go build -o /app/bin/mutating-webhook

# Runtime Stage
# Use a minimal Alpine Linux base image
FROM alpine:latest AS runtime

# Install runtime dependencies
RUN apk add --no-cache ca-certificates

# Set the working directory inside the container
WORKDIR /app

# Create a directory for TLS certificates
RUN mkdir -p /certs

# Copy the binary from the builder stage
COPY --from=build /app/bin/mutating-webhook /app/mutating-webhook

# Expose the necessary port (if applicable)
EXPOSE 8080

# Set up the entrypoint with TLS arguments
ENTRYPOINT ["/app/mutating-webhook", "--tls-cert", "/certs/tls.crt", "--tls-key", "/certs/tls.key"]
