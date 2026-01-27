homelab
=======

problem older hardware : 
------------------------
- Xeon E5-2690 v2
- Tesla P100 16GB
- Driver CUDA 11.8

software :
----------
- CUDA 12.8
- AVX512 or AV2 (> xeon v3


problem reranking:
-------------------
- compiled llama.cpp and gguf model which works OK
- unfortunately not recognised in infiniflow/ragflow (not anymore)


possible solution:
-------------------
installing xinference (cpu version) (dockercontainer for GPU too big and CUDA 12.8)


.. code-block:: bash

   
   docker run -d \
       --name xinference-cpu \
       -p 9997:9997 \
       --shm-size=8g \
       --restart unless-stopped \
       -v /home/jan/models:/models \
       xprobe/xinference:latest-cpu \
       xinference-local -H 0.0.0.0
   

.. code-block:: bash

    docker exec xinference-cpu xinference launch \
        --model-name qwen3-reranker-4b \
        --model-format gguf \
        --model-uri /models/Qwen3-Reranker-4B-q5_k_m.gguf \
        --model-type rerank
    

--------------------
Some parameters (especially engine-specific ones for custom/local models like GGUF rerankers) are treated as extra model kwargs and must be prefixed with -- to separate them from the main command options.

.. code-block:: bash

    docker exec -it xinference-cpu xinference launch \
        --model-name Qwen3-Reranker-4B \
        --model-type rerank \
        -- \
        --model-format gguf \
        --model-uri /models/Qwen3-Reranker-4B-q5_k_m.gguf
    
    
    in the container :  (this seems to work OK)
    xinference launch \
        --model-name Qwen3-Reranker-4B \
        --model-type rerank \
        -- \
        --model-format gguf \
        --model-uri /models/Qwen3-Reranker-4B-q5_k_m.gguf



