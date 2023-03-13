# 4 Configure your Network

When you want Customizer, you need to correct the network configuration at this early state. It is important as the installation of the Component Pack requires that all servers are reachable and that the correct host names are set up. Host names and access URLs could be changed later but this is not that simple and requires a lot of testing until everything is finally working as expected.

**Please be aware: You need to change the access URL for your existing Connections instance which will prevent your users to access the data until you have configured the Kubernetes infrastructure to forward the traffic correctly which is hopefully the case at the end of this chapter.**

This chapter will line out the tasks to get the new Kubernetes infrastructure to forward the traffic to the existing installation. The final Customizer configuration will be done later when everything is running.

This picture shows the target network setup. 

![Connections Infrastructure Networking AWS](../images/HCL_Connections_Infratructure_Networking_AWS.png "Connections Infrastructure Networking AWS")

## 4.1 Change Service URL for your existing infrastructure

Your existing infrastructure must have a different DNS name than the global ingress controller so that traffic can flow from the users through the ingress controller into your existing infrastructure. To avoid that the existing WebSphere servers start to communicate through the ingress controller what will produce a lot of unnecessary load, the DNS Names and service configurations must be adjusted.

### 4.1.1 Create new DNS entry for your existing front end

Create a new DNS entry for your existing HTTP Server or front end load balancer. For simplicity you could append "-backend" to your existing DNS name. e.g. cnx.demo.com will become cnx-backend.demo.com. Create the same type of DNS entry as the existing one. When you have a A record, create a new A record with the same IP. If you have a CNAME, create a new CNAME record with the same value as the existing one.

### 4.1.2 Reconfigure your existing connections instance

**This reconfiguration requires a full restart of the instance**

