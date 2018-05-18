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


# find my IP address, which will be on the interface the default route is configured on
myip=`ip route get 10.0.0.11 | awk 'NR==1 {print $NF}'`

echo "${myip} ${registry}" | sudo tee -a /etc/hosts

tar xf ${package_location} -O | sudo docker load
sudo docker images | grep -v REPOSITORY | grep -v ${registry} | awk '{print $1 ":" $2}' | xargs -n1 -I{} sudo docker tag {} ${registry}/{}
sudo docker images | grep ${registry} | awk '{print $1 ":" $2}' | sort | uniq | xargs -n1 sudo docker push 
