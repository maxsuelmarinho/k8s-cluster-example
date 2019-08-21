# K8S Cluster Example

## Useful commands
```
# logs
$ sudo journalctl -u kubelet

# decode certificates
$ echo "<content>" | base64 -d

# view the certificate information
$ echo "<certificate>" | openssl x509 -text -noout
$ echo "<content>" | base64 -d | openssl x509 -text -noout

# get the cgroup-driver assigned
$ cat /var/lib/kubelet/kubeadm-flags.env
$ docker info | grep -i cgroup

# to change the cgroup-driver
$ KUBELET_EXTRA_ARGS=--cgroup-driver=<value>

# Container Network Interface - Flannel
# https://coreos.com/flannel/docs/latest/troubleshooting.html
$ sysctl net.bridge.bridge-nf-call-iptables=1
$ kubeadm init ... -pod-network-cidr=10.244.0.0/16
$ kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/62e44c867a2846fefb68bd5f178daf4da3095ccb/Documentation/kube-flannel.yml

# joining your nodes
$ kubeadm join --token <token> <master-ip>:<master-port> --discovery-token-ca-cert-hash sha256:<hash>

# token list
$ kubeadm token list

# get the token ca certificate hash
$ openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'

# tear down
$ kubectl drain <node name> --delete-local-data --force --ignore-daemonsets
$ kubectl delete node <node name>
$ kubeadm reset # on the node being removed
$ iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
$ ipvsadm -C

# CNI plugin configuration
$ ls /etc/cni/net.d/

# Token
$ TOKEN=$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64 | tr -d "=+/[:space:]" | dd bs=32 count=1 2>/dev/null)

# Check product_uuid
$ sudo cat /sys/class/dmi/id/product_uuid
```

## To Do

* Configure Docker to make use of [systemd]([https://kubernetes.io/docs/setup/production-environment/container-runtimes/#docker)