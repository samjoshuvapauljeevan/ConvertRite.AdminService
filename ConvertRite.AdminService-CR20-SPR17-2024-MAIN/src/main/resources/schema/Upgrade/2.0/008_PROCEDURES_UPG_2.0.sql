----procedures
CREATE OR REPLACE PROCEDURE cr_hdl_filegen_proc (
    p_cld_template_id IN VARCHAR2,
    p_batch_name      IN VARCHAR2,
    p_intial_load     IN VARCHAR2 DEFAULT 'N',
    p_clob_hdl_file   OUT CLOB,
    p_ret_code        OUT VARCHAR2,
    p_ret_msg         OUT VARCHAR2
) IS 

    TYPE numtab IS
        TABLE OF NUMBER;
    TYPE varchartab IS
        TABLE OF VARCHAR2(32000);
    l_pod_id          NUMBER;
    l_project_id      NUMBER;
    l_parent_obj_id   NUMBER;
    l_obj_id          NUMBER;
    l_temp_id         NUMBER;
    l_metadata_tab    NUMBER;
    l_stg_table       VARCHAR2(100);
    l_orderby         VARCHAR2(100);
    l_parent_obj_name VARCHAR2(200);
    l_clob            CLOB := empty_clob;
    l_count           NUMBER;
    l_count_check     NUMBER;
    l_check           NUMBER;
    l_template_check  VARCHAR2(2000);

    FUNCTION table_to_hdl_func (
        p_cld_template_id IN NUMBER,
        p_table_name      IN VARCHAR2,
        p_batch_name      IN VARCHAR2,
        p_orderby_clause  IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB IS

        l_clob           CLOB;
        l_table_id       NUMBER;
        l_table_name     VARCHAR2(250) := p_table_name;
        TYPE varchartab IS
            TABLE OF VARCHAR2(500);
        TYPE largevarchartab IS
            TABLE OF VARCHAR2(32000);
        l_column_tab     varchartab;
        l_usr_column_tab varchartab;
        l_hdr_rec        CLOB;
        l_val_rec        CLOB;
        l_val_tab        largevarchartab;
        l_orderby_clause VARCHAR2(420);
    BEGIN
        SELECT
            metadata_table_id
        INTO l_table_id
        FROM
            cr_cld_template_hdrs
        WHERE
            cld_template_id = p_cld_template_id;

        SELECT
            CASE
                WHEN a.column_name = 'EFFECTIVEENDDATE'
                     AND a.column_type = 'D' THEN
                    q'[case when EFFECTIVEENDDATE is not null and EFFECTIVEENDDATE = to_date('31/12/2012','DD/MM/YYYY')
           then '4712/12/31'
           else to_char(EFFECTIVEENDDATE,'YYYY/MM/DD') END]'
                ELSE
                    decode(a.column_type, 'D', 'to_char('
                                               || a.column_name
                                               || ','
                                               || ''''
                                               || 'YYYY/MM/DD'
                                               || ''''
                                               || ')', a.column_name)
            END,
            user_column_name
        BULK COLLECT
        INTO
            l_column_tab,
            l_usr_column_tab
        FROM
            cr_cloud_columns     a,
            cr_cld_template_cols b
        WHERE
                a.table_id = l_table_id
            AND b.cld_template_id = p_cld_template_id
            AND b.selected = 'Y'
            AND a.column_name = b.column_name
            AND a.column_name NOT LIKE 'ATTRIBUTE%'
            AND a.column_name NOT LIKE 'ASS_ATTRIBUTE%'
        ORDER BY
            TO_NUMBER(a.column_sequence) ASC;

        FOR i IN l_column_tab.first..l_column_tab.last LOOP
            l_hdr_rec := l_hdr_rec
                         || l_usr_column_tab(i)
                         || '|';
            l_val_rec := l_val_rec
                         || 'replace('
                         || l_column_tab(i)
                         || q'[,'|','\|')]'
                         || q'[||'|'||]';

        END LOOP;

        l_hdr_rec := substr(l_hdr_rec, 0, length(l_hdr_rec) - 1);
        l_val_rec := substr(l_val_rec, 0, length(l_val_rec) - 7);
        EXECUTE IMMEDIATE 'SELECT '
                          || l_val_rec
                          || ' FROM '
                          || l_table_name
                          || ' WHERE CR_BATCH_NAME = '
                          || ''''
                          || p_batch_name
                          || ''''
                          || ' ORDER BY '
                          || nvl(p_orderby_clause, 'NULL')
        BULK COLLECT
        INTO l_val_tab;

        l_clob := l_hdr_rec
                  || ( convert(chr(10), substr(userenv('LANGUAGE'), instr(userenv('LANGUAGE'), '.') + 1), 'US7ASCII') );

        FOR i IN l_val_tab.first..l_val_tab.last LOOP
            l_clob := l_clob
                      || l_val_tab(i)
                      || ( convert(chr(10), substr(userenv('LANGUAGE'), instr(userenv('LANGUAGE'), '.') + 1), 'US7ASCII') );
        END LOOP;

        INSERT INTO cr_log_messages (
            proc_name,
            log_message,
            reference_key,
            creation_date
        ) VALUES (
            'TABLE_TO_HDL_FUNC',
            'HDL file generated Successfully',
            'Cloud template id:'
            || p_cld_template_id
            || ', Batch Name:'
            || p_batch_name,
            sysdate
        );

        RETURN l_clob
               || ( convert(chr(10), substr(userenv('LANGUAGE'), instr(userenv('LANGUAGE'), '.') + 1), 'US7ASCII') );

    EXCEPTION
        WHEN OTHERS THEN
            IF p_intial_load = 'Y' THEN
                raise_application_error(-20001, 'No data exits in the " '
                                                || p_table_name
                                                || ' " with batch_name : '
                                                || p_batch_name);
            ELSE
                raise_application_error(-20001, sqlerrm
                                                || ' on table '
                                                || p_table_name);
            END IF;
    END table_to_hdl_func;

