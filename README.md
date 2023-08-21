# About

This terraform module provisions an envoy load balancer with an integrated control plane that fetches the envoy configuration from an etcd key store. It will also listen for changes on the configuration in etcd and update envoy accordingly.

Additionally, the load balancer supports an ssh tunneling setup where a tunnel user will be setup with access limited to tunneling on the server's local **127.0.0.1** address. To make this tunneling arrangement work securely, the envoy load balancer should be configured in etcd to listen only on the **127.0.0.1** address as well.

The following related project helps with the configuration of the load balancer in etcd: https://github.com/Ferlab-Ste-Justine/terraform-etcd-envoy-transport-configuration

# Usage

## Input

The module takes the following variables as input:

- **name**: Name of the load balancer vm
- **image_source**: Source of the image to provision the server on. It takes the following keys (only one of the two fields should be used, the other one should be empty):
  - **image_id**: Id of the image to associate with a vm that has local storage
  - **volume_id**: Id of a volume containing the os to associate with the vm
- **flavor_id**: Id of the vm flavor to assign to the instance. See hardware recommendations to make an informed choice: https://etcd.io/docs/v3.4/op-guide/hardware/
- **network_port**: Resource of type **openstack_networking_port_v2** to assign to the vm for network connectivity
- **server_group**: Server group to assign to the node. Should be of type **openstack_compute_servergroup_v2**.
- **keypair_name**: Name of the ssh keypair that will be used to ssh against the vm.
- **load_balancer**: Configuration for the envoy load balancer. It has the following keys:
  - **cluster**: Name for the envoy cluter. Defaults to the node name if the empty string is passed.
  - **node_id**: Identifier envoy will use with the control plane. The control plane will also use it to find envoy's configuration in the etcd key store (by appending it to the etcd key prefix). Defaults to the node name if the empty string is passed.
- **control_plane**: Configuration for the control plane that will fetch envoy's configuration and send it to envoy. It has the following keys:
  - **log_level**: Level of the least important logs to show. Can be: debug, info, warn, error.
  - **version_fallback**: What to use to determine the version of the load balancer configuration to send to envoy if the version field is empty in the configuration. Can be: etcd (use the key version in etcd), time (use nanoseconds since epoch whenever a change is read in the configuration) or none (fail with an error if the version field is empty)
  - **server**: Configuration for the control plane grpc server that envoy will talk to. It has the following keys:
    - **port**: Port that the control plane will listen on on ip **127.0.0.1**. This might be important to you as the envoy server won't be able to listen on that port for that ip.
    - **max_connections**: Max connections to accept from envoy. Can be pretty small.
    - **keep_alive_time**: Interval at which to ping envoy for signs of life when there is no traffic. Should be in golang duration format.
    - **keep_alive_timeout**: Maximum amount of time to wait for a reply on keep alive pings before closing the connection. Should be in golang duration format.
    - **keep_alive_min_time**: Minimum expected time before envoys sends a first keep alive ping to the server. If envoy violates this, the server will close the connection.
  - **etcd**: Client connection configuration for the etcd cluster the control plane will connect to, to get envoy's configuration. It has the following keys:
    - **key_prefix**: Prefix in etcd's keyspace to use to detect envoy's configuration. Note that the key containing the configuration is assumed to have envoy's node id appended to that prefix.
    - **endpoints**: Endpoints of the etcd cluster. Should be an array of strings, each having the `<ip>:<port>` format.
    - **connection_timeout**: Connection timeout to etcd. Should be in golang duration format.
    - **request_timeout**: Request timeout to etcd. Should be in golang duration format.
    - **retries**: Number of times to retry a failed requests before giving.
    - **ca_certificate**: CA certificate that should be used to authentify the etcd cluster's server certificates.
    - **client**: Client authentication to etcd. It should have the following keys.
      - **certificate**: Client certificate to use to authentify against etcd. Can be empty if password authentication is used.
      - **key**: Client key to use to authentify against etcd. Can be empty is password authentication is used.
      - **username**: Username to use for password authentication. Can be empty if certificate authentication is used.
      - **password**: Password to use for password authentication. Can be empty is certificate authentication is used.
- **fluentbit**: Optional fluent-bit configuration to securely route logs to a fluend/fluent-bit node using the forward plugin. Alternatively, configuration can be 100% dynamic by specifying the parameters of an etcd store or git repo to fetch the configuration from. It has the following keys:
  - **enabled**: If set the false (the default), fluent-bit will not be installed.
  - **load_balancer_tag**: Tag to assign to logs coming from envoy
  - **control_plane_tag**: Tag to assign to logs coming from the control plane
  - **node_exporter_tag** Tag to assign to logs coming from the prometheus node exporter
  - **forward**: Configuration for the forward plugin that will talk to the external fluend/fluent-bit node. It has the following keys:
    - **domain**: Ip or domain name of the remote fluend node.
    - **port**: Port the remote fluend node listens on
    - **hostname**: Unique hostname identifier for the vm
    - **shared_key**: Secret shared key with the remote fluentd node to authentify the client
    - **ca_cert**: CA certificate that signed the remote fluentd node's server certificate (used to authentify it)
