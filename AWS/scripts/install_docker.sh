#!/bin/bash

if [ -f "/etc/os-release" ]; then
  . /etc/os-release

  OSID=$ID
  OSVersion_ID=$VERSION_ID
  OSMajorVersion=${OSVersion_ID%%.*}
  INSTALLED=0

  if [ "$OSID" == "centos" ]; then
    if [ $OSMajorVersion -eq 8 ]; then
      ## CentOS 8
      yum -y install docker-ce

      systemctl daemon-reload
      systemctl enable docker
      systemctl restart docker

      usermod -a -G docker $USER
      INSTALLED=1
    fi
  fi
  if [ "$OSID" == "almalinux" ]; then
    yum -y install podman

    systemctl daemon-reload
    systemctl enable podman
    systemctl restart podman
    INSTALLED=1
  fi
  if [ $INSTALLED == 0 ]; then
    echo "ERROR: Unknown distribution or version."
    echo "Correct installation procedure is not known."
    echo "Please install manually."
  fi
else
  echo "ERROR: File /etc/os-release not found in your distribution."
  echo "Correct installation procedure is not known."
  echo "Please install manually."
fi
