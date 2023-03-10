#!/bin/bash

. ~/installsettings.sh

source_dir=templates

SCRIPT_DIR=$(dirname $(readlink -f $0))

source_dir=$SCRIPT_DIR/$source_dir

#output_dir=$SCRIPT_DIR/outputs
output_dir=$HOME/cp_config

if [ ! -d "$source_dir" ]; then
	echo "ERROR: Template Directory $templates not found."
	exit 1
fi

# create subdirecoty
if [ ! -d "$output_dir" ]; then
  mkdir -p "$output_dir"
fi

if [ ! -d "$output_dir" ]; then
  echo "ERROR: Configuration directory "$output_dir" was not created."
  exit 1
fi

# ------------------------------------------------------------
# Create configuraion dependend variables
# ------------------------------------------------------------

if [ -z "$namespace" ]; then
  $namespace=connections
fi

if [ "$CNXSize" == "small" ]; then
  rCountNormal=1
  rCountSmall=0
  minCount=1
  maxCount=3
  bCountNormal=1
else
  rCountNormal=3
  rCountSmall=1
  minCount=3
  maxCount=3
  bCountNormal=2
fi

if [ "$EKSTags" ]; then
  serviceTags="service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags: $EKSTags"
fi
# Write global ingress controller configuration

if [ "$GlobalIngressPublic" != "1" ]; then
  annotationPrivate="service.beta.kubernetes.io/aws-load-balancer-internal: "true""
fi

# Write internal ingress controller configuration
if [ "$useStandaloneES" != "1" ]; then
  forwardES="  \"30099\": $namespace/elasticsearch:9200"
fi

# convert $starter_stack_list from a , separated list to a space separated list and remove kudos-boards in case it is available
stack_list=$(echo $starter_stack_list | sed -e "s/,/ /g" -e "s/kudos-boards//" |xargs)

# Mongo Configuration
if [ $installversion -ge 80 ]; then
  MONGO=false
  MONGO5=true
else
  MONGO=true
  MONGO5=false
fi

# Elasticsearch Configuration
if [ "$useStandaloneES" == "1" ]; then
  # use standalone ES Server
  if [ "$ESVersion" == "7" ]; then
    ESHost7=$standaloneESHost
    ESPort7=$standaloneESPort
  else
    if [ "$ESVersion" == "131" ]; then
      OSHost=$standaloneESHost
      OSPort=$standaloneESPort
    else
      ESHost=$standaloneESHost
      ESPort=$standaloneESPort
    fi
  fi
  ESPVC=false
  ESPVC7=false
  OSPVC=false
  if [ "$standaloneESHost" -a "$standaloneESPort" ]; then
    ESIndexing=true
  else
    ESIndexing=false
  fi
else
  # use integrated ES Server - values default from values.yaml in orientme helmchart
  ESHost=elasticsearch
  ESPort=9200
  ESHost7=elasticsearch7
  ESPort7=9200
  OSHost=opensearch
  OSPort=9200
  if [ $installversion -ge 80 ]; then
    ESPVC=false
    ESPVC7=false
    OSPVC=true
  else
    if [ $installversion -ge 70 ]; then
      ESPVC=false
      ESPVC7=true
      OSPVC=false
    fi
    ESPVC=true
    ESPVC7=false
    OSPVC=false
  fi
  ESIndexing=true
fi
if [ "$useSolr" == "0" -o "$installversion" -ge 70 ]; then
  SolrPVC=false
  SolrIndexing=false
  ESRetrieval=true
  SolrRepCount=0
  ZooRepCount=0
else
  SolrPVC=true
  SolrIndexing=true
  ESRetrieval=false
  SolrRepCount=$rCountNormal
  ZooRepCount=$rCountNormal
fi

if [ "$MSTeams" == "1" ]; then
  MSTeamsEnabled="true"
else
  MSTeamsEnabled="false"
fi

if [ "$RedisPwd" ]; then
set_redis_secret="  set_redis_secret: \"$RedisPwd\""
fi
if [ $installversion -ge 70 ]; then
  setIngress=false
else
  setIngress=true
fi

# Wirite Kudos Boards configuration
if [ $installversion == "80" ]; then
  if [ $installsubversion == "00" ]; then
    valid=1
    tag=XXXXX-XXXX
  fi
  if [ $installsubversion == "10" ]; then
    valid=1
    tag=XXXXX-XXXX
  fi
fi
if [ $installversion == "70" ]; then
  if [ $installsubversion == "00" ]; then
    valid=1
    tag=20201113-192158
  fi
fi
if [ $installversion == "65" ]; then
  if [ $installsubversion == "00" ]; then
    valid=1
    tag=20191120-214007
  fi
  if [ $installsubversion == "10" ]; then
    valid=1
    tag=20200306-180701
  fi
fi

if [ "$valid" != "1" ]; then
  echo "Not supported CP Version for Boards."
  exit 1
fi

if [ ! "$KudosPublicImages" == 1 -a "$installversion" -eq 70 ]; then
  kudosImage="  image:"
  kudosMinio="    name: kudosboards-minio"
  kudosWebfront="    name: kudosboards-webfront"
  kudosCore="    name: kudosboards-core"
  kudosLicence="    name: kudosboards-licence"
  kudosUser="    name: kudosboards-user"
  kudosApp="    name: kudosboards-boards"
  kudosProvider="    name: kudosboards-provider"
  kudosNotification="    name: kudosboards-notification"
fi

# ------------------------------------------------------------
# Process the templates 
# ------------------------------------------------------------

for template_file in ${source_dir}/*; do
	file_name=$(basename "${template_file}")
	echo "Processing file $file_name"
  template_str=$(cat "${template_file}")
	eval "echo \"${template_str}\"" > ${output_dir}/${file_name}
done

