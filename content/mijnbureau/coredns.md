# Please edit the object below. Lines beginning with a '#' will be ignored,
# and an empty file will abort the edit. If an error occurs while saving this file will be
# reopened with the relevant failures.
#
apiVersion: v1
data:
  Corefile: |
    .:53 {
        errors
        health
        ready



        rewrite name id.kubernetes.local traefik.default.svc.cluster.local
        rewrite name docs.kubernetes.local traefik.default.svc.cluster.local
        rewrite name drive.kubernetes.local traefik.default.svc.cluster.local
        rewrite name meet.kubernetes.local traefik.default.svc.cluster.local
        rewrite name bureaublad.kubernetes.local traefik.default.svc.cluster.local

        kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          fallthrough in-addr.arpa ip6.arpa
        }
        hosts /etc/coredns/NodeHosts {
          ttl 60
          reload 15s
          fallthrough
        }
        prometheus :9153
        cache 30
        loop
        reload
        loadbalance
        import /etc/coredns/custom/*.override
        forward . /etc/resolv.conf
    }
    import /etc/coredns/custom/*.server
  NodeHosts: |

