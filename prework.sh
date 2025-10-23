echo
echo "#######################################################################################################"
echo "# 1. UPGRADE HELM"
echo "#######################################################################################################"
echo

wget https://get.helm.sh/helm-v3.15.3-linux-amd64.tar.gz
tar -xvf helm-v3.15.3-linux-amd64.tar.gz
/bin/cp -f linux-amd64/helm /usr/local/bin/
rm -f helm-v3.15.3-linux-amd64.tar.gz

echo
echo "#######################################################################################################"
echo "# 2. MODIFY BASH.RC"
echo "#######################################################################################################"
echo

if [ $(more ~/.bashrc | grep kdesc | wc -l) -ne 1 ]; then

cp ~/.bashrc ~/.bashrc.bak
cat <<EOT >> ~/.bashrc
alias kc='kubectl create'
alias ka='kubectl apply' 
alias kg='kubectl get'
alias kdel='kubectl delete'
alias kx='kubectl exec -it'
alias kdesc='kubectl describe'
alias kedit='kubectl edit'
alias trident='tridentctl -n trident'
EOT
source ~/.bashrc
fi


echo
echo "#######################################################################################################"
echo "# 3. REMOVE Trident"
echo "#######################################################################################################"
echo

kubectl patch torc trident --type=merge -p '{"spec":{"wipeout":["crds"],"uninstall":true}}'
frames="/ | \\ -"
while [ $(kubectl get crd | grep trident | wc | awk '{print $1}') != 1 ];do
        for frame in $frames; do
                sleep 0.5; printf "\rWaiting for Trident to be removed $frame"
        done
done
helm uninstall trident -n trident
frames="/ | \\ -"
while [ $(kubectl get pods -n trident | wc | awk '{print $1}') != 0 ];do
        for frame in $frames; do
                sleep 0.5; printf "\rWaiting for Trident to be removed $frame"
        done
done
kubectl delete ns trident
helm repo remove netapp-trident
kubectl delete sc storage-class-iscsi
kubectl delete sc storage-class-nfs
kubectl delete sc storage-class-smb
kubectl delete sc storage-class-nvme

echo
echo "#######################################################################################################"
echo "# 4. ENABLE POD SCHEDULING ON THE CONTROL PLANE"
echo "#######################################################################################################"
echo

kubectl taint nodes rhel3 node-role.kubernetes.io/control-plane:NoSchedule-

echo
echo "#######################################################################################################"
echo "# 5. CACHING IMAGES"
echo "#######################################################################################################"
echo


TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq -r .token)
RATEREMAINING=$(curl --head -H "Authorization: Bearer $TOKEN" https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest 2>&1 | grep -i ratelimit-remaining | cut -d ':' -f 2 | cut -d ';' -f 1 | cut -b 1- | tr -d ' ')

if [[ $RATEREMAINING -lt 20 ]];then
  if ! grep -q "dockreg" /etc/containers/registries.conf; then
    echo
    echo "##############################################################"
    echo "# CONFIGURE MIRROR PASS THROUGH FOR IMAGES PULL"
    echo "##############################################################"
  cat <<EOT >> /etc/containers/registries.conf
[[registry]]
prefix = "docker.io"
location = "docker.io"
[[registry.mirror]]
prefix = "docker.io"
location = "dockreg.labs.lod.netapp.com"
EOT
  fi
fi

if [[ $(dnf list installed  | grep skopeo | wc -l) -eq 0 ]]; then
  echo "##############################################################"
  echo "# INSTALL SKOPEO"
  echo "##############################################################"
  dnf install -y skopeo
fi
skopeo login registry.demo.netapp.com  -u registryuser -p Netapp1!

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/trident 2> /dev/null | grep 25.06.1 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Multi-Arch TRIDENT Into Private Repo"
  echo "##############################################################"
  skopeo copy --multi-arch all docker://docker.io/netapp/trident:25.06.1 docker://registry.demo.netapp.com/trident:25.06.1
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/trident-operator 2> /dev/null | grep 25.06.1 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy TRIDENT OPERATOR Into Private Repo"
  echo "##############################################################"
  skopeo copy docker://docker.io/netapp/trident-operator:25.06.1 docker://registry.demo.netapp.com/trident-operator:25.06.1
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/trident-autosupport 2> /dev/null | grep 25.06.0 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy TRIDENT AUTOSUPPORT Into Private Repo"
  echo "##############################################################"
  skopeo copy docker://docker.io/netapp/trident-autosupport:25.06.0 docker://registry.demo.netapp.com/trident-autosupport:25.06.0
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/ghost 2> /dev/null | grep 2.6-alpine | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy GHOST 2.6 Into Private Repo"
  echo "##############################################################"
  skopeo login registry.demo.netapp.com  -u registryuser -p Netapp1!
  skopeo copy docker://docker.io/ghost:2.6-alpine docker://registry.demo.netapp.com/ghost:2.6-alpine
else
  echo
  echo "##############################################################"
  echo "# GHOST 2.6 already in the Private Repo - nothing to do"
  echo "##############################################################"
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/busybox 2> /dev/null | grep 1.35.0 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Busybox 1.35.0 Into Private Repo"
  echo "##############################################################"
  skopeo login registry.demo.netapp.com  -u registryuser -p Netapp1!
  skopeo copy docker://docker.io/busybox:1.35.0 docker://registry.demo.netapp.com/busybox:1.35.0
else
  echo
  echo "##############################################################"
  echo "# Busybox 1.35.0 already in the Private Repo - nothing to do"
  echo "##############################################################"
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/mysql 2> /dev/null | grep 5.7.30 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy MYSQL 5.7.30 Into Private Repo"
  echo "##############################################################"
  skopeo login registry.demo.netapp.com  -u registryuser -p Netapp1!
  skopeo copy docker://docker.io/mysql:5.7.30 docker://registry.demo.netapp.com/mysql:5.7.30
else
  echo
  echo "##############################################################"
  echo "# MYSQL 5.7.30 already in the Private Repo - nothing to do"
  echo "##############################################################"
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/dbench 2> /dev/null | grep 1.0.0 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy DBench 1.0.0 Into Private Repo"
  echo "##############################################################"
  skopeo login registry.demo.netapp.com  -u registryuser -p Netapp1!
  skopeo copy docker://docker.io/ndrpnt/dbench:1.0.0 docker://registry.demo.netapp.com/dbench:1.0.0
else
  echo
  echo "##############################################################"
  echo "# DBench 1.0.0 already in the Private Repo - nothing to do"
  echo "##############################################################"
fi

if [[ $(skopeo list-tags docker://registry.demo.netapp.com/mongo 2> /dev/null | grep 3.2 | wc -l) -eq 0 ]]; then
  echo
  echo "##############################################################"
  echo "# Skopeo Copy Mongo 3.2 Into Private Repo"
  echo "##############################################################"
  skopeo login registry.demo.netapp.com  -u registryuser -p Netapp1!
  skopeo copy docker://docker.io/mongo:3.2 docker://registry.demo.netapp.com/mongo:3.2
else
  echo
  echo "##############################################################"
  echo "# Mongo 3.2 already in the Private Repo - nothing to do"
  echo "##############################################################"
fi

echo
echo "#######################################################################################################"
echo "# 6. CREATE LABSVM"
echo "#######################################################################################################"
echo

mkdir -p /etc/ansible
if [ -f /etc/ansible/hosts ]; then mv /etc/ansible/hosts /etc/ansible/hosts.bak; fi;
cp hosts /etc/ansible/ 

ansible-playbook labsvm.yaml