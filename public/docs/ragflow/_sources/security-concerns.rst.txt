Security Concerns
==================


The origin of ragflow is Chinese. Infiniflow is a Chinese company.
It was open-sourced in 2024.

Chinese origin of RAGFlow is not a material security concern in practice — the project is one of the technically strongest deep-document-understanding RAG engines available right now.For organizations that must comply with very strict procurement rules, national security guidelines, or have board-level "no Chinese tech" policies → yes, it's frequently considered a blocking factor, even if the technical risk is low.Choose according to your actual risk appetite and compliance requirements — not just origin country.



considerations:
----------------

to mitigate risc :
→ Self-host + build your own Docker image from the official source code
→ Audit the diff yourself or let your security team do it (very feasible — the codebase is not enormous)
→ Use only Western/local/open-source LLMs & embedding models
→ Result: concern level drops to same as any other active open-source project


sandbox:
---------

RAGFlow is an excellent open-source deep-document-understanding + Agent-oriented RAG engine.It contains a very powerful feature: Code component inside Agents. Users can write Python or JavaScript code directly in the workflow/agent → this code can:Process retrieved chunks
Call external APIs
Do calculations / data cleaning
Transform data
Call other tools dynamically basically anything Python/JS can do

→ This is extremely powerful, but also extremely dangerous if you let random users (or even semi-trusted internal users) write code.



That's where RAGFlow Sandbox + gVisor comes in

This can be enabled in ".env".


User → Agent workflow → Code component (Python/JS)
                                 ↓
                     RAGFlow Sandbox Executor Manager
                                 ↓
               Spawns short-lived container(s) using
                        runtime: runsc (gVisor)
                                 ↓
             Code runs inside very strong syscall sandbox


elasticsearch:
---------------


-  xpack.security.enabled: true
-  Transport TLS enabled + working (verification_mode: certificate is ok)
-  HTTP TLS enabled (HTTPS) on all nodes that receive traffic
-  Strong passwords set for all built-in users (elastic, kibana_system, logstash_system, beats_system, apm_system, ...)
-  Dedicated roles + users for each service (never use elastic superuser in production apps)
-  Keystore used for all passwords (not plaintext in yml!)
-  Firewall: 9300 only between nodes, 9200 only from trusted sources
-  Regular certificate rotation plan (at least yearly, better automated)
-  Monitoring of certificate expiration
-  Audit logging enabled (at least for authentication/security events)
