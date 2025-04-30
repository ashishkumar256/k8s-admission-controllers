# Use a lightweight Python base image
FROM python:3.9-slim

# Install dependencies
RUN pip install flask

# Copy application code
COPY validation-webhook.py /app/validation-webhook.py

# Create certs directory
RUN mkdir /certs
WORKDIR /app

# Secure port
EXPOSE 443

# Start the webhook server
CMD ["python", "validation-webhook.py"]
