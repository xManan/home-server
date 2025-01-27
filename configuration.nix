{ config, lib, pkgs, ... }:
let
  unstable = import <nixos-unstable> {};

  protonVPNCreds = lib.splitString "\n" (builtins.readFile /home/manan/protonvpn/credentials.txt);
  protonVPNUsername = builtins.elemAt protonVPNCreds 0;
  protonVPNPassword = builtins.elemAt protonVPNCreds 1;
  pinggyToken = lib.trim (builtins.readFile /home/manan/pinggy/token.txt);
in
{
  imports =
    [
      ./hardware-configuration.nix
    ];

  nixpkgs.config.allowUnfree = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "home-server";

  time.timeZone = "Asia/Kolkata";

  i18n.defaultLocale = "en_US.UTF-8";

  services.logind = {
    lidSwitch = "ignore";
    lidSwitchDocked = "ignore";
    suspendKey = "ignore";
  };
  
  services.openssh = {
    enable = true;
  };

  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";

      CPU_MIN_PERF_ON_AC = 0;
      CPU_MAX_PERF_ON_AC = 100;
      CPU_MIN_PERF_ON_BAT = 0;
      CPU_MAX_PERF_ON_BAT = 20;

      START_CHARGE_THRESH_BAT0 = 40;
      STOP_CHARGE_THRESH_BAT0 = 80;

      WOL_DISABLE = "N";
    };
  };

  networking.interfaces.enp1s0.wakeOnLan.enable = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 4300 ];
  };

  environment.systemPackages = with pkgs; [
    neovim
    ethtool
    git
    wget
    tmux
    ngrok
    jellyfin
    jellyfin-web
    jellyfin-ffmpeg
    htop
  ];

  environment.shellAliases = {
    tmux = "tmux -2";
  };

  users.users.manan = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    packages = with pkgs; [
    ];
  };

  virtualisation.docker.enable = true;

  services.nginx = {
    enable = true;
    config = builtins.readFile /etc/nixos/nginx/nginx.conf;
  };

  # services.cron = {
  #   enable = true;
  #   systemCronJobs = [
  #     "*/5 * * * * /home/manan/duckdns/duck.sh >/dev/null 2>&1"
  #   ];
  # };

  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };

  services.jellyfin = {
    enable = true;
    openFirewall = true;
    user = "manan";
  };

  systemd.services.clippy = {
    enable = true;
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    description = "clippy service for %I";
    serviceConfig = {
        Type = "simple";
        KillMode = "process";
        ExecStart = "/home/manan/bin/clippy --port=8097 --base-url=/clippy";
        Restart = "on-failure";
        RestartSec = "3";
    };
  };

  systemd.services.pinggy = {
    enable = true;
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    description = "pinggy ssh tunnel";
    serviceConfig = {
        Type = "simple";
        KillMode = "process";
        ExecStart = "/run/current-system/sw/bin/ssh -p 443 -R0:localhost:80 -L0.0.0.0:4300:localhost:4300 -o StrictHostKeyChecking=no -o ServerAliveInterval=30 ${pinggyToken}@a.pinggy.io";
        Restart = "on-failure";
        RestartSec = "10";
    };
  };

  services.deluge = {
    enable = true;
    user = "manan";
    web = {
      enable = true;
      port = 8112;
      openFirewall = true;
    };
  };

  services.openvpn.servers = {
    protonVPN  = {
      config = '' config /home/manan/protonvpn/nl-free-92.protonvpn.tcp.ovpn '';
      autoStart = false;
      updateResolvConf = true;
      authUserPass = {
        username = protonVPNUsername;
        password = protonVPNPassword;
      };
    };
  };

  environment.etc.openvpn.source = "${pkgs.update-resolv-conf}/libexec/openvpn";

  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
  };

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      vaapiVdpau
      intel-compute-runtime
      vpl-gpu-rt
      intel-media-sdk
      libvdpau-va-gl
    ];
  };

  system.stateVersion = "23.11";
}
