.. _vllm_docker:

Serving vLLM Reranker Using Docker (CPU-Only)
=============================================

To ensure **reproducibility**, **portability**, and **isolation**, **vLLM** can be deployed using **Docker**. This is especially useful in environments with restricted internet access (e.g., corporate networks behind proxies or firewalls), where **Hugging Face Hub** may be blocked or rate-limited.

In this setup, **vLLM runs on CPU only** because:

- **Laptop has no GPU**
- **Home server has an old NVIDIA GPU** (not supported by vLLM’s CUDA requirements)

Thus, we use the **official CPU-optimized vLLM image** built from:  
https://github.com/vllm-project/vllm/blob/main/docker/Dockerfile.cpu

---

Docker Compose Configuration (CPU Mode)
---------------------------------------

.. code-block:: yaml

   version: '3.8'
   services:
     qwen-reranker:
       image: vllm-cpu:latest
       ports: ["8123:8000"]
       volumes:
         - /home/naj/qwen3-reranker-0.6b:/models/qwen3-reranker-0.6b:ro
       environment:
         VLLM_HF_OVERRIDES: |
           {
             "architectures": ["Qwen3ForSequenceClassification"],
             "classifier_from_token": ["no", "yes"],
             "is_original_qwen3_reranker": true
           }
       command: >
         /models/qwen3-reranker-0.6b
         --task score
         --dtype float32
         --port 8000
         --trust-remote-code
         --max-model-len 8192
       deploy:
         resources:
           limits:
             cpus: '10'
             memory: 16G
       shm_size: 4g
       restart: unless-stopped

---

Key Components Explained
------------------------

- **``image: vllm-cpu:latest``**
  - Official vLLM CPU image (no CUDA dependencies).
  - Built from: `vllm-project/vllm/docker/Dockerfile.cpu <https://github.com/vllm-project/vllm/blob/main/docker/Dockerfile.cpu>`_
  - Uses PyTorch CPU backend with optimized inference kernels.

- **``ports: ["8123:8000"]``**
  - Host port **8123** → container port **8000** (vLLM default).

- **``volumes``**
  - Mounts **locally pre-downloaded model** in **read-only** mode.

- **``VLLM_HF_OVERRIDES``**
  - Required for **Qwen3-Reranker** due to custom classification head and token handling.

- **``command``**
  - ``--task score``: Enables reranker scoring (outputs relevance logits).
  - ``--dtype float32``: Mandatory on CPU (no half-precision support).
  - ``--max-model-len 8192``: Supports long query+passage pairs.

- **Resource Limits**
  - ``cpus: '10'`` and ``memory: 16G`` prevent system overload.
  - ``shm_size: 4g`` ensures sufficient shared memory for batched inference.

---

Why the Model Must Be Pre-Downloaded Locally
--------------------------------------------

The container **cannot download the model at runtime** due to:

1. **Corporate Proxy / Firewall**
   - Outbound traffic to ``huggingface.co`` is blocked or requires authentication.

2. **Hugging Face Hub Blocked**
   - Git LFS and model downloads fail in restricted networks.

3. **vLLM Auto-Download Fails Offline**
   - vLLM uses ``transformers.AutoModel`` → attempts online download if model not found.

**Solution: Download via mirror**

.. code-block:: bash

   HF_ENDPOINT=https://hf-mirror.com huggingface-cli download Qwen/Qwen3-Reranker-0.6B --local-dir ./qwen3-reranker-0.6b

- Remark : for some models you need a token HF_TOKEN=xxxxxxxx (you have to specify the model in the token definition!)
- Remark2 : use "sudo" if non-root!!! 
- Uses **accessible mirror** (``hf-mirror.com``).
- Saves model locally for volume mounting.

---

Why CPU-Only (No GPU)?
----------------------

- **Laptop**: Integrated graphics only (no discrete GPU).
- **Home Server**: NVIDIA GPU too old (e.g., pre-Ampere) → **not supported** by vLLM’s CUDA 11.8+ / FlashAttention requirements.
- **vLLM CPU image** enables full functionality without GPU.

> **Performance Note**: CPU inference is slower (~1–3 sec per batch), but sufficient for **development**, **prototyping**, or **low-throughput** use cases.

---

Start the Service
-----------------

.. code-block:: bash

   docker-compose up -d

Verify Availability
-------------------

.. code-block:: bash

   curl http://localhost:8123/v1/models

Expected output confirms the model is loaded and ready.

---

Integration with RAGFlow
------------------------

Update RAGFlow config:

.. code-block:: yaml

   reranker:
     provider: vllm
     api_base: http://localhost:8123/v1
     model: /models/qwen3-reranker-0.6b

---

Benefits of This CPU + Docker Setup
-----------------------------------

- **Works on any machine** (laptop, old server, air-gapped systems)
- **No GPU required**
- **Offline-first** with pre-downloaded model
- **Consistent environment** via Docker
- **Secure**: read-only model, isolated container
- **Scalable later**: switch to GPU image when hardware upgrades

**Ideal for local RAGFlow development and constrained production environments.**
