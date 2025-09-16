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
CN = mutate-sidecar-container.webhook.svc
[ req_ext ]
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = mutate-sidecar-container.webhook.svc
DNS.2 = mutate-sidecar-container.webhook.svc.cluster.local
EOF

openssl req -new -sha256 -nodes -out $CERT_DIR/webhook.csr -newkey rsa:2048 -keyout $CERT_DIR/webhook.key -config $CERT_DIR/webhook-csr.conf
openssl x509 -req -in $CERT_DIR/webhook.csr -signkey $CERT_DIR/webhook.key -out $CERT_DIR/webhook.crt -days 365 -extensions req_ext -extfile $CERT_DIR/webhook-csr.conf

# kubectl apply -f - <<EOF
# apiVersion: v1
# kind: Namespace
# metadata:
#   name: webhook
# EOF

# # A ClusterRole that grants permission to 'get' and 'list' namespaces
# kubectl apply -f - <<EOF
# apiVersion: rbac.authorization.k8s.io/v1
# kind: ClusterRole
# metadata:
#   name: default
# rules:
# - apiGroups: [""]
#   resources: ["namespaces"]
#   verbs: ["get", "list"]
# EOF

# # A ClusterRoleBinding that links the ClusterRole to the ServiceAccount
# kubectl apply -f - <<EOF
# apiVersion: rbac.authorization.k8s.io/v1
# kind: ClusterRoleBinding
# metadata:
#   name: default
# subjects:
# - kind: ServiceAccount
#   name: default
#   namespace: webhook
# roleRef:
#   kind: ClusterRole
#   name: default
#   apiGroup: rbac.authorization.k8s.io
# EOF

# check diff
helm -n webhook diff upgrade --install mutate-webhook --set app.image=<image:tag> chart

# deploy
helm -n webhook upgrade --install mutate-webhook --set app.image=<image:tag> chart --create-namespace

# Note: Image was created while doing activity, you may use it - "ashishkumar256/mutate-webhook:1"

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: poc
  labels:
    sidecar: enabled
EOF


kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-mutate
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

