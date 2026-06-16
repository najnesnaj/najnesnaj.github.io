# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Voeg de benodigde kernel modules expliciet toe
  boot.kernelModules = [ "br_netfilter" "overlay" "iptables" ];

  #boot.loader.systemd-boot.enable = true;
  #boot.loader.efi.canTouchEfiVariables = true;
  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  # boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  # networking.hostName = "nixos"; # Define your hostname.

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  # Set your time zone.
  # time.timeZone = "Europe/Amsterdam";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;


  

  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # services.pulseaudio.enable = true;
  # OR
  # services.pipewire = {
  #   enable = true;
  #   pulse.enable = true;
  # };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.users.alice = {
  #   isNormalUser = true;
  #   extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  #   packages = with pkgs; [
  #     tree
  #   ];
  # };

  # programs.firefox.enable = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  # environment.systemPackages = with pkgs; [
  #   vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #   wget
  # ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  # Networking / firewall for K3s

  services.vsftpd = {
    enable = true;
    localUsers = true;      # Sta lokale systeemgebruikers toe om in te loggen
    writeEnable = true;     # Sta het uploaden van bestanden toe
    # optioneel: root-gebruikers opsluiten in hun eigen home directory
    chrootlocalUser = true; 
  };


  services.vsftpd.extraConfig = ''
    pasv_enable=Yes
    pasv_min_port=51000
    pasv_max_port=51999
  '';



  networking.firewall.allowedTCPPorts = [ 21 80 443 6443 ];  # kube-apiserver
  networking.firewall.allowedTCPPortRanges = [ { from = 51000; to = 51999; }];
  networking.firewall.allowedUDPPorts = [ 8472 ]; # flannel
 
  # 2. Forceer het gebruik van iptables (K3s heeft dit nodig)
  networking.nftables.enable = false;







  # Zorg dat K3s de juiste tools kan vinden
  systemd.services.k3s = {
    path = with pkgs; [ iptables kmod iproute2 ];
    serviceConfig = {
      # Voorkom dat een eerdere crash de herstart blokkeert
      ExecStartPre = "-${pkgs.kmod}/bin/modprobe br_netfilter";
    };
  };


  # K3s (single-node server)
  services.k3s = {
    enable = true;
    role = "server";           # use "agent" for worker nodes
    # clusterInit = true;      # only needed on the very first server node
    # tokenFile = /run/secrets/k3s-token;  # optional for HA

    # Extra flags (common useful ones)
    extraFlags = toString [
    #  "--disable=traefik"      # use your own ingress if you want
      "--write-kubeconfig-mode=644"
    ];
  }; 

  # Make KUBECONFIG available system-wide
  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

  # Enable SSH (in case the image didn't)
  services.openssh.enable = true;

  environment.systemPackages = with pkgs; [
    kubectl
    kubernetes-helm
    helmfile
  # optioneel voor helmfile templates:
    git
    vim 
  ];
  system.stateVersion = "25.11"; # Did you read the comment?

}