- **fluentbit_dynamic_config**: Optional configuration to update fluent-bit configuration dynamically either from an etcd key prefix or a path in a git repo.
  - **enabled**: Boolean flag to indicate whether dynamic configuration is enabled at all. If set to true, configurations will be set dynamically. The default configurations can still be referenced as needed by the dynamic configuration. They are at the following paths:
    - **Global Service Configs**: /etc/fluent-bit-customization/default-config/service.conf
    - **Default Variables**: /etc/fluent-bit-customization/default-config/default-variables.conf
    - **Systemd Inputs**: /etc/fluent-bit-customization/default-config/inputs.conf
    - **Forward Output For All Inputs**: /etc/fluent-bit-customization/default-config/output-all.conf
    - **Forward Output For Default Inputs Only**: /etc/fluent-bit-customization/default-config/output-default-sources.conf
  - **source**: Indicates the source of the dynamic config. Can be either **etcd** or **git**.
  - **etcd**: Parameters to fetch fluent-bit configurations dynamically from an etcd cluster. It has the following keys:
    - **key_prefix**: Etcd key prefix to search for fluent-bit configuration
    - **endpoints**: Endpoints of the etcd cluster. Endpoints should have the format `<ip>:<port>`
    - **ca_certificate**: CA certificate against which the server certificates of the etcd cluster will be verified for authenticity
    - **client**: Client authentication. It takes the following keys:
      - **certificate**: Client tls certificate to authentify with. To be used for certificate authentication.
      - **key**: Client private tls key to authentify with. To be used for certificate authentication.
      - **username**: Client's username. To be used for username/password authentication.
      - **password**: Client's password. To be used for username/password authentication.
  - **git**: Parameters to fetch fluent-bit configurations dynamically from an git repo. It has the following keys:
    - **repo**: Url of the git repository. It should have the ssh format.
    - **ref**: Git reference (usually branch) to checkout in the repository
    - **path**: Path to sync from in the git repository. If the empty string is passed, syncing will happen from the root of the repository.
    - **trusted_gpg_keys**: List of trusted gpp keys to verify the signature of the top commit. If an empty list is passed, the commit signature will not be verified.
    - **auth**: Authentication to the git server. It should have the following keys:
      - **client_ssh_key** Private client ssh key to authentication to the server.
      - **server_ssh_fingerprint**: Public ssh fingerprint of the server that will be used to authentify it.
- **chrony**: Optional chrony configuration for when you need a more fine-grained ntp setup on your vm. It is an object with the following fields:
  - **enabled**: If set the false (the default), chrony will not be installed and the vm ntp settings will be left to default.
  - **servers**: List of ntp servers to sync from with each entry containing two properties, **url** and **options** (see: https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#server)
  - **pools**: A list of ntp server pools to sync from with each entry containing two properties, **url** and **options** (see: https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#pool)
  - **makestep**: An object containing remedial instructions if the clock of the vm is significantly out of sync at startup. It is an object containing two properties, **threshold** and **limit** (see: https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#makestep)
- **ssh_tunnel**: Optional ssh tunneling parameter. It is an object with the following fields:
  - **enabled**: Boolean value indicating whether or not ssh tunneling is on. Defaults to false.
  - **ssh**: An object with the following fields:
    - **user**: Os user that remote users should use for ssh tunneling
    - **authorized_key**: Authorized ssh key that the user should be accessible with
- **ssh_host_key_rsa**: Predefined rsa ssh host key. Can be omitted if random value is acceptable. It is an object with the following fields:
  - **public**: Public part of the ssh key.
  - **private**: Private part of the ssh key.
- **ssh_host_key_ecdsa**: Predefined ecdsa ssh host key. Can be omitted if random value is acceptable. It is an object with the following fields:
  - **public**: Public part of the ssh key.
  - **private**: Private part of the ssh key.
- **custom_certificates**: A set of custom certificate-key pairs that can be added to the vm and configured in envoy to perform tls termination
  - **certificate**:
    - **path**: Path to put the certificate in
    - **content**: Content of the certificate
  - **key**:
    - **path**: Path to put the key in
    - **content**: Content of the key
- **install_dependencies**: Whether cloud-init should install external dependencies (should be set to false if you already provide an image with the external dependencies built-in).