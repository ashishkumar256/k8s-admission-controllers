# Use a lightweight Python base image
FROM python:3.9-slim

# Install dependencies
RUN pip install flask

# Copy application code
COPY validate-webhook.py /app/validate-webhook.py

# Create certs directory
RUN mkdir /certs
WORKDIR /app

# Secure port
EXPOSE 443

# Set the entrypoint to the Python interpreter
ENTRYPOINT ["python", "/app/validate-webhook.py"]

# Set the default command arguments for the entrypoint
# These arguments are passed to the python script
CMD ["/certs/tls.crt", "/certs/tls.key"]
