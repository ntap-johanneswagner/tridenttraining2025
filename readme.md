## :trident: Prework - Get LoD Ready

For this Hands-on Workshop, we are going to use Lab on Demand. Please enroll yourself the following Lab:
https://labondemand.netapp.com/node/878

First a big thank you to [Yves Weisser](github.com/yvosonthehub) as his LabNetApp repository is the foundation of this training material. I highly recommend to have look at his work and redo this from time to time as he is doing a tremendous job, explaining all the Trident functionalities with real good examples. 

**The Lab guide is only needed for getting the usernames and passwords. Please ignore the tasks in the lab guide, everything you need is in this github repository.**

Access the host *rhel3* via putty and clone this github repo

```console
git clone https://github.com/ntap-johanneswagner/tridenttraining2025
```

After that, jump into the directory, and run the prework script This script will prepare the lab for our excercises.

```console
cd /root/tridenttraining2025/
./prework.sh
```

This will take some minutes...

## :trident: Scenario 01 - Install Trident
____
There are multiple ways to install Trident, the most common is working with the operator, deployed by Helm. Helm helps you manage Kubernetes applications by utilizing so called Helm Charts that help you to define, install and upgrade Kubernetes based applications.
Helm is already running in this lab so the first thing we need to do is to add the repository, where the Trident Helm Chart is.

```console
helm repo add netapp-trident https://netapp.github.io/trident-helm-chart
```

After this, we can tell Helm to install the operator.  
It's not unusual that customers don't allow to access public repositorys and have their own image registry. While we can access public registries in LoD, we have to fight with the Docker image pull rate limitation. Due to this, we are also working with a private registry, the necessary images are already cached there and the secret to access it is also created. 
The default command to install trident without any customization like private registry is looking like this:
```console
helm install <name> netapp-trident/trident-operator --version 100.2506.2 --create-namespace --namespace <trident-namespace>
```

`<name>` will be the name of our release, usually we just call it "trident"  

`--version`defines the version of Trident. Unfortunately Helm requires semantic versioning, while Trident uses calendaric versioning. As a workaround we modified the version of the helmchart to be 100.`<YYMM>`.`<Patch>`. The June Release of 2025 with Patch 2 is 25.06.2, the Helm Chart Version is 100.2506.2  

`<trident-namespace>`is the place where the operator and Trident will be deployed. Usually we also use "trident" here.

As we want to use a private registry, we modify the command a little bit:

```console
helm install <name> netapp-trident/trident-operator --version 100.2506.2 --create-namespace --namespace <trident-namespace> --set tridentAutosupportImage=registry.demo.netapp.com/trident-autosupport:25.06.0,operatorImage=registry.demo.netapp.com/trident-operator:25.06.2,tridentImage=registry.demo.netapp.com/trident:25.06.2,tridentSilenceAutosupport=true,windows=true,imagePullSecrets[0]=regcred
```

As soon you fired the command above (ensure that you place the right release name and namespace name!), the operator will start with the deployment. You can check this by discovering the pods in the namespace:

```console
kubectl get pods -n <trident-namespace>
```

If everything is successfull you should see one controller pod and one node pod per kubernetes node.

As our cluster has 3 linux and 2 windows nodes, the output should look like this:
```console
k get pods -n trident

NAME                                 READY   STATUS    RESTARTS   AGE
trident-controller-5c6c9856d-jd8qc   6/6     Running   0          3m25s
trident-node-linux-6r5h8             2/2     Running   0          3m24s
trident-node-linux-cjkqq             2/2     Running   0          3m24s
trident-node-linux-th7mx             2/2     Running   0          3m24s
trident-node-windows-8cfzg           3/3     Running   0          3m23s
trident-node-windows-nlfqs           3/3     Running   0          3m23s
trident-operator-77f4f5f7f5-4wfb6    1/1     Running   0          4m14s
```

