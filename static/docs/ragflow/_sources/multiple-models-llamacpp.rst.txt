.. _running-multiple-models-llama-cpp-docker:

Running Multiple Models on llama.cpp Using Docker
=================================================

This guide demonstrates how to run multiple language models simultaneously using ``llama.cpp`` in Docker via ``docker-compose``. The example below defines two services: a lightweight reranker model (Qwen3 0.6B) and a general-purpose chat model (Llama 3.1).

Example ``docker-compose.yml``
------------------------------

.. code-block:: yaml
   :linenos:

   services:
     qwen-reranker:
       image: ghcr.io/ggerganov/llama.cpp:server-cpu
       ports:
         - "8123:8080"
       volumes:
         - /home/naj/qwen3-reranker-0.6b:/models/qwen3-reranker-0.6b:ro
       environment:
         - MODEL=/models/qwen3-reranker-0.6b
       command: >
         --model /models/qwen3-reranker-0.6b/model.gguf
         --port 8080
         --host 0.0.0.0
         --n-gpu-layers 0
         --ctx-size 8192
         --threads 6
         --temp 0.0
         --rpc
       deploy:
         resources:
           limits:
             cpus: '6'
             memory: 10G
       shm_size: 4g
       restart: unless-stopped

     llama3.1-chat:
       image: ghcr.io/ggerganov/llama.cpp:server-cpu
       ports:
         - "8124:8080"
       volumes:
         - /home/naj/llama3.1:/models/llama3.1:ro
       environment:
         - MODEL=/models/llama3.1
       command: >
         --model /models/llama3.1/model.gguf
         --port 8080
         --host 0.0.0.0
         --n-gpu-layers 0
         --ctx-size 8192
         --threads 10
         --temp 0.7
         --rpc
       deploy:
         resources:
           limits:
             cpus: '10'
             memory: 20G
       shm_size: 8g
       restart: unless-stopped

Key Configuration Notes
-----------------------

- **Images**: Both services use the official CPU-optimized ``llama.cpp`` server image.
- **Ports**:
  - Reranker exposed on ``8123`` → internal ``8080``
  - Chat model exposed on ``8124`` → internal ``8080``
- **Volumes**: Model directories are mounted read-only (``:ro``) from the host.
- **Environment**: ``MODEL`` variable simplifies path references in commands.
- **Command Flags**:
  - ``--n-gpu-layers 0``: Forces CPU-only inference.
  - ``--ctx-size 8192``: Sets context length.
  - ``--temp``: Controls randomness (0.0 for deterministic reranking, 0.7 for chat).
  - ``--rpc``: Enables RPC interface for external control.
- **Resource Limits**: CPU and memory capped via ``deploy.resources.limits``.
- **Shared Memory (shm_size)**: Increased to support larger contexts and batching.
- **Restart Policy**: ``unless-stopped`` ensures containers restart on failure or reboot.

Usage
-----

Start the services:

.. code-block:: bash

   docker compose up -d

Access the models:

- Reranker: ``http://localhost:8123``
- Chat:     ``http://localhost:8124``

Send requests using the OpenAI-compatible API or ``llama.cpp`` client tools.
