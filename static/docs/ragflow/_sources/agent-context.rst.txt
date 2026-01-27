Agent Context
=============


Deconstructing context composition clearly shows that Context Engineering's core task is still retrieval based on the three major data sources Agents need:

- Retrieval of enterprise-private, unstructured domain document data—i.e., RAG.
- Retrieval of conversation history and state data generated during Agent interactions, especially LLM-generated content—i.e., Memory.
- Retrieval of tool description and usage guide data from encapsulated enterprise services and APIs—termed Tool Retrieval. This data can also reside in a dedicated area like Memory.

Thus, in the AI Agent era, RAG technology will undeniably evolve. It is no longer just a step in "Retrieval-Augmented Generation." With "retrieval" as its core capability, expanding its data scope, it evolves into a Context Engine supporting all context assembly needs, becoming the unified Context Layer and data foundation serving LLM applications.

.. figure:: images/agent-context.png



Therefore, retrieval systems for Agents face unprecedented new demands: extremely high request frequency (potentially one to two orders of magnitude higher than human requests in the traditional search era), diverse query types (semantic queries on documents, keyword matching for tools, parameter matching for tool usage guides, associative queries on memory), stringent latency requirements (directly impacting Agent response speed), and the need for tight coupling with the Agent's reasoning flow.


A standalone search engine or vector database is far from sufficient. It requires building an intelligent intermediate service layer atop storage and indexing. This layer understands Agent intent, dynamically coordinates retrieval requests to different underlying data sources (document stores, memory stores, tool libraries) based on context assembly strategies, and performs necessary fusion, deduplication, ranking, and formatting of results, finally packaging them into LLM-ready context.

This usage pattern means the most intricate and specialized "Context Engineering" part of Agent development—currently highly manual and hardcoded in prompts—has the potential to move towards declarative configuration or even automation. This could significantly reduce Agent development and maintenance complexity while improving consistency and reusability.
