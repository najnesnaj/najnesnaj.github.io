---
title: 'lasuite-messagerie'
weight: 150 
draft: false
---

**Dans LaSuite (la Suite numérique de la DINUM), l'envoi de mails (courriels électroniques classiques, comme avec Outlook ou Gmail) se fait via l'outil dédié nommé simplement "Messagerie".**

C'est l'équivalent souverain et sécurisé d'une messagerie électronique professionnelle (remplaçant Outlook, Gmail, etc.). Il est conçu pour les agents publics et les entités du secteur public, avec des données hébergées en France et une forte emphase sur la sécurité et la souveraineté.

### Comment ça fonctionne concrètement ?
1. **Accès à Messagerie** :
   - Connectez-vous à LaSuite via **ProConnect** (l'authentification unifiée de l'État, avec MFA obligatoire).
   - Une fois dans l'espace LaSuite, cliquez sur l'icône ou le lien "Messagerie" (ou accédez directement à https://messagerie.numerique.gouv.fr si vous êtes déjà authentifié).
   - Vous obtenez une adresse e-mail professionnelle du type `@numerique.gouv.fr`, `@gouv.fr`, ou adaptée à votre administration/ministère (par exemple `@education.gouv.fr`, `@interieur.gouv.fr`, etc., selon l'entité).

2. **Envoi d'un mail** :
   - L'interface ressemble à un webmail classique et moderne (inspiré de standards open-source comme Roundcube ou similaires, mais customisé par la DINUM).
   - Cliquez sur **"Nouveau message"** / **"Composer"** (ou équivalent en français : "Nouveau courriel").
   - Remplissez :
     - **Destinataire(s)** : adresse e-mail (interne à LaSuite ou externe, y compris adresses @gmail.com, @yahoo.fr, etc.).
     - **Objet** (sujet).
     - **Corps du message** : texte simple ou enrichi (gras, italique, listes, etc.).
     - **Pièces jointes** : vous pouvez attacher des fichiers depuis **Fichiers** (le Drive de LaSuite) ou uploader directement (avec limites raisonnables pour les pièces jointes).
   - Options avancées : CC, CCI, priorité, accusé de réception, signature automatique, etc.
   - Cliquez sur **Envoyer** → le mail part via les serveurs SMTP de la DINUM (sécurisés, avec DKIM/SPF/DMARC configurés pour une bonne délivrabilité).

3. **Réception et gestion** :
   - Les mails entrants arrivent dans la **boîte de réception**.
   - Vous pouvez organiser avec **dossiers**, **étiquettes**, **filtres** automatiques.
   - L'outil intègre aussi un **calendrier/agenda** (pour les rendez-vous) et la gestion des **contacts**.
   - Tout est synchronisé avec les autres outils LaSuite (par exemple, un lien vers un document Docs ou un fichier Drive peut être inséré directement).

### Points importants sur la sécurité et les usages
- **Interopérabilité** : Vous envoyez/recevez des mails vers/de n'importe qui sur Internet (pas limité au secteur public).
- **Chiffrement** : Transport sécurisé (TLS), mais pas forcément de bout en bout comme pour Tchap (messagerie instantanée). Pour des échanges très sensibles, utilisez Tchap ou des pièces jointes chiffrées.
- **Limites** : C'est optimisé pour les usages administratifs (petites/moyennes entités, équipes publiques). Pour des gros volumes ou besoins très spécifiques, certaines administrations conservent encore des serveurs mails historiques en parallèle.
- **Disponibilité** : Principalement pour les agents publics via ProConnect. Si vous self-hostez LaSuite (open-source via le repo **suitenumerique/messages**), vous pouvez configurer votre propre domaine mail (ex. @votre-organisation.fr) et connecter un relais SMTP sortant sécurisé (par ex. via un fournisseur français certifié).

### Différence avec Tchap
Ne confondez pas :
- **Messagerie** → e-mails classiques (asynchrone, pour correspondance externe/interne formelle).
- **Tchap** → messagerie instantanée (chat en temps réel, groupes, appels, chiffré de bout en bout, comme Teams/Slack/Signal).

En résumé : pour **envoyer un mail** dans LaSuite, vous utilisez l'application **Messagerie**, de la même façon qu'avec n'importe quel webmail pro sécurisé. C'est simple, intégré à l'écosystème LaSuite, et 100 % souverain.

Si vous avez accès à une instance LaSuite (via votre administration), le plus simple est de cliquer sur "Messagerie" dans le dashboard. Pour plus de détails ou captures d'écran, consultez la page officielle https://messagerie.numerique.gouv.fr/ ou contactez support-messagerie@mail.numerique.gouv.fr. Si vous self-hostez, regardez le repo GitHub https://github.com/suitenumerique/messages pour la config SMTP sortante !