## :trident: Scenario 02 - Configure Trident
**Remember: All required files are in the folder */root/tridenttraining2025/scenario02* please ensure that you are in this folder now. You can do this with the command** 
```console
cd /root/tridenttraining2025/scenario02
```
Installation is quiet easy and straight forward, the fun begins with the configuration. 

### Backends

Via a TridentBackend, we are telling Trident how to contact the storagesystem and which driver to use. There are two ways to create Backends. 1. via tridentctl, 2. via a TridentBackenConfiguration CRD in K8s. The second way is the most common today, so we use it for our excercise. If you want to find out how to do it with tridentctl, have a look at the documentation: https://docs.netapp.com/us-en/trident/trident-use/backend_ops_tridentctl.html#create-a-backend

You will see different example configurations in the folder, to cover the different drivers. 

backend-ontap-nas.yaml is an example for using the ontap-nas driver.  
backend-ontap-nas-eco.yaml is an example for using the ontap-nas-economy driver.  
backend-ontap-san.yaml is an example for using the ontap-san driver using iSCSI.  
backend-ontap-san-eco.yaml is an example for using the ontap-san-economy driver using iSCSI.  

Edit each of them using your favorite editor and insert the missing values. Please use the SVM "labsvm" for this tasks as the nassvm and sansvm is a leftover from the original lab.
Small hint: To find out the network of your k8s nodes, *kubectl get nodes -o wide* might be helpful. 

You might have noticed that there is a reference to the credentials, called secret-svm. To provide Trident the necessary credentials to login into the svm, there are different possibilities. Trident supports local users, certificates and LDAP users. In most of the cases local users are used, so we do here.

