.. _vllm_reranker:

Why vLLM is Used to Serve the Reranker Model
============================================

vLLM is a high-throughput, memory-efficient inference engine specifically designed for serving large language models (LLMs). In **Infiniflow RAGFlow**, the **reranker model**—responsible for fine-grained relevance scoring of retrieved document chunks—is served using **vLLM** to ensure low-latency, scalable, and production-ready performance.

Key Reasons for Using vLLM to Serve the Reranker
------------------------------------------------

1. **PagedAttention for Memory Efficiency**
   - vLLM uses **PagedAttention**, a novel attention mechanism that manages KV cache in non-contiguous memory pages.
   - This dramatically reduces memory fragmentation and enables **higher batch sizes** and **longer sequence lengths** (up to 8192 tokens in this case), critical for processing query-chunk pairs during reranking.

2. **High Throughput & Low Latency**
   - Supports **continuous batching**, allowing dynamic batch formation as requests arrive.
   - Eliminates head-of-line blocking and maximizes GPU utilization—ideal for real-time reranking in interactive RAG pipelines.

3. **OpenAI-Compatible API**
   - Exposes a clean, standardized REST API compatible with OpenAI’s format.
   - Enables seamless integration with RAGFlow’s orchestration layer without custom inference code.

4. **Support for Cross-Encoder Rerankers**
   - Models like **Qwen3-Reranker-0.6B** are cross-encoders that take ``[query, passage]`` pairs as input.
   - vLLM efficiently handles the bidirectional attention required, delivering relevance scores via ``logits[0]`` (typically for binary classification: relevant/irrelevant).

5. **Ollama Does Not Support Reranker Models (Yet)**
   - **Ollama** is excellent for local LLM inference and chat models, but **currently lacks native support for reranker (cross-encoder) models**.
   - Rerankers require structured input formatting and logit extraction that Ollama’s current API and model loading system do not accommodate.
   - vLLM, in contrast, supports any Hugging Face transformer model—including rerankers—with full access to outputs and fine-grained control.

6. **Scalability Advantage Over Ollama**
   - When scaling to **multiple concurrent users** or **high-throughput workloads**, vLLM is significantly more robust than Ollama.
   - vLLM supports **distributed serving**, **tensor parallelism**, **GPU clustering**, and **dynamic batching at scale**.
   - Ollama is primarily designed for **single-user, local development**, and does not scale efficiently in production environments.

Serving the Reranker Locally with vLLM
---------------------------------------

You can run the reranker model locally using vLLM with the following command:

.. code-block:: bash

   vllm serve /models/qwen3-reranker-0.6b \
       --port 8123 \
       --max-model-len 8192 \
       --dtype auto \
       --trust-remote-code

Once running, the model is accessible via the OpenAI-compatible endpoint:

**GET** ``http://localhost:8123/v1/models``

**Example Response**:

.. code-block:: json

   {
     "object": "list",
     "data": [
       {
         "id": "/models/qwen3-reranker-0.6b",
         "object": "model",
         "created": 1762258164,
         "owned_by": "vllm",
         "root": "/models/qwen3-reranker-0.6b",
         "parent": null,
         "max_model_len": 8192,
         "permission": [
           {
             "id": "modelperm-1a0d5938e30b4eeebb53d9e5c7d9599e",
             "object": "model_permission",
             "created": 1762258164,
             "allow_create_engine": false,
             "allow_sampling": true,
             "allow_logprobs": true,
             "allow_search_indices": false,
             "allow_view": true,
             "allow_fine_tuning": false,
             "organization": "*",
             "group": null,
             "is_blocking": false
           }
         ]
       }
     ]
   }

RAGFlow Integration
-------------------

RAGFlow configures the reranker endpoint in its settings:

.. code-block:: yaml

   reranker:
     provider: vllm
     api_base: http://localhost:8123/v1
     model: /models/qwen3-reranker-0.6b

During inference, RAGFlow sends batched ``[query, passage]`` pairs to the vLLM server, receives relevance scores, and reorders chunks before passing them to the chat model.

**Result**: Fast, accurate, and scalable reranking powered by optimized LLM inference—**where Ollama cannot currently follow, and where vLLM excels in both development and production.**
