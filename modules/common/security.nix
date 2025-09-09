{ config, lib, pkgs, ... }:

{
  # Common security configuration for all node types
  
  # Enable firewall
  networking.firewall.enable = true;
  
  # Configure SSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
  };
  
  # Security hardening
  security = {
    sudo.enable = true;
    sudo.wheelNeedsPassword = true;
    
    # Polkit for privilege escalation
    polkit.enable = true;
    
    # PAM
    pam.services.login.enableGnomeKeyring = true;
    
    # Audit
    audit.enable = true;
    auditd.enable = true;
  };
  
  # Secure boot
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.systemd-boot.editor = false;
  
  # Kernel hardening
  boot.kernel.sysctl = {
    # Kernel hardening
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "kernel.printk" = "3 3 3 3";
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;
    
    # Network security
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.log_martians" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    
    # TCP hardening
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.tcp_rfc1337" = 1;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.conf.default.secure_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
  };
  
  # Security packages
  environment.systemPackages = with pkgs; [
    gnupg
    openssl
    fail2ban
    lynis
    clamav
    rkhunter
    chkrootkit
    aide
  ];
  
  # Enable fail2ban
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    ignoreIP = [
      "127.0.0.1/8"
      "10.0.0.0/8"
      "172.16.0.0/12"
      "192.168.0.0/16"
    ];
  };
  
  # Enable ClamAV
  services.clamav = {
    daemon.enable = true;
    updater.enable = true;
  };
}