Om volledig onafhankelijk te worden van Amerikaanse hyperscalers (zoals Microsoft 365, AWS of Azure) heb je meer nodig dan alleen een alternatieve server. Je moet de **gehele stack** — van de fysieke hosting en de identificatielaag tot de kantoorsoftware op de werkplek van de gebruiker — inrichten op basis van open standaarden en soevereine (Europese) bouwstenen.

Twee toonaangevende initiatieven illustreren hoe overheden en Europese bedrijven dit aanpakken: **MijnBureau** (het open-source werkplek-initiatief van de Nederlandse overheid) en de combinatie van **Nextcloud met Euro-Office** (het soevereine Europese Microsoft 365-alternatief).

---

### De 4 Lagen van een Hyperscaler-Vrije Stack

Om deze oplossingen succesvol in te richten, moet je de afhankelijkheid op **vier niveaus** vervangen:

```
+-----------------------------------------------------------------------+
| 4. APPLICATIES          Euro-Office / Collabora / Nextcloud Apps      |
+-----------------------------------------------------------------------+
| 3. PRODUCTIVITEITSHUB  Nextcloud Hub / openDesk / MijnBureau          |
+-----------------------------------------------------------------------+
| 2. IDENTITEIT & SEC    Keycloak / OpenID Connect (OIDC)               |
+-----------------------------------------------------------------------+
| 1. INFRASTRUCTUUR      Europese IaaS (Hetzner/OVH) of Private Cloud   |
+-----------------------------------------------------------------------+

```

---

### Voorbeeld 1: MijnBureau (Het Nederlandse Overheidsinitiatief)

**Wat is het?**
MijnBureau is een initiatief van de Nederlandse Rijksoverheid (onder meer ontwikkeld binnen SSC-ICT en gerelateerd aan het DAWO-programma). Het is een **geïntegreerde, autonome werkplek** die modulaire Europese open-source software bundelt (vaak leunend op de Duitse openDesk-bouwstenen) om rijksambtenaren te ontkoppelen van de Microsoft-vendor lock-in.

#### Aanpak & Architectuur van MijnBureau:

1. **Infrastructuur:** MijnBureau wordt niet gehost bij AWS of Azure, maar op een **autonome overheidscloud** of soevereine IaaS-providers. Met Kubernetes (bijv. via Rancher/RKE2 of Talos Linux) wordt de onderliggende cloud-hardware geabstraheerd.
2. **Identiteitsbeheer (De spil):** In plaats van Microsoft Entra ID (Azure AD) gebruikt MijnBureau **Keycloak** of een soortgelijke open-source Identity Provider (IdP). Dit regelt Single Sign-On (SSO) op basis van OpenID Connect en SAML2.
3. **Samenwerking & Kantoorsoftware:**
* **Chat & Videobellen:** Matrix/Element of Open-Xchange in plaats van Microsoft Teams.
* **Documenten & Bestanden:** Nextcloud als centrale opslag en archief.
* **Projectmanagement:** OpenProject.


4. **Beheer & Compliance:** Het platform is zo ontworpen dat data strikt binnen de landsgrenzen of de EU blijft, conform de BIO (Baseline Informatiebeveiliging Overheid) en GDPR.

---

### Voorbeeld 2: Euro-Office + Nextcloud (Het Europese M365 Alternatief)

**Wat is het?**
Nextcloud Hub dient als de vervanger van OneDrive, SharePoint en Teams. Sinds 2026 bundelt een breed Europees industrie-initiatief (met o.a. IONOS, Nextcloud, Eurostack en Soverin) dit met **Euro-Office**: een geharde, volledig soevereine Europese fork/kantoorsuite die de vervanger vormt van Word, Excel en PowerPoint (zowel in de browser als desktop-apps).

#### Aanpak & Architectuur van Euro-Office op Nextcloud:

