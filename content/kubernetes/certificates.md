---
title: 'Certificates'
draft: false
---

# Setting up Certificates for a Docker Registry on Talos

## Overview

This guide explains how to configure certificate-based authentication for a private Docker registry running in a Talos Kubernetes cluster, using internal certificates rather than external ones.

## Certificate Setup Approaches

There are several approaches to solve this:

1. Use a self-signed certificate and configure Docker to trust it
2. Set up an internal Certificate Authority (CA) in your cluster
3. Use Kubernetes cert-manager for certificate management

This guide focuses on approach #2, which provides a good balance of security and control.

## Step 1: Create a Certificate for your Registry

First, you’ll need to create a certificate for your registry. If you already have an internal CA, you can use it. Otherwise, you’ll need to create one.

```bash
# Create directory for certificates
mkdir -p certs
cd certs

# Generate a private key for your CA
openssl genrsa -out ca.key 4096

# Create a CA certificate
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt \
  -subj "/CN=Internal CA"

# Create a private key for your registry
openssl genrsa -out registry.key 4096

# Create a certificate signing request (CSR)

openssl req -new -key registry.key -out registry.csr \
  -subj "/CN=registry.yourdomain.local" \
  -addext "subjectAltName = DNS:registry.example.com"

# Sign the certificate with your CA
openssl x509 -req -in registry.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out registry.crt -days 365 -sha256 \
  -extfile <(echo "subjectAltName = DNS:registry.example.com")
```

#### NOTE
Make sure to replace `registry.yourdomain.local` with your registry’s actual hostname throughout this guide.

## Step 2: Configure Your Registry with the Certificates

Create a Kubernetes secret with your certificates:

```bash
kubectl create secret generic registry-certs \
  --from-file=tls.crt=./certs/registry.crt \
  --from-file=tls.key=./certs/registry.key \
  -n default
```

Update your registry deployment to use these certificates:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: registry
  namespace: registry
spec:
  # ...
  template:
    # ...
    spec:
      containers:
      - name: registry
        image: registry:2
        ports:
        - containerPort: 5000
        volumeMounts:
        - name: registry-certs
          mountPath: /certs
          readOnly: true
        # ...
        env:
        - name: REGISTRY_HTTP_TLS_CERTIFICATE
          value: /certs/tls.crt
        - name: REGISTRY_HTTP_TLS_KEY
          value: /certs/tls.key
      volumes:
      - name: registry-certs
        secret:
          secretName: registry-certs
```

## Step 3: Configure Docker Clients to Trust the Certificate

On each machine that will push to your registry:

```bash
# Copy your CA certificate to the Docker certs directory
# Replace registry.yourdomain.local with your registry's hostname
sudo mkdir -p /etc/docker/certs.d/registry.yourdomain.local
sudo cp ca.crt /etc/docker/certs.d/registry.yourdomain.local/ca.crt

# Restart Docker to apply changes
sudo systemctl restart docker
```

For Talos machines, you’ll need to add the CA certificate to the machine configuration:

```yaml
machine:
  files:
    - content: |
        -----BEGIN CERTIFICATE-----
        # Your CA certificate content here
        -----END CERTIFICATE-----
      permissions: 0644
      path: /etc/ssl/certs/registry-ca.crt
```

## Step 4: Test Pushing to Your Registry

Now you should be able to push images to your registry:

```bash
# Tag an image for your registry
docker tag myimage:latest registry.yourdomain.local:5000/myimage:latest

# Push to your registry
docker push registry.yourdomain.local:5000/myimage:latest
```

## Alternative: Use Insecure Registry

#### WARNING
This approach is not recommended for production environments!

If you’re just testing and don’t want to deal with certificates temporarily:

1. Configure Docker to use insecure registry:
   ```json
   # Add this to /etc/docker/daemon.json
   {
     "insecure-registries": ["registry.yourdomain.local:5000"]
   }
   ```
2. For Talos nodes, add to your machine configuration:
   ```yaml
   machine:
     registries:
       config:
         registry.yourdomain.local:5000:
           tls:
             insecureSkipVerify: true
   ```

## Troubleshooting

Common issues and solutions:

### Certificate Issues

If you encounter certificate verification errors, check that:

- The CA certificate has been correctly copied to all client machines
- The hostname in your registry URL matches exactly what’s in the certificate’s SAN field
- The certificates haven’t expired (check with `openssl x509 -in registry.crt -text -noout`)

### Registry Connection Issues

If you can’t connect to the registry:

- Verify the registry service is running: `kubectl get pods -n registry`
- Check that the registry service is exposed: `kubectl get svc -n registry`
- Ensure network policies allow traffic to the registry port
