Graphrag
========

curl --request POST \
     --url http://{address}/api/v1/datasets/{dataset_id}/run_graphrag \
     --header 'Authorization: Bearer <YOUR_API_KEY>' 

-> get dataset ID


 curl -H "Authorization: Bearer ragflow-_FdZQN68Q1NgLLeLmKe-3qbGHv15fqXg2AfJRENBIIw"         http://192.168.0.213/api/v1/datasets


reponse (json) 
--------------
{"code":0,"data":[{"avatar":null,"chunk_count":698,"chunk_method":"paper","create_date":"Tue, 28 Oct 2025 22:47:44 GMT","create_time":1761662864024,"created_by":"b61ff88eb40611f08d0f0242ac170006","description":"  ","document_count":6,"embedding_model":"mxbai-embed-large:latest@Ollama","graphrag_task_finish_at":null,"graphrag_task_id":null,"id":"0fbeb780b40d11f0bf690242ac170006","language":"English","mindmap_task_finish_at":null,"mindmap_task_id":null,"name":"testaankoop","pagerank":15,"parser_config":{"auto_keywords":5,"auto_questions":2,"chunk_token_num":512,"delimiter":"\n","graphrag":{"community":true,"entity_types":["organization","person","geo","event","category"],"method":"general","resolution":true,"use_graphrag":true},"html4excel":false,"layout_recognize":"DeepDOC","raptor":{"max_cluster":64,"max_token":256,"prompt":"Please summarize the following paragraphs. Be careful with the numbers, do not make things up. Paragraphs as following:\n      {cluster_content}\nThe above is the content you need to summarize.","random_seed":0,"scope":"file","threshold":0.1,"use_raptor":true},"tag_kb_ids":[],"toc_extraction":false,"topn_tags":3},"permission":"me","pipeline_id":"","raptor_task_finish_at":null,"raptor_task_id":null,"similarity_threshold":0.2,"status":"1","tenant_id":"b61ff88eb40611f08d0f0242ac170006","token_num":90496,"update_date":"Mon, 24 Nov 2025 23:09:25 GMT","update_time":1763996965365,"vector_similarity_weight":0.3}],"total_datasets":1}

--> we need: testaankoop
"id":"0fbeb780b40d11f0bf690242ac170006"

graphrag
---------


curl --request POST \
     --url http://{address}/api/v1/datasets/{dataset_id}/run_graphrag \
     --header 'Authorization: Bearer <YOUR_API_KEY>'

curl --request POST \
     --url http://192.168.0.213/api/v1/datasets/0fbeb780b40d11f0bf690242ac170006/run_graphrag \
     --header "Authorization: Bearer ragflow-_FdZQN68Q1NgLLeLmKe-3qbGHv15fqXg2AfJRENBIIw"

respons : {"code":0,"data":{"graphrag_task_id":"9512c8e8c9e511f09b860242ac170003"}}

(very resource intensive!!!!!)

[GIN] 2025/11/25 - 10:12:59 | 200 |         8m10s |      172.17.0.1 | POST     "/api/chat"

[GIN] 2025/11/25 - 10:13:15 | 200 |         7m18s |      172.17.0.1 | POST     "/api/chat"

[GIN] 2025/11/25 - 10:13:57 | 200 |         6m56s |      172.17.0.1 | POST     "/api/chat"

[GIN] 2025/11/25 - 10:14:47 | 200 |          6m9s |      172.17.0.1 | POST     "/api/chat"

[GIN] 2025/11/25 - 10:15:40 | 200 |         5m44s |      172.17.0.1 | POST     "/api/chat"
....................


So slow, need to see progress
-----------------------------
check log docker container docker-ragflow-cpu-1: 