Edit the secret-svm.yaml file and fill in user and password (Hint for getting the password of the trident user if you don't want to reset it: Look into the ansible playbook at labsvm.yaml). You will also see that there are values for the chap configuration provided. As we specified *useChap: true* in the backends, we need to tell Trident these values as Trident will do this configuration at the SVM. 

After you edited all the files, apply them to your k8s cluster:

```console
kubectl apply -f secret-svm.yaml
kubectl apply -f backend-ontap-nas.yaml
kubectl apply -f backend-ontap-nas-eco.yaml
kubectl apply -f backend-ontap-san.yaml
kubectl apply -f backend-ontap-san-eco.yaml 
```

As soon as they are applied, you can check the status of them via *kubectl get tbc -n trident*

The output should look like this:

```console
kubectl get tbc -n trident
‌kubectl get tbc -n trident
NAME                        BACKEND NAME   BACKEND UUID                           PHASE   STATUS
backend-ontap-nas           nas            1e4ff09a-b0ce-4709-8797-908139addd3f   Bound   Success
backend-ontap-nas-economy   nas-economy    ecccd445-93dd-4c0b-a8c3-8e7955654620   Bound   Success
backend-ontap-san           san            6a5068b5-24f1-4bc0-8376-babc438425ba   Bound   Success
backend-ontap-san-economy   san-economy    5eb0274f-ffe6-460e-a83b-54a87f29c9b1   Bound   Success
```

If everything is bound, all good. If the status is different to bound, inspect it via *kubectl describe tbc `<tbcname>` -n `<trident-namespace>`* find the errors and fix them. 

### StorageClass

The second thing we need to get Trident working, is a StorageClass that refers the PVC towards Trident.

In the folder you will find also some prepared files.

sc-nas.yaml is the StorageClass definition for the ontap-nas driver.  
sc-nas-eco.yaml is the StorageClass definition for the ontap-nas-economy driver.  
sc-san.yaml is the StorageClass definition for the ontap-san driver.  
sc-san-eco.yaml is the StorageClass definition for the ontap-nas-economy driver.

Have a quick look at them, this time there is no need for edits, and apply them:

```console
kubectl apply -f sc-nas.yaml
kubectl apply -f sc-nas-eco.yaml
kubectl apply -f sc-san.yaml
kubectl apply -f sc-san-eco.yaml 
```

Check the status with *kubectl get sc*

```console
kubectl get sc

NAME               PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
sc-nas (default)   csi.trident.netapp.io   Delete          Immediate           true                   29s
sc-nas-eco         csi.trident.netapp.io   Delete          Immediate           true                   29s
sc-san             csi.trident.netapp.io   Delete          Immediate           true                   29s
sc-san-eco         csi.trident.netapp.io   Delete          Immediate           true                   10s
```

### VolumeSnapshotClass

While having backend and storageclass configured is enough to provide persistent storage, sooner or later there might be the need for doing so called CSI-Snapshots. For this a few other things are needed. 
First the snapshot controller needs to be installed/ enabled on the cluster. This should be the case in most of the modern distributions, however it happens still that its missing. If you want to have more details on how to install it, this link is a good read: https://github.com/kubernetes-csi/external-snapshotter
In our cluster, it's already installed, let's check this:  

```console
kubectl get crd | grep volumesnapshot
volumesnapshotclasses.snapshot.storage.k8s.io         2024-04-27T21:06:08Z
volumesnapshotcontents.snapshot.storage.k8s.io        2024-04-27T21:06:08Z
volumesnapshots.snapshot.storage.k8s.io               2024-04-27T21:06:08Z

kubectl get all -n kube-system -l app=snapshot-controller
NAME                                       READY   STATUS    RESTARTS   AGE
pod/snapshot-controller-54f7648f78-lvgp2   1/1     Running   6          93d
pod/snapshot-controller-54f7648f78-p9gvk   1/1     Running   6          93d

NAME                                             DESIRED   CURRENT   READY   AGE
replicaset.apps/snapshot-controller-54f7648f78   2         2         2       93d
```

Aside from the 3 CRD & the Controller StatefulSet, the following objects have also been created during the installation of the CSI Snapshot feature:  
- serviceaccount/snapshot-controller
- clusterrole.rbac.authorization.k8s.io/snapshot-controller-runner
- clusterrolebinding.rbac.authorization.k8s.io/snapshot-controller-role
- role.rbac.authorization.k8s.io/snapshot-controller-leaderelection
- rolebinding.rbac.authorization.k8s.io/snapshot-controller-leaderelection

This base is needed for every CSI-driver that needs CSI-snapshots the next what is needed is a so called VolumeSnapshotClass that tells k8s to address the csi driver for the snapshot. The necessary file is already in your folder, have a look at it and apply it afterwards.

```console
kubectl apply -f volumesnapshotclass.yaml
```

## :trident: Scenario 03 - Testing Trident with the first applications
**Remember: All required files are in the folder */root/tridenttraining2025/scenario03* please ensure that you are in this folder now. You can do this with the command** 
```console
cd /root/tridenttraining2025/scenario03
```

It's quiet important to understand that even if Trident creates Volumes successful and you can see the PVC/PV objects created in K8s, there is still a ton of things that can go wrong. To verfiy that installation and configuration is successful, it's important to run some kind of test application to verify that also the worker nodes were correctly prepared. 

There are 5 files in the folder. One will create a pod that has 4 PVCs, one for each storage class. The others have only one covering one sc. 

Apply them and have a look whether all works or if something fails. 
Helpful commands for this might be:

```console
kubectl get namespace
kubectl get pods,pvc -n <namespace>
```

If there are errors, the first you should do is to have a look by using kubectl describe. Possible objects to start: Pod, PVC, trident controller.

Also let's try out whether we really can write data and read it again:

```console
kubectl exec -n allstorageclasses $(kubectl get pod -n allstorageclasses -o name) -- sh -c 'echo "Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-nas driver!" > /nas/test.txt'
kubectl exec -n allstorageclasses $(kubectl get pod -n allstorageclasses -o name) -- sh -c 'echo "Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-nas-economy driver!" > /naseco/test.txt'
kubectl exec -n allstorageclasses $(kubectl get pod -n allstorageclasses -o name) -- sh -c 'echo "Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-san driver!" > /san/test.txt'
kubectl exec -n allstorageclasses $(kubectl get pod -n allstorageclasses -o name) -- sh -c 'echo "Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-san-economy driver!" > /saneco/test.txt'
kubectl exec -n nasapp $(kubectl get pod -n nasapp -o name) -- sh -c 'echo "Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-nas driver!" > /nas/test.txt'
kubectl exec -n nasecoapp $(kubectl get pod -n nasecoapp -o name) -- sh -c 'echo "Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-nas-economy driver!" > /naseco/test.txt'
kubectl exec -n sanapp $(kubectl get pod -n sanapp -o name) -- sh -c 'echo "Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-san driver!" > /san/test.txt'
kubectl exec -n sanecoapp $(kubectl get pod -n sanecoapp -o name) -- sh -c 'echo "Hello little Container! Trident will care about your persistent Data that is written to a pvc utilizing the ontap-san-economy driver!" > /saneco/test.txt'

```


```console
kubectl exec -n allstorageclasses $(kubectl get pod -n allstorageclasses -o name) -- more /nas/test.txt
kubectl exec -n allstorageclasses $(kubectl get pod -n allstorageclasses -o name) -- more /naseco/test.txt
kubectl exec -n allstorageclasses $(kubectl get pod -n allstorageclasses -o name) -- more /san/test.txt
kubectl exec -n allstorageclasses $(kubectl get pod -n allstorageclasses -o name) -- more /saneco/test.txt
kubectl exec -n nasapp $(kubectl get pod -n nasapp -o name) -- more /nas/test.txt
kubectl exec -n nasecoapp $(kubectl get pod -n nasecoapp -o name) -- more /naseco/test.txt
kubectl exec -n sanapp $(kubectl get pod -n sanapp -o name) -- more /san/test.txt
kubectl exec -n sanecoapp $(kubectl get pod -n sanecoapp -o name) -- more /saneco/test.txt
```

## :trident: Scenario 04 - Backup anyone? Installation of Trident protect
**Remember: All required files are in the folder */root/tridenttraining2025/scenario04* please ensure that you are in this folder now. You can do this with the command** 
```console
cd /root/tridenttraining2025/scenario04
```

As K8s based applications become more and more important, people ask the mean questions around backup, dr and so on.

Since October 2024, Trident has a small add-on, called Trident protect. This little application is meant to do k8s native backup & DR.

We do this again utilizing a private registry. To access it we need a secret again, lets creat this first:

```console
kubectl create ns trident-protect
kubectl create secret docker-registry regcred --docker-username=registryuser --docker-password=Netapp1! -n trident-protect --docker-server=registry.demo.netapp.com
```

We are going to use parameters gathered in the trident_protect_helm_values.yaml file.
Now we can add the helm repository and install trident protect:

```console
helm repo add netapp-trident-protect https://netapp.github.io/trident-protect-helm-chart/
helm registry login registry.demo.netapp.com -u registryuser -p Netapp1!

helm install trident-protect netapp-trident-protect/trident-protect --set clusterName=lod1 --version 100.2506.0 --namespace trident-protect -f trident_protect_helm_values.yaml
```

After a very short time you should be able to see Trident protect being installed successfully. 
```console
kubectl get pods -n trident-protect
NAME                                                           READY   STATUS    RESTARTS   AGE
trident-protect-controller-manager-6454f4776f-6ls7v            2/2     Running   0          1h
```

Trident Protect CR can be configured with YAML manifests or CLI.  
Let's install its CLI which avoids making mistakes when creating the YAML files:  
```bash
cd
curl -L -o tridentctl-protect https://github.com/NetApp/tridentctl-protect/releases/download/25.06.0/tridentctl-protect-linux-amd64
chmod +x tridentctl-protect
mv ./tridentctl-protect /usr/local/bin

curl -L -O https://github.com/NetApp/tridentctl-protect/releases/download/25.02.0/tridentctl-completion.bash
mkdir -p ~/.bash/completions
mv tridentctl-completion.bash ~/.bash/completions/
source ~/.bash/completions/tridentctl-completion.bash

cat <<EOT >> ~/.bashrc
source ~/.bash/completions/tridentctl-completion.bash
EOT
```

The CLI will appear as a new sub-menu in the _tridentctl_ tool.  
```bash
tridentctl-protect version
25.06.0
```

## :trident: Scenario 05 - Trident protect initial configuration

There are not many "administrative" tasks when it comes to Trident protect. It's installation (what we've done in Scenario04) and creating the AppVaults.

