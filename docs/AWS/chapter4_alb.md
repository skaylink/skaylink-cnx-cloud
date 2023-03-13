# 4 Configure your Network

When you want Customizer, you need to correct the network configuration at this early state. It is important as the installation of the Component Pack requires that all servers are reachable and that the correct host names are set up. Host names and access URLs could be changed later but this is not that simple and requires a lot of testing until everything is finally working as expected.

**Please be aware: You need to change the access URL for your existing Connections instance which will prevent your users to access the data until you have configured the Kubernetes infrastructure to forward the traffic correctly which is hopefully the case at the end of this chapter.**

This chapter will line out the tasks to get the new Kubernetes infrastructure to forward the traffic to the existing installation. The final Customizer configuration will be done later when everything is running.

This picture shows the target network setup. 

[Connections Infrastructure Networking AWS](../images/HCL_Connections_Infratructure_Networking_AWS.png "Connections Infrastructure Networking AWS")

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

[Installing the AWS Load Balancer Controller add-on](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html)


To create the AWS Load Balancer Controller run this script:
```
# Create AWS Load Balancer Controller
bash skaylink-cnx-cloud/AWS/scripts/create_eks_lb_controller.sh
```

After you have installed the controller, you can check the necessary subnet tags using:
```
# check subnet tags
bash skaylink-cnx-cloud/AWS/scripts/create_eks_lb_check.sh

# review the output.
```

In case you want to test your installation, you can install the 2048 game form the page [Application Load Balancing auf Amazon EKS](https://docs.aws.amazon.com/de_de/eks/latest/userguide/alb-ingress.html).
 

# 4.3 Get SSL Certificate

The easiest way to retrieve to have a certificate for the application load balancer is to use the AWS Certificate Manager.

Use the AWS Console to generate a certificate for you.

Write down the ARN of the validated certificate. You need this information when you create your ingress resources.

# 4.4 Create a target group for the WebSphere HTTP Server

When using the AWS AKB ingress controller, the forward to external resources is handled a little bit different. The forward happens directly on the load balancer and is not routed through the cluster.

To define the forward, a load balancer target group must be created manually using the AWS console or via script.

Currently no instructions are provided here. Hopefully this will change in the future.

Record the target group arn for the next step.


# 4.5 Forward traffic through global ingress

To forward the traffic through the new global ingress controller to your WebSphere infrastructure you need to define an external service to route the traffic to and then add the ingress configuration to kubernetes.

To create the external service for your existing infrastructure run:

```
# Load settings
. ~/installsettings.sh

# Create external service cnx-backend
kubectl -n $namespace create service externalname cnx-backend \
  --external-name $ic_internal

# Set the ARN of your Certificate
CERT_ARN=<certificate arn>

# Set the ARN of your target group
TG_ARN=<target group arn>

# create ingress configuration to forward traffic
bash skaylink-cnx-cloud/common/scripts/global_ingress.sh $CERT_ARN $TG_ARN

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
