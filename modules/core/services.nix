{ host, ... }:
let
  inherit (import ../../hosts/${host}/variables.nix) username alsaDevice;
in
{
  # Services to start
  services = {
    libinput.enable = true; # Input Handling
    fstrim.enable = true; # SSD Optimizer
    devmon.enable = true; # For Mounting USB & More
    gvfs.enable = true; # For Mounting USB & More
    udisks2.enable = true; # For Mounting USB & More

    # Userspace CPU Scheduler for Improved Latency for Gaming (Hardware Specific)
    # services.scx = {
    #   enable = true;
    #   package = pkgs.scx.rustscheds;
    #   scheduler = "scx_lavd"; # https://github.com/sched-ext/scx/blob/main/scheds/rust/README.md
    # };

    openssh = {
      enable = false;
      ports = [ 22 ];
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = true;
        AllowUsers = [ username ]; # Allows all users by default. Can be [ "user1" "user2" ]
        UseDns = true;
        X11Forwarding = false;
        PermitRootLogin = "prohibit-password"; # "yes", "without-password", "prohibit-password", "forced-commands-only", "no"
      };
    };
    blueman.enable = true; # Bluetooth Support
    tumbler.enable = true; # Image/video preview

    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      # wireplumber = {
      #   enable = true;
      #   configPackages = [
      #     (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/11-bluetooth-policy.conf" ''
      #       bluetooth.autoswitch-to-headset-profile = false
      #     '')
      #   ];
      # };
      extraConfig.pipewire."92-low-latency" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.quantum" = 256;
          "default.clock.min-quantum" = 256;
          "default.clock.max-quantum" = 256;
        };
      };
      # Line In loopback - routes audio from Line In to default output
      extraConfig.pipewire."93-line-in-loopback" = {
        "context.modules" = [
          {
            name = "libpipewire-module-loopback";
            args = {
              "capture.props" = {
                "node.name" = "linein-capture";
                "audio.position" = [
                  "FL"
                  "FR"
                ];
                "node.target" = alsaDevice;
              };
              "playback.props" = {
                "node.name" = "linein-playback";
                "node.description" = "Line In Loopback";
                "media.class" = "Stream/Output/Audio";
                "audio.position" = [
                  "FL"
                  "FR"
                ];
              };
            };
          }
        ];
      };
      extraConfig.pipewire-pulse."92-low-latency" = {
        context.modules = [
          {
            name = "libpipewire-module-protocol-pulse";
            args = {
              pulse.min.req = "256/48000";
              pulse.default.req = "256/48000";
              pulse.max.req = "256/48000";
              pulse.min.quantum = "256/48000";
              pulse.max.quantum = "256/48000";
            };
          }
        ];
      };
    };
  };
}