BEGIN
    dbms_lob.createtemporary(l_clob, TRUE);
    IF p_intial_load = 'Y' THEN
        FOR k IN (
            SELECT DISTINCT
                coi.object_id,
                ch.cld_template_id,
                ch.cld_template_name
            FROM
                cr_object_information coi,
                cr_cld_template_hdrs  ch
            WHERE
                info_type LIKE 'Enable Object%'
                AND coi.object_id IN (
                    SELECT DISTINCT
                        object_id
                    FROM
                        cr_objects
                    WHERE
                        module_code = 'HCM'
                )
                AND coi.object_id = ch.object_id
        ) LOOP
            SELECT
                instr(','
                      || p_cld_template_id
                      || ',', ','
                              || k.cld_template_id
                              || ',')
            INTO l_check
            FROM
                dual;

            IF l_check = 0 THEN
                l_template_check := l_template_check
                                    || k.cld_template_name
                                    || ',';
            END IF;

        END LOOP;

    END IF;

    IF l_template_check IS NULL THEN
        SELECT
            regexp_count(p_cld_template_id, ',')
        INTO l_count
        FROM
            dual;

        FOR i IN 1..l_count + 1 LOOP
            SELECT DISTINCT
                hdrs.project_id,
                hdrs.parent_object_id,
                hdrs.object_id,
                hdrs.cld_template_id,
                hdrs.metadata_table_id,
                hdrs.staging_table_name,
                nvl(hdrs.attribute1, '1') collect
            INTO
                l_project_id,
                l_parent_obj_id,
                l_obj_id,
                l_temp_id,
                l_metadata_tab,
                l_stg_table,
                l_orderby
            FROM
                cr_cld_template_hdrs hdrs
            WHERE
                hdrs.cld_template_id IN ( regexp_substr(p_cld_template_id, '[^,]+', 1, i) )
                AND hdrs.staging_table_name IS NOT NULL;

            SELECT
                COUNT(object_id)
            INTO l_count_check
            FROM
                cr_objects
            WHERE
                    module_code = 'HCM'
                AND parent_object_id IS NULL
                AND object_id = l_parent_obj_id;

            IF l_count_check > 0 THEN
                dbms_lob.append(l_clob, to_clob(table_to_hdl_func(l_temp_id, l_stg_table, p_batch_name, l_orderby)));
            END IF;

        END LOOP;

        l_clob := 'SET CALCULATE_FTE Y'
                  || chr(10)
                  || l_clob;
        p_clob_hdl_file := l_clob;
        p_ret_code := 'Y';
        p_ret_msg := 'SUCCESS';
        INSERT INTO cr_log_messages (
            proc_name,
            log_message,
            reference_key,
            creation_date
        ) VALUES (
            'CR_HDL_FILEGEN_PROC',
            'HDL file generated Successfully for '
            || p_cld_template_id
            || ' Cloud templates',
            'Batch Name:' || p_batch_name,
            sysdate
        );

    ELSE
        p_clob_hdl_file := empty_clob();
        p_ret_code := 'N';
        p_ret_msg := 'As Part of Initial Load, Below Mandatory templates are missing. Please include them and try again.'
                     || chr(13)
                     || substr(l_template_check, 0, length(l_template_check) - 1);

        INSERT INTO cr_log_messages (
            proc_name,
            log_message,
            reference_key,
            creation_date
        ) VALUES (
            'CR_HDL_FILEGEN_PROC',
            'Failed to generate HDL file',
            p_ret_msg,
            sysdate
        );

    END IF;

