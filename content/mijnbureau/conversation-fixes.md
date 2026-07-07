# conversations-backend CrashLoopBackOff Fix

## Problem

The `conversations-backend` pod (`conversations-backend-89fc95d94-dxldl`) was in `CrashLoopBackOff` with exit code `137` (OOMKilled).

```
State:          Waiting
  Reason:       CrashLoopBackOff
Last State:     Terminated
  Reason:       OOMKilled
  Exit Code:    137
```

## Root Cause

The pod was using the `"micro"` resource preset, which allocates only **384Mi memory limit** (256Mi request). The application process exceeded this limit and was killed by the kernel OOM killer.

Resource preset values (defined in `helmfile/apps/common/charts/common/templates/_resources.tpl`):

| Preset | Memory Request | Memory Limit |
|--------|---------------|--------------|
| nano   | 128Mi         | 192Mi        |
| micro  | 256Mi         | 384Mi        |
| small  | 512Mi         | 768Mi        |
| medium | 1024Mi        | 1536Mi       |

## Fix

Changed `conversations.backend` resource preset from `"micro"` to `"small"` in:

**File:** `helmfile/environments/default/global.yaml.gotmpl:38`

```diff
     conversations:
-      backend: "micro"
+      backend: "small"
       frontend: "nano"
```

This increases memory from 384Mi → 768Mi limit and 256Mi → 512Mi request.

## Redeploy

After applying the fix, redeploy the conversations app:

```bash
helmfile -e demo -l name=conversations apply
```