1. **De Nextcloud Hub (Backend & Opslag):** Nextcloud draait als een PHP/S3-compatibele applicatie die je uitrolt op een Europese hostingpartij (zoals Hetzner, Scaleway, OVHcloud of IONOS).
2. **Euro-Office Document Server:** Euro-Office draait als een aparte, gespecialiseerde container-service (Document Server) naast Nextcloud.
3. **Integratie via Connector:** Via de officiële `eurooffice` Nextcloud-app worden documenten die in Nextcloud staan direct geopend in de browser of de Euro-Office desktop-app, inclusief **realtime co-authoring** (gelijktijdig bewerken).

---

### Stappenplan: Hoe pak je dit concreet aan in jouw organisatie?

Als je de stap wilt maken om hyperscaler-vrij te worden met behulp van deze bouwstenen, volg je dit 5-stappenplan:

#### Stap 1: Breng Identiteit buiten de Hyperscaler

* **Vervang:** Microsoft Entra ID / Okta.
* **Actie:** Zet een **Keycloak**-cluster op bij een Europese provider of in een eigen datacentrum. Koppel Keycloak met je bestaande personeelsdatabase (bijv. LDAP/Active Directory on-premise). Dit wordt het 'Single Source of Truth' voor al je medewerkers.

#### Stap 2: Kies een Soevereine Infrastructuur

* **Vervang:** Azure VMs, Azure Blob Storage, AWS S3.
* **Actie:** Huur bare-metal servers of Kubernetes-clusters bij Europese spelers (zoals Hetzner, OVHcloud of Exoscale) of gebruik OpenStack in eigen beheer. Gebruik **MinIO** of de lokale S3-service van de provider voor object storage.

#### Stap 3: Rol de Productiviteitshub uit (Nextcloud Hub)

* **Vervang:** SharePoint / OneDrive / Teams.
* **Actie:** Rol Nextcloud uit (bij voorkeur via Kubernetes Helm Charts). Koppel Nextcloud voor de authenticatie direct aan je Keycloak IdP via OIDC.

#### Stap 4: Integreer Euro-Office / Collabora voor Documenten

* **Vervang:** Microsoft Word, Excel, PowerPoint.
* **Actie:** Installeer de **Euro-Office Document Server** (of Collabora Online) in een eigen geïsoleerd cluster. Verbind de server via een JWT-secret met Nextcloud. Gebruikers kunnen nu `.docx`, `.xlsx` en `.pptx` bestanden rechtstreeks in de browser of desktop-app bewerken zonder dat er data naar Microsoft-servers lekt.

#### Stap 5: Beheer en Desktop-uitrol

* **Vervang:** Intune / Windows Autopilot.
* **Actie:** Gebruik open-source apparatenbeheer (zoals Canonical Landscape, FleetDM of Wazo) en rol de Nextcloud Sync Client en de Euro-Office Desktop App uit naar de eindgebruikers.

---

### Vergelijkingstabel: Azure/M365 vs. Soeverein Alternatief

| Functionaliteit | Microsoft 365 / Azure | Soeverein Alternatief (MijnBureau / Euro-Office) |
| --- | --- | --- |
| **Identity Provider** | Microsoft Entra ID | **Keycloak** (OpenID Connect / SAML) |
| **Bestanden & Sync** | OneDrive / SharePoint | **Nextcloud Hub** |
| **Documenten bewerken** | Office Online / Desktop | **Euro-Office** of **Collabora Online** |
| **Chat & Videobellen** | Microsoft Teams | **Nextcloud Talk** of **Element (Matrix)** |
| **E-mail & Agenda** | Exchange Online / Outlook | **Open-Xchange** / **Soverin** / **Nextcloud Mail** |
| **Hosting & Cloud** | Azure US datacenters | **Hetzner / OVHcloud / OpenStack** |

### Waar moet je rekening mee houden? (De 'Realiteitscheck')

* **Gebruikersgewenning:** Euro-Office en Nextcloud benaderen de UX van Microsoft erg dicht, maar complexe Excel-macro's (VBA) of specifieke PowerAutomate-flows moeten vaak opnieuw gebouwd of omgezet worden.
* **Systeembeheer:** In plaats van één maandelijkse factuur aan Microsoft, ben je (of je beheerderspartner) nu verantwoordelijk voor het onderhoud van de open-source componenten en de onderliggende Kubernetes-clusters.