EXCEPTION
    WHEN OTHERS THEN
        p_clob_hdl_file := empty_clob();
        p_ret_code := 'N';
        p_ret_msg := 'Unexpected error in HDL File Generation: ' || sqlerrm;
        INSERT INTO cr_log_messages (
            proc_name,
            log_message,
            reference_key,
            creation_date
        ) VALUES (
            'CR_HDL_FILEGEN_PROC',
            'Failed to generate HDL file',
            p_ret_msg,
            sysdate
        );

END cr_hdl_filegen_proc;
$#$
create or replace PROCEDURE cr_cloud_import_rej_proc (
    p_user_id         IN VARCHAR2,
    p_cld_template_id IN NUMBER,
    p_batch_name      IN VARCHAR2 DEFAULT NULL,
    p_clob_rej_file   OUT CLOB,
    p_ret_code        OUT VARCHAR2,
    p_ret_msg         OUT VARCHAR2
) IS
    TYPE varchartab IS
        TABLE OF VARCHAR2(32000);
    l_cld_stg_table VARCHAR2(200);
    l_cld_col_tab   varchartab;
    l_query         CLOB;
    l_clob_tab      varchartab;
    l_final_clob    CLOB;
    l_cols          CLOB;
    cur             SYS_REFCURSOR;
    l_project_id    NUMBER;
    l_parent_obj_id NUMBER;
    l_obj_id        NUMBER;
    l_obj_name      VARCHAR2(200);
    l_date_format   VARCHAR2(50) DEFAULT NULL;
    lc_proc         VARCHAR2(100) := 'CR_CLOUD_IMPORT_REJ_PROC';
    l_project_name  VARCHAR2(100);
    L_REJ_QUERY CLOB;
    L_LOAD_REQUEST_ID VARCHAR2(240);
BEGIN
    p_ret_code := 'SUCCESS';
    p_ret_msg := 'SUCCESS';
    cr_audit_log_msg_proc(p_user_id, lc_proc, 'CLD_TEMPLATE_ID: ' || p_cld_template_id, 'START', NULL);
    SELECT
        project_id,
        parent_object_id,
        object_id,
        object_name,
        staging_table_name
    INTO
        l_project_id,
        l_parent_obj_id,
        l_obj_id,
        l_obj_name,
        l_cld_stg_table
    FROM
        cr_cld_template_hdrs_v
    WHERE
        cld_template_id = p_cld_template_id;
    cr_audit_log_msg_proc(p_user_id, lc_proc, 'CLD_TEMPLATE_ID: '
                                              || p_cld_template_id
                                              || ' ,Cld staging_table_name: '
                                              || l_cld_stg_table
                                              || ' ,Project_Name: '
                                              || l_project_name
                                              || ', Object_Name : '
                                              || l_obj_name, 'Fetched Object information', NULL);
    SELECT
        column_name
    BULK COLLECT
    INTO l_cld_col_tab
    FROM
        all_tab_columns
    WHERE
        table_name = l_cld_stg_table
    ORDER BY
        column_id;
        SELECT nvl(info_value,'NULL')    INTO l_rej_query
FROM cr_object_information  WHERE
 info_type = 'RECON_CLOUD_FAIL'
AND object_id = l_obj_id;

