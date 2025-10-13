SET DEFINE ON
SET VERIFY OFF
SET ECHO OFF
SET FEEDBACK ON
SET HEADING OFF
SET TERMOUT ON
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT ======================================================================
PROMPT Configuring the Star Wars Galaxies database account (swgusr.sql)
PROMPT ======================================================================
PROMPT Adjust the values below to match your environment before running.
PROMPT The script is idempotent and can be safely re-run when changes are made.
PROMPT ----------------------------------------------------------------------

-- User-customisable defaults. Override with SQL*Plus DEFINE before @swgusr.sql.
DEFINE SWG_USERNAME = 'SWG'
DEFINE SWG_PASSWORD = 'swg'
DEFINE SWG_ROLE     = 'SWG_APP_ROLE'
DEFINE SWG_DATA_TBS = 'SWG_DATA'
DEFINE SWG_INDEX_TBS = 'SWG_INDEX'
DEFINE SWG_TEMP_TBS = 'SWG_TEMP'
-- Leave the *_DIR entries empty to rely on DB_CREATE_FILE_DEST.
DEFINE SWG_DATAFILE_DIR = ''
DEFINE SWG_INDEXFILE_DIR = ''
DEFINE SWG_TEMPFILE_DIR = ''

SPOOL swgusr.log

BEGIN
    EXECUTE IMMEDIATE 'ALTER SESSION SET "_ORACLE_SCRIPT"=TRUE';
    DBMS_OUTPUT.PUT_LINE('Enabled Oracle script mode for container databases.');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -1031 THEN -- insufficient privileges can be ignored
            RAISE;
        ELSE
            DBMS_OUTPUT.PUT_LINE('Skipping _ORACLE_SCRIPT change due to insufficient privileges.');
        END IF;
END;
/

