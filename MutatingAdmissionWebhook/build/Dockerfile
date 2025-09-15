FROM golang:1.24-alpine AS build

# Define the architecture build argument
ARG ARCH

# Set environment variables dynamically based on architecture
ENV GOOS=linux \
    GOARCH=${ARCH}

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
RUN go build -o /app/bin/mutate-webhook

# Runtime Stage
# Use a minimal Alpine Linux base image
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

# Set up the default entrypoint. Arguments will be passed from the Kubernetes manifest.
ENTRYPOINT ["/app/mutate-webhook"]
