#cloud-config
merge_how:
 - name: list
   settings: [append, no_replace]
 - name: dict
   settings: [no_replace, recurse_list]

ssh_pwauth: false
preserve_hostname: false
hostname: ${hostname}
users:
  - default

%{ if ssh_host_key_rsa.public != "" || ssh_host_key_ecdsa.public != "" ~}
ssh_keys:
%{ if ssh_host_key_rsa.public != "" ~}
  rsa_public: ${ssh_host_key_rsa.public}
  rsa_private: |
    ${indent(4, ssh_host_key_rsa.private)}
%{ endif ~}
%{ if ssh_host_key_ecdsa.public != "" ~}
  ecdsa_public: ${ssh_host_key_ecdsa.public}
  ecdsa_private: |
    ${indent(4, ssh_host_key_ecdsa.private)}
%{ endif ~}
%{ endif ~}

%{ if length(custom_certificates) > 0 ~}
write_files:
%{ for custom_certificate in custom_certificates ~}
  - path: ${custom_certificate.certificate.path}
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, custom_certificate.certificate.content)}
  - path: ${custom_certificate.key.path}
    owner: root:root
    permissions: "0400"
    content: |
      ${indent(6, custom_certificate.key.content)}
%{ endfor ~}

runcmd:
%{ for custom_certificate in custom_certificates ~}
  - chown transport-load-balancer:transport-load-balancer ${custom_certificate.certificate.path}
  - chown transport-load-balancer:transport-load-balancer ${custom_certificate.key.path}
%{ endfor ~}
%{ endif ~}