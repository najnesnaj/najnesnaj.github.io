---
title: 'Hybrid'
weight: 730
draft: false
---

```
``
```

```
`
```

rst
.. \_deployment-considerations:

# Deploying LLMs in Hybrid Cloud: Why llama.cpp Wins for Us

> ##### Table of Contents
> 
> * [1. Current Setup: Ollama in Testing](#current-setup-ollama-in-testing)
> * [2. Production Requirements: Hybrid Cloud & Multi-User Access](#production-requirements-hybrid-cloud-multi-user-access)
> * [3. Evaluation: vLLM vs llama.cpp](#evaluation-vllm-vs-llama-cpp)
> * [4. Why llama.cpp Is Our Production Choice](#why-llama-cpp-is-our-production-choice)
>   * [Example: Production-Ready Server](#example-production-ready-server)
> * [5. Migration Path: From Ollama → llama.cpp](#migration-path-from-ollama-llama-cpp)
> * [Summary](#summary)

---

## 1. Current Setup: Ollama in Testing

We have been using **Ollama** in a **test environment** with excellent results:

- **Easy to use** — ollama run llama3.1 just works
- **Docker support** is first-class:
  ```dockerfile
  FROM ollama/ollama
  COPY Modelfile /root/.ollama/
  RUN ollama create my-llama3.1 -f Modelfile
  ```
- Models are pulled, versioned, and cached automatically
- Web UI and OpenAI-compatible API available out of the box

**Verdict**: Perfect for **prototyping**, **local dev**, and **small-scale testing**.

---

## 2. Production Requirements: Hybrid Cloud & Multi-User Access

When moving to **production in a hybrid cloud**, new constraints emerge:

We need a **lightweight, portable, hardware-agnostic** inference engine.

---

## 3. Evaluation: vLLM vs llama.cpp

| Criteria                  | vLLM                                              | llama.cpp                                             |
|---------------------------|---------------------------------------------------|-------------------------------------------------------|
| **Hardware Requirements** | Requires **AVX-512** (fails on Xeon v2, older i7) | Runs on **SSE2+**, AVX2 optional                      |
| **GPU Support**           | Excellent (PagedAttention, high throughput)       | CUDA, Metal, Vulkan — full offloading                 |
| **CPU Performance**       | Poor without AVX-512                              | **Best-in-class** quantized inference                 |
| **Binary Size**           | ~200 MB + Python deps                             | **< 10 MB** (statically linked)                       |
| **Deployment**            | Python server, complex deps                       | Single binary, scp and run                            |
| **Multi-user / API**      | Built-in OpenAI API                               | server binary with full OpenAI compat + web UI        |
| **Quantization Support**  | FP16/BF16 only                                    | Q4_K, Q5_K, Q8_0, etc. — **4–8 GB models fit in RAM** |

**Key Finding**:

> **We cannot use vLLM** on our legacy Xeon v2 fleet due to missing **AVX-512**.
> **llama.cpp runs efficiently** on the **same hardware** with **Q4_K_M** models.

---

## 4. Why llama.cpp Is Our Production Choice

### Example: Production-Ready Server

```bash
./llama.cpp/server \
  --model /models/llama3.1-8b-instruct.Q4_K_M.gguf \
  --port 8080 \
  --host 0.0.0.0 \
  --threads 16 \
  --ctx-size 8192 \
  --n-gpu-layers 0    # CPU-only on older nodes
  --log-disable
```

Deploy via Docker:

```dockerfile
FROM alpine:latest
COPY llama.cpp/server /usr/bin/
COPY models/*.gguf /models/
EXPOSE 8080
CMD ["server", "--model", "/models/llama3.1-8b-instruct.Q4_K_M.gguf", "--port", "8080"]
```

---

## 5. Migration Path: From Ollama → llama.cpp

```bash
# 1. Reuse Ollama's GGUF
cp ~/.ollama/models/blobs/sha256-* /production/models/

# 2. Deploy llama.cpp server
kubectl apply -f llama-cpp-deployment.yaml

# 3. Point clients to new endpoint
export OPENAI_API_BASE=http://llama-cpp-prod:8080/v1
```

**Zero model reconversion. Zero downtime.**

---

## Summary

| Use Case                          | Recommended Tool            |
|-----------------------------------|-----------------------------|
| Local dev / prototyping           | **Ollama**                  |
| Hybrid cloud, old hardware, scale | **llama.cpp**               |
| High-throughput GPU cluster       | vLLM (if AVX-512 available) |

> **llama.cpp = the Swiss Army knife of LLM inference.**

—
