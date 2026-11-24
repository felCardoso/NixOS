# configuration.nix - NixOS + Hyprland (sistema principal) | Windows 11 em outro SSD
#
# Hardware: Ryzen 5 9600X, RTX 5060 Ti, 32 GB DDR5-6000 (EXPO ligado na BIOS)
#
# COMO USAR:
# 1. Instale o NixOS. O instalador cria /etc/nixos/hardware-configuration.nix.
# 2. Copie este arquivo para /etc/nixos/configuration.nix.
# 3. Ajuste os itens marcados com "AJUSTE".
# 4. Execute: sudo nixos-rebuild switch
#
# NAO apague o import de hardware-configuration.nix.

{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # ---------------------------------------------------------------
  # Boot
  # ---------------------------------------------------------------
  # Opcao A (padrao): systemd-boot. Para abrir o Windows, use o menu
  # de boot da BIOS (F12), pois o Windows esta em outro SSD.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  # Opcao B: menu unico com GRUB e os-prober (acha o Windows no outro SSD).
  # Para usar: comente as 3 linhas da Opcao A e tire o # destas linhas.
  # boot.loader.systemd-boot.enable = false;
  # boot.loader.grub = {
  #   enable = true;
  #   device = "nodev";
  #   efiSupport = true;
  #   useOSProber = true;
  # };

  # Kernel novo. O Ryzen 9000 (Zen 5) e a RTX 50 precisam de kernel recente.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Microcode e firmware da AMD.
  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  # O Windows usa hora local no relogio da placa. Isso evita hora errada.
  time.hardwareClockInLocalTime = true;

  # Le e escreve em particoes NTFS do Windows.
  boot.supportedFilesystems = [ "ntfs" ];

  # Swap comprimido na RAM (rapido, sem desgaste do SSD).
  zramSwap.enable = true;

  # ---------------------------------------------------------------
  # Rede
  # ---------------------------------------------------------------
  networking.hostName = "nixos";          # AJUSTE: nome do PC
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;
  # Confia em tudo que chega pela rede Tailscale (SSH, Open WebUI, Sunshine).
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # ---------------------------------------------------------------
  # Idioma, hora e teclado (Brasil)
  # ---------------------------------------------------------------
  time.timeZone = "America/Sao_Paulo";

  i18n.defaultLocale = "pt_BR.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "pt_BR.UTF-8";
    LC_IDENTIFICATION = "pt_BR.UTF-8";
    LC_MEASUREMENT = "pt_BR.UTF-8";
    LC_MONETARY = "pt_BR.UTF-8";
    LC_NAME = "pt_BR.UTF-8";
    LC_NUMERIC = "pt_BR.UTF-8";
    LC_PAPER = "pt_BR.UTF-8";
    LC_TELEPHONE = "pt_BR.UTF-8";
    LC_TIME = "pt_BR.UTF-8";
  };

  console.keyMap = "br-abnt2";
  services.xserver.xkb = {
    layout = "br";
    variant = "";
  };

  # ---------------------------------------------------------------
  # Video: NVIDIA RTX 5060 Ti (Blackwell)
  # ---------------------------------------------------------------
  hardware.graphics = {
    enable = true;
    enable32Bit = true;                    # necessario para Steam e Wine
    extraPackages = with pkgs; [
      nvidia-vaapi-driver                  # decodificacao de video por hardware
    ];
  };

  # O nome "nvidia" e necessario mesmo no Wayland.
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    # A serie RTX 50 SO funciona com os modulos abertos. Nao mude para false.
    open = true;
    nvidiaSettings = true;
    powerManagement.enable = false;        # PC de mesa: nao precisa
    # "latest" garante driver 570 ou mais novo (obrigatorio para RTX 50).
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };

  boot.kernelParams = [ "nvidia-drm.fbdev=1" ];

  # Variaveis para o Hyprland funcionar bem com NVIDIA.
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";                  # apps Electron/Chromium em Wayland
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };

  # ---------------------------------------------------------------
  # Desktop: Hyprland
  # ---------------------------------------------------------------
  programs.hyprland = {
    enable = true;
    withUWSM = true;                       # gerencia a sessao com systemd
    xwayland.enable = true;                # apps X11 (Steam, Discord, etc.)
  };

  # Tela de login. Na lista de sessoes, escolha "Hyprland (uwsm-managed)".
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # Portais (captura de tela, seletor de arquivos).
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Autenticacao grafica e tarefas de segundo plano.
  security.polkit.enable = true;
  services.gvfs.enable = true;             # lixeira e montagem no gerenciador de arquivos
  services.udisks2.enable = true;          # monta pendrives
  programs.dconf.enable = true;

  # ---------------------------------------------------------------
  # Audio
  # ---------------------------------------------------------------
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # ---------------------------------------------------------------
  # Impressao e Bluetooth
  # ---------------------------------------------------------------
  services.printing.enable = true;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # ---------------------------------------------------------------
  # Usuario
  # ---------------------------------------------------------------
  # AJUSTE: troque "felcardoso" pelo seu usuario.
  # Depois do primeiro boot, defina a senha com: passwd felcardoso
  users.users.felcardoso = {
    isNormalUser = true;
    description = "Felipe Cardoso";
    extraGroups = [ "wheel" "networkmanager" "docker" "video" "audio" ];

    # AJUSTE: cole aqui a sua chave publica SSH (o conteudo de ~/.ssh/id_ed25519.pub).
    # Sem chave, voce nao entra por SSH, pois a senha esta desativada.
    openssh.authorizedKeys.keys = [
      # "ssh-ed25519 AAAA... felcardoso@celular"
    ];
  };

  # ---------------------------------------------------------------
  # Nix
  # ---------------------------------------------------------------
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;

  # Cache binario do CUDA. Sem ele, o Nix compila o CUDA e o Ollama do zero.
  nix.settings.extra-substituters = [ "https://cuda-maintainers.cachix.org" ];
  nix.settings.extra-trusted-public-keys = [
    "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
  ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Permite programas de licenca nao livre (VS Code, Steam, driver NVIDIA).
  nixpkgs.config.allowUnfree = true;

  # ---------------------------------------------------------------
  # Programas
  # ---------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    # Basico
    curl
    wget
    vim
    htop
    btop
    unzip
    zip
    tree
    ripgrep
    fd
    jq
    pciutils
    usbutils
    ntfs3g
    nvtopPackages.nvidia                   # monitor da GPU

    # Hyprland: barra, menu, notificacoes, papel de parede, bloqueio
    kitty                                  # terminal (padrao do Hyprland)
    waybar
    rofi
    mako
    hyprpaper
    hyprlock
    hypridle
    hyprpolkitagent
    hyprshot                               # captura de tela
    wl-clipboard
    cliphist
    playerctl
    brightnessctl

    # Interface
    nautilus                               # gerenciador de arquivos
    pavucontrol                            # volume
    networkmanagerapplet
    adwaita-icon-theme
    nwg-look                               # tema GTK

    # Desenvolvimento
    vscode
    claude-code                            # Claude Code (CLI)
    nodejs
    python3
    gcc
    gnumake

    # Dia a dia
    firefox
    chromium                               # tambem usado para o driver web do teclado
    vlc
    discord

    # Jogos
    mangohud                               # overlay de FPS e uso de GPU
    protonup-qt                            # instala Proton-GE
    heroic                                 # Epic Games e GOG
  ];

  # Git
  programs.git = {
    enable = true;
    config.init.defaultBranch = "main";
    # AJUSTE: tire o # e preencha com os seus dados.
    # config.user.name = "Felipe Cardoso";
    # config.user.email = "seu@email.com";
  };

  # Roda binarios baixados da internet (extensoes do VS Code, ferramentas de Node e Rust).
  programs.nix-ld.enable = true;

  # Docker
  virtualisation.docker.enable = true;

  # Steam e jogos
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;        # sessao gamescope (opcional)
    remotePlay.openFirewall = true;        # Remote Play
    localNetworkGameTransfers.openFirewall = true;
  };
  programs.gamemode.enable = true;         # em Opcoes de Inicializacao: gamemoderun %command%

  # Fontes
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
  ];

  # ---------------------------------------------------------------
  # Servicos
  # ---------------------------------------------------------------
  services.fstrim.enable = true;           # mantem o SSD saudavel

  # Tailscale: rede privada entre o PC e o celular.
  # Depois do rebuild, execute: sudo tailscale up
  services.tailscale = {
    enable = true;
    openFirewall = true;                   # porta UDP 41641
    useRoutingFeatures = "client";
  };
  networking.firewall.checkReversePath = "loose";   # recomendado com Tailscale

  # SSH: so por chave. A porta 22 NAO abre na rede local.
  # O acesso e pela rede Tailscale (interface confiavel).
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Ollama (LLMs locais) com aceleracao CUDA na RTX 5060 Ti.
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    host = "127.0.0.1";
    port = 11434;
  };

  # Open WebUI: interface web para o Ollama. Acesso: http://IP-TAILSCALE:8080
  services.open-webui = {
    enable = true;
    host = "0.0.0.0";                      # a porta 8080 so e acessivel pelo Tailscale
    port = 8080;
    environment = {
      OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
    };
  };

  # Sunshine: transmite a tela e os jogos para o app Moonlight (celular, TV, outro PC).
  # Painel de configuracao: https://localhost:47990
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;                    # necessario para capturar a tela no Wayland
    openFirewall = false;                  # acesso pelo Tailscale. Mude para true para usar na rede local.
  };

  # ---------------------------------------------------------------
  # Versao do estado do sistema
  # ---------------------------------------------------------------
  # AJUSTE: mantenha o valor que o instalador gerou no seu arquivo original.
  # NAO mude este valor depois da instalacao.
  system.stateVersion = "26.05";
}