SELECT NVL (LOAD_REQUEST_ID , NULL ) INTO L_LOAD_REQUEST_ID   FROM CR_CLOUD_JOB_STATUS
WHERE OBJECT_ID = l_obj_id
AND BATCH_NAME = p_batch_name ;
  l_cols := ''''
                  || '"'
                  || ''''
                  || '|| Reject_lookup_code'
                  || '||'
                  || ''''
                  || '"'
                  || ''''
                  || '||'
                  || ''''
                  || ','
                  || ''''
                  || '||';
                          FOR i IN l_cld_col_tab.first..l_cld_col_tab.last LOOP
            l_cols := l_cols
                      || ''''
                      || '"'
                      || ''''
                     || '|| cld_stg .'
                      ||replace( l_cld_col_tab(i),chr(10),'')
                      || '||'
                      || ''''
                      || '"'
                      || ''''
                      || '||'
                      || ''''
                      || ','
                      || ''''
                      || '||';
                      END LOOP;
                              l_cols := substr(l_cols, 0, length(l_cols) - 7);
        cr_audit_log_msg_proc(p_user_id, lc_proc, 'CLD_TEMPLATE_ID: '
                                                  || p_cld_template_id
                                                  || ' ,Cld staging_table_name: '
                                                  || l_cld_stg_table
                                                  || ' ,Project_Name: '
                                                  || l_project_name
                                                  || ', Object_Name : '
                                                  || l_obj_name, 'Inside IF condition for Supplier Import rejected Records', l_query);
                     L_REJ_QUERY  := REPLACE (L_REJ_QUERY,':cr_batch_name',p_batch_name);
                       L_REJ_QUERY  := REPLACE (L_REJ_QUERY,':load_request_id',L_LOAD_REQUEST_ID);
                        L_REJ_QUERY  := REPLACE (L_REJ_QUERY,':cld_stg_table',l_cld_stg_table);
                        L_REJ_QUERY  := REPLACE (L_REJ_QUERY,':cld_cols',l_cols);
l_query := L_REJ_QUERY;
        OPEN cur FOR l_query;
        LOOP
            FETCH cur
            BULK COLLECT INTO l_clob_tab LIMIT 100;
            EXIT WHEN l_clob_tab.count = 0;
            FOR x IN 1..l_clob_tab.count LOOP
                l_final_clob := l_final_clob
                                || l_clob_tab(x)
                                || chr(10);
            END LOOP;
        END LOOP;
    p_clob_rej_file := l_final_clob;
    cr_audit_log_msg_proc(p_user_id, lc_proc, 'CLD_TEMPLATE_ID: '
                                              || p_cld_template_id
                                              || ' ,Cld staging_table_name: '
                                              || l_cld_stg_table
                                              || ' ,Project_Name: '
                                              || l_project_name
                                              || ', Object_Name : '
                                              || l_obj_name, 'END', NULL);
EXCEPTION
    WHEN OTHERS THEN
        p_ret_code := 'ERROR';
        p_ret_msg := 'Unexpected Error in CR_CLOUD_IMPORT_REJ_PROC. Error: ' || sqlerrm;
        cr_audit_log_msg_proc(p_user_id, lc_proc, 'CLD_TEMPLATE_ID: '
                                                  || p_cld_template_id
                                                  || ' ,Cld staging_table_name: '
                                                  || l_cld_stg_table
                                                  || ' ,Project_Name: '
                                                  || l_project_name
                                                  || ', Object_Name : '
                                                  || l_obj_name, 'Unexpected Error: ' || sqlerrm, NULL);
END cr_cloud_import_rej_proc;

$#$
create or replace PROCEDURE cr_cloud_import_succ_proc (
    p_user_id         IN VARCHAR2,
    p_cld_template_id IN NUMBER,
    p_batch_name      IN VARCHAR2 DEFAULT NULL,
    p_clob_rej_file   OUT CLOB,
    p_ret_code        OUT VARCHAR2,
    p_ret_msg         OUT VARCHAR2
) IS
    TYPE varchartab IS
        TABLE OF VARCHAR2(32000);
    l_cld_stg_table VARCHAR2(200);
    l_cld_col_tab   varchartab;
    l_query         CLOB;
    l_clob_tab      varchartab;
    l_final_clob    CLOB;
    l_cols          CLOB;
    cur             SYS_REFCURSOR;
    l_project_id    NUMBER;
    l_parent_obj_id NUMBER;
    l_obj_id        NUMBER;
    l_obj_name      VARCHAR2(200);
    l_date_format   VARCHAR2(50) DEFAULT NULL;
    lc_proc         VARCHAR2(100) := 'CR_CLOUD_IMPORT_REJ_PROC';
    l_project_name  VARCHAR2(100);
    L_REJ_QUERY CLOB;
    L_LOAD_REQUEST_ID VARCHAR2(240);
