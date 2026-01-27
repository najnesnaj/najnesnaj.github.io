upload document
===============


first get dataset_id (0fbeb780b40d11f0bf690242ac170006)


 curl --request POST \
     --url http://192.168.0.213/api/v1/datasets/0fbeb780b40d11f0bf690242ac170006/documents \                                       
     --header 'Content-Type: multipart/form-data' \
     --header 'Authorization: Bearer ragflow-_FdZQN68Q1NgLLeLmKe-3qbGHv15fqXg2AfJRENBIIw' \                       
     --form 'file=@./aai2228.pdf'


response
--------

{"code":0,"data":[{"chunk_method":"paper","created_by":"b61ff88eb40611f08d0f0242ac170006","dataset_id":"0fbeb780b40d11f0bf690242ac170006","id":"67288092c92411f0953d0242ac170003","location":"aai2228.pdf","name":"aai2228.pdf","parser_config":{"auto_keywords":0,"auto_questions":0,"chunk_token_num":512,"delimiter":"\n","graphrag":{"entity_types":["organization","person","geo","event","category"],"method":"light","use_graphrag":true},"html4excel":false,"layout_recognize":"Docling","raptor":{"max_cluster":64,"max_token":256,"prompt":"Please summarize the following paragraphs. Be careful with the numbers, do not make things up. Paragraphs as following:\n      {cluster_content}\nThe above is the content you need to summarize.","random_seed":0,"scope":"file","threshold":0.1,"use_raptor":true},"toc_extraction":false,"topn_tags":3},"pipeline_id":"","run":"UNSTART","size":2128247,"source_type":"local","suffix":"pdf","thumbnail":"thumbnail_67288092c92411f0953d0242ac170003.png","type":"pdf"}]}

