#!/bin/bash

. ~/installsettings.sh

if [ -z "$1" ]; then
  echo "No Certificate ARN is specfied."
  echo "Usage: $0 <Certificate ARN> <Target Group ARN>"
  exit 1
fi

if [ -z "$2" ]; then
  echo "No Target Group ARN is specfied."
  echo "Usage: $0 <Certificate ARN> <Target Group ARN>"
  exit 1
fi

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: global-ingress
  namespace: $namespace
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: $1
    alb.ingress.kubernetes.io/actions.cnx-backend: |
      {"Type":"forward","TargetGroupArn": "$2"}
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/group.name: global-ingress
    alb.ingress.kubernetes.io/group.order: '100'
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}, {"HTTP":80}]'
    alb.ingress.kubernetes.io/backend-protocol: HTTPS
    alb.ingress.kubernetes.io/ssl-redirect: "443"

    nginx.ingress.kubernetes.io/proxy-body-size: 512m
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
spec:
  ingressClassName: alb
  rules:
  - http:
      paths:
      - backend:
          service:
            name: cnx-backend 
            port:
              name: use-annotation
        path: /
        pathType: Prefix
EOF