2025-11-25 21:05:43,460 INFO     8082 task_executor_cedac6537903_0 reported heartbeat: {"ip_address": "172.23.0.3", "pid": 8082, "name": "task_executor_cedac6537903_0", "now": "2025-11-25T21:05:43.459+08:00", "boot_at": "2025-11-25T16:43:07.370+08:00", "pending": 1, "lag": 0, "done": 0, "failed": 0, "current": {"9512c8e8c9e511f09b860242ac170003": {"id": "9512c8e8c9e511f09b860242ac170003", "doc_id": "graph_raptor_x", "from_page": 100000000, "to_page": 100000000, "retry_count": 0, "kb_id": "0fbeb780b40d11f0bf690242ac170006", "parser_id": "paper", "parser_config": {"layout_recognize": "DeepDOC", "chunk_token_num": 512, "delimiter": "\n", "auto_keywords": 0, "auto_questions": 0, "html4excel": false, "topn_tags": 3, "raptor": {"use_raptor": true, "prompt": "Please summarize the following paragraphs. Be careful with the numbers, do not make things up. Paragraphs as following:\n      {cluster_content}\nThe above is the content you need to summarize.", "max_token": 256, "threshold": 0.1, "max_cluster": 64, "random_seed": 0}, "graphrag": {"use_graphrag": true, "entity_types": ["organization", "person", "geo", "event", "category"], "method": "light"}}, "name": "aai2225.pdf", "type": "pdf", "location": "aai2225.pdf", "size": 2893963, "tenant_id": "b61ff88eb40611f08d0f0242ac170006", "language": "English", "embd_id": "mxbai-embed-large:latest@Ollama", "pagerank": 15, "kb_parser_config": {"layout_recognize": "DeepDOC", "chunk_token_num": 512, "delimiter": "\n", "auto_keywords": 5, "auto_questions": 2, "html4excel": false, "tag_kb_ids": [], "topn_tags": 3, "toc_extraction": false, "raptor": {"use_raptor": true, "prompt": "Please summarize the following paragraphs. Be careful with the numbers, do not make things up. Paragraphs as following:\n      {cluster_content}\nThe above is the content you need to summarize.", "max_token": 256, "threshold": 0.1, "max_cluster": 64, "random_seed": 0, "scope": "file"}, "graphrag": {"use_graphrag": true, "entity_types": ["organization", "person", "geo", "event", "category"], "method": "general", "resolution": true, "community": true}}, "img2txt_id": "", "asr_id": "", "llm_id": "qwen2.5:14b@Ollama", "update_time": 1764064833424, "doc_ids": ["2d7ce1c0b40d11f0aad70242ac170006", "2dbc4db0b40d11f0aad70242ac170006", "2df27a3eb40d11f0aad70242ac170006", "2e46ad98b40d11f0aad70242ac170006", "2ed60b1eb40d11f0aad70242ac170006", "67288092c92411f0953d0242ac170003"], "task_type": "graphrag"}}}
2025-11-25 21:06:13,466 INFO     8082 task_executor_cedac6537903_0 reported heartbeat: {"ip_address": "172.23.0.3", "pid": 8082, "name": "task_executor_cedac6537903_0", "now": "2025-11-25T21:06:13.465+08:00", "boot_at": "2025-11-25T16:43:07.370+08:00", "pending": 1, "lag": 0, "done": 0, "failed": 0, "current": {"9512c8e8c9e511f09b860242ac170003": {"id": "9512c8e8c9e511f09b860242ac170003", "doc_id": "graph_raptor_x", "from_page": 100000000, "to_page": 100000000, "retry_count": 0, "kb_id": "0fbeb780b40d11f0bf690242ac170006", "parser_id": "paper", "parser_config": {"layout_recognize": "DeepDOC", "chunk_token_num": 512, "delimiter": "\n", "auto_keywords": 0, "auto_questions": 0, "html4excel": false, "topn_tags": 3, "raptor": {"use_raptor": true, "prompt": "Please summarize the following paragraphs. Be careful with the numbers, do not make things up. Paragraphs as following:\n      {cluster_content}\nThe above is the content you need to summarize.", "max_token": 256, "threshold": 0.1, "max_cluster": 64, "random_seed": 0}, "graphrag": {"use_graphrag": true, "entity_types": ["organization", "person", "geo", "event", "category"], "method": "light"}}, "name": "aai2225.pdf", "type": "pdf", "location": "aai2225.pdf", "size": 2893963, "tenant_id": "b61ff88eb40611f08d0f0242ac170006", "language": "English", "embd_id": "mxbai-embed-large:latest@Ollama", "pagerank": 15, "kb_parser_config": {"layout_recognize": "DeepDOC", "chunk_token_num": 512, "delimiter": "\n", "auto_keywords": 5, "auto_questions": 2, "html4excel": false, "tag_kb_ids": [], "topn_tags": 3, "toc_extraction": false, "raptor": {"use_raptor": true, "prompt": "Please summarize the following paragraphs. Be careful with the numbers, do not make things up. Paragraphs as following:\n      {cluster_content}\nThe above is the content you need to summarize.", "max_token": 256, "threshold": 0.1, "max_cluster": 64, "random_seed": 0, "scope": "file"}, "graphrag": {"use_graphrag": true, "entity_types": ["organization", "person", "geo", "event", "category"], "method": "general", "resolution": true, "community": true}}, "img2txt_id": "", "asr_id": "", "llm_id": "qwen2.5:14b@Ollama", "update_time": 1764064833424, "doc_ids": ["2d7ce1c0b40d11f0aad70242ac170006", "2dbc4db0b40d11f0aad70242ac170006", "2df27a3eb40d11f0aad70242ac170006", "2e46ad98b40d11f0aad70242ac170006", "2ed60b1eb40d11f0aad70242ac170006", "67288092c92411f0953d0242ac170003"], "task_type": "graphrag"}}}



Stuck ???? what now????
------------------------

stopped the container ....


2025-11-25 21:18:25,668 INFO     36 task_executor_cedac6537903_0 reported heartbeat: {"ip_address": "172.23.0.3", "pid": 36, "name": "task_executor_cedac6537903_0", "now": "2025-11-25T21:18:25.667+08:00", "boot_at": "2025-11-25T21:15:55.594+08:00", "pending": 0, "lag": 0, "done": 0, "failed": 1, "current": {}}


(failed state task_executor)
