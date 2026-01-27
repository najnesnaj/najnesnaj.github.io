Using SearXNG with RAGFlow
==========================

Introduction to SearXNG in RAGFlow Agents
-----------------------------------------

RAGFlow provides powerful **agent capabilities**, including built-in web
search tools for real-time information retrieval during reasoning or
chat sessions. The default web search often relies on cloud providers
like Tavily, which require API keys and may incur costs.

**SearXNG** serves as a privacy-focused, open-source metasearch engine
that aggregates results from multiple sources (e.g., Google, Bing,
DuckDuckGo) without tracking users. Deploying SearXNG locally offers a
fully self-hosted alternative, ideal for enterprises prioritizing data
privacy, avoiding external API dependencies, or operating in restricted
networks.

Although RAGFlow does not yet include native SearXNG support in its UI
(as of early 2026 releases), users can integrate it easily via **custom
agent tools** or by pointing the web search component to a local SearXNG
instance. This approach mirrors integrations in similar open-source
tools like Open WebUI, AnythingLLM, and Perplexica.

Benefits of Using SearXNG with RAGFlow
--------------------------------------

-  **Full Privacy and Control** — All searches stay within your
   infrastructure. No data leaks to third-party APIs, making it perfect
   for sensitive or regulated environments.
-  **No Costs or Rate Limits** — Unlike Tavily or SerpAPI, SearXNG runs
   free with unlimited queries (limited only by your hardware).
-  **Customizable Search Engines** — Configure SearXNG to use specific
   engines, add restrictions, or focus on reliable sources.
-  **Hybrid Real-Time Retrieval** — Agents combine internal knowledge
   bases (private documents) with fresh web results, reducing
   hallucinations on current events or external facts.
-  **Intranet Compatibility** — Deploy SearXNG in air-gapped or
   intranet-only setups. For purely internal “browsing,” configure it to
   search indexed intranet pages (via custom engines or plugins) or pair
   it with RAGFlow’s built-in web page ingestion for static internal
   sites.

Benefits for Intranet Page Browsing
-----------------------------------

RAGFlow excels at ingesting and querying private/internal documents, but
dynamic intranet pages (e.g., wikis, dashboards) may require real-time
access.

-  **With Internet Access**: SearXNG provides standard web search while
   keeping queries internal to your server.
-  **Without Internet (Pure Intranet)**:

   -  Use RAGFlow’s native web crawling/ingestion to periodically index
      intranet URLs into knowledge bases.
   -  Configure SearXNG with custom “site:” restrictions or internal
      search engines (e.g., via plugins for mediawiki or confluence) to
      query only intranet domains.
   -  This creates a “local web search” experience where agents retrieve
      up-to-date content from internal sites without exposing data
      externally.

Deployment in Docker Containers
-------------------------------

Both RAGFlow and SearXNG deploy easily with Docker, often on the same
network for seamless communication.

1. Deploy SearXNG
~~~~~~~~~~~~~~~~~

Use the official ``searxng/searxng`` image or the dedicated docker repo.

Example ``docker-compose.yml`` for SearXNG:

.. code-block:: yaml

version: ‘3’ services: searxng: image: searxng/searxng:latest
container_name: searxng ports: - “8080:8080” volumes: -
./searxng:/etc/searxng environment: - BASE_URL=http://localhost:8080
restart: unless-stopped

Key configuration in ``searxng/settings.yml`` (mounted volume):

.. code-block:: yaml

search: formats: - html - json # Required for API/tool calls server:
limiter: false # Disable rate limiting for agent use secret_key:
your_strong_secret

Run: ``docker compose up -d``

2. Integrate with RAGFlow
~~~~~~~~~~~~~~~~~~~~~~~~~

-  Deploy RAGFlow normally (via its official docker-compose.yml).
-  Place both in the same Docker network or use ``host`` networking.
-  In RAGFlow’s Agent builder:

   -  Create a custom tool that calls your local SearXNG API
      (``http://searxng:8080/search?q={query}&format=json``).
   -  Or, if using the built-in Websearch Agent, configure it (via env
      vars or custom code) to route to your SearXNG endpoint instead of
      Tavily.

-  Many users report success with similar custom integrations in agent
   frameworks.

Combined Example Network
~~~~~~~~~~~~~~~~~~~~~~~~

Extend RAGFlow’s compose file to include SearXNG:

.. code-block:: yaml

    services: # … existing RAGFlow services … searxng: image:
    searxng/searxng:latest ports: - “8080:8080” volumes: -
    ./searxng:/etc/searxng networks: - ragflow_network

This setup keeps everything containerized, secure, and scalable.

example on homelab

.. code-block:: yaml

   services:
     caddy:
       container_name: caddy
       image: docker.io/library/caddy:2-alpine
       network_mode: host
       restart: unless-stopped
       volumes:
         - ./Caddyfile:/etc/caddy/Caddyfile:ro
         - caddy-data:/data:rw
         - caddy-config:/config:rw
       environment:
         - SEARXNG_HOSTNAME=${SEARXNG_HOSTNAME:-http://192.168.0.213}
         - SEARXNG_TLS=${LETSENCRYPT_EMAIL:-internal}
       logging:
         driver: "json-file"
         options:
           max-size: "1m"
           max-file: "1"
   
     searxng:
       container_name: searxng
       image: docker.io/searxng/searxng:latest
       restart: unless-stopped
       networks:
         - searxng
       ports:
         - "192.168.0.213:8080:8080"
       volumes:
         - ./searxng:/etc/searxng:rw
       environment:
         - SEARXNG_BASE_URL=https://${SEARXNG_HOSTNAME:-192.168.0.213}/
       depends_on:
         - caddy
       logging:
         driver: "json-file"
         options:
           max-size: "1m"
           max-file: "1"

networks:
  searxng:

volumes:
  caddy-data:
  caddy-config:



Conclusion
----------

Integrating SearXNG with RAGFlow delivers a powerful, private
alternative to cloud-based web search in agents—especially valuable for
intranet deployments where data sovereignty matters. While awaiting
potential native support, the custom tool approach works reliably and
aligns with RAGFlow’s extensible design.

For the latest updates, monitor RAGFlow’s GitHub issues/releases or
community discussions. This combination empowers fully self-hosted,
real-time augmented agents without compromising privacy.
