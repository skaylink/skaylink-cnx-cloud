#!/bin/bash

. ~/installsettings.sh

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: global-ingress
  namespace: $namespace
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: HTTPS
    nginx.ingress.kubernetes.io/secure-backends: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: 512m
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
spec:
  ingressClassName: global-nginx
  rules:
  - host: $ic_front_door
    http:
      paths:
      - backend:
          service: 
            name: cnx-backend 
            port: 
              number: 443
        path: /
        pathType: Prefix
  tls:
  - hosts:
    - $ic_front_door 
    secretName: tls-secret
EOF

