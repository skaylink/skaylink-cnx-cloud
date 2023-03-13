#!/bin/bash
. ~/installsettings.sh

controller="connections-nginx-ingress-controller connections-nginx-ingress-controller-intern global-nginx-nginx-ingress-controller global-nginx-nginx-ingress-controller-extern global-nginx-ingress-nginx-controller"

for c in $controller; do
  echo
  echo "Check for Controller: $c"
 
  erg=$(kubectl get services --namespace $namespace $c)
  if [ $? -eq 0 ]; then
    lbhost=$(kubectl get services --namespace $namespace $c --output jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [ $? -eq 0 -a -n "$lbhost" ]; then
      echo "LB Hostname: $lbhost"
      lb_type=$(aws elbv2 describe-load-balancers --region us-west-2 --query "LoadBalancers[?DNSName=='$lbhost'].[Scheme,CanonicalHostedZoneId]" --output text)
      lb_type_array=($lb_type)
      if [ "${lb_type_array[0]}" = "internet-facing" ]; then
        echo "Public Load Balancer"
        ZONES="$HostedZoneIdPublic $HostedZoneId"
        dnsname=$ic_front_door
      else
        ZONES=$HostedZoneId
        dnsname=$master_ip
      fi
      lb_dns_zone=${lb_type_array[1]}

      for HostedZone in $ZONES; do
        echo "assign $lbhost to Zone ${HostedZone} to record $dnsname"
cat > /tmp/basic_dns.json <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$dnsname",
        "Type": "A",
        "AliasTarget": { 
          "HostedZoneId": "${lb_dns_zone}",
          "DNSName": "$lbhost",
          "EvaluateTargetHealth": false
        }
      }
    }
  ]
}
EOF
        echo
        aws route53 change-resource-record-sets --hosted-zone-id ${HostedZone} --region $AWSRegion --change-batch file:///tmp/basic_dns.json
        if [ $? -eq 0 ]; then
          echo "SUCCESS"
        else
          echo "FAILED !!!!!!!!"
        fi
        echo
        echo
      done
    else
      echo "Controller $c not LB Hostname found."
    fi
  else
    echo "Contorller $c does not exist."
  fi
done

