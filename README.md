# SWG Prepare

These are some tools you might be able to use if you want to [build your own SWG Server](https://tekaohswg.github.io/new.html).

> **Note**
> The helper scripts in this repository now target **openSUSE 16** exclusively. They will abort when executed on any other operating system or distribution release.

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

`oci8.sh`, `oinit.sh`, and `swginit.sh` now fetch and install the Oracle Instant Client **12.2.0.1.0** 32-bit RPMs directly from the mirrored Google Drive assets used by the SWG community. The scripts rely on the bundled `gdown.pl` helper to retrieve the following artefacts automatically:

* `oracle-instantclient12.2-basiclite-12.2.0.1.0-1.i386.rpm`
* `oracle-instantclient12.2-devel-12.2.0.1.0-1.i386.rpm`
* `oracle-instantclient12.2-sqlplus-12.2.0.1.0-1.i386.rpm`

Downloads are cached under `/tmp/oracle-instantclient` by default. Override the cache location by exporting `INSTANTCLIENT_RPM_DIR` before invoking any helper script:

```bash
export INSTANTCLIENT_RPM_DIR=/var/cache/oracle
sudo ./swginit.sh
```

If you need to populate the cache manually (for offline deployments), drop the three RPMs into the selected directory ahead of time and the scripts will reuse them without re-downloading.
