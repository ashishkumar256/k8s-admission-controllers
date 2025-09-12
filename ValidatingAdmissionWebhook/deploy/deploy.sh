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
CN = validate-owner-label.webhook.svc
[ req_ext ]
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = validate-owner-label.webhook.svc
DNS.2 = validate-owner-label.webhook.svc.cluster.local
EOF

openssl req -new -sha256 -nodes -out $CERT_DIR/webhook.csr -newkey rsa:2048 -keyout $CERT_DIR/webhook.key -config $CERT_DIR/webhook-csr.conf
openssl x509 -req -in $CERT_DIR/webhook.csr -signkey $CERT_DIR/webhook.key -out $CERT_DIR/webhook.crt -days 365 -extensions req_ext -extfile $CERT_DIR/webhook-csr.conf

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: webhook
EOF

# check diff
helm -n webhook diff upgrade --install validating-webhook --set app.image=<image:tag> chart

# deploy
helm -n webhook upgrade --install validating-webhook --set app.image=<image:tag> chart

# Note: Image was created while doing activity, you may use it - "ashishkumar256/validate-webhook:1"

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: poc
EOF

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-validate
  namespace: poc
  labels:
    app: sample
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sample
  template:
    metadata:
      labels:
        app: sample
    spec:
      containers:
        - name: sample-container
          image: nginx:1.25
          ports:
            - containerPort: 80
EOF

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-validate-with-owner-label
  namespace: poc
  labels:
    app: sample
    owner: sre
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sample
      owner: sre
  template:
    metadata:
      labels:
        app: sample
        owner: sre
    spec:
      containers:
        - name: sample-container
          image: nginx:1.25
          ports:
            - containerPort: 80
EOF