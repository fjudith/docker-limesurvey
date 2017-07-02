CephFS persistent installation of MariaDB and LimeSurvey on Kubernetes
===

this example describes how to run a persistent installation of [LimeSurvey](https://www.limesurvey.org) and [MariaDB](https://mariadb.org) on Kubernetes. We'll use the official official [mariadb](https://hub.docker.com/_/mariadb/) and [LimeSurvey](https://hub.docker.com/r/fjudith/limesurvey/) [Docker](https://www.docker.com) images for this installation.
Storage will be provided by Kubernetes [Ceph Filesystem](https://github.com/ceph/ceph-docker) to bring fault tolerance to Pods persistent data.

Demonstrated Kubernetes Concepts:

* [Persistent Volumes](http://kubernetes.io/docs/user-guide/persistent-volumes/) to define persistent disks (disk lifecycle not tied to the Pods).
* [Services](https://kubernetes.io/docs/concepts/services-networking/service/) to enable Pods to locate one another.
* [NodePort](http://kubernetes.io/docs/user-guide/services/#node-port) to expose Services externally.
* [Deployments](http://kubernetes.io/docs/user-guide/deployments/) to ensure Pods stay up and running.
* [Secrets](http://kubernetes.io/docs/user-guide/secrets/) to store sensitive passwords.

## Quickstart

Put your desired `root` and `limesurvey` MariaDB password in distinguished files called `root.limesurvey.mariadb.password.txt` and `limesurvey.mariadb.password.txt`, with no trailing newline. The first `tr` commands will remove the newline if your editor added one.

**Note**: if your cluster enforces **selinux** and you will be using [Host Path](https://github.com/fjudith/docker-limesurvey/tree/master/kubernetes#host-path) for storage, then please follow this [extra step](https://github.com/fjudith/docker-limesurvey/tree/master/kubernetes#selinux).

```bash
# Create MariaDB and LimeSurvey persistent volumes
kubectl create -f https://raw.githubusercontent.com/fjudith/docker-limesurvey/master/kubernetes/limesurvey-pv.yaml

# Create MariaDB and LimeSurvey secrets
tr --delete '\n' <root.limesurvey.mariadb.password.txt >.strippedpassword.txt && mv .strippedpassword.txt root.limesurvey.mariadb.password.txt
tr --delete '\n' <limesurvey.mariadb.password.txt >.strippedpassword.txt && mv .strippedpassword.txt limesurvey.mariadb.password.txt
kubectl create secret generic limesurvey-pass --from-file=root.limesurvey.mariadb.password.txt --from-file=limesurvey.mariadb.password.txt

# Deploy MariaDB and LimeSurvey pods along with persistent volumes claims and services
kubectl create -f https://raw.githubusercontent.com/fjudith/docker-limesurvey/master/kubernetes/limesurvey-dp.yaml
```

## Cluster Requirements

Kubernetes runs in a variety of environments and is inherently modular. Not all clusters are the same. These are the requirements for this example.

* Kubernetes version 1.6 is required due to using newer features, such as PV Claims and Deployments. Run `kubectl version` to see your cluster version.
* [Cluster DNS](https://github.com/kubernetes/dns) will be used for service discovery.
* [NodePort](http://kubernetes.io/docs/user-guide/services/#node-port) will be used to access LimeSurvey.
* [Persistent Volume Claims](http://kubernetes.io/docs/user-guide/persistent-volumes/) are used. You must create Persistent Volumes in your cluster to be claimed. This example demonstrates how to create three types of volumes, but any volume is sufficient.

Consult a [Getting Started Guide](http://kubernetes.io/docs/getting-started-guides/) to set up a cluster and the [kubectl](http://kubernetes.io/docs/user-guide/prereqs/) command-line client.

## Decide where you will store your data

MariaDB and LimeSurvey will each use [Persistent Volumes](http://kubernetes.io/docs/user-guide/persistent-volumes/) to store their data. We will use a Persistent Volume Claim to claim an available persistent volume. Labels will be leveraged to provide static mapping from Volume Claim down to Persistent Volume. This example covers HostPath and CephFS volumes. Choose one of the two, or see [Types of Persisten Volumes](http://kubernetes.io/docs/user-guide/persistent-volumes/#types-of-persistent-volumes) for more options.

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

We will **none** of these options in this guide as the [LimeSurvey](https://hub.docker.com/r/fjudith/limesurvey) image runs as `root` user.

#### SELinux

On systems supporting selinux it is preferred to leave it _enabled/enforcing_. However, docker containers mount the host path with the _"svirt_sandbox_file_t"_ label type, which is incompatible with the default label type for /var/lib/kubernetes/pv (_"var_lib_t"), resulting in a permissions error when the postgres container attempts to `chown`_/var/lib/postgres/data_. Therefore, on selinux systems using host path, you should pre-create the host path directory (/var/lib/kubernetes/pv/) and change it'is selinux label type to "_svirt_sandbox_file_t", as follows:

```bash
## on every node:
sudo mkdir -p /var/lib/kubernetes/pv
sudo chmod a+rwt /var/lib/kubernetes/pv

sudo mkdir -p \
  /var/lib/kubernetes/pv/limesurvey-db/db \
  /var/lib/kubernetes/pv/limesurvey-dblog/log \
  /var/lib/kubernetes/pv/limesurvey-data/data \
  /var/lib/kubernetes/pv/limesurvey-log/log

sudo chcon -Rt svirt_sandbox_file_t /var/lib/kubernetes/pv
```

Continuing with host path, create the persistent volume objects in Kubernetes using [limesurvey-pv.yaml](https://github.com/fjudith/docker-limesurvey/tree/master/kubernetes/limesurvey-pv.yaml):

```bash
export KUBE_REPO=https://raw.githubusercontent.com/fjudith/docker-limesurvey/master/kubernetes
kubectl create -f $KUBE_REPO/limesurvey-pv.yaml
```

### CephFS

CephFS is the POSIX-compliant filesystem used to store data in a Ceph Storage Cluster. 
It will be exposed to Kubernetes as [Persistent Volumes](http://kubernetes.io/docs/user-guide/persistent-volumes/) to be claimed and Mounted by MariaDB & LimeSurvey Pods via [Persistent Volume Claims](http://kubernetes.io/docs/user-guide/persistent-volumes/). **This is the recommanded approach for production** as the data will be available accross all nodes, unlocking stateful container capabilities accross the cluster. Then if the pod is recreated, **data will automatically be retreived**.

```bash
kubectl create -f $KUBE_REPO/cephfs/limesurvey-pv.yaml

kubectl get pv -o wide
```

```
kubectl get pv -o wide
NAME             CAPACITY   ACCESSMODES   RECLAIMPOLICY   STATUS      CLAIM     STORAGECLASS   REASON    AGE
limesurvey-data  5Gi        RWO           Retain          Available                                      3s
limesurvey-db    20Gi       RWO           Retain          Available                                      3s
limesurvey-dblog 20Gi       RWO           Retain          Available                                      2s
```

## Create Secrets

Use [Secret](http://kubernetes.io/docs/user-guide/secrets/) objects to store the PostgreSQL passwords. First create respective files (in the same directory as the LimeSurvey sample files) called `root.limesurvey.mariadb.password.txt` and `limesurvey.mariadb.password.txt`, then save your passwords in it. Make sure to not have a trailing newline at the end of the password. The first `tr` command will remove the newline if your editor added one. Then, create the Secret object.

```bash
# Cleanup secret files
tr --delete '\n' <root.limesurvey.mariadb.password.txt >.strippedpassword.txt && mv .strippedpassword.txt root.limesurvey.mariadb.password.txt
tr --delete '\n' <limesurvey.mariadb.password.txt >.strippedpassword.txt && mv .strippedpassword.txt limesurvey.mariadb.password.txt

# Create MariaDB root and limesurvey users secrets 
kubectl create secret generic limesurvey-pass --from-file=root.limesurvey.mariadb.password.txt --from-file=limesurvey.mariadb.password.txt
```

MariaDB secrets are referenced by the MariaDB pod configuration so that this pods will have access to it. The MariaDB pod will set the database passwords for `root` and `limesurvey` users. 
The Limesurvey pod does not use any of them as the database configuration setup happens during the initial access to the LimeSurvey WebUI. `admin:admin`.

## Deploy MariaDB and LimeSurvey

Now that the persistent disks and secrets are defined, the Kubernetes pods can be launched. Start MariaDB and LimeSurvey using [limesurvey-dp.yaml](https://github.com/fjudith/docker-limesurvey/tree/master/kubernetes/limesurvey-dp.yaml).

```bash
kubectl create -f $KUBE_REPO/limesurvey-dp.yaml
```
Take a look at [limesurvey-dp.yaml](https://github.com/fjudith/docker-limesurvey/tree/master/kubernetes/limesurvey-dp.yaml), and note that we've defined four volumes mounts for:

For `limesurvey-md`

* /var/lib/mysql
* /var/log/mysql

For `limesurvey`

* /var/www/html/upload

And then created a Persistent Volume Claim that each looks for a 20GB or 5GB volume. This claim is satisfied by any volume that meets the requirements, in our case one of the volumes we created above.

Also lookt at the `env` section and see that we specified the password by referencing the secret `limesurvey-pass` that we created above. Secrets can have multiple key:value pairs. Ours has two keys, `root.limesurvey.mariadb.password.txt` and `limesurvey.mariadb.password.txt` which were the name of the files we used to create the secrets. The [MariaDB](https://hub.docker.com/_/mariadb/) sets the `root` password using the `MYSQL_ROOT_PASSWORD` environment variable, and the `limesurvey` password using the `MYSQL_PASSWORD`.

It my takes a short period before the new pods reach the `Running` state. List all pods to see the status of these new pods.

```bash
kubectl get pods --label=limesurvey
```

```
NAME                             READY     STATUS    RESTARTS   AGE
limesurvey-3315793244-bxgk0      1/1       Running   0          1m
limesurvey-md-4200742838-kq4d4   1/1       Running   0          5m
```

Kubernetes logs the stderr and stdout for each pod. Take a look at the logs for a pod by using `kubectl log`. Copy the pod name from the `get pods`command, and then:

```bash
kubectl logs <pod-name>
```

```
2017-07-02 10:15:41 140227039569792 [Note] mysqld (mysqld 10.2.6-MariaDB-10.2.6+maria~jessie) starting as process 1 ...
2017-07-02 10:15:41 140227039569792 [Note] InnoDB: Mutexes and rw_locks use GCC atomic builtins
2017-07-02 10:15:41 140227039569792 [Note] InnoDB: Uses event mutexes
2017-07-02 10:15:41 140227039569792 [Note] InnoDB: Compressed tables use zlib 1.2.8
2017-07-02 10:15:41 140227039569792 [Note] InnoDB: Using Linux native AIO
2017-07-02 10:15:41 140227039569792 [Note] InnoDB: Number of pools: 1
2017-07-02 10:15:41 140227039569792 [Note] InnoDB: Using SSE2 crc32 instructions
2017-07-02 10:15:41 140227039569792 [Note] InnoDB: Initializing buffer pool, total size = 256M, instances = 1, chunk size = 128M
2017-07-02 10:15:41 140227039569792 [Note] InnoDB: Completed initialization of buffer pool
2017-07-02 10:15:41 140226303665920 [Note] InnoDB: If the mysqld execution user is authorized, page cleaner thread priority can be changed. See the man page of setpriority().
2017-07-02 10:15:41 140227039569792 [Note] InnoDB: Highest supported file format is Barracuda.
2017-07-02 10:15:41 140227039569792 [Note] InnoDB: 128 out of 128 rollback segments are active.
2017-07-02 10:15:41 140227039569792 [Note] InnoDB: Creating shared tablespace for temporary tables
2017-07-02 10:15:41 140227039569792 [Note] InnoDB: Setting file './ibtmp1' size to 12 MB. Physically writing the file full; Please wait ...
2017-07-02 10:15:41 140227039569792 [Note] InnoDB: File './ibtmp1' size is now 12 MB.
2017-07-02 10:15:41 140227039569792 [Note] InnoDB: 5.7.14 started; log sequence number 1620154
2017-07-02 10:15:41 140226152347392 [Note] InnoDB: Loading buffer pool(s) from /var/lib/mysql/ib_buffer_pool
2017-07-02 10:15:41 140226152347392 [Note] InnoDB: Buffer pool(s) load completed at 170702 10:15:41
2017-07-02 10:15:41 140227039569792 [Note] Plugin 'FEEDBACK' is disabled.
2017-07-02 10:15:41 140227039569792 [Note] Server socket created on IP: '::'.
2017-07-02 10:15:41 140227039569792 [Warning] 'proxies_priv' entry '@% root@limesurvey-md-4200742838-qskfr' ignored in --skip-name-resolve mode.
2017-07-02 10:15:41 140227039569792 [Note] Reading of all Master_info entries succeded
2017-07-02 10:15:41 140227039569792 [Note] Added new Master_info '' to hash table
2017-07-02 10:15:41 140227039569792 [Note] mysqld: ready for connections.
Version: '10.2.6-MariaDB-10.2.6+maria~jessie'  socket: '/var/run/mysqld/mysqld.sock'  port: 3306  mariadb.org binary distribution
```

Also in [limesurvey-dp.yaml](https://github.com/fjudith/docker-limesurvey/tree/master/kubernetes/limesurvey-dp.yaml) we created a service to allow ofther pods to reach this MariaDB instance. the name is `limesurvey-md` which resolves to the pod IP.

Up to this point two Deployment, two Pod, three PVC, two Service, two Endpoint, three PVs, and two Secrets have been created, shown below:

```bash
kubectl get deployment,pod,svc,endpoints,pvc -l app=limesurvey -o wide && \
  kubectl get secret limesurvey-pass && \
  kubectl get pv -l app=limesurvey
```

```
NAME                   DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE       CONTAINER(S)    IMAGE(S)             SELECTOR
deploy/limesurvey      1         1         1            1           22m       limesurvey      fjudith/limesurvey   app=limesurvey,tiers=frontend
deploy/limesurvey-md   1         1         1            1           22m       limesurvey-md   mariadb              app=limesurvey,tiers=backend

NAME                                READY     STATUS    RESTARTS   AGE       IP           NODE
po/limesurvey-3315793244-bxgk0      1/1       Running   0          22m       10.2.64.10   192.168.251.205
po/limesurvey-md-4200742838-kq4d4   1/1       Running   0          22m       10.2.64.9    192.168.251.205

NAME                CLUSTER-IP   EXTERNAL-IP   PORT(S)          AGE       SELECTOR
svc/limesurvey      10.3.0.225   <nodes>       80:30698/TCP     22m       app=limesurvey,tiers=frontend
svc/limesurvey-md   10.3.0.214   <nodes>       3306:30477/TCP   22m       app=limesurvey,tiers=backend

NAME               ENDPOINTS        AGE
ep/limesurvey      10.2.64.10:80    22m
ep/limesurvey-md   10.2.64.9:3306   22m

NAME                    STATUS    VOLUME              CAPACITY   ACCESSMODES   STORAGECLASS   AGE
pvc/limesurvey-db       Bound     limesurvey-db       20Gi       RWX                          22m
pvc/limesurvey-dblog    Bound     limesurvey-dblog    20Gi       RWX                          22m
pvc/limesurvey-upload   Bound     limesurvey-upload   5Gi        RWX                          22m

NAME              TYPE      DATA      AGE
limesurvey-pass   Opaque    2         15h

NAME                CAPACITY   ACCESSMODES   RECLAIMPOLICY   STATUS    CLAIM                       STORAGECLASS   REASON    AGE
limesurvey-db       20Gi       RWX           Retain          Bound     default/limesurvey-db                                16m
limesurvey-dblog    20Gi       RWX           Retain          Bound     default/limesurvey-dblog                             16m
limesurvey-upload   5Gi        RWX           Retain          Bound     default/limesurvey-upload                            16m        
```

# Find the external IP

The LimeSurvey service has the setting `type: NodePort`. This will set up the Limesurvey behind its node external IP.
Find the Node IP and Port for your LimeSurvey service.

```bash
kubectl get pod,svc -l app=limesurvey -l tiers=frontend -o wide
```

```
NAME                             READY     STATUS    RESTARTS   AGE       IP           NODE
po/limesurvey-3315793244-bxgk0   1/1       Running   0          54m       10.2.64.10   192.168.251.205

NAME             CLUSTER-IP   EXTERNAL-IP   PORT(S)        AGE       SELECTOR
svc/limesurvey   10.3.0.225   <nodes>       80:30698/TCP   54m       app=limesurvey,tiers=frontend
```

# Visit your new LimeSurvey

Now, we can visit running LimeSurvey app. Use the node IP running the limesurvey pod and the port mapped to `80/TCP` you obtained above.

```
http://<node-ip>:<port>/
```

You should see the familiar LimeSurvey setup page.

![LimeSurvey Setup welcome page](https://github.com/fjudith/docker-limesurvey/raw/master/kubernetes/LimeSurvey_1.png)
![LimeSurvey Setup license page](https://github.com/fjudith/docker-limesurvey/raw/master/kubernetes/LimeSurvey_2.png)
![LimeSurvey Setup pre-installation check page](https://github.com/fjudith/docker-limesurvey/raw/master/kubernetes/LimeSurvey_3.png)
![LimeSurvey Setup database configuration page](https://github.com/fjudith/docker-limesurvey/raw/master/kubernetes/LimeSurvey_4.png)
![LimeSurvey Setup database creation page](https://github.com/fjudith/docker-limesurvey/raw/master/kubernetes/LimeSurvey_5.png)
![LimeSurvey Setup optionnal settings page](https://github.com/fjudith/docker-limesurvey/raw/master/kubernetes/LimeSurvey_6.png)
![LimeSurvey Setup success page](https://github.com/fjudith/docker-limesurvey/raw/master/kubernetes/LimeSurvey_7.png)
![LimeSurvey Setup login page](https://github.com/fjudith/docker-limesurvey/raw/master/kubernetes/LimeSurvey_8.png)
![LimeSurvey Setup admin page](https://github.com/fjudith/docker-limesurvey/raw/master/kubernetes/LimeSurvey_9.png)