BEGIN
    p_ret_code := 'SUCCESS';
    p_ret_msg := 'SUCCESS';
    cr_audit_log_msg_proc(p_user_id, lc_proc, 'CLD_TEMPLATE_ID: ' || p_cld_template_id, 'START', NULL);
    SELECT
        project_id,
        parent_object_id,
        object_id,
        object_name,
        staging_table_name
    INTO
        l_project_id,
        l_parent_obj_id,
        l_obj_id,
        l_obj_name,
        l_cld_stg_table
    FROM
        cr_cld_template_hdrs_v
    WHERE
        cld_template_id = p_cld_template_id;
    cr_audit_log_msg_proc(p_user_id, lc_proc, 'CLD_TEMPLATE_ID: '
                                              || p_cld_template_id
                                              || ' ,Cld staging_table_name: '
                                              || l_cld_stg_table
                                              || ' ,Project_Name: '
                                              || l_project_name
                                              || ', Object_Name : '
                                              || l_obj_name, 'Fetched Object information', NULL);
    SELECT
        column_name
    BULK COLLECT
    INTO l_cld_col_tab
    FROM
        all_tab_columns
    WHERE
        table_name = l_cld_stg_table
    ORDER BY
        column_id;
        
        SELECT nvl(info_value,'NULL')    INTO l_rej_query
FROM cr_object_information  WHERE
 info_type = 'RECON_CLOUD_SUCCESS'
AND object_id = l_obj_id;

SELECT NVL (LOAD_REQUEST_ID , NULL ) INTO L_LOAD_REQUEST_ID   FROM CR_CLOUD_JOB_STATUS
WHERE OBJECT_ID = l_obj_id
AND BATCH_NAME = p_batch_name ;
  l_cols := ''''
                  || '"'
                  || ''''
                  || '|| NULL'
                  || '||'
                  || ''''
                  || '"'
                  || ''''
                  || '||'
                  || ''''
                  || ','
                  || ''''
                  || '||';
                          FOR i IN l_cld_col_tab.first..l_cld_col_tab.last LOOP
            l_cols := l_cols
                      || ''''
                      || '"'
                      || ''''
                     || '|| cld_stg .'
                      ||replace( l_cld_col_tab(i),chr(10),'')
                      || '||'
                      || ''''
                      || '"'
                      || ''''
                      || '||'
                      || ''''
                      || ','
                      || ''''
                      || '||';
                      END LOOP;
                              l_cols := substr(l_cols, 0, length(l_cols) - 7);
        cr_audit_log_msg_proc(p_user_id, lc_proc, 'CLD_TEMPLATE_ID: '
                                                  || p_cld_template_id
                                                  || ' ,Cld staging_table_name: '
                                                  || l_cld_stg_table
                                                  || ' ,Project_Name: '
                                                  || l_project_name
                                                  || ', Object_Name : '
                                                  || l_obj_name, 'Inside IF condition for Supplier Import rejected Records', l_query);
                     L_REJ_QUERY  := REPLACE (L_REJ_QUERY,':cr_batch_name',p_batch_name);
                       L_REJ_QUERY  := REPLACE (L_REJ_QUERY,':load_request_id',L_LOAD_REQUEST_ID);
                        L_REJ_QUERY  := REPLACE (L_REJ_QUERY,':cld_stg_table',l_cld_stg_table);
                        L_REJ_QUERY  := REPLACE (L_REJ_QUERY,':cld_cols',l_cols);
l_query := L_REJ_QUERY;
        OPEN cur FOR l_query;
        LOOP
            FETCH cur
            BULK COLLECT INTO l_clob_tab LIMIT 100;
            EXIT WHEN l_clob_tab.count = 0;
            FOR x IN 1..l_clob_tab.count LOOP
                l_final_clob := l_final_clob
                                || l_clob_tab(x)
                                || chr(10);
            END LOOP;
        END LOOP;
    p_clob_rej_file := l_final_clob;
    cr_audit_log_msg_proc(p_user_id, lc_proc, 'CLD_TEMPLATE_ID: '
                                              || p_cld_template_id
                                              || ' ,Cld staging_table_name: '
                                              || l_cld_stg_table
                                              || ' ,Project_Name: '
                                              || l_project_name
                                              || ', Object_Name : '
                                              || l_obj_name, 'END', NULL);
