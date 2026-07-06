{ ... }:
{
  ############################
  # Kernel / sysctl hardening
  # (Tuned to not hurt gaming: no linux_hardened, no module-loading lockdown
  # since NVIDIA + anticheat modules load at runtime.)
  ############################
  boot.kernel.sysctl = {
    # KASLR-adjacent info leaks
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    # Restrict eBPF/perf to privileged users
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;
    "kernel.perf_event_paranoid" = 3;
    # ptrace only on children (debuggers still work on own processes)
    "kernel.yama.ptrace_scope" = 1;
    # No kexec into unsigned kernels
    "kernel.kexec_load_disabled" = 1;
    # SysRq off
    "kernel.sysrq" = 0;
    # Network stack
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.tcp_rfc1337" = 1;
    # Filesystem
    "fs.protected_symlinks" = 1;
    "fs.protected_hardlinks" = 1;
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;
    "fs.suid_dumpable" = 0;
  };

  # Block rarely-used, historically buggy protocols/filesystems.
  boot.blacklistedKernelModules = [
    "dccp" "sctp" "rds" "tipc"
    "cramfs" "freevxfs" "jffs2" "hfs" "hfsplus" "udf"
    "firewire-core" "thunderbolt" # DMA attack surface; remove thunderbolt if you dock
  ];

  ############################
  # Mandatory access control
  ############################
  security.apparmor = {
    enable = true;
    packages = [ ];
    killUnconfinedConfinables = true;
  };

  security.polkit.enable = true;
  security.rtkit.enable = true; # low-latency audio for PipeWire

  # Memory allocator hardening that doesn't tank game perf:
  environment.memoryAllocator.provider = "libc"; # graphene-hardened breaks some games; keep libc
  security.forcePageTableIsolation = true;

  # Protect kernel image at runtime
  security.protectKernelImage = true;

  # Disable coredumps
  systemd.coredump.enable = false;
  security.pam.loginLimits = [
    { domain = "*"; item = "core"; type = "hard"; value = "0"; }
  ];

  ############################
  # Firmware updates
  ############################
  services.fwupd.enable = true;

  ############################
  # USB device authorization
  ############################
  services.usbguard = {
    enable = false; # flip to true after generating a policy:
    # sudo usbguard generate-policy > /var/lib/usbguard/rules.conf
    presentDevicePolicy = "allow";
  };
}
