AWS- en Azure-emulators zijn **softwaretools die de APIs en het gedrag van een cloudprovider lokaal op je eigen computer simuleren**.

In plaats van dat je code of Terraform-scripts daadwerkelijk verbinding maken met de servers van Amazon of Microsoft, stuur je het verkeer naar een lokale container op je eigen pc.

---

### Doel en voordelen van Cloud Emulators

1. **Kostenbesparing (Geen cloudrekening tijdens de bouw)**
* In de cloud betaal je voor virtuele machines, databases, opslag (S3/Blob) en API-requests.
* Met een emulator draait alles gratis op je eigen hardware. Fouten maken of loops laten draaien kost niets extra.


2. **Sneller testen en kortere feedback-loops**
* Het uitrollen van infrastructure-as-code (zoals Terraform) of serverless-functies naar de echte cloud duurt vaak enkele minuten.
* Lokaal duurt het uitrollen of herstarten van een emulator slechts enkele seconden.


3. **Offline werken**
* Je kunt software en infrastructuur bouwen en testen in de trein, in het vliegtuig of op plekken zonder stabiele internetverbinding.


4. **Veilige Sandbox voor CI/CD (Automated Testing)**
* In je CI/CD-pipelines (zoals GitHub Actions of GitLab CI) kun je integratietesten uitvoeren op een tijdelijke emulator.
* Je hoeft de automatische tests geen toegang/API-sleutels te geven tot je echte cloudomgeving, wat risico's op overschreden budgetten of beveiligingslekken voorkomt.



---

### Bekende voorbeelden

#### AWS Emulators

* **LocalStack:** De bekendste AWS-emulator. Het draait als een Docker-container op je pc en emuleert tientallen AWS-diensten zoals S3 (opslag), DynamoDB (database), Lambda (serverless) en SQS (queues).
* **DynamoDB Local / AWS SAM CLI:** Officiële, specifieke tools van AWS om lokaal serverless-applicaties of specifieke databases te testen.

#### Azure Emulators

* **Azurite:** De officiële emulator van Microsoft voor Azure Blob Storage, Queue Storage en Table Storage.
* **Cosmos DB Emulator:** Een officiële lokale versie van Microsofts NoSQL-database.
* **LocalStack for Azure / Localaz:** Uitbreidingen en open-source projecten die proberen de LocalStack-ervaring naar Azure-services te brengen.

---

### Wat kunnen ze WEL en wat NIET?

* **WEL:** Lokaal je logica testen, API-aanroepen controleren, Terraform-code op syntaxis en werking testen, en je applicaties code-niveau valideren.
* **NIET:** Echte cloud-performance simuleren (zoals netwerk-latency of IOPS-limieten), alle denkbare services 100% identiek emuleren, of complexe cloud-beveiliging/netwerklagen (VPCs, IAM-policies) exact nabootsen.
