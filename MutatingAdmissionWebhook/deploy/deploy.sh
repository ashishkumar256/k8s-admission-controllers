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
CN = mutate-sidecar.webhook.svc
[ req_ext ]
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = mutate-sidecar.webhook.svc
DNS.2 = mutate-sidecar.webhook.svc.cluster.local
EOF

openssl req -new -sha256 -nodes -out $CERT_DIR/webhook.csr -newkey rsa:2048 -keyout $CERT_DIR/webhook.key -config $CERT_DIR/webhook-csr.conf
openssl x509 -req -in $CERT_DIR/webhook.csr -signkey $CERT_DIR/webhook.key -out $CERT_DIR/webhook.crt -days 365 -extensions req_ext -extfile $CERT_DIR/webhook-csr.conf

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: poc
  labels:
    sidecar: enabled
EOF

# check diff
# helm -n webhook diff upgrade --install mutating-webhook --set app.image=ashishkumar256/mutating-webhook:1 chart

# deploy
helm -n webhook upgrade --install mutating-webhook --set app.image=ashishkumar256/mutating-webhook:1 chart

# Note: Image was created while doing activity, you may use it - "ashishkumar256/mutate-webhook:1"