# as-stats-ng

[AS-Stats](https://github.com/manuelkasper/AS-Stats) collector plus the
[as-stats-gui](https://github.com/nidebr/as-stats-gui) web interface in one container.
It's a modernised rebuild of [archaron/as-stats-ng](https://github.com/archaron/as-stats-ng),
which was stuck on Alpine 3.17 / PHP 8.1 (both end of life, 247 known CVEs).

## Changes from archaron/as-stats-ng

- Alpine 3.24, PHP 8.4, Perl 5.42; packages from apk instead of hand-built CPAN tarballs
- Upstream AS-Stats / as-stats-gui / perl-ip2as pinned to their latest commits
  (includes an XSS fix in `history.php` and IPv6 listen support)
- Fixed: hourly `rrd-extractstats.pl` job never ran (missing `TryCatch` module)
- Fixed: supervisord pointed at a non-existent `php-fpm` binary
- Fixed: default `config.inc` paths now match the `/data/as-stats` volume
- The collector runs under supervisord and is restarted if it crashes
- Week and month top-AS tables are generated (the GUI expected them, but nothing built them)
- `.inc` files (including `config.inc`) are no longer downloadable over HTTP
- Container healthcheck, and setup that's safe to repeat on restart
- Multi-stage build, so there's no compiler in the final image (615MB → 245MB)

Moving over from the old image? See [MIGRATION.md](MIGRATION.md).

## Image

    docker pull ghcr.io/wifinity/as-stats-ng:latest

| Tag | Built from |
|---|---|
| `latest` | `main` branch, plus the weekly rebuild |
| `YYYYMMDD` | Weekly scheduled rebuild (Mondays 05:00 UTC) |
| `1.2.3`, `1.2` | Git tags `v1.2.3` |
| `sha-xxxxxxx` | Every commit |

## CI

`.github/workflows/build.yml` builds the image, runs a smoke test, and fails if Trivy finds any
fixable HIGH/CRITICAL vulnerability. If everything passes, it pushes to GHCR. Pull requests
build and test but don't push. The weekly run rebuilds without cache so new Alpine package
fixes are picked up. Dependabot opens PRs for new GitHub Action versions and the Alpine base tag.

Upstream app code isn't tracked by Dependabot. To update it, bump `AS_STATS_REF`,
`AS_STATS_GUI_REF` or `IP2AS_REF` in the `Dockerfile` to a new commit SHA and open a PR.

## Build locally

    docker build -t as-stats-ng .

## Run

See `compose/docker-compose.yml`. Environment variables:

| Variable | Meaning |
|---|---|
| `NETFLOW=1`, `NETFLOW_PORT` | Enable the NetFlow listener on this UDP port |
| `SFLOW=1`, `SFLOW_PORT`, `SFLOW_ASN` | Enable the sFlow listener (your own ASN is required) |
| `IPV6=1` | Bind listeners to `::` instead of IPv4 only |
| `TZ` | Timezone, e.g. `Europe/London` (default UTC) |

Default ports are 9000 for NetFlow and 6343 for sFlow.

Put your `knownlinks` file at `<volume>/conf/knownlinks`. On first start `config.inc` is copied
into the volume; after that, edit it there.

Top-AS tables are rebuilt hourly (day) and nightly at 02:30 (week, month), and once about two
minutes after start-up. To rebuild them by hand:

    docker exec <container> stats-update            # all
    docker exec <container> stats-update day

## Licence

This repository (Dockerfile, scripts, config, CI) is [MIT](LICENSE) licensed.

The image also contains third-party software under its own licence, fetched at build time:

| Component | Licence |
|---|---|
| [AS-Stats](https://github.com/manuelkasper/AS-Stats) | BSD-2-Clause |
| [as-stats-gui](https://github.com/nidebr/as-stats-gui) | Apache-2.0 |
| [perl-ip2as](https://github.com/JackSlateur/perl-ip2as) | GPL-2.0 |
| [Net-Patricia](https://metacpan.org/dist/Net-Patricia), [Net-sFlow](https://metacpan.org/dist/Net-sFlow) | Perl (Artistic/GPL) |
| Alpine Linux packages | Various; see `apk info` in the image |

Packaging idea credited to [archaron/as-stats-ng](https://github.com/archaron/as-stats-ng).
No code from that repository is used.
