Persistent Installation of PostgreSQL and Alfresco on Kubernetes
===

this example describes how to run a persistent installation of [Alfresco Community Edition](https://community.alfresco.com/) and [PostgreSQL](https://www.postgresql.org/) on Kubernetes. We'll use the official official [postgres](https://hub.docker.com/_/postgres/) and [Alfresco](https://hub.docker.com/r/fjudith/alfresco/) [Docker](https://www.docker.com) images for this installation.

Demonstrated Kubernetes Concepts:

* [Persistent Volumes](http://kubernetes.io/docs/user-guide/persistent-volumes/) to define persistent disks (disk lifecycle not tied to the Pods).
* [Services](https://kubernetes.io/docs/concepts/services-networking/service/) to enable Pods to locate one another.
* [NodePort](http://kubernetes.io/docs/user-guide/services/#node-port) to expose Services externally.
* [Deployments](http://kubernetes.io/docs/user-guide/deployments/) to ensure Pods stay up and running.
* [Secrets](http://kubernetes.io/docs/user-guide/secrets/) to store sensitive passwords.

## Quickstart

Put your desired PostgreSQL in file called `alfresco.postgres.password.txt` with no trailing newline. The first `tr` commands will remove the newline if your editor added one.

**Note**: if your cluster enforces **selinux** and you will be using [Host Path](https://github.com/fjudith/docker-alfresco/tree/master/kubernetes#host-path) for storage, then please follow this [extra step](https://github.com/fjudith/docker-alfresco/tree/master/kubernetes#selinux).

```bash
# PostgreSQL and alfresco persistent volumes
kubectl create -f https://raw.githubusercontent.com/fjudith/docker-alfresco/master/kubernetes/alfresco-pv.yaml

# PostgreSQL and Alfresco with persistent volumes and secret file
tr --delete '\n' <alfresco.postgres.password.txt >.strippedpassword.txt && mv .strippedpassword.txt alfresco.postgres.password.txt
kubectl create secret generic alfresco-postgres-pass --from-file=alfresco.postgres.password.txt
kubectl create -f https://raw.githubusercontent.com/fjudith/docker-alfresco/master/kubernetes/alfresco-dp.yaml
```

## Cluster Requirements

Kubernetes runs in a variety of environments and is inherently modular. Not all clusters are the same. These are the requirements for this example.

* Kubernetes version 1.2 is required due to using newer features, such as PV Claims and Deployments. Run `kubectl version` to see your cluster version.
* [Cluster DNS](http://kubernetes.io/docs/user-guide/secrets/) will be used for service discovery.
* [NodePort](http://kubernetes.io/docs/user-guide/services/#node-port) will be used to access Alfresco.
* [Persistent Volume Claims](http://kubernetes.io/docs/user-guide/persistent-volumes/) are used. You must create Persistent Volumes in your cluster to be claimed. This example demonstrates how to create three types of volumes, but any volume is sufficient.

Consult a [Getting Started Guide](http://kubernetes.io/docs/getting-started-guides/) to set up a cluster and the [kubectl](http://kubernetes.io/docs/user-guide/prereqs/) command-line client.

## Decide where you will store your data

PostgreSQL and Alfresco will each use [Persistent Volumes](http://kubernetes.io/docs/user-guide/persistent-volumes/) to store their data. We will use a Persistent Volume Claim to claim an aivailable persistent volume. Labels will be leveraged to provide static mapping from Volume Claim down to Persistent Volume. This example covers HostPath and CephFS volumes. Choose one of the two, or see [Types of Persisten Volumes](http://kubernetes.io/docs/user-guide/persistent-volumes/#types-of-persistent-volumes) for more options.

### Host Path

Host paths are volumes mapped to directories on the host. **These should be used for testing or single-node clusters only**.
the data will not be moved between nodes if the pod is recreated on a new node. If the pod is deleted and recreated on a new node, **data will be lost**.

#### Ownership and Permissions issues

By default Host Path subdirectories are owned by the user running the Docker deamon (_i.e. root:root_) with MOD 755.
This is a big issue for images that runs with a different user as per [Dockerfile Best Practices](https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/#user) as it will not have permissions to write.

We have three options are available to solve this issue:

1. **Change MOD** to `777`/`a+rwt` of the Persistent Volume directory. 
   * Meaning all Pods or user accessing the node will also get read-write access to the data persisted
2. **Build a deriving image that enforce root** (_e.g._ Add `USER root` to the Dockerfile).
   * Requires you to maintain the image up-to-date.
3. **Create user and group in the node**, with the exact same `name`, `uid`, `gid` and change ownership of the Persistent Volume.
   * Secure but requires more administrative effort (_i.e._ stateless run to identify user attributes, add user to the node, pre-create persistent volume path with appropriate ownership. Thus create the pod).

We will **none** of these options in this guide as the [Alfresco]() image runs as `root` user.

#### SELinux

On systems supporting selinux it is preferred to leave it _enabled/enforcing_. However, docker containers mount the host path with the _"svirt_sandbox_file_t"_ label type, which is incompatible with the default label type for /var/lib/kubernetes/pv (_"var_lib_t"), resulting in a permissions error when the postgres container attempts to `chown`_/var/lib/postgres/data_. Therefore, on selinux systems using host path, you should pre-create the host path directory (/var/lib/kubernetes/pv/) and change it'is selinux label type to "_svirt_sandbox_file_t", as follows:

```bash
## on every node:
sudo mkdir -p /var/lib/kubernetes/pv
sudo chmod a+rwt /var/lib/kubernetes/pv

sudo mkdir -p \
  /var/lib/kubernetes/pv/alfresco-db/db \
  /var/lib/kubernetes/pv/alfresco-dblog/log \
  /var/lib/kubernetes/pv/alfresco-data/data \
  /var/lib/kubernetes/pv/alfresco-log/log

sudo chcon -Rt svirt_sandbox_file_t /var/lib/kubernetes/pv
```

Continuing with host path, create the persistent volume objects in Kubernetes using [alfresco-pv.yaml](https://github.com/fjudith/docker-alfresco/tree/master/kubernetes/alfresco-pv.yaml):

```bash
export KUBE_REPO=https://raw.githubusercontent.com/fjudith/docker-alfresco/master/kubernetes
kubectl create -f $KUBE_REPO/alfresco-pv.yaml
```

Use [Secret](http://kubernetes.io/docs/user-guide/secrets/) objects to store the PostgreSQL passwords. First create respective files (in the same directory as the Alfresco sample files) called `alfresco.postgres.password.txt`, then save your password in it. Make sure to not have a trailing newline at the end of the password. The first `tr` command will remove the newline if your editor added one. Then, create the Secret object.

```bash
# PostgresSQL secret file
tr --delete '\n' <alfresco.postgres.password.txt >.strippedpassword.txt && mv .strippedpassword.txt alfresco.postgres.password.txt
kubectl create secret generic alfresco-postgres-pass --from-file=alfresco.postgres.password.txt
```

Postgres secret is referenced by the PostgreSQL and Alfresco pod configuration so that those pods will have access to it. The PostgresSQL pod will set the database password, and the Alfresco pod will use the password to access the database.
The Alfresco password is not referenced by the Alfresco pod configuration as it use the default admin password `admin:admin`.

**Note**: if LDAP authentication is enabled use same method to store the BIND_DN password used by the Alfresco directory synchronization module.

## Deploy PostgreSQL and Alfresco

Now that the persistent disks and secrets are defined, the Kubernetes pods can be launched. Start PostgresSQL using [alfresco-dp.yaml](https://github.com/fjudith/docker-alfresco/tree/master/kubernetes/alfresco-dp.yaml).

```bash
kubectl create -f $KUBE_REPO/alfresco-dp.yaml
```
Take a look at [alfresco-dp.yaml](https://github.com/fjudith/docker-alfresco/tree/master/kubernetes/alfresco-dp.yaml), and note that we've defined four volumes mounts for:

For `alfresco-pg`

* /var/lib/postgres/data
* /var/log/postgres

For `alfresco`

* /alfresco/alf_data
* /alfresco/logs/tomcat/logs

And then created a Persistent Volume Claim that each looks for a 10GB volume. This claim is satisfied by any volume that meets the requirements, in our case one of the volumes we created above.

Also lookt at the `env` section and see that we specified the password by referencing the secret `alfresco-posgres-pass`that we created above. Secrets can have multiple key:value pairs. Ours has only one key `alfresco.postgres.password.txt` which was the name of the file we used to create de secret. The [PostgresSQL image](https://hub.docker.com/_/postgres/) sets the database password using the `POSTGRES_PASSWORD` environment variable, where the [Alfresco image](https://hub.docker.com/u/fjudith/alfresco/) sets the database user access passord using the `DB_PASSWORD` environment variable.

It my takes a short period before the new pods reach the `Running` state. List all pods to see the status of these new pods.

```bash
kubectl get pods --label=alfresco
```

```
NAME                           READY     STATUS    RESTARTS   AGE
alfresco-pg-2220682670-q280y   1/1       Running   0          1m
alfresco-3331793781-r391z      1/1       Running   0          1m
```

Kubernetes logs the stderr and stdout for each pod. Take a look at the logs for a pod by using `kubectl log`. Copy the pod name from the `get pods`command, and then:

```bash
kubectl logs <pod-name>
```

```
...
PostgreSQL init process complete; ready for start up.

LOG:  database system was shut down at 2017-04-12 12:14:19 UTC
LOG:  MultiXact member wraparound protections are now enabled
LOG:  database system is ready to accept connections
LOG:  autovacuum launcher started
```

Also in [alfresco-dp.yaml](https://github.com/fjudith/docker-alfresco/tree/master/kubernetes/alfresco-dp.yaml) we created a service to allow ofther pods to reach this postgres instance. the name is `alfresco-pg` which resolves to the pod IP.

Up to this point two Deployment, two Pod, four PVC, two Service, two Endpoint, four PVs, and one Secrets have been created, shown below:

```bash
kubectl get deployment,pod,svc,endpoints,pvc -l app=alfresco -o wide && \
  kubectl get secret alfresco-postgres-pass && \
  kubectl get pv
```

```
                    
```

# Visit your new Alfresco

Now, we can visit running Waarp-R66 app. Use the node IP running the alfresco pod and the port mapped to `8080/TCP` you obtained above.

```
http://<node-ip>:<port>/share
```

You should see the familiar Alfresco login page.

![Waarp-R66 login page](https://github.com/fjudith/docker-alfresco/raw/201704/kubernetes/Alfresco.png)