The process is described by HCL on page [Configuring the NGINX proxy server for Customizer](https://opensource.hcltechsw.com/connections-doc/v8-cr1/admin/install/cp_config_customizer_setup_nginx.html).

1. Get new SSL Certificates for your HTTP Server and in case for your Load Balancer where the Service Principal Name also includes the new DNS Name. The old name is only necessary until the new ingress controller is active. In case you do this during the same down time, the old name is not necessary in the SSL certificate.
2. Update your HTTP Server and in case your load balancer to use the new SSL certificate. 
3. Update all service names in the LotusConnections-config.xml from the existing DNS name to the new DNS name. 
4. Place the existing DNS Name in the Dynamic Host configuration so that URLs calculated by the system still have the old DNS name.
5. Restart your infrastructure

After the restart, your old infrastructure should behave normal. If not, you need to debug the configuration change and make sure the DNS entries point to the right systems.



# 4.2 Installing the Global Ingress Controller

The Customizer requires a reverse proxy in front of the whole infrastructure so that some specific HTTP URLs can be redirected to the Customizer for modification. HCL suggests to use a nginx server. As it is a common problem on kubernetes infrastructures to redirect HTTP(s) traffic to different backend services (internal servers and external endpoints) out of the box solutions exists that can be used.

This chapter uses the nginx-ingress controller from [nginx-ingress](https://kubernetes.github.io/ingress-nginx/).  

There are different possibilities on how to connect to a Kubernetes cluster. Usually this is done via a load balancer. The load balancer can be set up automatically by Kubernetes or manually. The load balancer ip can be either internal or a public ip address.

The infrastructure will contain 2 ingress controller. The global we are currently set up and the cnx-ingress-controller. All HCL and Kudos components assume that the cnx-ingress-controller is the default ingress controller. Therefore the new global-ingress-controller uses a different ingress-class called `global-nginx`. 

To install the global ingress controller make sure you created the global-ingress.yaml file. 
Depending on the setting "GlobalIngressPublic" the ingress controller will create a public or private load balancer.

```
# Load configuration
. ~/installsettings.sh

# Add Helm Repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update


# Global Ingress Controller
helm upgrade global-nginx ingress-nginx/ingress-nginx -i \
  -f ~/cp_config/global-ingress.yaml \
  --namespace $namespace \
  --version 4.5.2

# Check deployment
kubectl -n $namespace rollout status deployment global-nginx-ingress-nginx-controller

kubectl get deployment -n $namespace global-nginx-ingress-nginx-controller

```


# 4.3 Make sure your DNS resolution and service configuration is right

The DNS resolution must be set correctly to allow users and services to access your ingress controller from everywhere. 
Especially when using the automatic SSL Certificate generation configured in 4.5.1 Automatic SSL Certificate retrieval and renewal.

The script detects the currently running services by name, get the configured load balances and then creates Route53 CNAME entries in the appropriate Zones. Private Load Balancer get registered in the private zone only. Public load balancer get registered in both zones. 

To configure the DNS entry for your LB via script run:

```
# Create CNAME entries for your Load Balancers
bash skaylink-cnx-cloud/AWS/scripts/setupDNS4Ingress.sh

```

# 4.4 Get SSL Certificate

To secure your traffic a SSL certificate is necessary. This certificate must be added to a kubernetes secret.

## 4.4.1 Automatic SSL Certificate retrieval and renewal for nginx-ingress
When using the ingress controller together with the [cert-manager](https://cert-manager.io/) , the necessary ssl certificates can be retrieved automatically. 

**The SSL Certificate retrieval only works, when you are using a pulbic Load Balancer (The ingress controller is accessible via http (port 80) from the public internet and your productive DNS entry is already pointing to your load balancer.**

**Make sure that the internal and external DNS resolution works for your public DNS Name. The cert manager will check the dns name interally as well.**

Setup the certificate manager is simple when your ingress controller has a public IP.  

```
# Create namespace
kubectl create namespace cert-manager

# Add Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install the cert-manager Helm chart !! K8s v1.18 or newer, Helm v3.3 or newer !!
helm install cert-manager jetstack/cert-manager \
  --version v1.11.0 \
  --namespace cert-manager \
  --set rbac.create=true \
  --set installCRDs=true
  
```

to create the CA cluster issuer configuration update your installsettings.sh:  
Required parameters:

```
# Let's Encrypt CA Issuer configuration
acme_email=<valid email from your organization>
use_lestencrypt_prod=[true, false]

```

and run:

```
# Create issuer
bash skaylink-cnx-cloud/common/scripts/cert_issuer.sh

# check issuer
kubectl describe Issuer letsencrypt -n $namespace

```

## 4.4.2 Manual SSL Certificate creation for nginx-ingress
If you want to use an other CA managed certificate or a self singed certificate create the secret manually.  
For simplicity we use a self singed certificate in this documentation. Example: [TLS certificate termination](https://github.com/kubernetes/contrib/tree/master/ingress/controllers/nginx/examples/tls)

```
# Create a self signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /tmp/tls.key -out /tmp/tls.crt

# Store the certificate inside Kubenetes
kubectl -n connections create secret tls tls-secret --key /tmp/tls.key --cert /tmp/tls.crt

```


# 4.5 Forward traffic through global ingress

To forward the traffic through the new global ingress controller to your WebSphere infrastructure you need to define an external service to route the traffic to and then add the ingress configuration to kubernetes.

To create the external service for your existing infrastructure run:

```
# Load settings
. ~/installsettings.sh

# Create external service cnx-backend
kubectl -n connections create service externalname cnx-backend \
  --external-name $ic_internal

# create ingress configuration to forward traffic
bash skaylink-cnx-cloud/AWS/scripts/global_ingress.sh

```


# 4.6 Test your forwarding

To test your forwarding, you can use curl or wget. I do not recommend to use a browser as the forwarding might not fully functional yet and with a full browser it is not that easy to see the details.

**Test the access to your ingress loadbalancer by IP**

Your DNS entry may still pointing to the "old" infrastructure. In this case the DNS name can not yet tested.

Access the Load Balancer DNS name e.g. curl -v -k "https://<lb ip>"

* When the forward works as expected, the result of the test should be a "302" redirect to the DNS Name of your old connections instance.
* When the access to the service does not work, you get a connection timeout
* When the access to the service works but the forward fails, you get a 502 Gateway not reachable error.

** Test the access to your ingress loadbalancer by DNS**

To access the load balancer via DNS Name, you need to either reconfigure your DNS Server or create a local hosts entry on your computer.

1. Test `ping <dns name>` to check the correct DNS resolution to your new load balancer.
2. Test `curl -v -k http://<dns name>` to check the correct response.<br>
The results of your test should be a redirect to the DNS name of your old infrastructure.<br>
The error causes are the same as above.

** Test with a browser **

You can now use a browser to test the access.

**[Prepare cluster << ](chapter3.html) [ >> Install Component Pack](chapter5.html)**
