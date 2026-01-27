How the Knowledge Graph in Infiniflow/RAGFlow Works
====================================================

RAGFlow is an open-source Retrieval-Augmented Generation (RAG) engine developed by Infiniflow, designed to enhance LLM-based question-answering by integrating deep document understanding with structured data processing. The knowledge graph (KG) component plays a pivotal role in handling complex queries, particularly multi-hop question-answering, by extracting and organizing entities and relationships from documents into a graph structure. This enables more accurate and interconnected retrieval beyond simple vector-based searches.

Overview
--------

The KG is constructed as an intermediate step in RAGFlow's data pipeline, bridging raw document extraction and final indexing. It transforms unstructured text into a relational graph, allowing for entity-based reasoning and traversal during retrieval. Key benefits include:

- **Multi-Hop Query Support**: Facilitates queries requiring inference across multiple documents or concepts (e.g., "What caused the event that affected company X?").
- **Dynamic Updates**: From version 0.16.0 onward, the KG is built across an entire knowledge base (multiple files) and automatically updates when new documents are uploaded and parsed.
- **Integration with RAG 2.0**: Part of preprocessing stages like document clustering and domain-specific embedding, ensuring retrieval results are contextually rich and grounded.

The KG is stored as chunks in RAGFlow's document engine (Elasticsearch by default or Infinity for advanced vector/graph capabilities), making it queryable alongside embeddings.

Construction Process
--------------------

The KG construction occurs after initial document parsing but before indexing. Here's the step-by-step workflow:

1. **Document Ingestion and Extraction**:
   - Users upload files (e.g., PDF, Word, Excel, TXT) to a knowledge base.
   - RAGFlow's Deep Document Understanding (DDU) module parses the content, extracting structured elements like text blocks, tables, and layouts using OCR and layout models.

2. **Entity and Relation Extraction**:
   - Using NLP models (integrated via configurable LLMs or embedding services), RAGFlow identifies entities (e.g., people, organizations, events) and relations (e.g., "causes", "affiliated with") from extracted chunks.
   - This is model-driven: Preprocessing applies entity recognition and relation extraction to raw text, often leveraging domain-specific prompts for accuracy.

3. **Graph Building**:
   - Entities become nodes, and relations form directed/undirected edges.
   - The graph is unified across the entire dataset (not per-file since v0.16.0), enabling cross-document connections.
   - Acceleration features (introduced in later releases) optimize extraction speed, such as batch processing or efficient model inference.

4. **Storage**:
   - Graph chunks (nodes, edges, metadata) are serialized and stored in the document engine.
   - No separate graph database is required; it's embedded within the vector/full-text index for hybrid queries.

.. note::
   Construction can be toggled per knowledge base and is optional, but recommended for complex domains like finance or healthcare.

Query and Retrieval Process
---------------------------

During inference, the KG enhances retrieval in the following manner:

1. **Query Parsing**:
   - Incoming user queries are analyzed to detect multi-hop intent (e.g., via LLM routing).

2. **Hybrid Retrieval**:
   - Combine vector similarity search (for semantic relevance) with graph traversal:
     - Start from query entities as seed nodes.
     - Traverse edges to fetch connected nodes (e.g., 1-2 hops).
     - Rank results by relevance scores, incorporating graph proximity.
   - Infinity engine (optional) supports efficient graph-range filtering alongside vectors.

3. **Augmentation and Generation**:
   - Retrieved graph-derived contexts (e.g., subgraphs or paths) are fused with text chunks.
   - Fed to the LLM for grounded generation, with citations traceable to source documents.

This process addresses limitations of pure vector RAG, such as hallucination in interconnected scenarios, by providing explicit relational paths.

Key Features and Limitations
----------------------------

- **Features**:
  - **Scalability**: Handles enterprise-scale knowledge bases with dynamic rebuilding.
  - **Customizability**: Configurable extraction models and hop limits.
  - **Agent Integration**: Supports agentic workflows for iterative graph exploration.
  - **Performance**: Accelerated extraction in v0.21+ releases.

- **Limitations**:
  - Relies on quality of upstream extraction; noisy documents may yield incomplete graphs.
  - Graph depth is configurable but can increase latency for deep traversals.
  - Arm64 Linux support is limited when using Infinity.

For implementation details, refer to the official guide at https://github.com/infiniflow/ragflow/blob/main/docs/guides/dataset/construct_knowledge_graph.md. To experiment, deploy RAGFlow via Docker and enable KG in your knowledge base settings.
