# Network Recovery Runbook (NixOS-Ava)

## Goal
Get deterministic data after boot so we can fix root cause instead of repeatedly toggling `Wired Connection 1` and `wg_toggle`.

## What this captures
- Config identity:
  - Git commit/repo dirty state for `/home/onee/NixOS`
  - `/run/current-system` store path
  - `nixos-version`
- NetworkManager connection/device/autoconnect state
- WireGuard + DNS service health (`wg-quick-wg0`, `adguardhome`, `unbound`)
- IPv4 routes and default route ownership
- Resolver setup and local DNS listener checks
- Recent boot logs for network-related services
- A short heuristic summary of likely misconfiguration

## Quick start
1. Reboot.
2. As soon as internet is broken, run:

```bash
bash scripts/net-diagnose.sh
```

3. If internet eventually starts working after toggling, run it again and compare both reports.
4. Share the generated report paths from terminal output.

## Where output goes
Each run writes a timestamped folder:

```text
/tmp/net-diagnose-YYYYMMDD-HHMMSS/
```

Key files:
- `summary.txt`: high-level findings + likely fixes
- `commands.log`: command output and errors
- `journal-network.txt`: filtered boot logs

## Revision tracking
- Every `summary.txt` now includes:
  - `Config git revision: <short-sha> (clean|dirty)`
  - `Running system: /nix/store/...-nixos-system-...`
  - `NixOS version: ...`
- `commands.log` also captures full `git rev-parse HEAD` + `git status --short`.
- If you need to cite a specific generation manually, run:

```bash
readlink -f /run/current-system
```

## How to interpret common findings
- `No default IPv4 route`: uplink profile is not up or route is stolen/removed.
- `resolv.conf points to 127.0.0.1 but local DNS listener missing`: DNS chain is down (`adguardhome`/`unbound`) so internet appears broken even if link is up.
- `Mixed WireGuard control`: both NM WireGuard profile(s) and `wg-quick-wg0` systemd unit exist; this can flap routes and DNS.
- `NetworkManager requested org.freedesktop.resolve1`: NM is trying to use systemd-resolved while it is disabled.

## Decision guide
1. If default route is missing -> fix NM autoconnect/priority and ensure ethernet comes up first.
2. If DNS chain is down -> fix startup ordering/health of `adguardhome` and `unbound`.
3. If mixed WG control exists -> keep one control plane only:
   - either systemd `wg-quick-wg0` + `wg-toggle`
   - or NM profile (remove/disable the other)
4. If NM wants resolved but resolved is disabled -> set NM DNS backend consistently (usually `networking.networkmanager.dns = "none"` when using local DNS stack).

## Useful reruns (optional)
- Broken state capture:

```bash
bash scripts/net-diagnose.sh
```

- Working state capture after toggling:

```bash
bash scripts/net-diagnose.sh
```

Compare two `summary.txt` files first, then `commands.log`.
