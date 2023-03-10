# 3 Prepare cluster

Starting with HCL Connections v8 HCL is no longer provides the Component Pack installation as download. All necessary images and helm charts are published via Harbor registry https://hclcr.io.

To continue, make shure you have access to the registry and retrieved your access key. See [Prerequisites for Component Pack](https://opensource.hcltechsw.com/connections-doc/v8-cr1/admin/install/cp_prereqs.html).

# 3.1 Create configuration files

To simplify the resource creation, many settings can be placed into yaml files. Theses files will then be referenced by the various installation commands.  
HCL references to a git repository where you can find templates for these configuration files.  
I took these template files and made them available in this repository to be used with the installsettings.sh.

To create these files make sure, your `installsettings.sh` file is up to date, then run:

```
# Write Config Files
bash skaylink-cnx-cloud/common/scripts/write_cp_config.sh

```
This command will create the necessary configuration files in the directory `$HOME/cp_config/`.

# 3.2 Crate the connections namespace

All HCL Connections related services are deployed inside the namespace `connections` per default. See the HCL documentation in case you want to change this default.

To create the namespace run: 

```
. ~/installsettings.sh
kubectl create namespace $namespace

```

 
# 3.3 Create persistent volume claims

HCL provides the relevant documentation on page [Steps to install or upgrade to Component Pack 8 CR1 - Set up NFS](https://opensource.hcltechsw.com/connections-doc/v8-cr1/admin/install/cp_install_services_tasks.html#section_e4p_jrp_tnb) and later [Set up persistent volumes and persistent volume claims on NFS](https://opensource.hcltechsw.com/connections-doc/v8-cr1/admin/install/cp_install_services_tasks.html#pv_pvc).

The usage of my efs-aws storage class does not work when using the helm chart HCL is providing.  
Therefore I modified the helm chart to create the persistent volume claims necessary for your installation using a storage class.

To create the volume claims run:

```
# Load configuration
. ~/installsettings.sh

helm upgrade connections-volumes \
  ~/skaylink-cnx-cloud/common/helm/connections-persistent-storage-nfs \
  -i -f ~/cp_config/install_cp.yaml --namespace $namespace

```

To check the creation run: `kubectl -n $namespace get pvc`

Make sure the status of the created pvc is "Bound"

Per default all created persistent volumes have the retain policy _Delete_ which forces the resource to be deleted when the associated persistent volume clain is deleted.  
To keep your data in such a case the reclaim policy needs to be modified to _Retain_.  
To fix the reclaim policy run: `bash skaylink-cnx-cloud/common/scripts/fix_policy_all.sh`


**[Create Kubernetes infrastructure on AWS << ](chapter2.html) [ >> Configure your Network](chapter4.html)**
