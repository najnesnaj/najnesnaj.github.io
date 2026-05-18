**✅ Now I see the exact problem.**

Your app is correctly fetching (or being configured with) the OIDC discovery document, but **every single endpoint** uses the hostname `id.kubernetes.local`, which is **not resolvable** from inside your application pod.

### Root Cause
- The Keycloak/IdP is exposing its internal Kubernetes hostname.
- Your app (running in another pod) cannot resolve `id.kubernetes.local`.
- When Authlib tries to call the `token_endpoint` during the callback → `Name or service not known`.

---

### Best Solutions (ranked)

**Option 1: Best – Use proper Kubernetes DNS (Recommended)**

Change your OIDC issuer configuration to use the **full internal service DNS**:

```yaml
# Example - replace <namespace> with the actual namespace of Keycloak
issuer: "https://id.<namespace>.svc.cluster.local/realms/mijnbureau"
```

Or if you know the exact service name:

```yaml
issuer: "https://id.<namespace>.svc.cluster.local/realms/mijnbureau"
# or sometimes
issuer: "https://keycloak.<namespace>.svc.cluster.local/realms/mijnbureau"
```

After changing this, the whole discovery document will use the correct resolvable hostname.

---

**Option 2: Use an Ingress hostname (Good for production)**

Configure the issuer with a proper domain that resolves both inside and outside the cluster:

```yaml
issuer: "https://auth.yourcompany.com/realms/mijnbureau"
# or
issuer: "https://id.example.internal/realms/mijnbureau"
```

This usually requires an Ingress + proper TLS.

---

**Option 3: Quick & Dirty Fix (for testing)**

You can manually override the endpoints in your Authlib / OAuth configuration so it uses the internal Kubernetes DNS only for token exchange:

```python
oauth.register(
    name='oidc',
    issuer="https://id.kubernetes.local/realms/mijnbureau",   # can stay for discovery
    token_endpoint="https://id.<namespace>.svc.cluster.local/realms/mijnbureau/protocol/openid-connect/token",
    # You can also override others if needed:
    # userinfo_endpoint=...
    # jwks_uri=...
    ...
)
```

---

### Immediate Action I Recommend

1. Find the correct internal address of your IdP:
   ```bash
   kubectl get svc -A | grep -E 'id|keycloak|auth'
   ```

2. Tell me the output of that command, and I’ll give you the exact issuer URL to use.

Would you like me to show you how to override the endpoints in your current Authlib setup? Just paste the part of your code where you register the OAuth client (the `oauth.register(...)` call) and I’ll give you the corrected version.
