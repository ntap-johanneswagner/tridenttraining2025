## :trident: Prework - Get LoD Ready

For this Hands-on Workshop, we are going to use Lab on Demand. Please enroll yourself the following Lab:
https://labondemand.netapp.com/node/878

**The Lab guide is only needed for getting the usernames and passwords. Please ignore the tasks in the lab guide, everything you need is in this github repository.**

Access the host *rhel3* via putty and clone this github repo

```console
git clone https://github.com/ntap-johanneswagner/tridenttraining2025
```

After that, jump into the directory, modify the access of the prework script and run it. This script will prepare the lab for our excercises.

```console
cd tridenttraining2025
chmod 777 prework.sh
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

```console
helm install <name> netapp-trident/trident-operator --version 100.2506.2 --create-namespace --namespace <trident-namespace>
```

`<name>` will be the name of our release, usually we just call it "trident"  

`--version`defines the version of Trident. Unfortunately Helm requires semantic versioning, while Trident uses calendaric versioning. As a workaround we modified the version of the helmchart to be 100.`<YYMM>`.`<Patch>`. The June Release of 2025 with Patch 2 is 25.06.2, the Helm Chart Version is 100.2506.2  

`<trident-namespace>`is the place where the operator and Trident will be deployed. Usually we also use "trident" here.

As soon you fired the command above, the operator will start with the deployment. You can check this by discovering the pods in the namespace:
