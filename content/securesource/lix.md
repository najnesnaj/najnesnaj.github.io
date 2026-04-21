---
title: 'lix'
draft: false
weight: 1700
---

Om Lix te activeren op een bestaand NixOS-systeem, gebruik je de officiële Lix-module. De meest stabiele manier om dit te doen is via inputs in een Flake, maar als je een traditionele configuration.nix gebruikt, kan het ook via fetchTarball.
Hier zijn de twee manieren:
## Optie 1: Via Flakes (Aanbevolen)
Als je NixOS-setup al gebruikmaakt van Flakes, voeg je Lix toe aan je flake.nix:

{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Voeg de Lix-input toe
    lix-module = {
      url = "https://lix.systems";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, lix-module, ... }: {
    nixosConfigurations.jouw-hostnaam = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        # Activeer de Lix-module
        lix-module.nixosModules.default
      ];
    };
  };
}

## Optie 2: In een standaard configuration.nix
Als je geen Flakes gebruikt, kun je de module direct importeren in je /etc/nixos/configuration.nix:

{ config, pkgs, ... }:

{
  imports = [
    # Importeer de Lix-module direct van de bron
    (fetchTarball "https://lix.systems")
  ];

  # De module vervangt automatisch de standaard Nix-pakketbeheerder door Lix
}

## Hoe controleer je of het werkt?
Nadat je de configuratie hebt toegepast met sudo nixos-rebuild switch, kun je controleren of Lix actief is door de versie op te vragen:

nix --version

In plaats van alleen een versienummer, zul je nu ook de naam "Lix" in de output zien staan.
## Waarom dit veilig is:
De Lix-module is ontworpen om de standaard nix package in je systeem te overschrijven zonder je bestaande configuratie of profielen aan te tasten. Mocht je terug willen, dan verwijder je simpelweg de import en voer je nixos-rebuild opnieuw uit.
Gebruik je momenteel al Flakes voor je NixOS-beheer op Proxmox, of werk je met de standaard configuratiestructuur?

Om Lix te activeren op een bestaand NixOS-systeem, gebruik je de officiële Lix-module. De meest stabiele manier om dit te doen is via inputs in een Flake, maar als je een traditionele configuration.nix gebruikt, kan het ook via fetchTarball.
Hier zijn de twee manieren:
## Optie 1: Via Flakes (Aanbevolen)
Als je NixOS-setup al gebruikmaakt van Flakes, voeg je Lix toe aan je flake.nix:

{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Voeg de Lix-input toe
    lix-module = {
      url = "https://lix.systems";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, lix-module, ... }: {
    nixosConfigurations.jouw-hostnaam = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        # Activeer de Lix-module
        lix-module.nixosModules.default
      ];
    };
  };
}

## Optie 2: In een standaard configuration.nix
Als je geen Flakes gebruikt, kun je de module direct importeren in je /etc/nixos/configuration.nix:

{ config, pkgs, ... }:

{
  imports = [
    # Importeer de Lix-module direct van de bron
    (fetchTarball "https://lix.systems")
  ];

  # De module vervangt automatisch de standaard Nix-pakketbeheerder door Lix
}

## Hoe controleer je of het werkt?
Nadat je de configuratie hebt toegepast met sudo nixos-rebuild switch, kun je controleren of Lix actief is door de versie op te vragen:

nix --version

In plaats van alleen een versienummer, zul je nu ook de naam "Lix" in de output zien staan.
## Waarom dit veilig is:
De Lix-module is ontworpen om de standaard nix package in je systeem te overschrijven zonder je bestaande configuratie of profielen aan te tasten. Mocht je terug willen, dan verwijder je simpelweg de import en voer je nixos-rebuild opnieuw uit.
Gebruik je momenteel al Flakes voor je NixOS-beheer op Proxmox, of werk je met de standaard configuratiestructuur?


