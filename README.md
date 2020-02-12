# Habitat Docker Container
Based on [centos/systemd](https://hub.docker.com/r/centos/systemd/), this container aids iterative development of Habitat packages, as well as testing of Supervisors and Rings. Available on [Docker Hub](https://hub.docker.com/repository/docker/sirajr/habitat)

## Start the Container
Start the container minimally using:
```shell script
$ docker run -d --cap-add SYS_ADMIN siraj-habitat
33d9afdf53a9e9dadb167a732c5a6e4846c598b8ca7572e0a807ee7cd57b9e61
```
Note that the container must be started in detached mode with SYS_ADMIN capabilities due to SystemD requirements (see the centos/systemD page above). 

You can then connect to the container using `docker exec`, where the Supervisor will be installed as a SystemD service `hab-sup`:
```shell script
$ docker exec --interactive --tty 33d9afdf53a9 /bin/bash
```
From here you may modify the configuration, install packages/load services, etc.

## Interacting with the Supervisor
View the Supervisor status:
```shell script
[root@33d9afdf53a9 /]# systemctl status hab-sup
● hab-sup.service - Habitat Supervisor
   Loaded: loaded (/etc/systemd/system/hab-sup.service; disabled; vendor preset: disabled)
   Active: active (running) since Wed 2020-02-12 14:50:55 UTC; 1min 8s ago
     Docs: https://habitat.sh
 Main PID: 19 (hab-launch)
   CGroup: /docker/75f65b0b1da83e331e29365d378f938688616db8e299f70d308b2c538e732ba5/system.slice/hab-sup.service
           ├─19 /hab/pkgs/core/hab-launcher/13154/20200211164210/bin/hab-launch run --listen-ctl 0.0.0.0:9632
           └─34 /hab/pkgs/core/hab-sup/1.5.29/20200211164216/bin/hab-sup run --listen-ctl 0.0.0.0:9632
   
Feb 12 14:50:55 75f65b0b1da8 hab[19]: → Using core/xz/5.2.4/20190115013348
Feb 12 14:50:55 75f65b0b1da8 hab[19]: → Using core/zlib/1.2.11/20190115003728
...
```
Tail the Supervisor's log using `journalctl`:
```shell script
[root@33d9afdf53a9 /]# journalctl --follow --unit hab-sup
-- Logs begin at Wed 2020-02-12 14:50:55 UTC. --
...
Feb 12 14:50:55 75f65b0b1da8 hab[19]: hab-sup(MR): Starting http-gateway on 0.0.0.0:9631
```

### The Supervisor API
To access the Supervisor HTTP API or the Control Gateway, add `-P` to the `docker run` command to expose ports 9631/9632 on TCP on random host ports. You may specify specific ports using `-p <container-port>:[<optional-host-port>]`:
```shell script
$ docker run -d --cap-add SYS_ADMIN -p 9631:9631 siraj-habitat

$ curl --silent localhost:9631/butterfly | jq
{
  "member": {
    "members": {},
    ...
``` 

### Peering
To peer multiple containers, we can make use of the default bridge network. To do this, start up multiple containers, then use the `docker inspect` command to retrieve the IP address:
```shell script
$ docker run -d --cap-add SYS_ADMIN --name supervisor-1 -p 9631:9631 siraj-habitat
bb1094e08831cee0e3377b0774a5d3dc55b2adefd64c1c7e34c1deec7461a53d

$ docker run -d --cap-add SYS_ADMIN --name supervisor-2 siraj-habitat
96d630782aaa5e84ce54948d568392fa485f91d2653d98ad9675238f94ccb994"

$ docker inspect supervisor-1 | jq -r '.[0].NetworkSettings.Networks.bridge.IPAddress'
172.17.0.2
```
This IP address must now be added as a `--peer` argument to the other supervisors using the SystemD unit file at `/etc/systemd/system/hab-sup.service`:
```shell script
 [Unit]
 Description=Habitat Supervisor
 Documentation=https://habitat.sh

 [Service]
 Environment=HAB_LICENSE=accept-no-persist
-ExecStart=/bin/hab sup run --listen-ctl 0.0.0.0:9632
+ExecStart=/bin/hab sup run --listen-ctl 0.0.0.0:9632 --peer 172.17.0.2
 ExecStop=/bin/hab sup term
 Restart=on-success
 RestartSec=2

 [Install]
 WantedBy=default.target
```
Followed by a `daemon-reload` and a `restart`.
```shell script
[root@96d630782aaa /]# systemctl daemon-reload
[root@96d630782aaa /]# systemctl restart hab-sup
```

We can now query the API from either node, or from the host if we've forwarded ports from either machine.
```shell script
$ curl -s localhost:9631/butterfly | jq '.membership | keys'
[
  "aee86873f6f24d4a9efc920b2f01876b",
  "e8a6ba0f989e43d39e35e6da8a411440"
]
``` 

## Developing Habitat Packages
The container can be useful for testing packages that are deployed in specifically configured environments (such as through a cookbook, etc.) and aids in debugging the behaviour of packages in clustered scenarios, as well as being able to test 

To make full use of this container's functionality it is suggested to export `HAB_BLDR_URL`,`HAB_AUTH_TOKEN`,`HAB_ORIGIN` and mount the Habitat cache and our project directory to run builds or install packages to test outside the studio:
```shell script
$ docker run --cap-add SYS_ADMIN -d -e HAB_BLDR_URL -e HAB_AUTH_TOKEN -e HAB_ORIGIN --volume ${HOME}/.hab/cache:/hab/cache --volume $(pwd):/workspace siraj-habitat
917c59943c59

$ docker exec --interactive --tty 917c59943c59 /bin/bash

[root@917c59943c59 /]# source /workspace/results/last_build.env

[root@917c59943c59 /]# hab pkg install /workspace/results/$pkg_artifact

[root@917c59943c59 /]# hab svc load $pkg_ident

[root@917c59943c59 /]# journalctl -fu hab-sup
Feb 12 16:43:17 0e032bdb5c2c hab[20]: hab-sup(AG): The <pkg_ident> service was successfully loaded
...
```
Mounting of the cache results in faster build times/downloads as well as removes the need for re-downloading origin keys on every container.
