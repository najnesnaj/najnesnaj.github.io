kubectl edit configmap coredns -n kube-system




Corefile: |
  .:53 {
      errors
      health {
         lameduck 5s
      }
      ready
      
      # VOEG DIT BLOK TOE:
      hosts {
         10.43.203.109 id.kubernetes.local
         10.43.203.109 docs.kubernetes.local
         fallthrough
      }
      
      kubernetes cluster.local in-addr.arpa ip6.arpa {
         pods insecure
         fallthrough in-addr.arpa ip6.arpa
         ttl 30
      }
      prometheus :9153
      forward . /etc/resolv.conf
      cache 30
      loop
      reload
      loadbalance
  }



Corefile: |
  .:53 {
      errors
      health {
         lameduck 5s
      }
      ready
      
      # VERVANG HET GENERIEKE HOSTS BLOK DOOR DEZE REWRITES (veiliger voor K8s):
      rewrite name id.kubernetes.local traefik.kube-system.svc.cluster.local
      rewrite name docs.kubernetes.local traefik.kube-system.svc.cluster.local
      
      kubernetes cluster.local in-addr.arpa ip6.arpa {
         pods insecure
         fallthrough in-addr.arpa ip6.arpa
         ttl 30
      }
      prometheus :9153
      forward . /etc/resolv.conf
      cache 30
      loop
      reload
      loadbalance
  }

