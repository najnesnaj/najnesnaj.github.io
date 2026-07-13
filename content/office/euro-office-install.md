>Yes, you can absolutely install it yourself. Because Euro-Office is fully open source (licensed under the AGPLv3), you don't need to buy a platform like Canvos to use it.

Like ONLYOFFICE, Euro-Office is split into two parts:

1. **The Document Server:** The heavy-lifting engine (handles the rendering, text parsing, and calculations).
2. **The Connector:** A lightweight plugin for your frontend platform (like Nextcloud, XWiki, or OpenProject) that embeds the editors via an iframe.

Setting it up requires a self-hosted environment. The **Docker** method is the easiest way to get it running, though native packages for Ubuntu/Debian (`.deb`) and Fedora (`.rpm`) are also available.

---

### Step 1: Spin up the Euro-Office Document Server (via Docker)

The document server requires a decent amount of horsepower—the creators recommend a bare minimum of **4 GB RAM** (8 GB is better) and 10 GB of disk space.

Run the following command to start the container. Make sure to generate a strong, random JSON Web Token (JWT) secret to secure communication between your frontend and the document server:

```bash
docker run -i -t -d -p 8080:80 --restart always \
  -e JWT_ENABLED="true" \
  -e JWT_SECRET="your_very_long_random_secret_here" \
  -e JWT_HEADER="Authorization" \
  eurooffice/documentserver:latest

```

> **Pro Tip:** In production, you shouldn't expose port 8080 directly to the web. Instead, point a domain name (like `office.yourdomain.com`) to your server and set up a reverse proxy (like Nginx, Caddy, or Traefik) to handle HTTPS/SSL. The editor *must* run over HTTPS if your cloud platform uses HTTPS.

---

### Step 2: Connect it to Nextcloud

Euro-Office features first-class, built-in integration with Nextcloud (version 33 or newer).

1. **Install the Connector:** Log into your Nextcloud instance as an admin, head to **Apps** $\rightarrow$ **Office & Text**, look for **Euro-Office integration**, and click **Download and enable**.
2. **Configure the Settings:** Navigate to **Settings** $\rightarrow$ **Administration** $\rightarrow$ **Euro-Office**.
3. **Link the Servers:**
* In the **Document Server URL** field, enter the address of your newly installed server (e.g., `[https://office.yourdomain.com](https://office.yourdomain.com)`).
* In the **Secret Key** field, paste the exact `JWT_SECRET` string you used when launching the Docker container.


4. **Save:** Click save, and Nextcloud will test the link. Once it turns green, clicking any `.docx`, `.xlsx`, or `.pptx` file in your cloud will automatically launch the Euro-Office editor.

If you prefer to avoid manually dealing with Docker and web servers, the official **Nextcloud All-in-One (AIO)** installer lets you seamlessly check a box to deploy Euro-Office alongside your cloud environment automatically.
