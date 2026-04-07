------------------------------
## NixOS K3s Setup op Proxmox: Troubleshooting & Configuratie
Wanneer je een NixOS image bouwt met nixos-generate, bevat deze de gecompileerde software, maar vaak niet het /etc/nixos/configuration.nix bronbestand of de juiste bootloader-instellingen voor live wijzigingen.
## 1. De Basis Configuratie (/etc/nixos/configuration.nix)
Om nixos-rebuild werkend te krijgen in de VM, moet de configuratie de juiste bootloader en hardware-imports bevatten.

{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Bootloader voor Proxmox (VirtIO)
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda"; 
  
  # Benodigde kernel modules voor Kubernetes/K3s
  boot.kernelModules = [ "br_netfilter" "overlay" "iptables" ];

  # K3s Service
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = "--disable=traefik --write-kubeconfig-mode=644";
  };

  # Omgevingsvariabele voor kubectl
  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

  # Firewall instellingen voor K3s
  networking.firewall.allowedTCPPorts = [ 6443 ];

  # Zorg dat K3s de juiste binaries kan vinden
  systemd.services.k3s.path = with pkgs; [ iptables kmod iproute2 ];

  services.openssh.enable = true;
  system.stateVersion = "23.11"; # Of de versie die je gebruikt
}

## 2. De "Hard Reset" Procedure
Als K3s weigert te starten (bijv. status=1/FAILURE of ServiceUnavailable), komt dit vaak door corrupte tokens of database-bestanden van een eerdere (mislukte) start. Volg dan deze stappen:

   1. Stop de service:
   
   sudo systemctl stop k3s
   
   2. Wis corrupte runtime data:
   
   sudo rm -rf /var/lib/rancher/k3s
   sudo rm -f /etc/rancher/k3s/k3s.yaml
   
   3. Pas configuratie aan & Rebuild:
   
   sudo nixos-rebuild switch
   
   4. Start de service:
   
   sudo systemctl start k3s
   
   
## 3. Toegang tot het Cluster
Omdat NixOS omgevingsvariabelen pas na een nieuwe inlog laadt, moet je de eerste keer handmatig het pad naar de config opgeven:

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes

------------------------------
## Tips voor Proxmox:

* Disk Naam: Gebruik lsblk om te controleren of je schijf /dev/vda (VirtIO) of /dev/sda (SATA/SCSI) heet voor de GRUB-instelling.
* Hardware Config: Draai sudo nixos-generate-config als je de VM voor het eerst handmatig configureert om de juiste schijf-UUID's op te halen.

Wil je ook weten hoe je dit proces kunt automatiseren zodat je nimmer meer handmatig bestanden hoeft te wissen bij een nieuwe uitrol?


