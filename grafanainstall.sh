#!/bin/bash

# Update system
yum update -y

# Install Docker
yum install docker -y
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -aG docker ec2-user

# Install Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
install minikube-linux-amd64 /usr/local/bin/minikube

# Run Minikube as ec2-user
su - ec2-user -c "minikube start --driver=docker"

# Wait for Minikube to be ready
sleep 90

# Create Grafana YAML
tee /tmp/grafana.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-pvc
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana
        ports:
        - containerPort: 3000
        volumeMounts:
        - mountPath: /var/lib/grafana
          name: grafana-storage
      volumes:
      - name: grafana-storage
        persistentVolumeClaim:
          claimName: grafana-pvc

---
apiVersion: v1
kind: Service
metadata:
  name: grafana-service
  namespace: monitoring
spec:
  type: NodePort
  selector:
    app: grafana
  ports:
    - port: 3000
      targetPort: 3000
      nodePort: 32000
EOF

# Deploy Grafana as ec2-user
su - ec2-user -c "minikube kubectl -- apply -f /tmp/grafana.yaml"