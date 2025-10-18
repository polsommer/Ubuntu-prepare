# SWG Prepare Ubuntu 24.04 LTS

> The helper scripts in this repository now target **Ubuntu 24.04 LTS** exclusively.

## SQL\*Plus bootstrap for the SWG schema

The `swgusr.sql` helper now provisions a production-ready Oracle account for the Star Wars Galaxies server:

* Creates dedicated data, index, and temporary tablespaces with autoextend enabled.
* Establishes a reusable application role that contains all required privileges.
* Ensures the `SWG` schema exists (creating or updating it as needed) and grants the role.
* Tunes key Oracle initialization parameters that commonly limit large private server deployments (`PROCESSES`, `SESSIONS`, and `OPEN_CURSORS`).
* Disables password rotation limits on the default profile so that the service account stays available.

Run the script from SQL\*Plus as a privileged user (`SYS` or `SYSTEM`):

```sql
sqlplus / as sysdba
SQL> @swgusr.sql
```

### Customisation

All important attributes can be overridden before invoking the script via `DEFINE` statements:

```sql
DEFINE SWG_PASSWORD = 'UseARealPassword!'
DEFINE SWG_DATAFILE_DIR = '/u01/app/oracle/oradata/SWG'
DEFINE SWG_TEMPFILE_DIR = '/u01/app/oracle/oradata/SWG/temp'
@swgusr.sql
```

If `SWG_*FILE_DIR` values are omitted, Oracle's `DB_CREATE_FILE_DEST` is used. Review the generated `swgusr.log` for the full execution trace and restart the database if parameter changes are reported.

## Oracle Instant Client delivery

`install.sh` orchestrates the end-to-end provisioning flow and ties all of the helpers together. Run it as `root` (tested on Ubuntu 24.04 LTS) to perform the full installation automatically:

```bash
sudo ./install.sh
```

The automation keeps lightweight state under `/var/lib/swg-prepare` to avoid repeating expensive steps and exposes convenience switches:

* `--dry-run` prints the actions that would be executed without applying them.
* `--force` reruns every helper even when the state file indicates completion.
* `--skip-oci8` and `--skip-service` allow you to omit the PHP OCI8 extension or systemd service deployment respectively.

`oci8.sh`, `oinit.sh`, and `swginit.sh` now fetch and install the Oracle Instant Client **21.18.0.0.0** 32-bit RPMs that match the `oracle-instantclient-basiclite`, `-devel`, and `-sqlplus` packages released for Linux. On Ubuntu the scripts transparently convert the RPMs to Debian packages with `alien`. By default the scripts download the artefacts from the maintained Google Drive mirror (via the bundled `gdown.pl` helper):

* `oracle-instantclient-basiclite-21.18.0.0.0-1.i386.rpm`
* `oracle-instantclient-devel-21.18.0.0.0-1.i386.rpm`
* `oracle-instantclient-sqlplus-21.18.0.0.0-1.i386.rpm`

If you mirror the RPMs elsewhere (for example on Google Drive), provide a newline-separated list of `filename|url` pairs via the `INSTANTCLIENT_COMPONENTS_OVERRIDE` environment variable and the helper will continue to fetch them—Google Drive URLs automatically trigger the bundled `gdown.pl` workflow. Downloads are cached under `/tmp/oracle-instantclient` by default. Override the cache location by exporting `INSTANTCLIENT_RPM_DIR` before invoking any helper script:

```bash
export INSTANTCLIENT_RPM_DIR=/var/cache/oracle
sudo ./swginit.sh
```

If you need to populate the cache manually (for offline deployments), drop the three RPMs into the selected directory ahead of time and the scripts will reuse them without re-downloading.

## Azul Zulu 32-bit JDK delivery

`swginit.sh` now installs a dedicated 32-bit Azul Zulu JDK 17 runtime so the emulator and its tooling can run with a consistent, supported Java environment. By default the script downloads the `zulu17.46.19-ca-jdk17.0.10-linux_i686.tar.gz` archive from Azul's CDN, caches it under `/tmp/azul-zulu`, and extracts it into `/opt/zulu`. A stable `JAVA_HOME` symlink (`/opt/zulu/zulu17`) is created and exported via `/etc/profile.d/java.sh` alongside an updated `PATH`.

Customise the download or installation paths as required:

```bash
export AZUL_ZULU_JDK_TARBALL=zulu17.46.19-ca-jdk17.0.10-linux_i686.tar.gz
export AZUL_ZULU_JDK_URL=https://cdn.azul.com/zulu/bin/${AZUL_ZULU_JDK_TARBALL}
export AZUL_ZULU_CACHE_DIR=/var/cache/azul
export AZUL_ZULU_INSTALL_ROOT=/opt/custom-zulu
sudo ./swginit.sh
```

When a tarball is already present in the cache directory, the script will reuse it without hitting the network, allowing completely offline provisioners to seed the archive ahead of time.
