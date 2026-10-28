# Modernised rebuild of https://github.com/archaron/as-stats-ng
# Upstream sources are pinned to commits; bump the ARGs below to update.

# --- Fetch upstream sources ---
FROM alpine:3.24 AS src
ARG AS_STATS_REF=b36595b799ffe61c37ff79bca895d0bd2c109b9b
ARG AS_STATS_GUI_REF=959c7c486d7b7e4b3aefe5eee35187949581c6bb
ARG IP2AS_REF=408d499b580bfda9abb3cdd13d5564bea86c55cb
WORKDIR /src
RUN wget -qO- https://github.com/manuelkasper/AS-Stats/archive/${AS_STATS_REF}.tar.gz | tar xz \
  && mv AS-Stats-${AS_STATS_REF} AS-Stats && rm -rf AS-Stats/www \
  && wget -qO- https://github.com/nidebr/as-stats-gui/archive/${AS_STATS_GUI_REF}.tar.gz | tar xz \
  && mv as-stats-gui-${AS_STATS_GUI_REF} www \
  && wget -qO- https://github.com/JackSlateur/perl-ip2as/archive/${IP2AS_REF}.tar.gz | tar xz \
  && mv perl-ip2as-${IP2AS_REF}/ip2as.pm . \
  # TryCatch is unmaintained and doesn't build on current Perl; Perl >= 5.34
  # has native try/catch with the same syntax.
  && sed -i 's/^use TryCatch;/use feature "try"; no warnings "experimental::try";/' AS-Stats/bin/rrd-extractstats.pl \
  # The GUI's default config points at /data/asstats; this image uses /data/as-stats.
  && sed -i 's|/data/asstats/asstats/|/data/as-stats/|; s|/data/asstats/|/data/as-stats/|' www/config.inc

# --- Build the Perl XS modules Alpine doesn't package ---
FROM alpine:3.24 AS perl-build
RUN apk add --no-cache perl perl-dev perl-app-cpanminus perl-socket6 make gcc musl-dev
RUN cpanm --notest \
      https://cpan.metacpan.org/authors/id/G/GR/GRUBER/Net-Patricia-1.24.tar.gz \
      https://cpan.metacpan.org/authors/id/E/EL/ELISA/Net-sFlow-0.11.tar.gz

# --- Runtime ---
FROM alpine:3.24

LABEL org.opencontainers.image.title="as-stats-ng" \
      org.opencontainers.image.description="AS-Stats with the as-stats-gui web interface" \
      org.opencontainers.image.licenses="MIT"

RUN apk upgrade --no-cache \
  && apk add --no-cache \
      tzdata ttf-dejavu supervisor nginx \
      php84 php84-fpm php84-sqlite3 php84-xml php84-curl \
      rrdtool perl perl-rrd perl-dbi perl-dbd-sqlite perl-json-xs \
      perl-socket6 perl-file-find-rule \
  && rm -rf /var/www/localhost

COPY --from=perl-build /usr/local/lib/perl5 /usr/local/lib/perl5
COPY --from=perl-build /usr/local/share/perl5 /usr/local/share/perl5

WORKDIR /root/
COPY --from=src /src/ip2as.pm /usr/local/lib/perl5/site_perl/ip2as.pm
COPY --from=src /src/AS-Stats /root/AS-Stats
COPY --from=src /src/www /var/www

COPY files/nginx.conf /etc/nginx/nginx.conf
COPY files/supervisord.conf /etc/supervisord.conf
COPY --chmod=755 files/entrypoint.sh /usr/local/bin/entrypoint
COPY --chmod=755 files/asstatd.sh /usr/local/bin/asstatd
COPY --chmod=755 files/stats-update.sh /usr/local/bin/stats-update

RUN mkdir -p /usr/share/as-stats \
  && mv /var/www/config.inc /usr/share/as-stats/config.inc \
  && printf '%s\n' \
      '0 * * * * /usr/local/bin/stats-update day' \
      '30 2 * * * /usr/local/bin/stats-update week month' \
      >> /etc/crontabs/root \
  && nginx -t \
  && perl -c /root/AS-Stats/bin/asstatd.pl \
  && perl -c /root/AS-Stats/bin/rrd-extractstats.pl

EXPOSE 80
VOLUME ["/data/as-stats"]
HEALTHCHECK --start-period=30s CMD wget -q --spider http://127.0.0.1/ || exit 1
ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
