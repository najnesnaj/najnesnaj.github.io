MinerU and Its Use in RAGFlow
=============================

test : https://huggingface.co/spaces/opendatalab/MinerU 


.. code-block:: bash

   docker build -t mineru:latest -f Dockerfile .   (34GB in size!!)
   docker run --gpus all   --shm-size 32g   -p 30000:30000 -p 7860:7860 -p 8003:8003   --ipc=host   -it mineru:latest /bin/bash (normally with port 8000, but I used 8003) 



Introduction to MinerU
----------------------

MinerU is an open-source tool developed by OpenDataLab (Shanghai AI
Laboratory) for converting complex PDF documents into machine-readable
formats, such as Markdown or JSON. It excels at extracting text, tables
(in HTML or LaTeX), mathematical formulas (in LaTeX), images (with
captions), and preserving document structure, including headings,
paragraphs, lists, and reading order for multi-column layouts.

Key features include:

-  Removal of noise elements like headers, footers, footnotes, and page
   numbers.
-  Support for scanned PDFs via OCR (PaddleOCR, multilingual with over
   80 languages).
-  Handling of complex layouts, including scientific literature with
   symbols and equations.
-  Multiple backends: pipeline (rule-based, CPU-friendly), VLM-based
   (vision-language models for higher accuracy, often GPU-accelerated),
   and hybrid modes.
-  Built on PDF-Extract-Kit models for layout detection, table
   recognition, and formula parsing.
-  AGPL-3.0 license.

MinerU is particularly suited for preparing documents for LLM workflows,
such as Retrieval-Augmented Generation (RAG), due to its structured,
clean output that minimizes hallucinations in downstream tasks. Recent
versions (e.g., MinerU 2.5) achieve state-of-the-art performance on
benchmarks like OmniDocBench.

MinerU in RAGFlow
-----------------

RAGFlow is an open-source RAG engine focused on deep document
understanding, supporting complex data ingestion for accurate
question-answering with citations.

MinerU integration was introduced in RAGFlow v0.22.0 (released October
2025), supporting MinerU >= 2.6.3. RAGFlow acts solely as a **client**
to MinerU:

-  RAGFlow calls MinerU to parse uploaded PDFs.
-  MinerU processes the file and outputs structured data (e.g.,
   JSON/Markdown with images and tables).
-  RAGFlow reads the output and proceeds with chunking, embedding, and
   indexing.

Configuration options:

-  Enable via ``USE_MINERU=true`` in Docker/.env or manual environment
   variables.
-  Select MinerU in the dataset configuration UI under “PDF parser” (for
   built-in pipelines) or in the Parser component (for custom
   pipelines).
-  Supports remote MinerU API deployment (e.g., via vLLM backend for GPU
   offloading, decoupling from RAGFlow’s CPU-only server).
-  Alongside other parsers like DeepDoc (RAGFlow’s default VLM), Naive
   (text-only), and Docling.

This integration leverages MinerU’s superior handling of complex PDFs
(e.g., tables, formulas in academic/technical documents) to improve
retrieval quality in RAGFlow-based applications.

Comparison with Existing PDF Ingestion Tools
--------------------------------------------

Common PDF ingestion tools for RAG include Unstructured.io, LlamaParse
(LlamaIndex), Docling, Marker, and traditional libraries like PyMuPDF.
As of early 2026, MinerU frequently ranks among the top open-source
options in benchmarks for complex PDFs, especially scientific/technical
ones with tables and formulas.

.. table:: Comparison of PDF Parsers for RAG (as of early 2026)

    ================= =============
    ==========================================================================
    =========================================================================
    ============================================= ===========
    ======================= Tool Type Key Strengths Weaknesses Best For
    Open-Source GPU Required (Optional) ================= =============
    ==========================================================================
    =========================================================================
    ============================================= ===========
    ======================= **MinerU** VLM/Rule-based Excellent
    table/formula extraction (LaTeX/HTML), layout preservation, multilingual
    OCR, clean Markdown/JSON, SOTA on scientific PDFs. Resource-intensive
    (VLM backend), AGPL-3.0 may require source disclosure for SaaS.
    Academic/technical PDFs, precise structured RAG. Yes Yes (for best
    accuracy) **Unstructured.io** Rule-based + partitions Broad format
    support, fast partitioning, good integrations. Weaker on complex
    tables/formulas vs VLM tools, needs post-processing. General enterprise
    documents, multi-format. Yes (core) No **LlamaParse** Cloud/API Fast,
    superior table extraction, seamless LlamaIndex integration.
    Proprietary/paid for advanced features, privacy concerns. Quick
    high-quality parsing (cloud). No No (cloud) **Docling** Modular (IBM)
    Fast, local/offline, native Office format support, balanced accuracy.
    Less strong on formulas/scientific content or complex tables than
    MinerU. Local deployments, mixed document types. Yes No **Marker**
    VLM-based Fast PDF-to-Markdown, good OCR, offline. Slightly behind
    MinerU on table/formula precision in recent benchmarks. Offline Markdown
    conversion. Yes Optional ================= =============
    ==========================================================================
    =========================================================================
    ============================================= ===========
    =======================
    
Summary of MinerU Advantages
----------------------------

-  High performance in 2025–2026 benchmarks (e.g., top scores in table
   recognition, formula parsing, and layout accuracy on complex docs).
-  Superior to Unstructured for structured scientific output; often
   comparable to or better than LlamaParse in open-source/local setups.
-  In RAGFlow, it complements or outperforms the default DeepDoc parser
   for challenging PDFs requiring top-tier layout/table handling.

For most RAG pipelines in 2026, MinerU is a leading open-source choice
for difficult PDFs, particularly when integrated into frameworks like
RAGFlow.


Activating MinerU in RagFlow
------------------------------

in the dataset select in the configuration / ingestion pipeline / pdf parser -> mineru-from-env-1 Experimental

adapt the .env settings :
# Enable Mineru
# Uncommenting these lines will automatically add MinerU to the model provider whenever possible.
# More details see https://ragflow.io/docs/faq#how-to-use-mineru-to-parse-pdf-documents.
MINERU_APISERVER=http://host.docker.internal:8003
MINERU_DELETE_OUTPUT=0   # keep output directory
MINERU_BACKEND=pipeline  # or another backend you prefer

