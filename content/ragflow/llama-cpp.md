---
title: 'Llama Cpp'
draft: false
---

<a id="llama-cpp-model-format-gguf"></a>

# Running Llama 3.1 with llama.cpp

> ##### Table of Contents
> 
> * [1. Model Format: GGUF](#model-format-gguf)
> * [2. Compile llama.cpp for Intel i7 (CPU-only)](#compile-llama-cpp-for-intel-i7-cpu-only)
> * [3. Run the Model with Web Interface](#run-the-model-with-web-interface)
>   * [Features](#features)
> * [4. Compile llama.cpp with NVIDIA GPU Support (CUDA)](#compile-llama-cpp-with-nvidia-gpu-support-cuda)
>   * [Prerequisites](#prerequisites)
>   * [Build with CUDA](#build-with-cuda)
>   * [Run with GPU offloading](#run-with-gpu-offloading)
> * [Summary](#summary)

---

<a id="llama-cpp-compile-llama-cpp-for-intel-i7-cpu-only"></a>

## 1. Model Format: GGUF

`llama.cpp` uses the **GGUF** (GPT-Generated Unified Format) model format.

You can download a pre-quantized **Llama 3.1 8B** model in GGUF format directly from Hugging Face:

```bash
https://huggingface.co/QuantFactory/Meta-Llama-3-8B-GGUF
```

Example file: `Meta-Llama-3-8B.Q4_K_S.gguf` (~4.7 GB, 4-bit quantization, excellent quality/size tradeoff).

#### NOTE
The `Q4_K_S` variant uses ~4.7 GB RAM and runs efficiently on Intel i7 CPUs.

---

## 2. Compile llama.cpp for Intel i7 (CPU-only)

```bash
# Step 1: Clone the repository
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp

# Step 2: Build for CPU (Intel i7, AVX2 enabled by default)
make clean
make -j$(nproc) LLAMA_CPU=1

# Optional: Force AVX2 (most i7 CPUs support it)
make clean
make -j$(nproc) LLAMA_CPU=1 LLAMA_AVX2=1
```

The binaries will be in the root directory:

- `./llama-cli` → interactive CLI
- `./server`   → web server (OpenAI-compatible API + full web UI)

#### WARNING
**Do not use vLLM** on older Xeon v2 CPUs — they **lack AVX-512**, which vLLM requires.
**llama.cpp is a better choice** — it runs efficiently with just AVX2 or even SSE.

---

<a id="llama-cpp-run-the-model-with-web-interface"></a>

## 3. Run the Model with Web Interface

Place the downloaded GGUF file in a `models/` folder:

```bash
mkdir -p models
# Copy or symlink the model
ln -s /path/to/Meta-Llama-3-8B.Q4_K_S.gguf models/
```

Start the server on port **8087** using **12 threads**:

```bash
./server \
  --model models/Meta-Llama-3-8B.Q4_K_S.gguf \
  --port 8087 \
  --threads 12 \
  --host 0.0.0.0
```

In a corporate network : avoid contacting the proxy !!

```bash
curl -X POST http://127.0.0.1:8087/v1/chat/completions \
  --noproxy 127.0.0.1,localhost \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Meta-Llama-3-8B",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "Hello! How are you?"}
    ]
  }'
```

<a id="llama-cpp-features"></a>

### Features

- **Full web UI** at: [http://localhost:8087](http://localhost:8087)
- **OpenAI-compatible API** at: [http://localhost:8087/v1](http://localhost:8087/v1)
- List models:

```bash
curl http://localhost:8087/v1/models
```

**Response**:

```json
{
  "object": "list",
  "data": [
    {
      "id": "models/Meta-Llama-3-8B.Q4_K_S.gguf",
      "object": "model",
      "created": 1762783003,
      "owned_by": "llamacpp",
      "meta": {
        "vocab_type": 2,
        "n_vocab": 128256,
        "n_ctx_train": 8192,
        "n_embd": 4096,
        "n_params": 8030261248,
        "size": 4684832768
      }
    }
  ]
}
```

---

<a id="llama-cpp-compile-llama-cpp-with-nvidia-gpu-support-cuda"></a>

## 4. Compile llama.cpp with NVIDIA GPU Support (CUDA)

If you have an **NVIDIA GPU** (e.g., RTX 3060, 4070, A100, etc.), enable **CUDA acceleration**:

<a id="llama-cpp-prerequisites"></a>

### Prerequisites

- NVIDIA driver (\\geq{} 525)
- CUDA Toolkit (\\geq{} 11.8, preferably 12.x)
- `nvcc` in `$PATH`

<a id="llama-cpp-build-with-cuda"></a>

### Build with CUDA

```bash
# Clean previous build
make clean

# Build with full CUDA support
make -j$(nproc) \
  LLAMA_CUDA=1 \
  LLAMA_CUDA_DMMV=1 \
  LLAMA_CUDA_F16=1

# Optional: Specify compute capability (e.g., for RTX 40xx)
# make LLAMA_CUDA=1 CUDA_ARCH="-gencode arch=compute_89,code=sm_89"
```

<a id="llama-cpp-run-with-gpu-offloading"></a>

### Run with GPU offloading

```bash
./server \
  --model models/Meta-Llama-3-8B.Q4_K_S.gguf \
  --port 8087 \
  --threads 8 \
  --n-gpu-layers 999 \   # offload ALL layers to GPU
  --host 0.0.0.0
```

---

<a id="llama-cpp-summary"></a>

## Summary

| Feature          | Command / Note                                                                           |
|------------------|------------------------------------------------------------------------------------------|
| Model Format     | **GGUF**                                                                                 |
| Download         | [https://huggingface.co/QuantFactory/…GGUF](https://huggingface.co/QuantFactory/...GGUF) |
| CPU Build (i7)   | `make LLAMA_CPU=1`                                                                       |
| GPU Build (CUDA) | `make LLAMA_CUDA=1`                                                                      |
| Run Server       | `./server --model ... --port 8087`                                                       |
| Web UI           | [http://localhost:8087](http://localhost:8087)                                           |
| API              | [http://localhost:8087/v1](http://localhost:8087/v1)                                     |

**llama.cpp = lightweight, CPU/GPU flexible, no AVX-512 needed → ideal replacement for vLLM on older hardware.**

—
