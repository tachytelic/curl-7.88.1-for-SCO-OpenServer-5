# curl 7.88.1 with TLS for SCO OpenServer 5

A working build of [curl 7.88.1](https://curl.se/) (February 2023) for
**SCO OpenServer 5.0.7**, with full TLS support via statically-linked
OpenSSL 1.0.2q.

```
$ curl -sI https://www.google.com/
HTTP/1.1 200 OK
Content-Type: text/html; charset=ISO-8859-1
...
$ curl https://api.github.com/zen
Encourage flow.
```

Just want HTTPS on your SCO box? Skip to **[Install](#install)**.

## Why 7.88?

curl 8.0 (March 2023) dropped support for 32-bit `curl_off_t`. SCO 5.0.7
is 32-bit i386 with 32-bit `off_t`, no `off64_t`, no large-file support.
**7.88.1** is the final release that still supports systems like SCO
(via the `--with-n64-deprecated` configure opt-in).

## Install

The binary is **442 KB** — small enough to commit. Grab `prebuilt/curl`,
`extras/cacert.pem`, copy them to your SCO box:

```sh
# scp curl + cacert.pem to the SCO machine, then on SCO:
chmod +x curl
mv curl /usr/local/bin/curl

# Install the Mozilla CA bundle for HTTPS verification:
mkdir -p /usr/local/etc/ssl
cp cacert.pem /usr/local/etc/ssl/cert.pem

curl --version
curl -sI https://www.google.com/
```

The CA bundle path `/usr/local/etc/ssl/cert.pem` is baked into the
curl binary as the default — no `--cacert` flag needed.

## Bootstrapping the rest of your system

This is the only file you need to scp onto a fresh SCO box. Once curl
is in place you can fetch everything else over HTTPS from GitHub
releases. The full chain on a freshly-installed SCO 5.0.7 (no Skunkware,
no extras):

```sh
# After curl is installed (above), get GNU tar so you can extract
# .tar.gz releases in one step instead of piping gunzip into tar.
# This first one uses stock SCO tools (gunzip + /usr/bin/tar):

curl -LO https://github.com/tachytelic/Tar-1.34-for-SCO-OpenServer-5/releases/download/v1.0.0/tar-1.34-sco.tar.gz
gunzip -c tar-1.34-sco.tar.gz | /usr/bin/tar xf -
mv install /usr/local/tar-1.34
ln -s /usr/local/tar-1.34/bin/tar /usr/local/bin/gtar

# Now `gtar xzf x.tar.gz` works for everything else. Pick what you want:

# Python 3.6.15 with HTTPS (~35 MB)
curl -LO https://github.com/tachytelic/Python-3.6.15-for-SCO-OpenServer-5/releases/download/v1.0.1/python-3.6.15-sco.tar.gz
gtar xzf python-3.6.15-sco.tar.gz
mv install /usr/local/python-3.6.15
ln -s /usr/local/python-3.6.15/bin/python3 /usr/local/bin/python3

# Lua 5.4.7 (single binary, no tarball)
curl -LO https://github.com/tachytelic/Lua-5.4.7-for-SCO-OpenServer-5/releases/download/v1.0.0/lua
chmod +x lua && mv lua /usr/local/bin/lua

# rsync 3.2.7
curl -LO https://github.com/tachytelic/rsync-3.2.7-for-SCO-OpenServer-5/releases/download/v1.0.0/rsync-3.2.7-sco.tar.gz
gtar xzf rsync-3.2.7-sco.tar.gz
# ...etc per each repo's README
```

That's the entire bootstrap. Every release verified end-to-end on a SCO
5.0.7 box: HTTPS fetch from github.com works on our curl, the .tar.gz
releases extract cleanly with stock tools, and `gtar` then handles every
later untar in one shot.

The full hub of available builds is at
[tachytelic.net/2017/07/sco-openserver-5-binaries/](https://tachytelic.net/2017/07/sco-openserver-5-binaries/).

## What you get

- **Modern TLS** — TLS 1.0/1.1/1.2 (no 1.3 — that needs OpenSSL 1.1.1+,
  which SCO can't currently build)
- **Modern ciphers** including ECDHE-RSA-AES256-GCM-SHA384
- **Mozilla CA bundle** for verifying server certs against real-world
  certificate authorities
- Protocols: `http`, `https`, `ftp`, `ftps`, `file`
- Features: HSTS, alt-svc, NTLM, SSL, TLS-SRP

## What's not included

Compile-time disabled — these need libraries SCO doesn't have, or
features that don't fit SCO's runtime:

- `HTTP/2`, `HTTP/3` (need nghttp2 / ngtcp2)
- `SSH`/`SCP`/`SFTP` protocols (need libssh/libssh2)
- `MQTT`, `RTSP`, `LDAP`, `LDAPS`, `DICT`, `TELNET`, `TFTP`,
  `POP3`/`IMAP`/`SMB`/`SMTP`/`GOPHER` — none of these are common needs
- IPv6 (SCO is IPv4-only)
- IDN, PSL, brotli, zstd, zlib (optional features that need extra libs)
- Threaded resolver (no pthreads on SCO — uses synchronous
  `gethostbyname` instead, which works fine for normal use)

What's left covers ~99% of what people actually use curl for: HTTP and
HTTPS to internet servers.

## Quick demos

```sh
# HEAD request
curl -sI https://example.com/

# Fetch JSON from an HTTPS API
curl -s https://api.github.com/repos/curl/curl | head

# Save to a file
curl -o page.html https://www.google.com/

# Verbose TLS handshake (debug)
curl -v https://example.com/ 2>&1 | grep -E "TLS|SSL|cipher"
```

## Updating the CA bundle

Mozilla's CA bundle changes occasionally as CAs are added or removed.
The `extras/cacert.pem` in this repo was the current version at build
time. To refresh:

```sh
# On any internet-connected machine:
curl -sLO https://curl.se/ca/cacert.pem
scp cacert.pem root@your-sco-host:/usr/local/etc/ssl/cert.pem
```

## Building from source

You probably don't need to do this — `prebuilt/curl` is what `build.sh`
produces. If you want to rebuild (different version, different config
flags), run `build.sh` **on the SCO box**.

This is a **native build, not a cross-build**.

### Requirements

- **GCC 3.4 or later** somewhere on the SCO box (the SCO-shipped GCC
  2.95.3 is C89-only — curl 7.88 needs C99). The build script refuses to
  start with 2.x. If your modern gcc is on PATH as `gcc`, just run
  `./build.sh`. Otherwise: `GCC=/path/to/your/gcc-3.4 ./build.sh`.
- `/usr/gnu/bin/{gmake,gtar}`
- **Static OpenSSL 1.0.2** at `/usr/local/lib/{libssl,libcrypto}.a` with
  headers at `/usr/local/include/openssl/`. SCO's stock 0.9.7 won't do —
  modern TLS handshakes against current servers need 1.0.2 or 1.1.1+.
  Build OpenSSL 1.0.2 first:
  ```sh
  ./Configure no-shared no-asm sco5-gcc
  make depend && make && make install
  ```

### Build

```sh
cd curl-sco
./build.sh
```

Downloads `curl-7.88.1.tar.gz` from curl.se, configures, builds, runs
`make install` to `./curl_install/`, strips. **No source patches needed.**
That's the nice thing about curl — its `configure` script has clean
toggles for every optional feature, so the right combination of `--with`/
`--without` flags gets us a clean SCO build with no source changes at all.

## Repository layout

```
prebuilt/
  curl                       442 KB stripped binary  ← start here

extras/
  cacert.pem                 Mozilla CA bundle (~221 KB)

build.sh                     Native-build script (run on SCO)
```

## License

curl is © Daniel Stenberg and many contributors, distributed under the
[curl License](https://curl.se/docs/copyright.html). The prebuilt binary
is unmodified upstream curl 7.88.1 with no patches applied.

The Mozilla CA bundle (`extras/cacert.pem`) is provided by Mozilla
Foundation, distributed by [curl.se/docs/caextract.html](https://curl.se/docs/caextract.html)
under the terms described there (MPL 2.0 / public domain hybrid).

The build script in this repo is released under the MIT license — see
[LICENSE](LICENSE).

## See also

If you're keeping a SCO OpenServer 5 box alive, head over to
[my SCO OpenServer 5 binaries page](https://tachytelic.net/2017/07/sco-openserver-5-binaries/)
to find other compiled software for the SCO OpenServer (bash, rsync,
Python, lzop, …) along with notes on running these systems day to day.
