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

# check listened ports
$ netstat -ntlp

$ echo -n securepass | md5sum
$ chmod 600 /etc/ha.d/authkeys

# display hostname
$ uname -n
```

```
$ cat /kubeadm.yaml

apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
bootstrapTokens:                                      
- token: "co4zhu.timmt8nyl29udq96"                                      
certificateKey: "d29a57954a7d92a3941cea3c9a9625df68d2cbdc0d10c4a7f42b354c1c27f2ca"                                      
---
apiVersion: kubeadm.k8s.io/v1beta2                                      
kind: ClusterConfiguration                                      
kubernetesVersion: v1.15.0-rc.1                                      
controlPlaneEndpoint: kubeadm-ha.luxas.dev:6443                                      
apiServer:                                      
  certSANs:                                      
  - "192.168.43.253"
```

```
$ kubeadm init --config /kubeadm.yaml --upload-certs

...
You can now join any number of the control-plane node running the following command on each as root:             
kubeadm join kubeadm-ha.luxas.dev:6443 --token co4zhu.timmt8nyl29udq96 \                                    
    --discovery-token-ca-cert-hash sha256:c5afb11a8e7a26e7ffb5b57202a66f82322298ed926f6efa9c61e66a55d316a5 \
    --experimental-control-plane --certificate-key d29a57954a7d92a3941cea3c9a9625df68d2cbdc0d10c4a7f42b354c1c27f2ca
...

Then you can join any number of worker nodes by running the following on each as root:                                              
                                                                                                                                    
kubeadm join kubeadm-ha.luxas.dev:6443 --token co4zhu.timmt8nyl29udq96 \                                      
    --discovery-token-ca-cert-hash sha256:c5afb11a8e7a26e7ffb5b57202a66f82322298ed926f6efa9c61e66a55d316a5

```

```
$ export KUBECONFIG=/etc/kubernetes/admin.conf
$ kubectl apply -f https://git.io/weave-kube-1.6

# second master node
$ export TOKEN=co4zhu.timmt8nyl29udq96                                      
$ export CERT_KEY=d29a57954a7d92a3941cea3c9a9625df68d2cbdc0d10c4a7f42b354c1c27f2ca                                      
$ export CA_HASH=c5afb11a8e7a26e7ffb5b57202a66f82322298ed926f6efa9c61e66a55d316a5
$ kubeadm join kubeadm-ha.luxas.dev:6443 \
    --token ${TOKEN} \                                    
	--discovery-token-ca-cert-hash sha256:${CA_HASH} \                                    
	--certificate-key ${CERT_KEY} \                                    
	--control-plane
```

## To Do

* Configure Docker to make use of [systemd]([https://kubernetes.io/docs/setup/production-environment/container-runtimes/#docker)

## Vagrant on WSL

```
export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"
export VAGRANT_WSL_WINDOWS_ACCESS_USER_HOME_PATH="$HOME"
export PATH="${PATH}:/mnt/c/Program Files/Oracle/VirtualBox"
#export VAGRANT_WSL_DISABLE_VAGRANT_HOME="true"
#export VAGRANT_HOME="$HOME/k8s-cluster-example-local"
```

**Administer the cluster from your host**
```shell
$ curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl \
    && chmod +x ./kubectl \
    && sudo mv ./kubectl /usr/local/bin/kubectl

$ vagrant ssh-config kubemaster-1 >> ~/.ssh/config
$ chown $USER ~/.ssh/config
$ chmod 600 ~/.ssh/config
$ mkdir ~/.kube
$ scp -P 2222 vagrant@kubemaster-1:/home/vagrant/.kube/config ~/.kube/config

$ kubectl cluster-info
$ kubectl get nodes --all-namespaces
$ kubectl get pods --all-namespaces
``` 
