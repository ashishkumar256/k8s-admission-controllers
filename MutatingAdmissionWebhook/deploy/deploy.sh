#!/bin/bash
set -e

# Generate TLS certificates
CERT_DIR="./chart/certs/"
mkdir -p $CERT_DIR

cat <<EOF > $CERT_DIR/webhook-csr.conf
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn
[ dn ]
C = US
ST = State
L = Locality
O = Organization
OU = Unit
CN = pod-label-webhook.webhook.svc
[ req_ext ]
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = pod-label-webhook.webhook.svc
DNS.2 = pod-label-webhook.webhook.svc.cluster.local
EOF

openssl req -new -sha256 -nodes -out $CERT_DIR/webhook.csr -newkey rsa:2048 -keyout $CERT_DIR/webhook.key -config $CERT_DIR/webhook-csr.conf
openssl x509 -req -in $CERT_DIR/webhook.csr -signkey $CERT_DIR/webhook.key -out $CERT_DIR/webhook.crt -days 365 -extensions req_ext -extfile $CERT_DIR/webhook-csr.conf

# Base64 encode the certificate and key
CERT_BASE64=$(cat $CERT_DIR/webhook.crt | base64 | tr -d '\n')
KEY_BASE64=$(cat $CERT_DIR/webhook.key | base64 | tr -d '\n')

# Install Helm chart
cd chart
# check diff
helm -n webhook diff upgrade --install mutating-webhook --set app.image=<image:tag> .

# deploy
helm -n webhook upgrade --install mutating-webhook --set app.image=<image:tag> .
