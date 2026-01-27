RAGFlow GPU vs CPU: Full Explanation (2025 Edition)
***************************************************

Why Does RAGFlow Still Need a GPU Even When Using Ollama?
========================================================

You are absolutely right to ask this question.

Most people configure RAGFlow to use **external services** (Ollama, Xinference, vLLM, OpenAI, etc.) for:

- Embedding model
- Re-ranking model  
- Inference LLM (the actual answer generator)

Ollama runs these models **entirely on your GPU** — RAGFlow only sends HTTP requests.  
So why does the official documentation and community still strongly recommend the **ragflow-gpu** image (or setting ``DEVICE=gpu``)?

The answer is simple: **Deep Document Understanding (DeepDoc)** — the part that happens *before* any embedding or LLM call.

Complete RAGFlow Pipeline (with GPU usage marked)
=================================================

.. table::
   :widths: auto
   :align: center

   +---------------------------+-------------------------------+----------------------------+---------------------------+
   | Step                      | Component                     | Runs inside RAGFlow?       | Uses GPU when?            |
   +===========================+===============================+============================+===========================+
   | 1. Document Upload        | DeepDoc parser                | Yes (core of RAGFlow)      | **YES** — heavily         |
   +---------------------------+-------------------------------+----------------------------+---------------------------+
   | 2. Chunking               | Text splitting                | Yes                        | No (pure CPU)             |
   +---------------------------+-------------------------------+----------------------------+---------------------------+
   | 3. Embedding              | Sentence-Transformers, BGE…   | External (Ollama, etc.)    | GPU via Ollama/vLLM       |
   +---------------------------+-------------------------------+----------------------------+---------------------------+
   | 4. Vector storage         | Elasticsearch / InfiniFlow DB | Yes                        | No                        |
   +---------------------------+-------------------------------+----------------------------+---------------------------+
   | 5. Retrieval              | Vector + keyword search       | Yes                        | No                        |
   +---------------------------+-------------------------------+----------------------------+---------------------------+
   | 6. Re-ranking             | Cross-encoder (optional)      | External or local          | GPU via external service  |
   +---------------------------+-------------------------------+----------------------------+---------------------------+
   | 7. Answer generation      | LLM (Llama 3, Qwen2, etc.)    | External (Ollama, etc.)    | GPU via Ollama/vLLM       |
   +---------------------------+-------------------------------+----------------------------+---------------------------+

→ The **only part that RAGFlow itself accelerates with GPU** is Step 1 — but it is by far the most compute-intensive for real-world documents.

What DeepDoc Actually Does (and Why GPU Makes It 5–20× Faster)
==============================================================

When you upload a PDF, scanned image, or complex report, DeepDoc performs these AI-heavy tasks:

1. **Layout Detection**  
   Detects columns, headers, footers, reading order using CNN-based models (LayoutLM-style).

2. **Table Structure Recognition (TSR)**  
   Identifies table boundaries, row/column spans, merged cells — extremely important for accurate retrieval.

3. **Formula & Math Recognition**  
   Converts LaTeX/math images into readable text.

4. **Enhanced OCR**  
   For scanned PDFs: runs deep-learning OCR models (not just Tesseract CPU).

5. **Visual Language Model Tasks** (charts, diagrams, screenshots)  
   Optionally calls lightweight VLMs (Qwen2-VL, LLaVA, etc.) to describe images inside the document.

All of these run **inside RAGFlow’s deepdoc module** using PyTorch + CUDA when ``DEVICE=gpu`` is enabled.

Real-World Performance Numbers
==============================

.. table::
   :widths: auto

   +----------------------------------+-----------------+-----------------+
   | Document Type                    | ragflow-cpu     | ragflow-gpu     |
   +==================================+=================+=================+
   | 50-page clean text PDF           | ~2–4 minutes    | ~2–4 minutes    |
   +----------------------------------+-----------------+-----------------+
   | 50-page scanned PDF (images)     | 30–90 minutes   | 4–10 minutes    |
   +----------------------------------+-----------------+-----------------+
   | 100-page financial report w/ tables | Often fails   | 8–15 minutes    |
   +----------------------------------+-----------------+-----------------+
   | PDF with charts & diagrams       | Very poor OCR   | Accurate + fast |
   +----------------------------------+-----------------+-----------------+

When Do You Actually Need ragflow-gpu?
=======================================

**YES – You need it if your documents contain any of the following:**
- Scanned pages (images instead of selectable text)
- Complex tables or financial reports
- Charts, graphs, screenshots
- Mixed layouts (multi-column, sidebars, footnotes)
- Handwritten notes or formulas

**NO – You can stay on ragflow-cpu if:**
- All documents are clean, born-digital text (Word → PDF, Markdown, etc.)
- You only do quick prototypes with a few simple files
- You have no NVIDIA GPU available

Recommended Setup in 2025 (Best of Both Worlds)
===============================================

.. code-block:: bash

   # .env file
   DEVICE=gpu                     # ← Enables DeepDoc GPU acceleration
   SVR_HTTP_PORT=80

   # Use Ollama (or vLLM) for embeddings + LLM
   EMBEDDING_MODEL=ollama/bge-large
   RERANK_MODEL=reranker  (this cannnot be served by ollama, vLLM or llama.cpp is needed)
   LLM_MODEL=ollama/llama3.1:70b

Result:
- DeepDoc parsing → blazing fast on your NVIDIA GPU (inside RAGFlow container)
- Embeddings + LLM → also blazing fast on the same GPU (inside Ollama container)
- No bottlenecks anywhere

Monitoring & Verification
=========================

During document upload:

.. code-block:: bash

   watch -n 1 nvidia-smi

You will see:
- RAGFlow container using 4–12 GB VRAM during parsing
- Ollama container using VRAM only when embedding or generatinging

Conclusion
==========

- **ragflow-cpu**  → fine for clean text only  
- **ragflow-gpu**  → mandatory for real-world unstructured documents

Even if Ollama handles your LLM and embeddings perfectly, **without ragflow-gpu, the very first step (understanding the document) will be painfully slow or inaccurate**.

Use ``DEVICE=gpu`` — it’s the difference between a toy and a true enterprise-grade RAG system.
