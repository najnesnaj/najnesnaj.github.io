.. _ragflow_models:


example:
--------

curl -X POST http://localhost:8000/v1/rerank \
    -H "Content-Type: application/json" \
    -d '{
        "model": "uw-modelnaam.gguf",
        "query": "Wat is het weer in Lokeren?",
        "documents": [
            "Het is vandaag zonnig in Brussel.",
            "Lokeren ligt in Oost-Vlaanderen.",
            "Het KNMI voorspelt regen voor morgen."
        ]
    }'




Why Infiniflow RAGFlow Uses a Reranker, an Embedding Model, and a Chat Model
===========================================================================

Infiniflow RAGFlow is a Retrieval-Augmented Generation (RAG) framework designed to build high-quality, traceable question-answering systems over complex data sources. To achieve accurate and contextually relevant responses, RAGFlow employs three distinct models that work in concert:

1. **Embedding Model**
   - **Purpose**: Converts both the user query and the chunks of retrieved documents into dense vector representations in the same semantic space.
   - **Role in Pipeline**: Enables semantic similarity search during the retrieval phase. By computing cosine similarity (or other distance metrics) between the query embedding and document chunk embeddings, RAGFlow retrieves the most semantically relevant passages from a large corpus—far beyond keyword matching.

2. **Reranker**
   - **Purpose**: Refines the initial retrieval results by re-scoring the top-*k* candidate chunks using a cross-encoder architecture.
   - **Role in Pipeline**: While the embedding model provides efficient approximate retrieval, the reranker applies a more computationally intensive but accurate relevance scoring. This step significantly improves precision by pushing the most contextually appropriate chunks to the top, reducing noise before generation.

   .. figure:: images/rerank.png
      :alt: RAGFlow reranking process illustration
      :align: center

      **Figure 1**: The reranker evaluates query-chunk pairs to produce fine-grained relevance scores.

3. **Chat Model (LLM)**
   - **Purpose**: Generates the final natural language response grounded in the refined retrieved context.
   - **Role in Pipeline**: Takes the top reranked chunks as context and synthesizes a coherent, accurate, and fluent answer. The chat model (typically a large language model fine-tuned for instruction following) ensures the output is not only factually aligned with the source material but also conversational and user-friendly.

Synergy of the Three Models
---------------------------

- **Embedding Model** → Broad, fast, semantic retrieval  
- **Reranker** → Precise, fine-grained reordering  
- **Chat Model** → Coherent, grounded generation  

This modular design allows RAGFlow to balance **speed**, **accuracy**, and **interpretability**, making it suitable for enterprise-grade RAG applications where both performance and trustworthiness are critical.