An AppVault is our backup target, or said differently the single source of truth when it comes to restores. We can loose everything, as long as we still have the AppVault we can start restores, even if the whole K8s Cluster and the original storage system was destroyed completely.

Several applications can share the same bucket, through the same AppVault.  
If you have only one bucket available (like in this lab), one AppVault per Trident Protect is enough.  

Let's see how we can create an AppVault in the lab.  
We first need to retrieve the bucket _access key_ & _secret_.  

During the prework, a s3-svm was created already. In the output file (/root/tridenttraining2025/ansible_S3_SVM_result.txt) of the ansible-playbook you should be able to find the key. 
```text
TASK [Print ONTAP Response for S3 User create] *********************************
ok: [localhost] => {
    "msg": [
        "SAVE THESE credentials for: S3user",
        "user access_key: EO1XP61T31I8EDGUZ1PM ",
        "user secret_key: SthzvJ1S_QY4N3ng_r5n2L8hPA4tdCVtPc6D14gx "
    ]
}
```
If you don't have this file at hand, you can connect to ONTAP in cli and retrieve the keys in advanced mode:  
```bash
cluster1::> set -priv advanced

cluster1::*> vserver object-store-server user show -vserver svm_s3
Vserver     User            ID       Key Time To Live Key Expiry Time
----------- --------------- -------- ---------------- -----------------
svm_s3      root            0        -                -
Access Key: -
Secret Key: -
   Comment: Root User
svm_s3      S3user          1        -                -
Access Key: EO1XP61T31I8EDGUZ1PM
Secret Key: SthzvJ1S_QY4N3ng_r5n2L8hPA4tdCVtPc6D14gx
   Comment:
2 entries were displayed.
```