EXCEPTION
    WHEN OTHERS THEN
        p_ret_code := 'ERROR';
        p_ret_msg := 'Unexpected Error in CR_CLOUD_IMPORT_REJ_PROC. Error: ' || sqlerrm;
        cr_audit_log_msg_proc(p_user_id, lc_proc, 'CLD_TEMPLATE_ID: '
                                                  || p_cld_template_id
                                                  || ' ,Cld staging_table_name: '
                                                  || l_cld_stg_table
                                                  || ' ,Project_Name: '
                                                  || l_project_name
                                                  || ', Object_Name : '
                                                  || l_obj_name, 'Unexpected Error: ' || sqlerrm, NULL);
END cr_cloud_import_succ_proc;

$#$
CREATE OR REPLACE PROCEDURE cr_fbdi_filegen_proc (
    p_cld_template_id IN NUMBER,
    p_batch_name      IN VARCHAR2,
    p_clob_fbdi_file  OUT CLOB,
    p_result_code     OUT VARCHAR2,
    p_result_msg      OUT VARCHAR2
) IS

    TYPE varchartab IS
        TABLE OF CLOB;
    TYPE clobtab IS
        TABLE OF CLOB;
    l_clob_tab      clobtab;
    l_clob          CLOB;
    l_tab_name      VARCHAR2(150);
    l_cols          VARCHAR(25000);
    l_orig_ref_tab  varchartab;
    l_temp          VARCHAR2(32000);
    l_col_tab       varchartab;
    l_project_id    NUMBER;
    l_parent_obj_id NUMBER;
    l_obj_id        NUMBER;
    l_date_format   VARCHAR2(50) DEFAULT NULL;
    l_select        VARCHAR2(2400);
    i               INT := 0;
    l_sql           CLOB;
    x               INT;
    cur             SYS_REFCURSOR;
    l_no_data_found BOOLEAN := FALSE;

    PROCEDURE insert_into_log_proc (
        p_template_id IN NUMBER,
        p_data        IN CLOB
    ) IS
        PRAGMA autonomous_transaction;
    BEGIN
        INSERT INTO cr_mapping_clob (
            template_id,
            dynamic_query,
            altered,
            attribute1,
            attribute2,
            attribute3,
            attribute4,
            attribute5,
            last_updated_by,
            last_update_date,
            creation_date,
            created_by
        ) VALUES (
            p_template_id,
            p_data,
            'N',
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            'CONVRITE',
            sysdate,
            sysdate,
            'CONVRITE'
        );

        COMMIT;
    END insert_into_log_proc;

