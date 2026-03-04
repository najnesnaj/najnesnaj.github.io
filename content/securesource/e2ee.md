---
title: 'e2ee'
draft: false
weight: 200
---
**Using End-to-End Encryption (E2EE) folders in openDesk** is done through the integrated **Nextcloud** component, as openDesk uses Nextcloud for file storage, synchronization, and sharing. E2EE provides true zero-knowledge protection: files are encrypted on your device before upload, and the server (including admins) never sees plaintext data or keys. This is folder-level (not account-wide), and it's client-driven.

**Important notes before starting (as of March 2026):**
- Your openDesk instance admin must have the **End-to-End Encryption** app enabled in Nextcloud (it's usually available in sovereign/public-sector setups like openDesk, but confirm with your admin if you don't see the option).
- **Server-side encryption** (the older/default module) must be **disabled** — the two are incompatible.
- Setup and folder encryption happen **only in the official Nextcloud clients** (desktop, Android, iOS) — not in the web browser initially.
- E2EE folders support sharing with other users (since Nextcloud ~26+ improvements), but previews, search, and some web features are limited or unavailable for encrypted content.
- Always back up important files outside E2EE folders before experimenting.

### Step-by-Step Guide to Set Up and Use E2EE Folders

1. **Install/Update the Nextcloud Client**  
   Download and install the latest official Nextcloud desktop client from nextcloud.com/install (or via your openDesk portal links if provided).  
   - Windows/macOS/Linux desktop client (version 3.10+ recommended, ideally latest).  
   - Android/iOS mobile apps from their stores.  
   Connect the client to your openDesk Nextcloud server URL (usually something like https://yourinstance.opendesk.eu or similar) using your openDesk login credentials.

2. **Enable/Activate E2EE on Your First Device**  
   Open the Nextcloud desktop client (or mobile app):  
   - Go to **Settings** (gear icon) → Look for the **End-to-End Encryption** or **E2EE** section (it may appear under Security or a dedicated tab once the server supports it).  
   - Click **Activate** / **Setup end-to-end encryption** / **Enable E2EE**.  
   - The client generates your cryptographic key pair locally.  
   - It displays a **12-word mnemonic** (recovery passphrase) — **write this down immediately and store it securely** (paper in safe place, offline password manager, etc.).  
     - This mnemonic is critical: it's the only way to recover access if you lose all devices or need to add new ones.  
     - Never share it unless intentionally giving full access.  
     - The server never sees this mnemonic.  
   - Confirm/acknowledge the mnemonic (some clients ask you to re-enter words for verification).

3. **Create and Encrypt a Folder**  
   - In the Nextcloud client, create a **new empty folder** (important: must be empty to enable encryption — safety feature to avoid data loss).  
   - Right-click the folder (in the file explorer integration or client interface) → Select **Encrypt** / **Enable end-to-end encryption** / similar option.  
   - The client encrypts the folder metadata and prepares it.  
   - Now add files/documents to this folder:  
     - They are encrypted **locally** on your device before syncing/upload.  
     - On the server (visible in web if you check), files appear as encrypted blobs with lock icons; filenames may be visible or partially obfuscated depending on version/settings.

4. **Access and Work with E2EE Folders**  
   - Use the desktop/mobile client to view, edit, add, or delete files — decryption happens automatically on trusted devices.  
   - Web browser access:  
     - In recent versions, you can enable E2EE in browser personal settings → Security → enter mnemonic temporarily per session.  
     - But E2EE folders are often **read-only** in web, and full edit/upload may be restricted — prefer clients for best experience.  
   - Sync works across your devices: add the mnemonic on new devices to trust them (see step 5).

5. **Add More Devices (Multi-Device Support)**  
   - Install client on new device and connect to the same account.  
   - In E2EE settings → Choose **Add device** / **Recover** / **Enter mnemonic**.  
   - Enter your 12-word mnemonic → the client derives keys, downloads encrypted private key material, and adds the device.  
   - After this, sync is seamless — no need to re-enter mnemonic unless adding yet another device.

6. **Sharing E2EE Folders with Others** (in openDesk/Nextcloud)**  
   - Right-click the encrypted folder in client → **Share** → Add internal openDesk users (by name/email) or groups.  
   - The sharing uses public-key cryptography: your client encrypts folder keys for the recipient's public key (they must have E2EE enabled and set up on their side).  
   - Recipient accepts the share in their client → they can now decrypt and access.  
   - Revoke: Remove the share — access is instantly cut (no full re-encryption needed).  
   - External/public links: Possible with password/expiration, but recipient needs compatible client to decrypt.  
   - Tip: Recipient must set up E2EE first; share works best internally within openDesk.

7. **Managing / Recovering / Best Practices**  
   - View mnemonic anytime: In client settings → E2EE section → **Display mnemonic**.  
   - If lost: Data in E2EE folders becomes permanently inaccessible without mnemonic + at least one trusted device.  
   - Test first: Create a small test folder with dummy files.  
   - Limitations: No efficient full-text search, thumbnails/previews often don't work, some apps (e.g., photo gallery) can't read encrypted files.  
   - Combine with openDesk 2FA (YubiKey supported for login) for account protection.  
   - For ultra-sensitive use: Consider CryptPad (integrated in openDesk for diagrams/pads) which has its own E2EE by default.