Now that you know where to retrieve those keys, let's create variables that we will use a few times:  
```bash
BUCKETKEY=EO1XP61T31I8EDGUZ1PM
BUCKETSECRET=SthzvJ1S_QY4N3ng_r5n2L8hPA4tdCVtPc6D14gx
```
Creating an AppVault requires a secret where the keys are stored:  
```bash
kubectl create secret generic -n trident-protect s3-creds --from-literal=accessKeyID=$BUCKETKEY --from-literal=secretAccessKey=$BUCKETSECRET
```
You can now proceed with the AppVault creation & validation (_on both Kubernetes clusters_):  
```bash
$ tridentctl protect create appvault OntapS3 ontap-vault -s s3-creds --bucket s3lod --endpoint 192.168.0.230 --skip-cert-validation --no-tls -n trident-protect
$ tridentctl protect get appvault -n trident-protect
+--------------+----------+-----------+------+-------+
|     NAME     | PROVIDER |   STATE   | AGE  | ERROR |
+--------------+----------+-----------+------+-------+
|  ontap-vault | OntapS3  | Available |   3h |       |
+--------------+----------+-----------+------+-------+
```
If the bucket is listed as _available_, then the process was successful.  

You can also install a S3 browser, which can be quite useful.  
I tend to often use the one provided by AWS, which can be quite handy:  
```bash
cd
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws

mkdir ~/.aws
cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = $BUCKETKEY
aws_secret_access_key = $BUCKETSECRET
EOF
```

2 commands that could be useful to list the content of the bucket:  
```bash
aws s3 ls --no-verify-ssl --endpoint-url http://192.168.0.230 s3://s3lod --summarize
aws s3 ls --no-verify-ssl --endpoint-url http://192.168.0.230 s3://s3lod --recursive --summarize
```