BEGIN
    SELECT
        staging_table_name,
        project_id,
        parent_object_id,
        object_id
    INTO
        l_tab_name,
        l_project_id,
        l_parent_obj_id,
        l_obj_id
    FROM
        cr_cld_template_hdrs
    WHERE
        cld_template_id = p_cld_template_id;
        ----    l_select := 'SELECT  orig_trans_id FROM '
        --                || l_tab_name
        --                || ' WHERE CR_BATCH_NAME='--                || ''''
        --                || p_batch_name--                || '''';
        ----    EXECUTE IMMEDIATE l_select
        --    BULK COLLECT--    INTO l_orig_ref_tab;
    BEGIN
        SELECT
            cloud_date_format
        INTO l_date_format
        FROM
            cr_date_configuration
        WHERE
                project_id = l_project_id
            AND parent_object_id = l_parent_obj_id
            AND object_id = l_obj_id;

    EXCEPTION
        WHEN OTHERS THEN
            l_date_format := NULL;
    END;

    IF l_date_format IS NULL THEN
        SELECT
            column_name
        BULK COLLECT
        INTO l_col_tab
        FROM
            cr_cld_template_cols
        WHERE
                cld_template_id = p_cld_template_id
            AND display_seq IS NOT NULL
        ORDER BY
            nvl(display_seq, 9999999999) ASC;

    ELSE
        SELECT
            decode(column_type, 'D', 'TO_CHAR('
                                     || column_name
                                     || ','
                                     || ''''
                                     || l_date_format
                                     || ''''
                                     || ')', column_name)
        BULK COLLECT
        INTO l_col_tab
        FROM
            cr_cld_template_cols
        WHERE
                cld_template_id = p_cld_template_id
            AND display_seq IS NOT NULL
        ORDER BY
            nvl(display_seq, 9999999999) ASC;

    END IF;

    FOR t IN l_col_tab.first..l_col_tab.last LOOP
        l_cols := l_cols
                  || ''''
                  || '"'
                  || ''''
                  || '||'
                  || l_col_tab(t)
                  || '||'
                  || ''''
                  || '"'
                  || ''''
                  || '||'
                  || ''''
                  || ','
                  || ''''
                  || '||';
    END LOOP;

            -- dbms_output.put_line(l_cols);

    l_cols := substr(l_cols, 0, length(l_cols) - 7);
    l_sql := 'SELECT  '
             || l_cols
             || ' FROM '
             || l_tab_name
             || ' WHERE '
             || 'CR_BATCH_NAME='
             || ''''
             || p_batch_name
             || '''';

    dbms_output.put_line(l_sql);
    BEGIN
        OPEN cur FOR l_sql;

        LOOP
            FETCH cur
            BULK COLLECT INTO l_clob_tab LIMIT 1000;
            EXIT WHEN l_clob_tab.count = 0;
--            l_clob_tab.extend;
            i := i + 1;
            FOR x IN 1..l_clob_tab.count LOOP
                l_clob := l_clob
                          || l_clob_tab(x)
                          || chr(10);
            END LOOP;

            COMMIT;
        END LOOP;

        IF i = 0 THEN
            l_no_data_found := TRUE;
        END IF;
        CLOSE cur;
    EXCEPTION
        WHEN OTHERS THEN
            insert_into_log_proc(p_cld_template_id, 'SELECT  '
                                                    || l_cols
                                                    || ' FROM '
                                                    || l_tab_name
                                                    || ' WHERE orig_trans_id = '
                                                    || 'q'
                                                    || ''''
                                                    || '['
                                                    || l_orig_ref_tab(i)
                                                    || ']'
                                                    || ''''
                                                    || 'and CR_BATCH_NAME='
                                                    || ''''
                                                    || p_batch_name
                                                    || '''');

            RAISE;
    END;

    IF l_no_data_found THEN
        p_clob_fbdi_file := empty_clob();
        p_result_code := 'Y';
        p_result_msg := 'No records found for the given batch name.';
        INSERT INTO cr_log_messages (
            proc_name,
            reference_key,
            log_message,
            audit_when,
            creation_date,
            last_update_date
        ) VALUES (
            'CR_FBDI_FILEGEN_PROC',
            'Cloud Template Id:' || p_cld_template_id,
            'No records found for the given batch name:' || p_batch_name,
            sysdate,
            sysdate,
            sysdate
        );

        COMMIT;
    ELSE
        p_clob_fbdi_file := l_clob;
        p_result_code := 'Y';
        p_result_msg := 'SUCCESS';
        INSERT INTO cr_log_messages (
            proc_name,
            reference_key,
            log_message,
            audit_when,
            creation_date,
            last_update_date
        ) VALUES (
            'CR_FBDI_FILEGEN_PROC',
            'Cloud Template Id:' || p_cld_template_id,
            'Successfully Generated FBDI.',
            sysdate,
            sysdate,
            sysdate
        );

        COMMIT;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        p_clob_fbdi_file := empty_clob();
        p_result_code := 'N';
        p_result_msg := 'Unexpected error in CR_FBDI_FILEGEN_PROC: ' || sqlerrm;
        INSERT INTO cr_log_messages (
            proc_name,
            reference_key,
            log_message,
            audit_when,
            creation_date,
            last_update_date
        ) VALUES (
            'CR_FBDI_FILEGEN_PROC',
            'Cloud Template Id:' || p_cld_template_id,
            'Failed to generate FBDI',
            sysdate,
            sysdate,
            sysdate
        );

        COMMIT;
        dbms_output.put_line('checkkk:' || p_result_msg);
END cr_fbdi_filegen_proc;
$#$
