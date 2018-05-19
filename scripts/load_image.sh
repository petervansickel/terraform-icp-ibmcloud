#!/bin/bash

while getopts ":p:r:" arg; do
    case "${arg}" in
      p)
        package_location=${OPTARG}
        ;;
      r)
        registry=${OPTARG}
        ;;
    esac
done

# find my private IP address, which will be on the interface the default route is configured on
myip=`ip route get 10.0.0.11 | awk 'NR==1 {print $NF}'`

echo "${myip} ${registry}" | sudo tee -a /etc/hosts
echo "Unpacking ${package_location} ..."
pv ${package_location} | tar zxf - -O | sudo docker load

sudo mkdir -p /registry
sudo mkdir -p /etc/docker/certs.d/${registry}
sudo cp /etc/registry/registry-cert.pem /etc/docker/certs.d/${registry}/ca.crt

sudo docker run -d \
  --restart=always \
  --name registry \
  -v /etc/registry:/certs \
  -v /registry:/registry \
  -e REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/registry \
  -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry-cert.pem \
  -e REGISTRY_HTTP_TLS_KEY=/certs/registry-key.pem  \
  -p 443:443 \
  registry:2

sudo docker images | grep -v REPOSITORY | grep -v ${registry} | awk '{print $1 ":" $2}' | xargs -n1 -I{} sudo docker tag {} ${registry}/{}
sudo docker images | grep ${registry} | awk '{print $1 ":" $2}' | sort | uniq | xargs -n1 sudo docker push
