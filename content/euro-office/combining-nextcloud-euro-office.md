Yes, Euro-Office can be integrated into Nextcloud and Nextcloud All-in-One (AIO). Nextcloud added Euro-Office as an alternative office suite alongside options like Collabora Online and Nextcloud/ONLYOFFICE.

---

### Integration Options

#### Option 1: Fresh Installation via Nextcloud AIO

In the latest versions of the Nextcloud All-in-One setup interface (the setup wizard running on port `8080`), Euro-Office is selectable directly as a bundled container option during initial setup:

1. Launch the Nextcloud AIO interface before finalizing the initial container deployment.
2. Under the **Optional Add-ons / Office Suite** section, toggle on **Euro-Office**.
3. Click **Start Containers**. AIO will automatically spin up the Euro-Office document server container and handle internal network routing and SSL certificates for you.

---

#### Option 2: Existing Nextcloud AIO Setup (App Store)

If your AIO instance is already running:

1. **Enable the Integration App in Nextcloud:**
* Log in as an administrator.
* Go to **Top-Right Profile Menu** $\rightarrow$ **Apps** $\rightarrow$ **Office & text**.
* Find **Euro-Office integration** (or search for `eurooffice`) and click **Download and enable**.


2. **Connect to the Euro-Office Document Server:**
* Go to **Administration settings** $\rightarrow$ **Euro-Office**.
* Enter the address of your Euro-Office Document Server instance (if self-hosting externally) along with your Secret Key / JWT token.
* Save the configuration.



---