DECLARE
    v_datafile_dir  VARCHAR2(512) := NULLIF(TRIM(BOTH '/' FROM q'[&&SWG_DATAFILE_DIR]'), '');
    v_indexfile_dir VARCHAR2(512) := NULLIF(TRIM(BOTH '/' FROM q'[&&SWG_INDEXFILE_DIR]'), '');
    v_tempfile_dir  VARCHAR2(512) := NULLIF(TRIM(BOTH '/' FROM q'[&&SWG_TEMPFILE_DIR]'), '');

    FUNCTION default_file_dest RETURN VARCHAR2 IS
        v_dir v$parameter.value%TYPE;
    BEGIN
        SELECT value INTO v_dir FROM v$parameter WHERE name = 'db_create_file_dest';
        RETURN NULLIF(TRIM(BOTH '/' FROM v_dir), '');
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END;

    FUNCTION build_path(p_dir VARCHAR2, p_file VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE
                   WHEN p_dir IS NULL THEN NULL
                   ELSE p_dir || '/' || p_file
               END;
    END;

    PROCEDURE ensure_tablespace(
        p_name VARCHAR2,
        p_file VARCHAR2,
        p_kind VARCHAR2 -- DATA, INDEX, TEMP
    ) IS
        v_dir       VARCHAR2(512);
        v_final_dir VARCHAR2(512);
        v_path      VARCHAR2(1024);
        v_sql       VARCHAR2(4000);
        v_exists    INTEGER;
    BEGIN
        SELECT COUNT(*) INTO v_exists FROM dba_tablespaces WHERE tablespace_name = UPPER(p_name);
        IF v_exists > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Tablespace ' || UPPER(p_name) || ' already exists.');
            RETURN;
        END IF;

        CASE UPPER(p_kind)
            WHEN 'DATA' THEN
                v_dir := v_datafile_dir;
            WHEN 'INDEX' THEN
                v_dir := NVL(v_indexfile_dir, v_datafile_dir);
            WHEN 'TEMP' THEN
                v_dir := NVL(v_tempfile_dir, NVL(v_datafile_dir, v_indexfile_dir));
            ELSE
                v_dir := NULL;
        END CASE;

        v_final_dir := NVL(v_dir, default_file_dest);
        v_path := build_path(v_final_dir, p_file);

        IF v_path IS NULL THEN
            RAISE_APPLICATION_ERROR(-20000,
                'Unable to determine a location for tablespace ' || p_name ||
                '. Define the SWG_*FILE_DIR variables or configure DB_CREATE_FILE_DEST.');
        END IF;

        IF UPPER(p_kind) = 'TEMP' THEN
            v_sql := 'CREATE TEMPORARY TABLESPACE ' || UPPER(p_name) ||
                     ' TEMPFILE ''' || v_path ||
                     ''' SIZE 1024M REUSE AUTOEXTEND ON NEXT 128M MAXSIZE UNLIMITED '
                     || 'EXTENT MANAGEMENT LOCAL UNIFORM SIZE 1M';
        ELSE
            v_sql := 'CREATE BIGFILE TABLESPACE ' || UPPER(p_name) ||
                     ' DATAFILE ''' || v_path ||
                     ''' SIZE 2048M REUSE AUTOEXTEND ON NEXT 256M MAXSIZE UNLIMITED '
                     || 'LOGGING EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO';
        END IF;

        EXECUTE IMMEDIATE v_sql;
        DBMS_OUTPUT.PUT_LINE('Created tablespace ' || UPPER(p_name) || ' at ' || v_path);
    END;
BEGIN
    ensure_tablespace('&&SWG_DATA_TBS',  'swg_data01.dbf',  'DATA');
    ensure_tablespace('&&SWG_INDEX_TBS', 'swg_index01.dbf', 'INDEX');
    ensure_tablespace('&&SWG_TEMP_TBS',  'swg_temp01.dbf',  'TEMP');
END;
/

PROMPT Tablespace check complete.

DECLARE
BEGIN
    EXECUTE IMMEDIATE 'CREATE ROLE &&SWG_ROLE';
    DBMS_OUTPUT.PUT_LINE('Created role &&SWG_ROLE.');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -1921 THEN
            DBMS_OUTPUT.PUT_LINE('Role &&SWG_ROLE already exists.');
        ELSE
            RAISE;
        END IF;
END;
/

DECLARE
    TYPE priv_tab IS TABLE OF VARCHAR2(128);
    v_privs priv_tab := priv_tab(
        'CREATE SESSION',
        'CREATE TABLE',
        'CREATE VIEW',
        'CREATE SEQUENCE',
        'CREATE TRIGGER',
        'CREATE PROCEDURE',
        'CREATE TYPE',
        'CREATE SYNONYM',
        'CREATE MATERIALIZED VIEW',
        'ALTER SESSION',
        'CREATE JOB'
    );
BEGIN
    FOR i IN 1 .. v_privs.COUNT LOOP
        BEGIN
            EXECUTE IMMEDIATE 'GRANT ' || v_privs(i) || ' TO &&SWG_ROLE';
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLCODE != -1951 THEN -- ignore "already granted" errors
                    RAISE;
                END IF;
        END;
    END LOOP;

    BEGIN
        EXECUTE IMMEDIATE 'GRANT UNLIMITED TABLESPACE TO &&SWG_ROLE';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -1951 THEN
                RAISE;
            END IF;
    END;
END;
/

PROMPT Role &&SWG_ROLE configured.

DECLARE
    v_username CONSTANT VARCHAR2(30) := DBMS_ASSERT.SIMPLE_SQL_NAME(UPPER('&&SWG_USERNAME'));
    v_password CONSTANT VARCHAR2(4000) := DBMS_ASSERT.ENQUOTE_LITERAL(q'[&&SWG_PASSWORD]');
    v_exists   INTEGER;
    v_sql      VARCHAR2(4000);
BEGIN
    SELECT COUNT(*) INTO v_exists FROM dba_users WHERE username = v_username;

    IF v_exists = 0 THEN
        v_sql := 'CREATE USER ' || v_username ||
                 ' IDENTIFIED BY ' || v_password ||
                 ' DEFAULT TABLESPACE ' || UPPER('&&SWG_DATA_TBS') ||
                 ' TEMPORARY TABLESPACE ' || UPPER('&&SWG_TEMP_TBS');
        EXECUTE IMMEDIATE v_sql;
        DBMS_OUTPUT.PUT_LINE('Created user ' || v_username || '.');
    ELSE
        v_sql := 'ALTER USER ' || v_username || ' IDENTIFIED BY ' || v_password;
        EXECUTE IMMEDIATE v_sql;
        EXECUTE IMMEDIATE 'ALTER USER ' || v_username ||
                          ' DEFAULT TABLESPACE ' || UPPER('&&SWG_DATA_TBS') ||
                          ' TEMPORARY TABLESPACE ' || UPPER('&&SWG_TEMP_TBS');
        DBMS_OUTPUT.PUT_LINE('Updated credentials for user ' || v_username || '.');
    END IF;

    EXECUTE IMMEDIATE 'ALTER USER ' || v_username || ' QUOTA UNLIMITED ON ' || UPPER('&&SWG_DATA_TBS');
    EXECUTE IMMEDIATE 'ALTER USER ' || v_username || ' QUOTA UNLIMITED ON ' || UPPER('&&SWG_INDEX_TBS');

    BEGIN
        EXECUTE IMMEDIATE 'GRANT &&SWG_ROLE TO ' || v_username;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -1951 THEN -- ignore already granted
                RAISE;
            END IF;
    END;
END;
/

PROMPT User &&SWG_USERNAME provisioned.

BEGIN
    EXECUTE IMMEDIATE 'ALTER SYSTEM SET processes = 3000 SCOPE = SPFILE';
    DBMS_OUTPUT.PUT_LINE('Set PROCESSES to 3000 (requires restart).');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -32017 THEN -- cannot alter in current mode
            RAISE;
        ELSE
            DBMS_OUTPUT.PUT_LINE('Skipped altering PROCESSES due to restricted session.');
        END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER SYSTEM SET sessions = 4500 SCOPE = SPFILE';
    DBMS_OUTPUT.PUT_LINE('Set SESSIONS to 4500 (requires restart).');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -32017 THEN
            RAISE;
        ELSE
            DBMS_OUTPUT.PUT_LINE('Skipped altering SESSIONS due to restricted session.');
        END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER SYSTEM SET open_cursors = 1000 SCOPE = BOTH';
    DBMS_OUTPUT.PUT_LINE('Ensured OPEN_CURSORS is at least 1000.');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -02095 THEN -- parameter cannot be modified
            RAISE;
        ELSE
            DBMS_OUTPUT.PUT_LINE('OPEN_CURSORS cannot be changed in this environment.');
        END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER PROFILE DEFAULT LIMIT PASSWORD_LIFE_TIME UNLIMITED';
    EXECUTE IMMEDIATE 'ALTER PROFILE DEFAULT LIMIT PASSWORD_REUSE_TIME UNLIMITED';
    EXECUTE IMMEDIATE 'ALTER PROFILE DEFAULT LIMIT PASSWORD_REUSE_MAX UNLIMITED';
    DBMS_OUTPUT.PUT_LINE('Adjusted DEFAULT profile password limits for long-lived service accounts.');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -02379 THEN -- already set to specified value
            RAISE;
        END IF;
END;
/

PROMPT ======================================================================
PROMPT SWG database bootstrap completed successfully.
PROMPT Review swgusr.log for full details and restart the database if prompted.
PROMPT ======================================================================

SPOOL OFF

EXIT
