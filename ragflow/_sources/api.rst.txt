.. _ragflow_batch_api:

Batch Processing and Metadata Management in Infiniflow RAGFlow
==============================================================

**Infiniflow RAGFlow** provides a **RESTful API** (`/api/v1`) that enables **programmatic control** over datasets and documents, making it ideal for **batch processing large volumes of documents**, **automated ingestion pipelines**, and **metadata enrichment**.

This is essential in enterprise settings where thousands of PDFs, reports, or web pages need to be:

- Ingested in bulk
- Tagged with structured metadata (author, date, source, category, etc.)
- Updated post-ingestion
- Queried or filtered later via the RAG system

---

API Base URL
------------

.. code-block:: text

   http://<RAGFLOW_HOST>/api/v1

Authentication
--------------

All requests require a **Bearer token**:

.. code-block:: text

   Authorization: Bearer ragflow-<your-token>

> **Tip**: Obtain token via login or API key management in the RAGFlow UI.

---

Step 1: Retrieve Dataset and Document IDs
------------------------------------------

Before updating, you **must know** the target:

- **Dataset ID** (e.g., `f388c05e9df711f0a0fe0242ac170003`)
- **Document ID** (e.g., `4920227c9eb711f0bff40242ac170003`)

**List all datasets**:

.. code-block:: bash

   curl -H "Authorization: Bearer ragflow-..." \
        http://192.168.0.213/api/v1/datasets

**List documents in a dataset**:

.. code-block:: bash

   curl -H "Authorization: Bearer ragflow-..." \
        http://192.168.0.213/api/v1/datasets/<dataset_id>/documents

---

Step 2: Add Metadata to a Document (via PUT)
--------------------------------------------

Use the **PUT** endpoint to **update metadata** of an existing document:

.. code-block:: bash

   curl --request PUT \
        --url http://192.168.0.213/api/v1/datasets/f388c05e9df711f0a0fe0242ac170003/documents/4920227c9eb711f0bff40242ac170003 \
        --header 'Content-Type: multipart/form-data' \
        --header 'Authorization: Bearer ragflow-QxNWIzMGNlOWRmMzExZjBhZjljMDI0Mm' \
        --data '{
          "meta_fields": {
            "author": "Example Author",
            "publish_date": "2025-01-01",
            "category": "AI Business Report",
            "url": "https://example.com/report.pdf"
          }
        }'

**Request Breakdown**:

- **Method**: `PUT`
- **Path**: `/api/v1/datasets/<dataset_id>/documents/<document_id>`
- **Content-Type**: `multipart/form-data` (required even for JSON payload)
- **Body**: JSON string with `"meta_fields"` object

**Response (on success)**:

.. code-block:: json

   {
     "code": 0,
     "message": "Success",
     "data": { "document_id": "4920227c9eb711f0bff40242ac170003" }
   }

---

Use Case: Batch Metadata Enrichment
------------------------------------

You can **automate metadata tagging** for **1000s of documents** using a script:

.. code-block:: python

   import requests
   import json

   BASE_URL = "http://192.168.0.213/api/v1"
   TOKEN = "ragflow-QxNWIzMGNlOWRmMzExZjBhZjljMDI0Mm"
   HEADERS = {
       "Authorization": f"Bearer {TOKEN}",
       "Content-Type": "multipart/form-data"
   }

   # Example: Load CSV with doc_id, author, date, url...
   import pandas as pd
   df = pd.read_csv("documents_metadata.csv")

   for _, row in df.iterrows():
       dataset_id = row['dataset_id']
       doc_id = row['document_id']
       payload = {
           "meta_fields": {
               "author": row['author'],
               "publish_date": row['publish_date'],
               "category": row['category'],
               "url": row['source_url']
           }
       }

       files = {'': ('', json.dumps(payload), 'application/json')}
       resp = requests.put(
           f"{BASE_URL}/datasets/{dataset_id}/documents/{doc_id}",
           headers=HEADERS,
           files=files
       )
       print(doc_id, resp.json().get("message"))

**Benefits**:

- Enrich RAG context with **structured, queryable metadata**
- Enable **filtering** in UI or API (e.g., “Show reports from 2025 by Author X”)
- Improve **traceability** and **auditability**

---

Other Batch-Capable Endpoints
-----------------------------

| Endpoint | Purpose |
|--------|--------|
| `POST /api/v1/datasets` | Create new dataset |
| `POST /api/v1/datasets/{id}/documents` | Upload new documents (with metadata) |
| `DELETE /api/v1/datasets/{id}/documents/{doc_id}` | Remove document |
| `GET /api/v1/datasets/{id}/documents` | List + filter by metadata |

---

Best Practices
---------------

1. **Always use IDs** — never rely on filenames
2. **Batch in chunks** (e.g., 100 docs/sec) to avoid rate limits
3. **Validate metadata schema** in RAGFlow settings first
4. **Log responses** for retry logic
5. **Use dataset-level permissions** for access control

---

See also:
---------

https://github.com/infiniflow/ragflow/blob/main/example/http/dataset_example.sh


Summary
-------

RAGFlow’s **API-first design** enables:

- **Scalable batch ingestion**
- **Rich metadata attachment**
- **Full automation** of document lifecycle

> **Perfect for ETL pipelines, CMS integration, or enterprise knowledge base automation.**

With this API, you can manage **tens of thousands of documents** with full metadata — all programmatically.
