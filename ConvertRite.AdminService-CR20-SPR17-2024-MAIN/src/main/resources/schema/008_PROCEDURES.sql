create or replace PROCEDURE CR_AUDIT_LOG_MSG_PROC ( 
    p_user_id            IN VARCHAR2,
    p_audit_log_proc     IN VARCHAR2,
    p_reference_key      IN VARCHAR2 DEFAULT NULL,
    p_log_message        IN VARCHAR2 DEFAULT NULL,
    p_clob_dynamic_query IN CLOB DEFAULT NULL
) IS
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN

    INSERT INTO cr_log_messages (
        user_id,
        proc_name,
        reference_key,
        log_message,
        dynamic_query,
        audit_when,
        last_updated_by,
        last_update_date,
        created_by,
        creation_date
    ) VALUES (
        p_user_id,
        p_audit_log_proc,
        p_reference_key,
        p_log_message,
        p_clob_dynamic_query,
        systimestamp,
        p_user_id,
        sysdate,
        p_user_id,
        sysdate
    );

    COMMIT;
END CR_AUDIT_LOG_MSG_PROC;
$#$

create or replace PROCEDURE cr_load_metadata_proc (
    p_calling_env VARCHAR2,
    p_file_name   VARCHAR2,
    p_user_id     VARCHAR2,
    p_object_id   NUMBER,
    p_ret_code    OUT VARCHAR2,
    p_ret_msg     OUT VARCHAR2
) IS

    lc_column_name                 VARCHAR2(100);
    lc_user_column_name            VARCHAR2(100);
    lc_column_type                 VARCHAR2(100);
    ln_width                       NUMBER;
    lc_null_allowed_flag           VARCHAR2(100);
    lc_translate_flag              VARCHAR2(100);
    lc_flexfield_usage_code        VARCHAR2(100);
    lc_description                 VARCHAR2(4000);
    lc_flexfield_name              VARCHAR2(100);
    lc_default_value               VARCHAR2(100);
    lc_precision                   VARCHAR2(100);
    lc_scale                       VARCHAR2(100);
    lc_irep_comments               VARCHAR2(100);
    ln_cnt                         NUMBER := 0;
    l_appl_id                      NUMBER;
    l_table_id                     NUMBER;
    ln_column_sequence             NUMBER;
    l_offset                       PLS_INTEGER := 1;
    l_line                         VARCHAR2(32767);
    l_total_length                 PLS_INTEGER;
    l_line_length                  PLS_INTEGER;
    l_count                        NUMBER DEFAULT 0;
    l_clob_file_content            CLOB;
    lc_proc                        VARCHAR2(2000) DEFAULT 'CR_LOAD_METADATA_PROC';
    lc_src_table_name              VARCHAR2(100);
    lc_cld_table_name              VARCHAR2(100);
    ln_cld_table_id                NUMBER;
    TYPE varchartab IS
        TABLE OF VARCHAR2(500);
    l_val_tab                      varchartab;
    lc_object_name                 VARCHAR2(100);
    lc_physical_column_name        VARCHAR2(100);
    lc_width                       VARCHAR2(100);
    lc_status                      VARCHAR2(100);
    lc_short_name                  VARCHAR2(100);
    lc_domain_code                 VARCHAR2(100);
    lc_denorm_path                 VARCHAR2(100);
    lc_routing_mode                VARCHAR2(100);
    lc_cloud_version               VARCHAR2(100);
    lc_eligible_to_be_secured      VARCHAR2(100);
    lc_security_classification     VARCHAR2(100);
    lc_sec_classification_override VARCHAR2(100);
    l_src_tbl_exist_chk            NUMBER;
    l_src_col_dup_chk_cnt          NUMBER;
    l_cld_tbl_exist_chk            NUMBER;
    l_cld_col_dup_chk_cnt          NUMBER;
BEGIN
    dbms_output.enable(1000000);
    p_ret_code := 'SUCCESS';
    p_ret_msg := 'SUCCESS';
    cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                              || p_object_id
                                              || ' ,File Name: '
                                              || p_file_name
                                              || ' ,Calling Environment: '
                                              || p_calling_env, ' START ', NULL);

    BEGIN
        SELECT
            file_content
        INTO l_clob_file_content
        FROM
            cr_file_details
        WHERE
            file_name = p_file_name;

    EXCEPTION
        WHEN OTHERS THEN
            p_ret_code := 'ERROR';
            p_ret_msg := 'Error while fetching Source Metadata file';
            cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                      || p_object_id
                                                      || ' ,File Name: '
                                                      || p_file_name
                                                      || ' ,Calling Environment: '
                                                      || p_calling_env, p_ret_msg, NULL);

            RETURN;
    END;

    dbms_output.put_line('Calling Environment:' || p_calling_env);
    IF p_calling_env = 'SOURCE' THEN
        dbms_output.put_line('Proceeding to insert data into SRC tables and Columns');
        cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                  || p_object_id
                                                  || ' ,File Name: '
                                                  || p_file_name
                                                  || ' ,Calling Environment: '
                                                  || p_calling_env, 'Proceeding to insert data into SRC tables and Columns', NULL);

        l_total_length := length(l_clob_file_content);
        dbms_output.put_line('l_total_length:' || l_total_length);
        WHILE l_offset <= l_total_length LOOP
            dbms_output.put_line('l_offset:' || l_offset);
            l_count := l_count + 1; 
            l_line_length := instr(l_clob_file_content, chr(10), l_offset) - l_offset;
            dbms_output.put_line('l_line_length:' || l_line_length);
            IF l_line_length < 0 THEN
                l_line_length := l_total_length + 1 - l_offset;
            END IF;
            l_line := substr(l_clob_file_content, l_offset, l_line_length);
            IF l_count = 1 THEN
                l_offset := l_offset + l_line_length + 1;
                CONTINUE;
            END IF;

            ln_cnt := ln_cnt + 1;
            lc_src_table_name := upper(regexp_substr(l_line, '([^,]*),|$', 1, 1, NULL,
                                                    1));

            dbms_output.put_line('lc_src_table_name: ' || lc_src_table_name);
            dbms_output.put_line('ln_cnt: ' || ln_cnt);
            IF ln_cnt = 1 THEN
                BEGIN
                    SELECT
                        COUNT(1)
                    INTO l_src_tbl_exist_chk
                    FROM
                        cr_source_tables
                    WHERE
                        table_name = lc_src_table_name;

                EXCEPTION
                    WHEN OTHERS THEN
                        l_src_tbl_exist_chk := 0;
                END;

                IF ( l_src_tbl_exist_chk > 0 ) THEN
                    p_ret_code := 'ERROR';
                    p_ret_msg := 'MetaData Table Name: '
                                 || lc_src_table_name
                                 || ' provided in the Upload file already exists. MetaData Table Name must be Unique';
                    cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                              || p_object_id
                                                              || ' ,File Name: '
                                                              || p_file_name
                                                              || ' ,Calling Environment: '
                                                              || p_calling_env, p_ret_msg, NULL);

                    EXIT;
                ELSE
                    cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                              || p_object_id
                                                              || ' ,File Name: '
                                                              || p_file_name
                                                              || ' ,Calling Environment: '
                                                              || p_calling_env, 'MetaData Table Name: '
                                                                                || lc_src_table_name
                                                                                || ' provided in the Upload file does not exists. Proceeding to create MetaData'
                                                                                , NULL);
                END IF;

                l_table_id := cr_src_table_id_s.nextval;
                dbms_output.put_line('INSERT SRC TABLE Record with Name: '
                                     || lc_src_table_name
                                     || ', Table_ID: '
                                     || l_table_id
                                     || ',Object_ID: '
                                     || p_object_id);

                BEGIN
                    INSERT INTO cr_source_tables (
                        table_id,
                        table_name,
                        user_table_name,
                        description,
                        application_id,
                        auto_size,
                        table_type,
                        initial_extent,
                        next_extent,
                        min_extents,
                        max_extents,
                        pct_increase,
                        ini_trans,
                        max_trans,
                        pct_free,
                        pct_used,
                        hosted_support_style,
                        irep_comments,
                        irep_annotations,
                        object_id,
                        attribute1,
                        attribute2,
                        attribute3,
                        attribute4,
                        attribute5,
                        last_update_date,
                        last_updated_by,
                        creation_date,
                        created_by
                    ) VALUES (
                        l_table_id,
                        lc_src_table_name,
                        lc_src_table_name,
                        NULL,
                        200,
                        'Y',
                        'T',
                        4,
                        8,
                        1,
                        50,
                        0,
                        3,
                        255,
                        5,
                        80,
                        'Local',
                        NULL,
                        NULL,
                        p_object_id,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        sysdate,
                        'CONVRITE',
                        sysdate,
                        'CONVRITE'
                    );

                    dbms_output.put_line('TableName Inserted. COUNT of Rows Inserted into SRC table:' || SQL%rowcount);
                    cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                              || p_object_id
                                                              || ' ,File Name: '
                                                              || p_file_name
                                                              || ' ,Calling Environment: '
                                                              || p_calling_env, 'TableName Inserted. COUNT of Rows Inserted into SRC table:'
                                                              || SQL%rowcount, NULL);

                EXCEPTION
                    WHEN OTHERS THEN
                        dbms_output.put_line('Exception while inserting the data into SRC tables:' || sqlerrm);
                        p_ret_code := 'ERROR';
                        p_ret_msg := 'Exception while inserting the data into SRC tables:' || sqlerrm;
                        cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                                  || p_object_id
                                                                  || ' ,File Name: '
                                                                  || p_file_name
                                                                  || ' ,Calling Environment: '
                                                                  || p_calling_env, p_ret_msg, NULL);

                        raise_application_error(-20001, substr(sqlerrm, 0, 150));
                        dbms_output.put_line('Exiting from further process');
                        EXIT;
                END;

            END IF;

            IF ln_cnt >= 1 THEN
                lc_column_name := upper(regexp_substr(l_line, '([^,]*),|$', 1, 2, NULL,
                                                     1));

                lc_user_column_name := regexp_substr(l_line, '([^,]*),|$', 1, 3, NULL,
                                                    1);
                ln_column_sequence := regexp_substr(l_line, '([^,]*),|$', 1, 4, NULL,
                                                   1) * 10;

                lc_column_type := regexp_substr(l_line, '([^,]*),|$', 1, 5, NULL,
                                               1);
                ln_width := regexp_substr(l_line, '([^,]*),|$', 1, 6, NULL,
                                         1);
                lc_null_allowed_flag := regexp_substr(l_line, '([^,]*),|$', 1, 7, NULL,
                                                     1);
                lc_translate_flag := regexp_substr(l_line, '([^,]*),|$', 1, 8, NULL,
                                                  1);
                lc_flexfield_usage_code := regexp_substr(l_line, '([^,]*),|$', 1, 9, NULL,
                                                        1);
                lc_description := regexp_substr(l_line, '([^,]*),|$', 1, 21, NULL,
                                               1);
                lc_flexfield_name := regexp_substr(l_line, '([^,]*),|$', 1, 10, NULL,
                                                  1);
                lc_default_value := regexp_substr(l_line, '([^,]*),|$', 1, 11, NULL,
                                                 1);
                lc_precision := regexp_substr(l_line, '([^,]*),|$', 1, 12, NULL,
                                             1);
                lc_scale := regexp_substr(l_line, '([^,]*),|$', 1, 13, NULL,
                                         1);
                SELECT
                    decode(regexp_substr(l_line, '(([^,"]*("[^"]*")?)*)(,|$)', 1, 14, NULL,
                                         1),
                           CHR(10),
                           NULL,
                           CHR(13),
                           NULL,
                           regexp_substr(l_line, '(([^,"]*("[^"]*")?)*)(,|$)', 1, 14, NULL,
                                         1))
                INTO lc_irep_comments
                FROM
                    dual;

                dbms_output.put_line('lc_user_column_name:' || lc_user_column_name);
                dbms_output.put_line('lc_irep_comments:' || lc_irep_comments);
                BEGIN
                    SELECT
                        COUNT(1)
                    INTO l_src_col_dup_chk_cnt
                    FROM
                        cr_source_columns
                    WHERE
                            table_id = l_table_id
                        AND column_name = lc_column_name;

                    IF l_src_col_dup_chk_cnt > 0 THEN
                        p_ret_code := 'ERROR';
                        p_ret_msg := 'Column Name: '
                                     || lc_column_name
                                     || ' is duplicate. Please check and reload the file.';
                        cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                                  || p_object_id
                                                                  || ' ,File Name: '
                                                                  || p_file_name
                                                                  || ' ,Calling Environment: '
                                                                  || p_calling_env, p_ret_msg, NULL);

                        EXIT;
                    ELSE
                        cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                                  || p_object_id
                                                                  || ' ,File Name: '
                                                                  || p_file_name
                                                                  || ' ,Calling Environment: '
                                                                  || p_calling_env, 'Proceeding to Insert Column Name: ' || lc_column_name
                                                                  , NULL);
                    END IF;

                    INSERT INTO cr_source_columns (
                        table_id,
                        column_id,
                        column_name,
                        user_column_name,
                        description,
                        application_id,
                        column_sequence,
                        column_type,
                        width,
                        null_allowed_flag,
                        translate_flag,
                        flexfield_usage_code,
                        flexfield_application_id,
                        flexfield_name,
                        flex_value_set_application_id,
                        flex_value_set_id,
                        default_value,
                        precision,
                        scale,
                        irep_comments,
                        attribute1,
                        attribute2,
                        attribute3,
                        attribute4,
                        attribute5,
                        last_update_date,
                        last_updated_by,
                        creation_date,
                        created_by
                    ) VALUES (
                        l_table_id,
                        ln_cnt,
                        lc_column_name,
                        lc_user_column_name,
                        upper(lc_description),
                        200,
                        ln_column_sequence,
                        upper(lc_column_type),
                        ln_width,
                        upper(lc_null_allowed_flag),
                        upper(lc_translate_flag),
                        lc_flexfield_usage_code,
                        NULL,
                        lc_flexfield_name,
                        NULL,
                        NULL,
                        lc_default_value,
                        lc_precision,
                        lc_scale,
                        lc_irep_comments,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        sysdate,
                        'CONVRITE',
                        sysdate,
                        'CONVRITE'
                    );

                    dbms_output.put_line('Column: '
                                         || upper(lc_column_name)
                                         || ' Inserted. COUNT of Rows Inserted into SRC Columns:'
                                         || SQL%rowcount);

                    cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                              || p_object_id
                                                              || ' ,File Name: '
                                                              || p_file_name
                                                              || ' ,Calling Environment: '
                                                              || p_calling_env, 'Column: '
                                                                                || upper(lc_column_name)
                                                                                || ' Inserted. COUNT of Rows Inserted into SRC Columns:'
                                                                                || SQL%rowcount, NULL);

                EXCEPTION
                    WHEN OTHERS THEN
                        dbms_output.put_line('Exception while inserting Column data into SRC columns:' || sqlerrm);
                        p_ret_code := 'ERROR';
                        p_ret_msg := 'Exception while inserting Column data into SRC columns:' || sqlerrm;
                        cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                                  || p_object_id
                                                                  || ' ,File Name: '
                                                                  || p_file_name
                                                                  || ' ,Calling Environment: '
                                                                  || p_calling_env, p_ret_msg, NULL);

                        raise_application_error(-20001, sqlerrm);
                        EXIT;
                END;

            END IF;

            l_offset := l_offset + l_line_length + 1;
            dbms_output.put_line('Repeat l_offset :' || l_offset);
        END LOOP;

        IF p_ret_code = 'SUCCESS' THEN
            COMMIT;
            p_ret_msg := 'Data Loaded Successfully';
            cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                      || p_object_id
                                                      || ' ,File Name: '
                                                      || p_file_name
                                                      || ' ,Calling Environment: '
                                                      || p_calling_env, 'Process Completed insert data into SRC tables and Columns. COMMITED the change'
                                                      , NULL);

        ELSE
            ROLLBACK;
            cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                      || p_object_id
                                                      || ' ,File Name: '
                                                      || p_file_name
                                                      || ' ,Calling Environment: '
                                                      || p_calling_env, 'Process ended in ERROR. ROLLBACK the change', NULL);

        END IF;

    ELSIF p_calling_env = 'CLOUD' THEN
        dbms_output.put_line('Proceeding to insert data into CLD tables and Columns');
        cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                  || p_object_id
                                                  || ' ,File Name: '
                                                  || p_file_name
                                                  || ' ,Calling Environment: '
                                                  || p_calling_env, 'Proceeding to insert data into CLD tables and Columns', NULL);

        l_total_length := length(l_clob_file_content);
        dbms_output.put_line('l_total_length:' || l_total_length);
        WHILE l_offset <= l_total_length LOOP
            dbms_output.put_line('l_offset:' || l_offset);
            l_count := l_count + 1; 
            l_line_length := instr(l_clob_file_content, chr(10), l_offset) - l_offset;
            dbms_output.put_line('l_line_length:' || l_line_length);
            IF l_line_length < 0 THEN
                l_line_length := l_total_length + 1 - l_offset;
            END IF;
            l_line := substr(l_clob_file_content, l_offset, l_line_length);
            IF l_count = 1 THEN
                l_offset := l_offset + l_line_length + 1;
                CONTINUE;
            END IF;

            ln_cnt := ln_cnt + 1;
            lc_cld_table_name := upper(regexp_substr(l_line, '([^,]*),|$', 1, 1, NULL,
                                                    1));

            dbms_output.put_line('lc_cld_table_name: ' || lc_cld_table_name);
            dbms_output.put_line('ln_cnt: ' || ln_cnt);
            IF ln_cnt = 1 THEN
                BEGIN
                    SELECT
                        COUNT(1)
                    INTO l_cld_tbl_exist_chk
                    FROM
                        cr_cloud_tables
                    WHERE
                        table_name = lc_cld_table_name;

                EXCEPTION
                    WHEN OTHERS THEN
                        l_cld_tbl_exist_chk := 0;
                END;

                IF ( l_cld_tbl_exist_chk > 0 ) THEN
                    p_ret_code := 'ERROR';
                    p_ret_msg := 'MetaData Table Name: '
                                 || lc_cld_table_name
                                 || ' provided in the Upload file already exists. MetaData Table Name must be Unique';
                    cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                              || p_object_id
                                                              || ' ,File Name: '
                                                              || p_file_name
                                                              || ' ,Calling Environment: '
                                                              || p_calling_env, p_ret_msg, NULL);

                    EXIT;
                ELSE
                    cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                              || p_object_id
                                                              || ' ,File Name: '
                                                              || p_file_name
                                                              || ' ,Calling Environment: '
                                                              || p_calling_env, 'MetaData Table Name: '
                                                                                || lc_cld_table_name
                                                                                || ' provided in the Upload file does not exists. Proceeding to create MetaData'
                                                                                , NULL);
                END IF;

                ln_cld_table_id := cr_cld_table_id_s.nextval;
                dbms_output.put_line('INSERT CLD TABLE Record with Name: '
                                     || lc_cld_table_name
                                     || ', Table_ID: '
                                     || l_table_id
                                     || ',Object_ID: '
                                     || p_object_id);

                BEGIN
                    INSERT INTO cr_cloud_tables (
                        table_id,
                        table_name,
                        physical_table_name,
                        user_table_name,
                        description,
                        application_short_name,
                        table_type,
                        object_id,
                        last_update_date,
                        last_updated_by,
                        creation_date,
                        created_by
                    ) VALUES (
                        ln_cld_table_id,
                        lc_cld_table_name,
                        lc_cld_table_name,
                        lc_cld_table_name,
                        NULL,
                        'CONVRITE',
                        'T',
                        p_object_id,
                        sysdate,
                        'CONVRITE',
                        sysdate,
                        'CONVRITE'
                    );

                    dbms_output.put_line('Cloud TableName Inserted. COUNT of Rows Inserted into CLD table:' || SQL%rowcount);
                    cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                              || p_object_id
                                                              || ' ,File Name: '
                                                              || p_file_name
                                                              || ' ,Calling Environment: '
                                                              || p_calling_env, 'Cloud TableName Inserted. COUNT of Rows Inserted into CLD table:'
                                                              || SQL%rowcount, NULL);

                EXCEPTION
                    WHEN OTHERS THEN
                        dbms_output.put_line('Exception while inserting the data into CR_CLOUD_TABLES:' || sqlerrm);
                        p_ret_code := 'ERROR';
                        p_ret_msg := 'Exception while inserting the data into CR_CLOUD_TABLES:' || sqlerrm;
                        cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                                  || p_object_id
                                                                  || ' ,File Name: '
                                                                  || p_file_name
                                                                  || ' ,Calling Environment: '
                                                                  || p_calling_env, p_ret_msg, NULL);

                        raise_application_error(-20001, substr(sqlerrm, 0, 150));
                        dbms_output.put_line('Exiting from further process');
                        EXIT;
                END;

            END IF;

            IF ln_cnt >= 1 THEN
                BEGIN
                    SELECT
                        ( asciistr(decode(token,
                                          CHR(10),
                                          NULL,
                                          CHR(13),
                                          NULL,
                                          token)) )
                    BULK COLLECT
                    INTO l_val_tab
                    FROM
                        (
                            WITH t AS (
                                SELECT
                                    l_line strval
                                FROM
                                    dual
                            )
                            SELECT
                                level ord,
                                TRIM(BOTH '"' FROM regexp_substr(t.strval, '(([^,"]*("[^"]*")?)*)(,|$)', 1, level, NULL,
                                                                 1))   AS token
                            FROM
                                t t
                            CONNECT BY
                                level <= CASE
                                             WHEN ( substr(t.strval,
                                                           length(t.strval),
                                                           length(t.strval)) ) = '' THEN
                                                 regexp_count(t.strval, '(([^,"]*("[^"]*")?)*),')
                                             ELSE
                                                 regexp_count(t.strval, '(([^,"]*("[^"]*")?)*),') + 1
                                         END
                        );

                    lc_column_name := l_val_tab(2);
                    lc_physical_column_name := l_val_tab(3);
                    lc_user_column_name := l_val_tab(4);
                    ln_column_sequence := l_val_tab(5);
                    lc_column_type := l_val_tab(6);
                    lc_width := l_val_tab(7);
                    lc_null_allowed_flag := l_val_tab(8);
                    lc_translate_flag := l_val_tab(9);
                    lc_precision := l_val_tab(10);
                    lc_scale := l_val_tab(11);
                    lc_description := l_val_tab(12);
                    lc_status := l_val_tab(13);
                    lc_short_name := l_val_tab(14);
                    lc_domain_code := l_val_tab(15);
                    lc_denorm_path := l_val_tab(16);
                    lc_routing_mode := l_val_tab(17);
                    lc_cloud_version := l_val_tab(18);
                    lc_eligible_to_be_secured := l_val_tab(19);
                    lc_security_classification := l_val_tab(20);
                    lc_sec_classification_override := l_val_tab(21);
                EXCEPTION
                    WHEN OTHERS THEN
                        dbms_output.put_line('Exception while inserting Column data into CLD columns:' || sqlerrm);
                        p_ret_code := 'ERROR';
                        p_ret_msg := 'Exception while inserting Column data into CLD columns:' || sqlerrm;
                        cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                                  || p_object_id
                                                                  || ' ,File Name: '
                                                                  || p_file_name
                                                                  || ' ,Calling Environment: '
                                                                  || p_calling_env, p_ret_msg, NULL);

                        raise_application_error(-20001, sqlerrm);
                        dbms_output.put_line('Exiting from further process');
                        EXIT;
                END;

                dbms_output.put_line('lc_user_column_name:' || lc_user_column_name);
                BEGIN
                    SELECT
                        COUNT(1)
                    INTO l_cld_col_dup_chk_cnt
                    FROM
                        cr_cloud_columns
                    WHERE
                            table_id = ln_cld_table_id
                        AND column_name = upper(lc_column_name);

                    IF l_cld_col_dup_chk_cnt > 0 THEN
                        p_ret_code := 'ERROR';
                        p_ret_msg := 'Column Name: '
                                     || upper(lc_column_name)
                                     || ' is duplicate. Please check and reload the file.';
                        cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                                  || p_object_id
                                                                  || ' ,File Name: '
                                                                  || p_file_name
                                                                  || ' ,Calling Environment: '
                                                                  || p_calling_env, p_ret_msg, NULL);

                        EXIT;
                    ELSE
                        cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                                  || p_object_id
                                                                  || ' ,File Name: '
                                                                  || p_file_name
                                                                  || ' ,Calling Environment: '
                                                                  || p_calling_env, 'Proceeding to Insert Column Name: ' || upper(lc_column_name)
                                                                  , NULL);
                    END IF;

                    INSERT INTO cr_cloud_columns (
                        column_id,
                        column_name,
                        physical_column_name,
                        user_column_name,
                        description,
                        table_id,
                        status,
                        short_name,
                        ora_edition_context,
                        column_sequence,
                        column_type,
                        width,
                        null_allowed_flag,
                        translate_flag,
                        precision,
                        scale,
                        domain_code,
                        denorm_path,
                        routing_mode,
                        cloud_version,
                        eligible_to_be_secured,
                        security_classification,
                        sec_classification_override,
                        object_id,
                        attribute1,
                        attribute2,
                        attribute3,
                        attribute4,
                        attribute5,
                        last_update_date,
                        last_updated_by,
                        creation_date,
                        created_by
                    ) VALUES (
                        ln_cnt,
                        upper(lc_column_name),
                        upper(lc_physical_column_name),
                        lc_user_column_name,                                                                                                                                                                                                    --upper(lc_description),
                        lc_description,
                        ln_cld_table_id,
                        upper(lc_status),
                        upper(lc_short_name),
                        NULL,
                        ln_column_sequence,
                        lc_column_type,
                        lc_width,
                        upper(lc_null_allowed_flag),
                        upper(lc_translate_flag),
                        lc_precision,
                        lc_scale,
                        lc_domain_code,
                        lc_denorm_path,
                        lc_routing_mode,
                        lc_cloud_version,
                        lc_eligible_to_be_secured,
                        lc_security_classification,
                        lc_sec_classification_override,
                        p_object_id,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        sysdate,
                        'CONVRITE',
                        sysdate,
                        'CONVRITE'
                    );

                    dbms_output.put_line('Column Inserted. COUNT of Rows Inserted into CLD columns table:' || SQL%rowcount);
                    cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                              || p_object_id
                                                              || ' ,File Name: '
                                                              || p_file_name
                                                              || ' ,Calling Environment: '
                                                              || p_calling_env, 'Column: '
                                                                                || upper(lc_column_name)
                                                                                || ' Inserted. COUNT of Rows Inserted into CLD Columns:'
                                                                                || SQL%rowcount, NULL);

                EXCEPTION
                    WHEN OTHERS THEN
                        dbms_output.put_line('Exception while inserting Column data into CLD columns:' || sqlerrm);
                        p_ret_code := 'ERROR';
                        p_ret_msg := 'Exception while inserting Column data into CLD columns:' || sqlerrm;
                        cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                                  || p_object_id
                                                                  || ' ,File Name: '
                                                                  || p_file_name
                                                                  || ' ,Calling Environment: '
                                                                  || p_calling_env, p_ret_msg, NULL);

                        raise_application_error(-20001, sqlerrm);
                        EXIT;
                END;

            END IF;

            l_offset := l_offset + l_line_length + 1;
            dbms_output.put_line('Repeat l_offset :' || l_offset);
        END LOOP;

        IF p_ret_code = 'SUCCESS' THEN
            COMMIT;
            p_ret_msg := 'Data Loaded Successfully';
            cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                      || p_object_id
                                                      || ' ,File Name: '
                                                      || p_file_name
                                                      || ' ,Calling Environment: '
                                                      || p_calling_env, 'Process Completed insert data into CLD tables and Columns. COMMITED the change'
                                                      , NULL);

        ELSE
            ROLLBACK;
            cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                      || p_object_id
                                                      || ' ,File Name: '
                                                      || p_file_name
                                                      || ' ,Calling Environment: '
                                                      || p_calling_env, 'Process ended in ERROR. ROLLBACK the change', NULL);

        END IF;
    ELSE
        dbms_output.put_line('Calling environment should be either SOURCE or CLOUD');
        p_ret_code := 'ERROR';
        p_ret_msg := 'Calling environment should be either SOURCE or CLOUD';
    END IF;

    cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                              || p_object_id
                                              || ' ,File Name: '
                                              || p_file_name
                                              || ' ,Calling Environment: '
                                              || p_calling_env, ' END ', NULL);

EXCEPTION
    WHEN OTHERS THEN
        p_ret_code := 'Error';
        p_ret_msg := 'Process ended in Unexpected Error: ' || sqlerrm;
        cr_audit_log_msg_proc(p_user_id, lc_proc, 'Object_ID: '
                                                  || p_object_id
                                                  || ' ,File Name: '
                                                  || p_file_name
                                                  || ' ,Calling Environment: '
                                                  || p_calling_env, p_ret_msg, NULL);

        ROLLBACK;
        dbms_output.put_line('Exception occured in the procedure CR_LOAD_METADATA_PROC:' || sqlerrm);
END cr_load_metadata_proc;
$#$

CREATE OR REPLACE PROCEDURE CR_CREATE_STG_TABLE_PROC (
    p_table_id         IN NUMBER,
    p_template_id      IN NUMBER,
    p_template_code    IN VARCHAR2,
    p_calling_env      IN VARCHAR2,
    p_user_id          IN VARCHAR2,     
    p_ret_code         OUT VARCHAR2,
    P_ret_msg          OUT VARCHAR2
) AS
    lc_src_stg_table_name  VARCHAR2(100);
    lc_cld_stg_table_name  VARCHAR2(100);
    ln_cnt         NUMBER := 0;
    lc_err_msg     VARCHAR2(4000) := NULL;
    lc_sql         VARCHAR2(1000);
    lc_proc       VARCHAR2(2000) DEFAULT 'CR_CREATE_STG_TABLE_PROC';      
    CURSOR c_src_stg_data IS
        SELECT     ' add(' || rtrim((sc.column_name
                || ' ' || CASE WHEN sc.column_type IS NULL THEN 'VARCHAR2(400)' ELSE (decode(upper(sc.column_type), 'V', 'VARCHAR2(' || nvl(sc.width,400) || ')', 'D', 'DATE',
                   'N', 'NUMBER', 'L', 'LONG', upper(sc.column_type)) ) END  || ','), ',') || ')' sql_data
          FROM cr_src_template_cols sc
         WHERE sc.SRC_TEMPLATE_ID = p_template_id
         ORDER BY display_seq ASC;
    CURSOR c_cld_stg_data IS
        SELECT  ' add(' || rtrim((cc.column_name
                || ' ' || CASE WHEN cc.column_type IS NULL THEN 'VARCHAR2(400)' ELSE (decode(upper(cc.column_type), 'V', 'VARCHAR2(' || nvl(cc.width,400) || ')', 'D', 'DATE',
                'N', 'NUMBER', 'L', 'LONG', upper(cc.column_type)) ) END || ','),     ',')|| ')' sql_data
          FROM cr_cloud_columns  cc
         WHERE cc.table_id = p_table_id
           AND cc.column_name IN ( SELECT column_name 
                                     FROM cr_cld_template_cols
                                    WHERE cld_template_id = p_template_id
                )
         ORDER BY COLUMN_SEQUENCE;         

BEGIN
    dbms_output.put_line('Procedure is called from '||p_calling_env|| ' Template WorkBench'); 
    IF (p_calling_env = 'SOURCE')
    THEN   
    
        lc_err_msg := NULL;
        
        lc_src_stg_table_name := 'CR_S_' || upper(replace(p_template_code, ' ', '_')) || '_STG' ;

        dbms_output.put_line('lc_src_stg_table_name:' || lc_src_stg_table_name); 

        SELECT COUNT(1)
          INTO ln_cnt
          FROM all_tables
         WHERE upper(table_name) = upper(lc_src_stg_table_name);


        dbms_output.put_Line('COUNT of SRC STG table exists: '|| ln_cnt);
        IF ln_cnt = 0 
        THEN
            EXECUTE IMMEDIATE 'CREATE TABLE ' || lc_src_stg_table_name
                            || '(SRC_TEMPLATE_ID NUMBER, VALIDATION_FLAG VARCHAR2(2000), ERROR_MSG VARCHAR2(4000), ORIG_TRANS_ID VARCHAR2(4000))';
            FOR rec_src_stg_data IN c_src_stg_data 
            LOOP
                lc_sql := 'ALTER TABLE ' || lc_src_stg_table_name || rec_src_stg_data.sql_data;
                             
                DBMS_OUTPUT.PUT_LINE(rec_src_stg_data.sql_data);
                EXECUTE IMMEDIATE lc_sql;
            END LOOP;

            lc_sql :=    'ALTER TABLE ' || lc_src_stg_table_name
                     || ' ADD (CR_LOAD_ID NUMBER,CR_BATCH_NAME VARCHAR2(2400))';
            EXECUTE IMMEDIATE lc_sql;
            P_ret_code := 'SUCCESS';
            P_ret_msg := 'Source STG Table successfully created: ' || lc_src_stg_table_name;
            DBMS_OUTPUT.PUT_LINE('P_ret_msg: '||P_ret_msg);
            UPDATE cr_src_template_hdrs
               SET staging_table_name = lc_src_stg_table_name,
                   last_update_date = SYSDATE
             WHERE src_template_id = p_template_id;
            DBMS_OUTPUT.PUT_LINE('Updated Stg Table name to CR_SRC_TEMPLATE_HDRS'); 
            COMMIT;
        ELSIF ln_cnt = 1 THEN
            P_ret_code := 'SUCCESS';
            P_ret_msg := 'Table already exists: ' || lc_src_stg_table_name;
            DBMS_OUTPUT.PUT_LINE('P_ret_msg: '||P_ret_msg);
        ELSE
            P_ret_code := 'ERROR';
            lc_err_msg := 'Error occured while creating the table';
            P_ret_msg := lc_err_msg;
            DBMS_OUTPUT.PUT_LINE('P_ret_msg: '||P_ret_msg);
        END IF;
    ELSIF (p_calling_env = 'CLOUD')
    THEN
    
        lc_err_msg := NULL;
        
        lc_cld_stg_table_name := 'CR_C_' || UPPER(REPLACE(p_template_code, ' ', '_')) || '_STG' ;

        dbms_output.put_line('lc_cld_stg_table_name:' || lc_cld_stg_table_name); 

        SELECT COUNT(1)
          INTO ln_cnt
          FROM all_tables
         WHERE upper(table_name) = upper(lc_cld_stg_table_name);


        dbms_output.put_Line('COUNT of CLD STG table exists: '|| ln_cnt);
        IF ln_cnt = 0 
        THEN
            EXECUTE IMMEDIATE 'CREATE TABLE ' || lc_cld_stg_table_name
                            || '(CLD_TEMPLATE_ID NUMBER ,ORIG_TRANS_ID VARCHAR2(2000) ,REC_STATUS VARCHAR2(100))';
            FOR rec_cld_stg_data IN c_cld_stg_data 
            LOOP
                lc_sql := 'ALTER TABLE ' || lc_cld_stg_table_name || rec_cld_stg_data.sql_data;
                             
                DBMS_OUTPUT.PUT_LINE(rec_cld_stg_data.sql_data);
                EXECUTE IMMEDIATE lc_sql;
            END LOOP;

            lc_sql :=    'ALTER TABLE ' || lc_cld_stg_table_name
                     || ' ADD (CR_LOAD_ID NUMBER,CR_BATCH_NAME VARCHAR2(2400))';
            EXECUTE IMMEDIATE lc_sql;
            P_ret_code := 'SUCCESS';
            P_ret_msg := 'CLD STG Table successfully created: ' || lc_cld_stg_table_name;
            DBMS_OUTPUT.PUT_LINE('P_ret_msg: '||P_ret_msg);
            
            UPDATE cr_cld_template_hdrs
               SET staging_table_name = lc_cld_stg_table_name,
                   last_update_date = SYSDATE
             WHERE cld_template_id = p_template_id;
            DBMS_OUTPUT.PUT_LINE('Updated Stg Table name to CR_CLD_TEMPLATE_HDRS'); 
            COMMIT;
            
        ELSIF ln_cnt = 1 THEN
            P_ret_code := 'SUCCESS';
            P_ret_msg := 'Table already exists: ' || lc_cld_stg_table_name;
            DBMS_OUTPUT.PUT_LINE('P_ret_msg: '||P_ret_msg);
        ELSE
            P_ret_code := 'ERROR';
            lc_err_msg := 'Error occured while creating the table';
            P_ret_msg := lc_err_msg;
            DBMS_OUTPUT.PUT_LINE('P_ret_msg: '||P_ret_msg);
        END IF;    
    ELSE
       dbms_output.put_line('Calling environment should be either SOURCE or CLOUD');
        P_ret_code := 'ERROR';
    END IF;
EXCEPTION
WHEN OTHERS 
THEN
    P_ret_code := 'ERROR';
    P_ret_msg := 'Error in CR_CREATE_STG_TABLE_PROC. Error: '||SQLERRM;
    DBMS_OUTPUT.PUT_LINE('P_ret_msg: '||P_ret_msg);
END CR_CREATE_STG_TABLE_PROC;

$#$

create or replace PROCEDURE cr_populate_orig_trans_id_proc (
    p_template_id IN NUMBER,
    p_table_name  IN VARCHAR2,
    p_user_id     IN VARCHAR2,
    p_batch_name  IN VARCHAR2,
    p_ret_code    OUT VARCHAR2,
    p_ret_msg     OUT VARCHAR2
) IS

    lc_duplicate_chk_flag                VARCHAR2(50) DEFAULT 'N';
    lc_prog                              VARCHAR2(2000) DEFAULT 'CR_POPULATE_ORIG_TRANS_ID_PROC';
    lc_unique_trans_cols_list            VARCHAR2(2000);
    lc_denorm_orig_trans_upd_sql         VARCHAR2(2500) DEFAULT 'UPDATE '
                                                        || p_table_name
                                                        || q'[ set orig_trans_id = :COLUMN_LIST]'
                                                        || ' where src_template_id = '
                                                        || p_template_id
                                                        || q'[ AND nvl(orig_trans_id,'NULL') NOT LIKE '% - %' AND CR_BATCH_NAME = ']'
                                                        || p_batch_name
                                                        || '''';
    lc_denorm_update_duplicate           VARCHAR2(5000) DEFAULT q'[UPDATE :TABLE_NAME a SET a.validation_flag = 'DUPLICATE',
                                                         a.error_msg = 'DUPLICATE DATA IDENTIFIED FOR COLUMN(S) COMBINATION : '|| ]'
                                                      || 'q'
                                                      || '''['
                                                      || q'[':COLUMN_LIST']'
                                                      || ']'''
                                                      || q'[ WHERE a.rowid NOT IN ( SELECT MIN(b.rowid)
                                                                                        FROM :TABLE_NAME b
                                                                                       WHERE b.:COLUMN_LIST = a.:COLUMN_LIST
                                                                                         AND cr_batch_name = ':P_BATCH_NAME'
                                                                                     )
                                                               AND cr_batch_name = ':P_BATCH_NAME']';
    lc_denorm_update_duplicate_first_row VARCHAR2(5000) DEFAULT q'[UPDATE :TABLE_NAME a SET a.validation_flag = 'DUPLICATE',
                                                         a.error_msg = 'DUPLICATE DATA IDENTIFIED FOR COLUMN(S) COMBINATION : '|| ]'
                                                                || 'q'
                                                                || '''['
                                                                || q'[':COLUMN_LIST']'
                                                                || ']'''
                                                                || q'[ WHERE :COLUMN_LIST  IN ( SELECT DISTINCT :COLUMN_LIST
                                                                                        FROM :TABLE_NAME b
                                                                                       WHERE B.VALIDATION_FLAG = 'DUPLICATE'
                                                                                         AND cr_batch_name = ':P_BATCH_NAME'
                                                                                     )
                                                               AND cr_batch_name = ':P_BATCH_NAME']';
    lc_norm_orig_trans_cols_list         VARCHAR2(2000);
    lc_norm_orig_trans_upd_sql           VARCHAR2(2500) DEFAULT 'UPDATE '
                                                      || p_table_name
                                                      || q'[ set orig_trans_id = cr_orig_trans_id_s.NEXTVAL :COLUMN_LIST]'
                                                      || ' where src_template_id = '
                                                      || p_template_id
                                                      || q'[ AND nvl(orig_trans_id,'NULL') NOT LIKE '% - %'  AND CR_BATCH_NAME = ']'
                                                      || p_batch_name
                                                      || '''';
BEGIN

    p_ret_code := 'SUCCESS';
    p_ret_msg := 'SUCCESS';
    BEGIN
        SELECT
            nvl(normalize_data_flag, 'N')
        INTO lc_duplicate_chk_flag
        FROM
            cr_src_template_hdrs
        WHERE
            src_template_id = p_template_id;

        SELECT
            LISTAGG(column_name, '||'
                                 || ''''
                                 || ' - '
                                 || ''''
                                 || '||') WITHIN GROUP(
            ORDER BY
                1 ASC
            )
        INTO lc_unique_trans_cols_list
        FROM
            cr_src_template_cols
        WHERE
                src_template_id = p_template_id
            AND nvl(unique_trans_ref, 'N') = 'Y';


    EXCEPTION
        WHEN OTHERS THEN
            p_ret_code := 'ERROR';
            p_ret_msg := 'Error while fetching denormalized Column List. Error: ' || sqlerrm;

            RETURN;
    END;

    IF lc_duplicate_chk_flag = 'Y' THEN
        BEGIN

            IF lc_unique_trans_cols_list IS NOT NULL THEN

                lc_denorm_orig_trans_upd_sql := replace(lc_denorm_orig_trans_upd_sql, ':COLUMN_LIST', lc_unique_trans_cols_list);
                EXECUTE IMMEDIATE lc_denorm_orig_trans_upd_sql;
                COMMIT;


                lc_denorm_update_duplicate := replace(lc_denorm_update_duplicate, ':TABLE_NAME', p_table_name);
                lc_denorm_update_duplicate := replace(lc_denorm_update_duplicate, ':P_BATCH_NAME', p_batch_name);
                lc_denorm_update_duplicate := replace(lc_denorm_update_duplicate, ':COLUMN_LIST', nvl(lc_unique_trans_cols_list, ''))
                ;
                EXECUTE IMMEDIATE lc_denorm_update_duplicate;
                COMMIT;


                lc_denorm_update_duplicate_first_row := replace(lc_denorm_update_duplicate_first_row, ':TABLE_NAME', p_table_name);
                lc_denorm_update_duplicate_first_row := replace(lc_denorm_update_duplicate_first_row, ':P_BATCH_NAME', p_batch_name);
                lc_denorm_update_duplicate_first_row := replace(lc_denorm_update_duplicate_first_row, ':COLUMN_LIST', nvl(lc_unique_trans_cols_list
                , ''));
                EXECUTE IMMEDIATE lc_denorm_update_duplicate_first_row;
                COMMIT;

            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                p_ret_code := 'ERROR';
                p_ret_msg := 'Unexpected error while proceeding with denormalized orig_trans_id population. Error: ' || sqlerrm;

        END;
    ELSE
        BEGIN

            IF lc_unique_trans_cols_list IS NOT NULL THEN
                lc_norm_orig_trans_upd_sql := replace(lc_norm_orig_trans_upd_sql, ':COLUMN_LIST', q'[||' - '|| ]' || lc_unique_trans_cols_list
                );
            END IF;

            lc_norm_orig_trans_upd_sql := replace(lc_norm_orig_trans_upd_sql, ':COLUMN_LIST', '');

            EXECUTE IMMEDIATE lc_norm_orig_trans_upd_sql;
            COMMIT;

        EXCEPTION
            WHEN OTHERS THEN
                p_ret_code := 'ERROR';
                p_ret_msg := 'Unexpected error while proceeding with normalized orig_trans_id population. Error: ' || sqlerrm;

        END;
    END IF;


EXCEPTION
    WHEN OTHERS THEN
        p_ret_code := 'ERROR';
        p_ret_msg := 'Unexpected error in CR_POPULATE_ORIG_TRANS_ID_PROC. Error: ' || sqlerrm;

END cr_populate_orig_trans_id_proc;
$#$

CREATE OR REPLACE PROCEDURE CR_LOAD_SRC_DATA_PROC (
    p_data_file_name     IN VARCHAR2,
    p_batch_name         IN VARCHAR2,
    p_template_id        IN NUMBER,
    p_template_name      IN VARCHAR2,
    p_user_id            IN VARCHAR2,
    p_ret_code          OUT VARCHAR2,
    p_ret_msg           OUT VARCHAR2
) IS
    lcl_load_data_content    CLOB;
    lc_proc VARCHAR2(2000)   DEFAULT 'CR_LOAD_SRC_DATA_PROC';
    li_offset                PLS_INTEGER := 1;
    lc_line                  VARCHAR2(32767);
    li_total_length          PLS_INTEGER ;
    li_line_length           PLS_INTEGER;
    lc_src_tbl_columns_list  VARCHAR2(15000);
    lc_insert_sql_vals       VARCHAR2(15000);
    lcl_insert_sql           CLOB DEFAULT 'INSERT INTO ';
    ln_count                 NUMBER DEFAULT 0;
    ln_error_insert_cnt      NUMBER DEFAULT 0;
    lc_metadata_tbl_name     VARCHAR2(150);
    lc_src_stg_table_name    VARCHAR2(150);
    lcl_fail_clob            CLOB;
    ln_success_insert_cnt    NUMBER DEFAULT 0;
    ln_parent_obj_id         NUMBER;
    lc_oti_ret_code          VARCHAR2(150);
    lc_oti_ret_msg           VARCHAR2(4000);

    BEGIN
        p_ret_code := 'SUCCESS';
        p_ret_msg  := 'SUCCESS';
        BEGIN
            SELECT FILE_CONTENT
              INTO lcl_load_data_content
              FROM CR_FILE_DETAILS
            WHERE file_name = p_data_file_name;
        EXCEPTION
        WHEN OTHERS
        THEN
            p_ret_code := 'ERROR' ;
            p_ret_msg := 'Error while fetching Data file. Error: '||SQLERRM;
            RETURN;
        END;

        dbms_output.put_line(' File Content fetched successfully');

        IF lcl_load_data_content IS NULL
        THEN
            dbms_output.put_line(' File Content is empty');
            p_ret_msg := 'Content in the file is EMPTY';
            RETURN;
        END IF;

        dbms_output.put_line('Fetch MetaData table and staging table details');
        BEGIN
            SELECT st.table_name,
                   sth.staging_table_name,
                   sth.parent_object_id
              INTO lc_metadata_tbl_name,
                   lc_src_stg_table_name,
                   ln_parent_obj_id
              FROM CR_SRC_TEMPLATE_HDRS sth,
                   CR_SOURCE_TABLES st
             WHERE sth.metadata_table_id = st.table_id
               AND sth.src_template_id = p_template_id;
        EXCEPTION
        WHEN OTHERS
        THEN
            p_ret_code := 'ERROR' ;
            p_ret_msg := 'Error while fetching MetaData table and staging table details. Error: '||SQLERRM;
            RETURN;
        END;
        dbms_output.put_line('Fetched MetaData Table Name: '||lc_metadata_tbl_name
                             || ' STG Table Name: '||lc_src_stg_table_name
                             || ' Project Object ID: '||ln_parent_obj_id);

        dbms_output.put_line('Fetch SOURCE TABLE Column LIST');
        BEGIN
            SELECT LISTAGG(sc.column_name, ',') WITHIN GROUP( ORDER BY sc.column_sequence ) list
              INTO lc_src_tbl_columns_list
              FROM cr_source_tables  st,
                   cr_source_columns sc
             WHERE sc.table_id = st.table_id
               AND st.table_name = lc_metadata_tbl_name;
        EXCEPTION
        WHEN OTHERS
        THEN
            p_ret_code := 'ERROR' ;
            p_ret_msg := 'Error while fetching SOURCE TABLE Column LIST. Error: '||SQLERRM;
            RETURN;
        END;
        dbms_output.put_line('Fetched SOURCE TABLE Column LIST: '||lc_src_tbl_columns_list);

        dbms_output.put_line('Preparing insert query to load Data');
        lcl_insert_sql :=   lcl_insert_sql
                         || lc_src_stg_table_name
                         || '( '
                         || lc_src_tbl_columns_list
                         || ',src_template_id,cr_batch_name,orig_trans_id) VALUES (';

        dbms_output.put_line('Part of INSERT QRY to Load Data: '||lcl_insert_sql);
        dbms_output.put_line('Begin LOOP through CLOB to load data into STG table: '||lc_src_stg_table_name);
        BEGIN
            dbms_output.put_line('Looping through CLOB data and inserting data into STG table: '||lc_src_stg_table_name);
            li_total_length := length(lcl_load_data_content);
            WHILE li_offset <= li_total_length
            LOOP
                lc_insert_sql_vals := NULL;
                ln_count := ln_count + 1;
                li_line_length := instr(lcl_load_data_content, chr(10), li_offset) - li_offset;

                IF li_line_length < 0
                THEN
                   li_line_length := li_total_length + 1 - li_offset;
                END IF;

                lc_line := substr(lcl_load_data_content, li_offset, li_line_length);
                dbms_output.put_line('Inside Loop Count: '||ln_count);
                IF ln_count = 1
                THEN
                    lcl_fail_clob := 'FAIL_REASON,' || lc_line ||chr(10);
                    li_offset := li_offset + li_line_length + 1;
                    CONTINUE;
                END IF;
                dbms_output.put_line('Preparing LISTTAGG of Column values for INSERT');
                SELECT LISTAGG('q' || '''' || '['
                        || asciistr(decode(token, CHR(10), NULL, CHR(13), NULL, token)) || ']'
                        || '''', ',') WITHIN GROUP( ORDER BY ord ASC )
                  INTO lc_insert_sql_vals
                  FROM (   WITH t AS
                         ( SELECT lc_line strval
                             FROM dual )
                         SELECT level ord,
                                TRIM(BOTH '"' FROM regexp_substr(t.strval, '(([^,"]*("[^"]*")?)*)(,|$)', 1, level, NULL, 1)) AS token
                           FROM t t
                        CONNECT BY level <= CASE WHEN ( substr(t.strval, length(t.strval), length(t.strval)) ) = ','
                                                 THEN regexp_count(t.strval, '(([^,"]*("[^"]*")?)*)(,|$)')
                                                 ELSE regexp_count(t.strval, '(([^,"]*("[^"]*")?)*)(,|$)') - 1
                                                 END
                        );


                lc_insert_sql_vals := replace(lc_insert_sql_vals, chr(10), NULL);
                lc_insert_sql_vals := replace(lc_insert_sql_vals, chr(13), NULL);

                dbms_output.put_line('Completed LISTTAGG of Column values for INSERT');

                IF lc_insert_sql_vals IS NOT NULL
                THEN
                    BEGIN
                        dbms_output.put_line('Proceeding to Insert for count of Line: '||ln_count);
                        EXECUTE IMMEDIATE lcl_insert_sql
                                      || lc_insert_sql_vals
                                      || ','
                                      || P_template_id
                                      || ','
                                      ||''''
                                      || p_batch_name
                                      ||''''
                                      || ','
                                      || cr_orig_trans_id_s.nextval
                                      || ')';

                        ln_success_insert_cnt := ln_success_insert_cnt + 1;
                    EXCEPTION
                    WHEN OTHERS
                    THEN
                        dbms_output.put_line('Error while inserting. Adding up the Error line to lcl_fail_clob');
                        lcl_fail_clob := lcl_fail_clob
                                       || substr(sqlerrm, 0, 2000)
                                       || ','
                                       || lc_line
                                       ||chr(10);
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
                            lcl_insert_sql
                            || lc_insert_sql_vals
                            || ','
                            || p_template_id
                            || ','
                            || p_batch_name
                            || ','
                            || cr_orig_trans_id_s.NEXTVAL
                            || ')',
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
                        dbms_output.put_line('Inserted into cr_mapping_clob');
                        ln_error_insert_cnt := ln_error_insert_cnt + 1;
                        COMMIT;
                    END;
                END IF;

                li_offset := li_offset + li_line_length + 1;
            END LOOP;

            COMMIT;
        EXCEPTION
        WHEN OTHERS
        THEN
            p_ret_code := 'ERROR' ;
            p_ret_msg := 'ERROR while Looping through CLOB data and inserting data into STG table. Error: '||SQLERRM;
            dbms_output.put_line('ERROR while Looping through CLOB data and inserting data into STG table. Error: '||SQLERRM );
        END;
        dbms_output.put_line('END of LOOP through CLOB to load data into STG table: '||lc_src_stg_table_name);
        BEGIN
            dbms_output.put_line('CR_POPULATE_ORIG_TRANS_ID_PROC procedure call to populate orig_trans_id');
            CR_POPULATE_ORIG_TRANS_ID_PROC (
                    p_template_id  => p_template_id,
                    p_table_name   => lc_src_stg_table_name,
                    p_user_id      => p_user_id,
                    p_batch_name   => p_batch_name,
                    p_ret_code     => lc_oti_ret_code,
                    p_ret_msg      => lc_oti_ret_msg
                    );
            IF lc_oti_ret_code <> 'SUCCESS'
            THEN
               dbms_output.put_line('CR_POPULATE_ORIG_TRANS_ID_PROC completed in Error. Error Message: '||lc_oti_ret_msg);
            ELSE
               dbms_output.put_line('CR_POPULATE_ORIG_TRANS_ID_PROC completed Successfully');
            END IF;
        EXCEPTION
        WHEN OTHERS
        THEN
            p_ret_code := 'ERROR' ;
            p_ret_msg := 'ERROR while Calling CR_POPULATE_ORIG_TRANS_ID_PROC to populate orig_trans_id. Error: '||SQLERRM;
            dbms_output.put_line('ERROR while Calling CR_POPULATE_ORIG_TRANS_ID_PROC to populate orig_trans_id. Error: '||SQLERRM );
        END;

        IF ln_error_insert_cnt <> 0
        THEN
            p_ret_msg := 'Data Load Completed with ' || ln_error_insert_cnt || ' Errors';
            p_ret_code := 'WARNING';

            INSERT INTO CR_SRC_LOADDATA_FAIL_RECORDS
            (
               src_template_id,
               file_name,
               failed_clob,
               success_count,
               failed_count,
               created_by,
               creation_date
            ) VALUES (
               p_template_id,
               p_data_file_name,
               lcl_fail_clob,
               ln_success_insert_cnt,
               ln_error_insert_cnt,
               'CONVRITE',
               sysdate
            );
            COMMIT;
            dbms_output.put_line('Inserted failed records into CR_SRC_LOADDATA_FAIL_RECORDS');
        END IF;

    EXCEPTION
    WHEN OTHERS
    THEN
        p_ret_code := 'ERROR';
        p_ret_msg  := 'Unexpected error in CR_LOAD_SRC_DATA_PROC. Error: '||SQLERRM;
        dbms_output.put_line('Error :'||p_ret_msg);
    END CR_LOAD_SRC_DATA_PROC;
$#$

CREATE OR REPLACE PROCEDURE CR_SRC_COLS_MODIFY_PROC (
    P_TEMPLATE_ID           IN  NUMBER ,
    P_COLUMN_NAME           IN  VARCHAR2,
    P_COLUMN_TYPE           IN  VARCHAR2,
    P_OPERATION_TYPE        IN  VARCHAR2,
    P_DISPLAY_SEQ           IN  NUMBER,
    p_user_id               IN  VARCHAR2,
    P_RET_MSG               OUT VARCHAR2,
    P_RET_CODE              OUT VARCHAR2
) IS
    ln_metadata_tbl_id           NUMBER;
    lc_staging_table_name        VARCHAR2(420);
    ln_src_column_id             NUMBER;
    lc_src_template_code             VARCHAR2(420);
    lc_bkp_stg_table_name        VARCHAR2(420);
    lc_recreate_result           VARCHAR2(420);
    lc_out_recreate_stg_tbl      VARCHAR2(420);
    lc_template_cols_insrt_qry   VARCHAR2(4000) DEFAULT q'[INSERT INTO cr_src_template_cols (SRC_TEMPLATE_ID,COLUMN_NAME,COLUMN_TYPE,WIDTH,DISPLAY_SEQ,SELECTED,CREATION_DATE,CREATED_BY,LAST_UPDATE_DATE,LAST_UPDATED_BY) values ( :SRC_TEMPLATE_ID ,':COLUMN_NAME',':COLUMN_TYPE',200,:DISPLAY_SEQ ,'Y',SYSDATE,'CONVRITE',SYSDATE,'CONVRITE')]';
    lc_metadata_cols_insrt_qry   VARCHAR2(4000) DEFAULT q'[INSERT INTO cr_source_columns values(:TABLE_ID ,:ln_src_column_id ,':COLUMN_NAME',':COLUMN_NAME','','2000',:COLUMN_SEQUENCE ,':COLUMN_TYPE',DECODE(':COLUMN_TYPE','V','2000','D','','N',''),'N','N','N','','','','','','','','','','','','','',SYSDATE,'CONVRITE',SYSDATE,'CONVRITE' )]';
    lcl_clob                     CLOB;
BEGIN
    P_RET_MSG := 'SUCCESS';
    P_RET_CODE :='Y';
    BEGIN
       SELECT metadata_table_id, nvl(staging_table_name, 'N'),src_template_code
         INTO ln_metadata_tbl_id, lc_staging_table_name, lc_src_template_code
         FROM cr_src_template_hdrs
        WHERE src_template_id = p_template_id;

        DBMS_OUTPUT.put_line('STG Table Name: '||lc_staging_table_name);
        DBMS_OUTPUT.put_line('MetaDate Table ID: '||ln_metadata_tbl_id);
    EXCEPTION
    WHEN OTHERS THEN
       P_RET_CODE := 'ERROR';
       P_RET_MSG := 'Failed while fetching Metadata Table ID for the given SRC template ID: '||P_TEMPLATE_ID ||' Error: '||SQLERRM;
       RETURN;
    END;

    DBMS_OUTPUT.put_line('P_OPERATION_TYPE: '||P_OPERATION_TYPE);

    IF P_OPERATION_TYPE = 'INSERT'
    THEN
        BEGIN
            SELECT MAX(column_id) + 1
              INTO ln_src_column_id
              FROM cr_source_columns
             WHERE table_id = ln_metadata_tbl_id;

            DBMS_OUTPUT.put_line('Column ID to be inserted: '||ln_src_column_id);
            DBMS_OUTPUT.put_line('Preparing Template Columns insert qry');

            lc_template_cols_insrt_qry := REPLACE(lc_template_cols_insrt_qry,':COLUMN_NAME',P_COLUMN_NAME);
            lc_template_cols_insrt_qry := REPLACE(lc_template_cols_insrt_qry,':SRC_TEMPLATE_ID',P_TEMPLATE_ID);
            lc_template_cols_insrt_qry := REPLACE(lc_template_cols_insrt_qry,':COLUMN_TYPE',P_COLUMN_TYPE);
            lc_template_cols_insrt_qry := REPLACE(lc_template_cols_insrt_qry,':DISPLAY_SEQ',P_DISPLAY_SEQ);

            DBMS_OUTPUT.PUT_LINE('lc_template_cols_insrt_qry: '||lc_template_cols_insrt_qry);
            DBMS_OUTPUT.put_line('Preparing Source Columns insert qry');

            lc_metadata_cols_insrt_qry := REPLACE (lc_metadata_cols_insrt_qry,':TABLE_ID',ln_metadata_tbl_id);
            lc_metadata_cols_insrt_qry := REPLACE (lc_metadata_cols_insrt_qry,':ln_src_column_id',ln_src_column_id);
            lc_metadata_cols_insrt_qry := REPLACE (lc_metadata_cols_insrt_qry,':COLUMN_NAME',P_COLUMN_NAME);
            lc_metadata_cols_insrt_qry := REPLACE (lc_metadata_cols_insrt_qry,':COLUMN_TYPE',P_COLUMN_TYPE);
            lc_metadata_cols_insrt_qry := REPLACE (lc_metadata_cols_insrt_qry,':COLUMN_SEQUENCE',P_DISPLAY_SEQ);

            DBMS_OUTPUT.PUT_LINE('lc_metadata_cols_insrt_qry: '|| lc_metadata_cols_insrt_qry);
        EXCEPTION
        WHEN OTHERS THEN
            P_RET_CODE := 'ERROR';
            P_RET_MSG := 'Error While Preparing Template Columns insert qry. Error: '||SQLERRM;
            RETURN;
        END;

        BEGIN
            EXECUTE IMMEDIATE lc_template_cols_insrt_qry;
            DBMS_OUTPUT.PUT_LINE('Execute lc_template_cols_insrt_qry completed successfully');

            EXECUTE IMMEDIATE lc_metadata_cols_insrt_qry;
            DBMS_OUTPUT.PUT_LINE('Execute lc_metadata_cols_insrt_qry completed successfully');

            COMMIT;
        EXCEPTION
        WHEN OTHERS THEN
            P_RET_CODE := 'ERROR';
            P_RET_MSG := 'Error While executing Dynamic Columns insert qry. Error: '||SQLERRM;
            RETURN;
        END;
      IF  lc_staging_table_name NOT LIKE 'N'
      THEN
       DBMS_OUTPUT.put_line('STG Table already exists. Rename existing STG table for baack up of existing data, Create stg Table with new structure, move data from backup table, drop backup table');
       DBMS_OUTPUT.put_line('Existing STG table name: '||lc_staging_table_name );

       lc_bkp_stg_table_name:= lc_staging_table_name||'_CR2';
       DBMS_OUTPUT.put_line('STEP 1: Rename existing STG table name. Table Name ALTER to: '||lc_bkp_stg_table_name);
       EXECUTE IMMEDIATE 'ALTER TABLE '|| lc_staging_table_name ||' RENAME TO ' || lc_bkp_stg_table_name;
       DBMS_OUTPUT.put_line('Table Renamed with dynamic statement.');

       BEGIN
           DBMS_OUTPUT.put_line('STEP 2: Recreate the STG table with new structure by calling CR_CREATE_SRC_STG_TAB_PROC');

         CR_CREATE_STG_TABLE_PROC (

    p_table_id        =>ln_metadata_tbl_id,
    p_template_id      =>P_TEMPLATE_ID,
    p_template_code    =>lc_src_template_code,
    p_calling_env    =>'SOURCE',
    p_user_id         => p_user_id,
    p_ret_code         =>lc_recreate_result,
    P_ret_msg        =>lc_out_recreate_stg_tbl
) ;
           DBMS_OUTPUT.put_line('Recreated STG table. lc_out_recreate_stg_tbl: '|| lc_out_recreate_stg_tbl);

        EXCEPTION
        WHEN OTHERS THEN
            P_RET_CODE := 'ERROR';
            P_RET_MSG := 'Error While recreating the stg table. Error: '||SQLERRM;
            RETURN;
        END;

        BEGIN
            DBMS_OUTPUT.put_line('STEP 3: Move the data FROM '||lc_bkp_stg_table_name||' TO '||lc_staging_table_name);

            SELECT LISTAGG(a.column_name, ',') WITHIN GROUP( ORDER BY a.column_id ) list
              INTO lcl_clob
              FROM all_tab_columns a
             WHERE table_name = lc_bkp_stg_table_name;

            DBMS_OUTPUT.put_line('Column List Prepared. Proceed to move data');
            EXECUTE IMMEDIATE 'INSERT INTO '|| lc_staging_table_name ||' ( '
                   ||lcl_clob || ' ) (SELECT ' ||lcl_clob ||' FROM '||lc_bkp_stg_table_name||' ) ';
            COMMIT;
            DBMS_OUTPUT.put_line('Restored Data. COMMIT SUCCESSFUL');
        EXCEPTION
        WHEN OTHERS THEN
            P_RET_CODE := 'ERROR';
            P_RET_MSG := 'Error While Moving the data from backup table. Error: '||SQLERRM;
            RETURN;
        END;

        BEGIN
            DBMS_OUTPUT.put_line('STEP 4: Drop Backup Table with name: '||lc_bkp_stg_table_name);

            EXECUTE IMMEDIATE 'DROP TABLE '||lc_bkp_stg_table_name;

            DBMS_OUTPUT.put_line('Table Dropped');

        EXCEPTION
        WHEN OTHERS THEN
            P_RET_CODE := 'ERROR';
            P_RET_MSG := 'Error While dropping bkp table. Error: '||SQLERRM;
            RETURN;
        END;

      END IF;
    ELSIF P_OPERATION_TYPE = 'DELETE'
    THEN
        BEGIN
           EXECUTE IMMEDIATE ' DELETE FROM cr_src_template_cols WHERE COLUMN_NAME =  '||''''||P_COLUMN_NAME||''''|| ' AND SRC_TEMPLATE_ID = '||P_TEMPLATE_ID ;
           DBMS_OUTPUT.PUT_LINE('successfully deleted Column from cr_src_template_cols');

           EXECUTE IMMEDIATE 'DELETE FROM cr_source_columns WHERE COLUMN_NAME =  '||''''||P_COLUMN_NAME ||'''' ||' AND TABLE_ID = '||ln_metadata_tbl_id;
           DBMS_OUTPUT.PUT_LINE('successfully deleted Column from cr_source_columns');

           EXECUTE IMMEDIATE 'ALTER TABLE '||lc_staging_table_name|| ' DROP COLUMN '||P_COLUMN_NAME  ;
           DBMS_OUTPUT.PUT_LINE('successfully deleted Column from '||lc_staging_table_name);

           COMMIT;
        EXCEPTION
        WHEN OTHERS THEN
            P_RET_CODE := 'ERROR';
            P_RET_MSG := 'Error While executing Dynamic Columns delete qry. Error: '||SQLERRM;
            ROLLBACK;
            RETURN;
        END;
    END IF;


EXCEPTION
WHEN OTHERS THEN
    P_RET_CODE := 'ERROR';
    P_RET_MSG := 'Unexpected Error in CR_SRC_COLS_MODIFY_PROC. Error: '||SQLERRM;
END CR_SRC_COLS_MODIFY_PROC;
$#$

CREATE OR REPLACE PROCEDURE CR_CLD_TRANSFORM_ASYNC_PROC (
    p_cloud_template_name IN VARCHAR2,
    p_user_id             IN VARCHAR2,
    p_reprocess_flag      IN VARCHAR2 DEFAULT 'N',
    p_batch_flag          IN VARCHAR2 DEFAULT 'Y',
    p_batch_name          IN VARCHAR2,
    p_request_id          OUT NOCOPY NUMBER,
    p_ret_code            OUT NOCOPY VARCHAR2,
    p_ret_msg             OUT NOCOPY VARCHAR2
) IS
    TYPE numtab IS TABLE OF NUMBER;
    CURSOR get_thread_limts ( p_tot_count    IN NUMBER, p_thread_limit IN NUMBER )
    IS
        WITH t1 AS ( SELECT p_tot_count    trec,
                            p_thread_limit tlimit
                       FROM dual )
        SELECT a.threadid,
               a.weightage,
               ( t.tlimit * ( a.threadid - 1 ) ) + 1 rec_start,
               CASE
                  WHEN t.tlimit * a.threadid > t.trec  THEN t.trec
                  ELSE t.tlimit * a.threadid
               END rec_end
          FROM ( SELECT COUNT(*) weightage,
                        grp      threadid
                   FROM ( WITH input AS ( SELECT 100 p_number, ceil(t.trec / t.tlimit) p_buckets
                                            FROM dual, t1 t ),
                                data AS ( SELECT level id, ( p_number / p_buckets ) group_size
                                            FROM input
                                         CONNECT BY level <= p_number )
                        SELECT id,
                               ceil(ROW_NUMBER() OVER( ORDER BY id ) / group_size) grp
                          FROM data
                        )
                  GROUP BY grp
                  ORDER BY grp
                )  a,
               t1 t;

    l_cloud_template_id    NUMBER;
    l_source_template_id   NUMBER;
    l_source_template_name VARCHAR2(250);
    l_cloud_table_name     VARCHAR2(150);
    l_source_table_name    VARCHAR2(150);
    l_source_record_count  NUMBER;
    l_thread_rec_limit     NUMBER;
    l_request_id           NUMBER;
    l_pod_id               NUMBER;
    l_status_flag          VARCHAR2(1);
    l_status_flag_query    VARCHAR2(2000)  ;
    l_record_count_sql     VARCHAR2(500) := 'SELECT COUNT(*) FROM :TABLE_NAME ';
    l_job_sql              VARCHAR2(5000) DEFAULT q'[ BEGIN  CR_CLD_TRANSFORM_MAIN_PROC
                                                                        (p_request_id          => :REQUEST_ID
                                                                        ,p_job_id              => :JOB_ID
                                                                        ,p_cloud_template_name => ':CLOUD_TEMPLATE_NAME'
                                                                        ,p_cloud_template_id   => :CLOUD_TEMPLATE_ID
                                                                        ,p_source_template_id  => :SOURCE_TEMPLATE_ID
                                                                        ,p_reprocess_flag      => ':L_REPROCESS_FLAG'
                                                                        ,p_source_table_name   => ':SOURCE_TABLE_NAME'
                                                                        ,p_cloud_table_name    => ':CLOUD_TABLE_NAME'
                                                                        ,p_start_rownum        => :INIT_ROWNUM
                                                                        ,p_end_rownum          => :FINAL_ROWNUM
                                                                        ,p_batch_flag          => ':BATCH_FLAG'
                                                                        ,p_batch_name          => ':BATCH_NAME');
                                                      END; ]';
    l_min_job_sql          VARCHAR2(5000);
    l_thread_id_tab        numtab;
    l_thread_weightage_tab numtab;
    l_rec_start_tab        numtab;
    l_rec_end_tab          numtab;
    lc_proc                VARCHAR2(2000) DEFAULT 'CR_CLD_TRANSFORM_ASYNC_PROC';
    lc_location            VARCHAR2(40);

   FUNCTION is_similar_request_running (
        p_cld_table_name IN VARCHAR2
    ) RETURN BOOLEAN IS
        l_val VARCHAR2(10);
    BEGIN
        SELECT
            'Y'
        INTO l_val
        FROM
            cr_cld_template_hdrs    cld_head,
            cr_process_requests requests
        WHERE
                requests.request_id = 'I'
            AND cld_head.cld_template_id = requests.cld_template_id
            AND cld_head.staging_table_name = p_cld_table_name;

        RETURN true;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN false;
    END is_similar_request_running;

BEGIN
    lc_location := 'CLD_TRANSFORM_001';
    p_ret_code  := 'SUCCESS';
    p_request_id := 0;

    SELECT cld_hdrs.cld_template_id        cloud_template_id,
           cld_hdrs.staging_table_name     cloud_table_name,
           src_hdrs.src_template_id        source_template_id,
           src_hdrs.staging_table_name     source_table_name
      INTO l_cloud_template_id,
           l_cloud_table_name,
           l_source_template_id,
           l_source_table_name
      FROM cr_cld_template_hdrs cld_hdrs,
           cr_src_template_hdrs src_hdrs
     WHERE cld_hdrs.cld_template_name = p_cloud_template_name
       AND cld_hdrs.src_template_id = src_hdrs.src_template_id;
        INSERT INTO CR_LOG_MESSAGES (PROC_NAME ,REFERENCE_KEY,Log_message,DYNAMIC_QUERY,USER_ID,CREATION_DATE,CREATED_BY)
                         VALUES ('CR_CLD_TRANSFORM_ASYNC_PROC','p_cloud_template_name: '||p_cloud_template_name,'Fetched CLoud Details',NULL,NULL,SYSDATE,NULL);
        COMMIT;
    IF is_similar_request_running(l_cloud_table_name)
    THEN
        lc_location := 'CLD_TRANSFORM_0010';
        p_request_id := -1;
        p_ret_code  := 'ERROR';
        p_ret_msg := 'Location: '||lc_location||', ERROR: Another Conversion is Running. Please submit request after it completes';
        INSERT INTO CR_LOG_MESSAGES (PROC_NAME ,REFERENCE_KEY,Log_message,DYNAMIC_QUERY,USER_ID,CREATION_DATE,CREATED_BY)
                         VALUES ('CR_CLD_TRANSFORM_ASYNC_PROC','p_cloud_template_name: '||p_cloud_template_name,p_ret_msg,NULL,NULL,SYSDATE,NULL);
        COMMIT;
        RETURN;
    END IF;


    l_record_count_sql := replace(l_record_count_sql, ':TABLE_NAME', l_source_table_name);
    IF nvl(p_reprocess_flag, 'N') <> 'N'
    THEN
        lc_location := 'CLD_TRANSFORM_0020';
        l_record_count_sql := l_record_count_sql
                                  || ' WHERE nvl(validation_flag,'
                                  || ''''
                                  || 'VF'
                                  || ''''
                                  || ') = '
                                  || ''''
                                  || 'VF'
                                  || ''''
                                  || ' AND CR_BATCH_NAME ='
                                  || ''''
                                  || p_batch_name
                                  || '''';
    ELSE
        lc_location := 'CLD_TRANSFORM_030';
        l_record_count_sql := l_record_count_sql
                                  || ' WHERE nvl(CR_BATCH_NAME,'
                                  || ''''
                                  || 'XXX'
                                  || ''''
                                  || ') = '
                                  || ''''
                                  || p_batch_name
                                  || '''';
    END IF;


    lc_location := 'CLD_TRANSFORM_040';
        INSERT INTO CR_LOG_MESSAGES (PROC_NAME ,REFERENCE_KEY,Log_message,DYNAMIC_QUERY,USER_ID,CREATION_DATE,CREATED_BY)
                         VALUES ('CR_CLD_TRANSFORM_ASYNC_PROC','p_cloud_template_name: '||p_cloud_template_name,l_record_count_sql,NULL,NULL,SYSDATE,NULL);
        COMMIT;
    EXECUTE IMMEDIATE l_record_count_sql
       INTO l_source_record_count;

    SELECT 9999999999
      INTO l_thread_rec_limit
      FROM dual;

    lc_location := 'CLD_TRANSFORM_040.5';
    l_request_id := cr_transform_req_id_s.nextval;
    l_job_sql := replace(l_job_sql, ':REQUEST_ID', l_request_id);
    l_job_sql := replace(l_job_sql, ':CLOUD_TEMPLATE_NAME', p_cloud_template_name);
    l_job_sql := replace(l_job_sql, ':CLOUD_TEMPLATE_ID', l_cloud_template_id);
    l_job_sql := replace(l_job_sql, ':SOURCE_TEMPLATE_ID', l_source_template_id);
    l_job_sql := replace(l_job_sql, ':SOURCE_TABLE_NAME', l_source_table_name);
    l_job_sql := replace(l_job_sql, ':CLOUD_TABLE_NAME', l_cloud_table_name);
    l_job_sql := replace(l_job_sql, ':L_REPROCESS_FLAG', nvl(p_reprocess_flag, 'N'));
    l_job_sql := replace(l_job_sql, ':BATCH_FLAG', nvl(p_batch_flag, 'N'));
    l_job_sql := replace(l_job_sql, ':BATCH_NAME', nvl(p_batch_name, 'XXX'));
    lc_location := 'CLD_TRANSFORM_050';
    INSERT INTO CR_PROCESS_REQUESTS (
            request_id,
            request_type,
            CLD_TEMPLATE_ID,
            CR_BATCH_NAME,
            STATUS,
            total_records,
            completed_percentage,
            start_date,
            user_id,
            creation_date,
            created_by
        ) VALUES (
            l_request_id,
            'VALIDATION',
            l_cloud_template_id,
            p_batch_name,
            'I',
            l_source_record_count,
            0,
            sysdate,
            p_user_id,
            sysdate,
            'CONVRITE'
        );

    l_status_flag_query := replace(l_status_flag_query,':TEMPLATE_ID',l_cloud_template_id);
    l_status_flag_query := replace(l_status_flag_query,':BATCH_NAME',p_batch_name);

    l_min_job_sql := l_job_sql;
    IF l_source_record_count < l_thread_rec_limit
    THEN
        lc_location := 'CLD_TRANSFORM_060';

        l_job_sql := replace(l_job_sql, ':JOB_ID', 1);
        l_job_sql := replace(l_job_sql, ':INIT_ROWNUM', 1);
        l_job_sql := replace(l_job_sql, ':FINAL_ROWNUM', l_source_record_count);

        dbms_scheduler.create_job(job_name => 'VALIDATION_'
                                            || l_cloud_template_id
                                            || '_'
                                            || l_pod_id
                                            || '_'
                                            || l_request_id,
                                  job_type => 'PLSQL_BLOCK',
                                  job_action => l_job_sql,
                                  enabled => true,
                                  auto_drop => true,
                                  comments => 'Validation of ' || p_cloud_template_name);

        INSERT INTO CR_LOG_MESSAGES (PROC_NAME ,REFERENCE_KEY,Log_message,DYNAMIC_QUERY,USER_ID,CREATION_DATE,CREATED_BY)
                         VALUES ('CR_CLD_TRANSFORM_ASYNC_PROC','p_cloud_template_name: '||p_cloud_template_name,NULL,l_job_sql,NULL,SYSDATE,NULL);
        COMMIT;
        INSERT INTO CR_PROCESS_JOBS (
                request_id,
                job_id,
                job_name,
                job_status,
                weightage,
                CR_BATCH_NAME,
                creation_date,
                created_by
            ) VALUES (
                l_request_id,
                1,
                'Validation of '
                || p_cloud_template_name
                || ' '
                || l_request_id,
                'I',
                100,
                p_batch_name,
                sysdate,
                'CONVRITE'
            );

    ELSE

       lc_location := 'CLD_TRANSFORM_070';
        OPEN get_thread_limts(l_source_record_count, l_thread_rec_limit);
       FETCH get_thread_limts
        BULK
     COLLECT INTO l_thread_id_tab,
                   l_thread_weightage_tab,
                   l_rec_start_tab,
                   l_rec_end_tab;
       CLOSE get_thread_limts;

        IF l_thread_id_tab.count > 0
        THEN
            FOR i IN l_thread_id_tab.first..l_thread_id_tab.last
            LOOP
                lc_location := 'CLD_TRANSFORM_080';
                l_job_sql := l_min_job_sql;
                l_job_sql := replace(l_job_sql, ':JOB_ID', l_thread_id_tab(i));
                l_job_sql := replace(l_job_sql, ':INIT_ROWNUM', l_rec_start_tab(i));
                l_job_sql := replace(l_job_sql, ':FINAL_ROWNUM', l_rec_end_tab(i));

                IF l_status_flag = 'Y'
                THEN
                    dbms_scheduler.create_job(job_name => 'VALIDATION_'
                                                          || l_cloud_template_id
                                                          || '_'
                                                          || l_request_id
                                                          || '_'
                                                          || l_thread_id_tab(i), job_type => 'PLSQL_BLOCK', job_action => l_job_sql, enabled => true
                                                          , auto_drop => true, comments => 'Validation of ' || p_cloud_template_name);
                END IF;

                INSERT INTO CR_PROCESS_JOBS (
                        request_id,
                        job_id,
                        job_name,
                        job_status,
                        weightage,
                        CR_BATCH_NAME,
                        creation_date,
                        created_by
                    ) VALUES (
                        l_request_id,
                        l_thread_id_tab(i),
                        'Validation of '
                        || p_cloud_template_name
                        || ' '
                        || l_request_id
                        || ' '
                        || l_thread_id_tab(i),
                        'I',
                        l_thread_weightage_tab(i),
                        p_batch_name,
                        sysdate,
                        'CONVRITE'
                    );

            END LOOP;
        END IF;

    END IF;

    COMMIT;
    p_request_id := l_request_id;
    p_ret_msg := 'REQUEST SUBMITTED SUCCESSFULLY';
        INSERT INTO CR_LOG_MESSAGES (PROC_NAME ,REFERENCE_KEY,Log_message,DYNAMIC_QUERY,USER_ID,CREATION_DATE,CREATED_BY)
                         VALUES ('CR_CLD_TRANSFORM_ASYNC_PROC','p_cloud_template_name: '||p_cloud_template_name||', p_request_id:'||p_request_id,
                         'REQUEST SUBMITTED SUCCESSFULLY',NULL,NULL,SYSDATE,NULL);
        COMMIT;
EXCEPTION
WHEN OTHERS
THEN
    p_request_id := -1;
    p_ret_code  := 'ERROR';
    p_ret_msg := 'Location: '||lc_location||', Unexpected Error in CR_CLD_TRANSFORM_ASYNC_PROC: '||SQLERRM;
        INSERT INTO CR_LOG_MESSAGES (PROC_NAME ,REFERENCE_KEY,Log_message,DYNAMIC_QUERY,USER_ID,CREATION_DATE,CREATED_BY)
                         VALUES ('CR_CLD_TRANSFORM_ASYNC_PROC','p_cloud_template_name: '||p_cloud_template_name||', p_request_id:'||p_request_id,
                         p_ret_msg,NULL,NULL,SYSDATE,NULL);
        COMMIT;
END CR_CLD_TRANSFORM_ASYNC_PROC;
$#$

create or replace PROCEDURE CR_CLD_TRANSFORM_MAIN_PROC (
    p_request_id          IN NUMBER,
    p_job_id              IN NUMBER,
    p_cloud_template_name IN VARCHAR2,
    p_cloud_template_id   IN NUMBER,
    p_source_template_id  IN NUMBER,
    p_source_table_name   IN VARCHAR2,
    p_cloud_table_name    IN VARCHAR2,
    p_reprocess_flag      IN VARCHAR2 DEFAULT 'N',
    p_start_rownum        IN NUMBER,
    p_end_rownum          IN NUMBER,
    p_batch_flag          IN VARCHAR2 DEFAULT 'Y',
    p_batch_name          IN VARCHAR2
) IS
    l_pre_clob           CLOB;
    l_post_clob          CLOB;
    l_validation_flag    VARCHAR2(2);
    l_delete_query       VARCHAR2(2000) DEFAULT q'[ DELETE FROM  :TABLE_NAME  WHERE CR_BATCH_NAME  LIKE '%:BATCH_NAME%' ]';
    l_end_proc           CLOB DEFAULT q'[ SELECT COUNT(*)
                                            INTO  l_tot_count
                                            FROM :SOURCE_TABLE
                                           WHERE CR_BATCH_NAME = ':P_BATCH_NAME';
                                          SELECT COUNT(*)
                                            INTO L_VS_NUM
                                            FROM :SOURCE_TABLE
                                           WHERE validation_flag = 'VS'
                                             AND CR_BATCH_NAME = ':P_BATCH_NAME';
                                          SELECT COUNT(*)
                                            INTO L_VF_NUM
                                            FROM :SOURCE_TABLE
                                           WHERE validation_flag = 'VF'
                                             AND CR_BATCH_NAME = ':P_BATCH_NAME';
                                          UPDATE CR_PROCESS_JOBS
                                             SET job_status = 'C',
                                                 success_records = L_VS_NUM,
                                                 failure_records = L_VF_NUM,
                                                 last_updated_by = 'CONVERTRITE',
                                                 last_update_date = sysdate
                                           WHERE job_id = :P_JOB_ID
                                             AND request_id = :P_REQUEST_ID;
                                          COMMIT;
                                          END;]';
     CURSOR main_cur
    IS
      SELECT a.*, ( 'BEGIN ' || CHR(10)
                             || 'SELECT ('
                             || nvl(a.source_field, 'NULL')
                             || ') INTO '
                             || a.insert_col
                             || ' FROM DUAL;'
                             || CHR(10)
                             || 'EXCEPTION WHEN OTHERS THEN '
                             || CHR(10)
                             || 'l_err_msg := l_err_msg||'
                             || 'SQLERRM  ||'
                             || ''' '
                             || a.column_name
                             || ''''
                             || ' || '
                             || source_column
                             || ' ||chr(10);'
                             || CHR(10)
                             || 'END;'
                             || CHR(10) ) declare_col
        FROM ( SELECT CASE
                         WHEN nvl(ctc.unique_trans_ref, 'N') = 'Y' THEN
                               to_clob('base_table.ORIG_TRANS_ID')
                         ELSE decode(ctc.mapping_type, 'As-Is',
                               CASE
                                   WHEN stc.column_name IS NULL THEN
                                       NULL
                                   ELSE 'base_table.' || to_clob(stc.column_name)
                               END,
                               'Constant',
                               ''''
                               || to_clob(ctc.mapping_value1)
                               || '''',
                               'Prefix',
                               ''''
                               || ctc.mapping_value1
                               || ''''
                               || '||'
                               || to_clob('base_table.' || stc.column_name),
                               'Suffix',
                               to_clob('base_table.' || stc.column_name)
                               || '||'
                               || ''''
                               || ctc.mapping_value1
                               || '''',
                               'One to One',
                               cr_fetch_onetoone_sql_func(ctc.column_name,ctc.mapping_value1,ctc.mapping_set_id)
                               ,
                               'Two to One',
                               cr_fetch_twotoone_sql_func(ctc.mapping_value1,ctc.mapping_value2,ctc.mapping_set_id),
                               'Formula',
                               cr_fetch_formula_sql_func(ctc.mapping_set_id),
                               NULL)
                      END source_field,
                      ctc.column_name,
                      'l_c_' || ctc.column_name || ' ' ||
                        CASE WHEN utc.data_type LIKE '%TIMESTAMP%'
                             THEN 'DATE'
                             ELSE utc.data_type
                        END ||
                        CASE WHEN utc.data_type NOT IN ( 'DATE','CLOB' ) AND utc.data_type NOT LIKE '%TIMESTAMP%'
                             THEN '(' || utc.data_length || ')'
                             ELSE NULL
                        END || ';' local_var,
                      'l_c_' || ctc.column_name || ' :=NULL;' null_assign_cols,
                      'l_c_' || ctc.column_name insert_col,
                       nvl2(stc.column_name, 'BASE_TABLE.' || stc.column_name, 'null') source_column
                 FROM cr_cld_template_hdrs hdrs,
                      cr_cld_template_cols ctc,
                      cr_src_template_cols stc,
                      user_tab_columns  utc
                WHERE hdrs.cld_template_id = p_cloud_template_id
                  AND ctc.cld_template_id = hdrs.cld_template_id
                  AND ctc.source_column_id = stc.column_id (+)
                  AND ( ( nvl(ctc.selected, 'N') IN ( 'Y', 'M' ) )
                      OR ( nvl(ctc.unique_trans_ref, 'N') = 'Y' ) )
                  AND utc.table_name = hdrs.staging_table_name
                  AND upper(ctc.column_name) = upper(utc.column_name)
             ) a;
    CURSOR user_hooks_cur (p_cloud_template_id IN NUMBER)
    IS
    SELECT chu.usage_type,
           cuh.hook_text,
           cuh.description,
           cuh.hook_name
      FROM CR_HOOK_USAGES chu,
           cr_user_hooks cuh
     WHERE cuh.hook_id = chu.hook_id
       AND chu.template_id = p_cloud_template_id;

    TYPE cur_tab_type IS TABLE OF main_cur%rowtype;
    l_cur_tab_type       cur_tab_type;

    l_main_clob          CLOB;
    l_column_names       CLOB;
    l_local_vars         CLOB;
    l_null_assigned_cols CLOB;
    l_cld_cols           CLOB;
    l_insert_col         CLOB;
    l_declare_blocks     CLOB;
    l_cld_stg_table      VARCHAR2(250);
    l_src_stg_table      VARCHAR2(250);
    l_loop_clause        VARCHAR2(2000);

    FUNCTION raise_exception_func
      RETURN VARCHAR2 IS
    BEGIN
        RAISE case_not_found;
    END raise_exception_func;

    FUNCTION raise_exception_func ( p_cloud_column IN VARCHAR2 )
      RETURN VARCHAR2 IS
    BEGIN
        raise_application_error(-20001, ' Error :' || p_cloud_column,TRUE);
    END raise_exception_func;

    PROCEDURE insert_map_clob_proc(p_template_id in number,p_data in clob)
    IS
    PRAGMA AUTONOMOUS_TRANSACTION;
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
            p_batch_name,
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

    END insert_map_clob_proc;

    PROCEDURE update_request_proc (
        p_request_id IN NUMBER,
        p_job_id     IN NUMBER,
        p_job_status IN VARCHAR2,
        p_err_msg    IN VARCHAR2 DEFAULT ''
    ) IS
        l_current_status  VARCHAR2(50);
        l_current_percent NUMBER;
        l_job_weightage   NUMBER;
    BEGIN
        SELECT weightage
          INTO l_job_weightage
          FROM cr_process_jobs
         WHERE request_id = p_request_id
           AND job_id = p_job_id;

        SELECT status,
               NVL(completed_percentage, 0)
          INTO l_current_status,
               l_current_percent
          FROM cr_process_requests
         WHERE request_id = p_request_id;

        IF l_current_status = 'CE'
        THEN
            UPDATE cr_process_requests
               SET completed_percentage = l_current_percent + l_job_weightage,
                   err_msg = p_err_msg,
                   last_updated_by = 'CONVRITE',
                   last_update_date = sysdate
             WHERE request_id = p_request_id;
        ELSE
            IF l_current_percent + l_job_weightage = 100
            THEN
                UPDATE cr_process_requests
                   SET completed_percentage = l_current_percent + l_job_weightage,
                       status = p_job_status,
                       err_msg = p_err_msg,
                       end_date = sysdate,
                       last_updated_by = 'CONVRITE',
                       last_update_date = sysdate
                 WHERE request_id = p_request_id;
            ELSE
                UPDATE cr_process_requests
                   SET completed_percentage = l_current_percent + l_job_weightage,
                       last_updated_by = 'CONVRITE',
                       err_msg = p_err_msg,
                       last_update_date = sysdate
                 WHERE request_id = p_request_id;
            END IF;
        END IF;

        UPDATE cr_process_jobs
           SET job_status = p_job_status,
               last_updated_by = 'CONVRITE',
               last_update_date = sysdate
         WHERE request_id = p_request_id
           AND job_id = p_job_id;

        COMMIT;
    END update_request_proc;

BEGIN
    dbms_output.put_line('BEGIN');
    SELECT cld_hdr.staging_table_name cld_stg_table,
           src_hdr.staging_table_name src_stg_table
      INTO l_cld_stg_table,
           l_src_stg_table
      FROM cr_cld_template_hdrs cld_hdr,
           cr_src_template_hdrs src_hdr
     WHERE cld_hdr.cld_template_id = p_cloud_template_id
       AND cld_hdr.src_template_id = src_hdr.src_template_id;
    dbms_output.put_line('l_cld_stg_table: '||l_cld_stg_table);
    dbms_output.put_line('l_src_stg_table: '||l_src_stg_table);
    BEGIN
        FOR user_hooks_rec IN user_hooks_cur (p_cloud_template_id)
        LOOP
            IF user_hooks_rec.usage_type = 'PRE_HOOK'
            THEN
               l_pre_clob := user_hooks_rec.hook_text|| chr(10);
               l_pre_clob := replace(l_pre_clob, ':P_BATCH_NAME', p_batch_name);
            ELSIF user_hooks_rec.usage_type = 'POST_HOOK'
            THEN
               l_post_clob := user_hooks_rec.hook_text|| chr(10);
               l_post_clob := replace(l_post_clob, ':P_BATCH_NAME', p_batch_name);
            ELSE
               l_pre_clob := 'null';
               l_post_clob := 'null';
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            l_pre_clob := 'null';
            l_post_clob := 'null';
    END;
    l_pre_clob := NVL(l_pre_clob,'null');
    l_post_clob := NVL(l_post_clob,'null');
    dbms_output.put_line('l_pre_clob: '||l_pre_clob);
    dbms_output.put_line('l_post_clob: '||l_post_clob);
    l_loop_clause := 'FOR base_table IN('
                     || chr(10)
                     || 'SELECT a.*, rowid row_id  FROM '
                     || l_src_stg_table
                     || ' a WHERE CR_BATCH_NAME = '
                     || chr(39)
                     || p_batch_name
                     || chr(39)
                     || Q'[ AND   NVL(VALIDATION_FLAG,'N') <> 'DUPLICATE' ) LOOP]' -- Added for NORMALIZE
                     || chr(10);

    OPEN main_cur;
    FETCH main_cur
    BULK COLLECT INTO l_cur_tab_type;
    CLOSE main_cur;
    COMMIT;
    FOR i IN l_cur_tab_type.first..l_cur_tab_type.last
    LOOP
        l_local_vars := l_local_vars || l_cur_tab_type(i).local_var || chr(10);

        l_null_assigned_cols := l_null_assigned_cols || l_cur_tab_type(i).null_assign_cols || chr(10);

        l_declare_blocks := l_declare_blocks || l_cur_tab_type(i).declare_col;

        l_insert_col := l_insert_col || ',' || l_cur_tab_type(i).insert_col || chr(10);

        l_cld_cols := l_cld_cols || ',' || l_cur_tab_type(i).column_name || chr(10);
    END LOOP;

    l_null_assigned_cols := l_null_assigned_cols || 'l_err_msg  := null ;';
    l_end_proc := replace(l_end_proc, ':SOURCE_TABLE', p_source_table_name);
    l_end_proc := replace(l_end_proc, ':P_JOB_ID', p_job_id);
    l_end_proc := replace(l_end_proc, ':P_REQUEST_ID', p_request_id);
    l_end_proc := replace(l_end_proc, ':P_BATCH_NAME', p_batch_name);

    l_insert_col := substr(l_insert_col, 2);
    l_cld_cols := substr(l_cld_cols, 2);
    l_main_clob := 'DECLARE '
                   || chr(10)
                   || 'l_err_msg clob; l_vs_num  NUMBER; l_vf_num    NUMBER; l_tot_count NUMBER;'
                   || l_local_vars
                   || chr(10);

    l_main_clob := l_main_clob
                   || 'BEGIN'
                   || chr(10)
                   || l_pre_clob
                   || ' ; commit; '
                   || chr(10)
                   || l_loop_clause
                   || chr(10);

    l_main_clob := l_main_clob || l_null_assigned_cols;
    l_main_clob := l_main_clob || l_declare_blocks;
    l_main_clob := l_main_clob
                   || chr(10)
                   || 'IF l_err_msg IS NULL THEN ';
    l_main_clob := l_main_clob
                   || 'INSERT INTO '
                   || l_cld_stg_table
                   || '(';
    l_main_clob := l_main_clob
                   || l_cld_cols
                   || ',orig_trans_id,cld_template_id,cr_batch_name '
                   || ')VALUES(';
    dbms_lob.append(l_main_clob, l_insert_col);
    dbms_lob.append(l_main_clob, to_clob(',base_table.orig_trans_id,'
                                         || p_cloud_template_id
                                         || ','''
                                         || p_batch_name
                                         || ''''
                                         || ');'));

    l_main_clob := replace(l_main_clob, ':p_batch_name', p_batch_name);
    l_main_clob := l_main_clob
                   || 'UPDATE '
                   || l_src_stg_table
                   || Q'[ SET error_msg = 'SUCCESS',validation_flag= ]'
                   || ''''
                   || 'VS'
                   || ''''
                   || ' WHERE orig_trans_id = base_table.orig_trans_id and rowid = base_table.row_id '
                   || ' and cr_batch_name = '
                   || ''''
                   || p_batch_name
                   || ''' ; ';

    l_main_clob := l_main_clob
                   || 'ELSE '
                   || chr(10);
    l_main_clob := l_main_clob
                   || 'UPDATE '
                   || l_src_stg_table
                   || Q'[  SET error_msg = (
                            CASE WHEN l_err_msg LIKE '%ORA-06512%'  AND (LENGTH(l_err_msg) - LENGTH(REPLACE(l_err_msg ,'ORA','')))/(LENGTH('ORA'))> 1
                                   THEN substr(l_err_msg,
                                       11,
                                       instr(l_err_msg,
                                             'ORA-06512') - 12)
                                              ELSE SUBSTR(l_err_msg,11,2000) END ),validation_flag=]'
                   || ''''
                   || 'VF'
                   || ''''
                   || ' WHERE orig_trans_id = base_table.orig_trans_id and rowid = base_table.row_id '
                   || ' and cr_batch_name =  '
                   || ''''
                   || p_batch_name
                   || ''''
                   || ' ; END IF; COMMIT; END LOOP;commit; '
                   || l_post_clob
                   || ' ; commit; ';

    l_main_clob := l_main_clob || l_end_proc;
    l_delete_query := replace(l_delete_query, ':TABLE_NAME', p_cloud_table_name);
    l_delete_query := replace(l_delete_query, ':BATCH_NAME', p_batch_name);
    BEGIN
        EXECUTE IMMEDIATE l_delete_query;
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END;

    insert_map_clob_proc(p_cloud_template_id, l_main_clob);
    COMMIT;

    l_main_clob := replace(l_main_clob, ':p_batch_name', p_batch_name);

        INSERT INTO CR_LOG_MESSAGES (PROC_NAME ,REFERENCE_KEY,Log_message,DYNAMIC_QUERY,USER_ID,CREATION_DATE,CREATED_BY)
                         VALUES ('CR_CLD_TRANSFORM_MAIN_PROC','p_cloud_template_id: '||p_cloud_template_id,NULL,l_main_clob,NULL,SYSDATE,NULL);
        COMMIT;
    BEGIN
        EXECUTE IMMEDIATE l_main_clob;
        update_request_proc(p_request_id => p_request_id, p_job_id => p_job_id, p_job_status => 'C');

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            update_request_proc(p_request_id => p_request_id, p_job_id => p_job_id, p_job_status => 'CE', p_err_msg => sqlerrm );
    END;
EXCEPTION
WHEN OTHERS THEN
    update_request_proc(p_request_id => p_request_id, p_job_id => p_job_id, p_job_status => 'CE', p_err_msg => sqlerrm );
END CR_CLD_TRANSFORM_MAIN_PROC;
$#$

CREATE OR REPLACE PROCEDURE CR_FBDI_FILEGEN_PROC (
    p_cld_template_id IN NUMBER,
    p_batch_name  IN VARCHAR2,
    p_clob_fbdi_file    OUT CLOB
) IS
    TYPE varchartab IS TABLE OF VARCHAR2(32000);
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
    SELECT staging_table_name,
           project_id,
           parent_object_id,
           object_id
      INTO l_tab_name,
           l_project_id,
           l_parent_obj_id,
           l_obj_id
      FROM cr_cld_template_hdrs
    WHERE cld_template_id = p_cld_template_id;

    l_select := 'SELECT  orig_trans_id FROM '
                || l_tab_name
                || ' WHERE CR_BATCH_NAME='
                || ''''
                || p_batch_name
                || '''';

    EXECUTE IMMEDIATE l_select
    BULK COLLECT
    INTO l_orig_ref_tab;

    BEGIN
        SELECT cloud_date_format
          INTO l_date_format
          FROM cr_date_configuration
        WHERE project_id = l_project_id
          AND parent_object_id = l_parent_obj_id
          AND object_id = l_obj_id;
    EXCEPTION
    WHEN OTHERS
    THEN
       l_date_format := NULL;
    END;

    IF l_date_format IS NULL
    THEN
        SELECT column_name
          BULK COLLECT
          INTO l_col_tab
          FROM cr_cld_template_cols
         WHERE cld_template_id = p_cld_template_id
           AND display_seq IS NOT NULL
         ORDER BY NVL(display_seq, 9999999999) ASC;
    ELSE
        SELECT decode(column_type, 'D', 'TO_CHAR('
                                     || column_name
                                     || ','
                                     || ''''
                                     || l_date_format
                                     || ''''
                                     || ')', column_name)
          BULK COLLECT
          INTO l_col_tab
          FROM cr_cld_template_cols
         WHERE cld_template_id = p_cld_template_id
           AND display_seq IS NOT NULL
         ORDER BY NVL(display_seq, 9999999999) ASC;
    END IF;

    FOR t IN l_col_tab.first..l_col_tab.last
    LOOP
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

    l_cols := substr(l_cols, 0, length(l_cols) - 7);

    FOR i IN l_orig_ref_tab.first..l_orig_ref_tab.last
    LOOP
        BEGIN
            EXECUTE IMMEDIATE 'SELECT  '
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
                              || ''''
            INTO l_temp;

            l_clob := l_clob
                      || l_temp
                      || ( convert(chr(10), substr(userenv('LANGUAGE'), instr(userenv('LANGUAGE'), '.') + 1), 'US7ASCII') );

            l_temp := NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
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
                                               || '''');--MODIFIED 22/06/2022
                RAISE;
        END;
    END LOOP;

    p_clob_fbdi_file := l_clob;
END CR_FBDI_FILEGEN_PROC;
$#$

create or replace PROCEDURE cr_hdl_filegen_proc (

    p_cld_template_id IN NUMBER,

    p_batch_name      IN VARCHAR2,

    p_intial_load     IN VARCHAR2 DEFAULT 'N',

    p_clob_hdl_file   OUT CLOB

) IS

    TYPE numtab IS

        TABLE OF NUMBER;

    TYPE varchartab IS

        TABLE OF VARCHAR2(32000);

    l_pod_id          NUMBER;

    l_project_id      NUMBER;

    l_parent_obj_id   NUMBER;

    l_obj_id          NUMBER;

    l_parent_obj_name VARCHAR2(200);

    l_temp_id_tab     numtab;

    l_metadata_tab_id numtab;

    l_stg_table_name  varchartab;

    l_orderby_clause  varchartab;

    l_clob            CLOB :=EMPTY_CLOB;

    l_count           NUMBER;

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

        RETURN l_clob

               || ( convert(chr(10), substr(userenv('LANGUAGE'), instr(userenv('LANGUAGE'), '.') + 1), 'US7ASCII') );

    EXCEPTION

        WHEN OTHERS THEN

            if p_intial_load = 'Y' then

          raise_application_error(-20001, 'No data exits in the " '

                                            || p_table_name ||' " with batch_name : '||p_batch_name);

        else

            raise_application_error(-20001, sqlerrm

                                            || ' on table '

                                            || p_table_name);

                                            end if;

    END table_to_hdl_func;

BEGIN

dbms_lob.createtemporary(l_clob, true);

    SELECT

        project_id,

        parent_object_id,

        object_id

    INTO

        l_project_id,

        l_parent_obj_id,

        l_obj_id

    FROM

        cr_cld_template_hdrs

    WHERE

        cld_template_id = p_cld_template_id;


    SELECT count(object_id) into  l_count

    FROM cr_objects

    WHERE module_code = 'HCM'

    AND parent_object_id IS NULL

    AND object_id = l_parent_obj_id;


    IF l_count > 0 THEN

        IF p_intial_load = 'Y' THEN

            SELECT

                hdrs.cld_template_id,

                hdrs.metadata_table_id,

                hdrs.staging_table_name,

                nvl(hdrs.attribute1, '1')

            BULK COLLECT

            INTO

                l_temp_id_tab,

                l_metadata_tab_id,

                l_stg_table_name,

                l_orderby_clause

            FROM

                cr_cld_template_hdrs hdrs

            WHERE

                    hdrs.project_id = l_project_id

                AND hdrs.parent_object_id = l_parent_obj_id

                AND hdrs.staging_table_name IS NOT NULL

            ORDER BY

                hdrs.cld_template_id ASC;

        ELSE

            SELECT

                hdrs.cld_template_id,

                hdrs.metadata_table_id,

                hdrs.staging_table_name,

                nvl(hdrs.attribute1, '1')

            BULK COLLECT

            INTO

                l_temp_id_tab,

                l_metadata_tab_id,

                l_stg_table_name,

                l_orderby_clause

            FROM

                cr_cld_template_hdrs hdrs

            WHERE

                    hdrs.project_id = l_project_id

                AND hdrs.parent_object_id = l_parent_obj_id

                AND hdrs.staging_table_name IS NOT NULL

                AND hdrs.object_id = l_obj_id

            ORDER BY

                hdrs.cld_template_id ASC;

        END IF;

    END IF;

    FOR i IN l_temp_id_tab.first..l_temp_id_tab.last LOOP

	 DBMS_LOB.APPEND(l_clob,to_clob(table_to_hdl_func(l_temp_id_tab(i), l_stg_table_name(i), p_batch_name, l_orderby_clause(i))));


    END LOOP;

    l_clob := 'SET CALCULATE_FTE Y'

              || chr(10)

              || l_clob;

    p_clob_hdl_file := l_clob;

END cr_hdl_filegen_proc;
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


create or replace PROCEDURE cr_src_val_fail_proc (
    p_user_id          IN VARCHAR2,
    p_cld_template_id  IN NUMBER,
    p_batch_name       IN VARCHAR2 DEFAULT NULL,
    p_clob_src_vf_file OUT CLOB,
    p_ret_code         OUT VARCHAR2,
    p_ret_msg          OUT VARCHAR2
) IS
    TYPE varchartab IS
        TABLE OF VARCHAR2(32000);
    l_cld_stg_table      VARCHAR2(200);
    l_cld_col_tab        varchartab;
    l_query              CLOB;
    l_clob_tab           varchartab;
    l_final_clob         CLOB;
    l_cols               CLOB;
    cur                  SYS_REFCURSOR;
    l_project_id         NUMBER;
    l_parent_obj_id      NUMBER;
    l_obj_id             NUMBER;
    l_obj_name           VARCHAR2(200);
    l_date_format        VARCHAR2(50) DEFAULT NULL;
    lc_proc              VARCHAR2(100) := 'CR_SRC_VAL_FAIL_PROC';
    l_project_name       VARCHAR2(100);
    l_src_template_id    NUMBER;
    l_src_stg_table_name VARCHAR2(100);
BEGIN
    p_ret_code := 'SUCCESS';
    p_ret_msg := 'SUCCESS';
    cr_audit_log_msg_proc(p_user_id, lc_proc, 'CLD_TEMPLATE_ID: ' || p_cld_template_id, 'START', NULL);
    SELECT
        cld.project_id,
        cld.parent_object_id,
        cld.object_id,
        cld.object_name,
        cld.staging_table_name,
        cld.src_template_id,
        src.staging_table_name
    INTO
        l_project_id,
        l_parent_obj_id,
        l_obj_id,
        l_obj_name,
        l_cld_stg_table,
        l_src_template_id,
        l_src_stg_table_name
    FROM
        cr_cld_template_hdrs_v cld,
        cr_src_template_hdrs   src
    WHERE
            cld_template_id = p_cld_template_id
        AND src.src_template_id = cld.src_template_id;
    cr_audit_log_msg_proc(p_user_id, lc_proc, 'CLD_TEMPLATE_ID: '
                                              || p_cld_template_id
                                              || ' ,Cld staging_table_name: '
                                              || l_cld_stg_table
                                              || ' ,Project_Name: '
                                              || l_project_name
                                              || ', Object_Name : '
                                              || l_obj_name, 'Fetched Object information', NULL);
    cr_audit_log_msg_proc(p_user_id, lc_proc, 'CLD_TEMPLATE_ID: '
                                              || p_cld_template_id
                                              || ' ,Cld staging_table_name: '
                                              || l_cld_stg_table
                                              || ' ,Project_Name: '
                                              || l_project_name
                                              || ', Object_Name : '
                                              || l_obj_name, 'SRC Information - SRC Template ID: '
                                                             || l_src_template_id
                                                             || ', SRC STG Table Name: '
                                                             || l_src_stg_table_name, NULL);
    SELECT
        column_name
    BULK COLLECT
    INTO l_cld_col_tab
    FROM
        all_tab_columns
    WHERE
        table_name = l_src_stg_table_name
    ORDER BY
        column_id;
    FOR i IN l_cld_col_tab.first..l_cld_col_tab.last LOOP
        l_cols := l_cols
                  || ''''
                  || '"'
                  || ''''
                  || '||src_stg.'
                  || l_cld_col_tab(i)
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
                                              || l_obj_name
                                              || ', SRC Template ID: '
                                              || l_src_template_id
                                              || ', SRC STG Table Name: '
                                              || l_src_stg_table_name, 'Build Dynamic query for SRC VF Records', l_query);
    l_query := ' SELECT'
               || l_cols
               || 'FROM '
               || l_src_stg_table_name
               || q'[ src_stg
        WHERE nvl(validation_flag,'N')='VF' and cr_batch_name = ]'||''''||p_batch_name ||'''';
    cr_audit_log_msg_proc(p_user_id, lc_proc, 'CLD_TEMPLATE_ID: '
                                              || p_cld_template_id
                                              || ' ,Cld staging_table_name: '
                                              || l_cld_stg_table
                                              || ' ,Project_Name: '
                                              || l_project_name
                                              || ', Object_Name : '
                                              || l_obj_name
                                              || ', SRC Template ID: '
                                              || l_src_template_id
                                              || ', SRC STG Table Name: '
                                              || l_src_stg_table_name, 'Dynamic Query Built', l_query);
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
    p_clob_src_vf_file := l_final_clob;
    cr_audit_log_msg_proc(p_user_id, lc_proc, 'CLD_TEMPLATE_ID: '
                                              || p_cld_template_id
                                              || ' ,Cld staging_table_name: '
                                              || l_cld_stg_table
                                              || ' ,Project_Name: '
                                              || l_project_name
                                              || ', Object_Name : '
                                              || l_obj_name
                                              || ', SRC Template ID: '
                                              || l_src_template_id
                                              || ', SRC STG Table Name: '
                                              || l_src_stg_table_name, 'END', NULL);
EXCEPTION
    WHEN OTHERS THEN
        p_ret_code := 'ERROR';
        p_ret_msg := 'Unexpected Error in CR_SRC_VAL_FAIL_PROC. Error: ' || sqlerrm;
        cr_audit_log_msg_proc(p_user_id, lc_proc, 'CLD_TEMPLATE_ID: '
                                                  || p_cld_template_id
                                                  || ' ,Cld staging_table_name: '
                                                  || l_cld_stg_table
                                                  || ' ,Project_Name: '
                                                  || l_project_name
                                                  || ', Object_Name : '
                                                  || l_obj_name
                                                  || ', SRC Template ID: '
                                                  || l_src_template_id
                                                  || ', SRC STG Table Name: '
                                                  || l_src_stg_table_name, 'Unexpected Error: ' || sqlerrm, NULL);
END cr_src_val_fail_proc;
$#$

create or replace PROCEDURE cr_copy_proc(
    p_source_pod     IN VARCHAR2,
    p_destinaion_pod IN VARCHAR2,
    p_project_name   IN VARCHAR2,
    p_msg            OUT VARCHAR2,
    p_result         OUT VARCHAR2
) AS

    l_final_clob CLOB;
    l_query_1    CLOB DEFAULT q'[
 DECLARE
    TYPE varchartab IS
        TABLE OF VARCHAR2(420);
    TYPE numtab IS
        TABLE OF NUMBER;
    l_object_codes         varchartab;
    l_object_id            numtab;
    l_object_code          varchartab;
    l_src_template_id      numtab;
    l_cld_template_id      numtab;
    l_parent_object        varchartab;
    l_source_table_id      NUMBER;
    l_projectexists        NUMBER; -- Variable to store whether the project exists (1) or not (0)
    l_project_id           NUMBER;
    l_src_temp_id          NUMBER;
    l_cld_temp_id          NUMBER;
    l_obj_list             VARCHAR2(2000);
    l_cloud_table_id       NUMBER;
    l_map_set_count        NUMBER;
    l_map_set_id           NUMBER;
    l_formula_count        NUMBER;
    l_count                NUMBER;
    l_cld_count            NUMBER;
    l_src_col_id           NUMBER;
    l_dest_src_temp_check  NUMBER;
    l_dest_cld_temp_check  NUMBER;
    l_map_set_check        NUMBER;
    l_uh_clob clob;
    l_HOOK_ID number;
    l_uh_check number;
    l_ret_code varchar2(250);
    l_ret_msg varchar2(250);
    l_drop_stmt varchar2(2000);
    l_table_chek number;
	l_lookup_set_id NUMBER;
    l_lookup_check number;
    l_GROUP_ID number;
    CURSOR get_src_temp_details (
        l_project_id IN NUMBER
    ) IS
    SELECT
        src_template_id,
        src_template_code,
        STAGING_TABLE_NAME
    FROM
        :p_destinaion_pod.cr_src_template_hdrs
    WHERE
        src_template_code in (select src_template_code from :p_source_pod.cr_src_template_hdrs where project_id = l_project_id);

    CURSOR get_cld_temp_details (
        l_project_id IN NUMBER
    ) IS
    SELECT
        cld_template_id,
        cld_template_code,
        STAGING_TABLE_NAME
    FROM
        :p_destinaion_pod.cr_cld_template_hdrs
    WHERE
         project_id = l_project_id;

    CURSOR get_src_temp_id (
        l_project_id IN NUMBER
    ) IS
    SELECT
        src_template_id,
        src_template_code,STAGING_TABLE_NAME
    FROM
        :p_source_pod.cr_src_template_hdrs
    WHERE
        project_id = l_project_id;

    CURSOR get_cld_temp_id (
        l_project_id IN NUMBER
    ) IS
    SELECT
        cld_template_id,
        cld_template_code,
        object_id,STAGING_TABLE_NAME
    FROM
        :p_source_pod.cr_cld_template_hdrs
    WHERE
        project_id = l_project_id;

    CURSOR get_cld_temp_cols_details (
        p_template_id IN NUMBER
    ) IS
    SELECT
        *
    FROM
        :p_source_pod.cr_cld_template_cols
    WHERE
        cld_template_id = p_template_id
    ORDER BY
        column_id;

    CURSOR get_mapping_details (
        l_project_id IN NUMBER
    ) IS
    SELECT DISTINCT
        cols.mapping_set_id,
        cols.mapping_type,
        CASE
            WHEN cols.mapping_type IN ( 'One to One', 'Two to One', 'Three to One' ) THEN
                (
                    SELECT
                        map_set_code
                    FROM
                        :p_source_pod.cr_mapping_sets
                    WHERE
                        map_set_id = cols.mapping_set_id
                )
            WHEN cols.mapping_type IN ( 'Formula' ) THEN
                (
                    SELECT
                        formula_set_code
                    FROM
                        :p_source_pod.cr_formula_sets
                    WHERE
                        formula_set_id = cols.mapping_set_id
                )
        END code
    FROM
        :p_source_pod.cr_cld_template_hdrs hdrs,
        :p_source_pod.cr_cld_template_cols cols,
        :p_source_pod.cr_formula_sets f,
        :p_source_pod.cr_mapping_sets m
    WHERE
            hdrs.project_id = l_project_id
        AND hdrs.cld_template_id = cols.cld_template_id
        AND mapping_type IN ( 'One to One', 'Two to One', 'Three to One', 'Formula' )
        and (cols.mapping_set_id=f.formula_set_id or cols.mapping_set_id=m.map_set_id);

    CURSOR get_userhook_details (
        l_cld_template_id IN NUMBER
    ) IS
    select distinct dbms_lob.substr(cuh.HOOK_TEXT,instr(cuh.HOOK_TEXT,'(')-1) userhook
    from :p_source_pod.CR_HOOK_USAGES chu,
    :p_source_pod.CR_USER_HOOKS cuh
    where chu.TEMPLATE_ID=l_cld_template_id
    and chu.HOOK_ID=cuh.HOOK_ID;

    CURSOR get_exist_uh_details (
        l_cld_template_id IN NUMBER
    ) IS
    select distinct chu.HOOK_ID,cuh.HOOK_CODE,dbms_lob.substr(cuh.HOOK_TEXT,instr(cuh.HOOK_TEXT,'(')-1) userhook
    from :p_source_pod.CR_HOOK_USAGES chu,
    :p_source_pod.CR_USER_HOOKS cuh
    where chu.TEMPLATE_ID in (select cld_template_id
                            from :p_source_pod.cr_cld_template_hdrs
                            WHERE project_id = l_project_id)
    and chu.HOOK_ID=cuh.HOOK_ID;

	CURSOR get_lookup_details (
        l_project_id IN NUMBER
    ) IS
    SELECT DISTINCT
        ls.LOOKUP_SET_ID,
        ls.LOOKUP_SET_CODE
    FROM
        :p_source_pod.cr_cld_template_hdrs hdrs,
        :p_source_pod.cr_cld_template_cols cols,
        :p_source_pod.cr_mapping_sets m,
        :p_source_pod.CR_LOOKUP_SETS ls
    WHERE
            hdrs.project_id = l_project_id
        AND hdrs.cld_template_id = cols.cld_template_id
        AND  cols.mapping_set_id=m.map_set_id
        and m.LOOKUP_SET_ID=ls.LOOKUP_SET_ID;

 CURSOR get_exist_object_group_details (
        l_project_id IN NUMBER
    ) IS
    select GROUP_ID,PROJECT_ID,GROUP_CODE from :p_source_pod.CR_OBJECT_GROUP_HDRS where PROJECT_ID=l_project_id;

BEGIN
    -- Check if the project exists in the table
    l_projectexists := 0;
    SELECT
        nvl(COUNT(project_name), 0)
    INTO l_projectexists
    FROM
        :p_destinaion_pod.cr_projects
    WHERE
        project_name = ':p_project_name';

    SELECT
        project_id
    INTO l_project_id
    FROM
        :p_source_pod.cr_projects
    WHERE
            project_name = ':p_project_name'
        AND ROWNUM = 1;

    IF l_projectexists > 0 THEN
        DELETE FROM :p_destinaion_pod.cr_projects
        WHERE
            project_id = l_project_id;

        DELETE FROM :p_destinaion_pod.cr_project_objects
        WHERE
            project_id = l_project_id;

        DELETE FROM :p_destinaion_pod.cr_proj_activities
        WHERE
            project_id = l_project_id;

        COMMIT;
            dbms_output.put_line('Dlete proj  data');
    END IF;

    --Inserting from the Source pod to destintion pod (Project Details )

    INSERT INTO :p_destinaion_pod.cr_projects
        SELECT
            *
        FROM
            :p_source_pod.cr_projects
        WHERE
            project_id = l_project_id;

    COMMIT;
    INSERT INTO :p_destinaion_pod.cr_project_objects
        SELECT
            *
        FROM
            :p_source_pod.cr_project_objects
        WHERE
            project_id = l_project_id;

    COMMIT;
    INSERT INTO :p_destinaion_pod.cr_proj_activities (
        project_id,
        seq,
        task_num,
        task_name,
        object_id,
        task_type,
        pre_req_task,
        start_date,
        end_date,
        weightage,
        complete_percentage,
        legacy_resource_id,
        task_status,
        destination_resource_id,
        task_owner_id,
        completion_flag,
        cloud_resource_id,
        integrator_resource_id,
        client_resource_id,
        attribute1,
        attribute2,
        attribute3,
        attribute4,
        attribute5,
        last_updated_by,
        last_update_date,
        creation_date,
        created_by
    )
        SELECT
            project_id,
            seq,
            task_num,
            task_name,
            object_id,
            task_type,
            pre_req_task,
            start_date,
            end_date,
            weightage,
            complete_percentage,
            legacy_resource_id,
            task_status,
            destination_resource_id,
            task_owner_id,
            completion_flag,
            cloud_resource_id,
            integrator_resource_id,
            client_resource_id,
            attribute1,
            attribute2,
            attribute3,
            attribute4,
            attribute5,
            last_updated_by,
            last_update_date,
            creation_date,
            created_by
        FROM
            :p_source_pod.cr_proj_activities
        WHERE
            project_id = l_project_id;

    COMMIT;
            dbms_output.put_line('Insert proj  data');

    -- Delete Existing Userhooks data
    begin
    for x in (select distinct cuh.HOOK_CODE
    from :p_source_pod.CR_HOOK_USAGES chu,
    :p_source_pod.CR_USER_HOOKS cuh
    where chu.TEMPLATE_ID in (select cld_template_id
                            from :p_source_pod.cr_cld_template_hdrs
                            WHERE project_id = l_project_id)
    and chu.HOOK_ID=cuh.HOOK_ID)
    loop
        delete from :p_destinaion_pod.CR_HOOK_USAGES
                where HOOK_ID in (select distinct HOOK_ID from :p_destinaion_pod.CR_USER_HOOKS where HOOK_CODE=x.HOOK_CODE);
                commit;
            delete from :p_destinaion_pod.CR_USER_HOOKS where HOOK_CODE=x.HOOK_CODE;
            commit;
            insert into :p_destinaion_pod.CR_USER_HOOKS(
            HOOK_TYPE,HOOK_NAME,HOOK_CODE,DESCRIPTION,HOOK_TEXT,ATTRIBUTE1,ATTRIBUTE2,ATTRIBUTE3,ATTRIBUTE4,ATTRIBUTE5,CREATION_DATE,CREATED_BY,LAST_UPDATE_DATE,LAST_UPDATED_BY)
            select HOOK_TYPE,HOOK_NAME,HOOK_CODE,DESCRIPTION,HOOK_TEXT,ATTRIBUTE1,ATTRIBUTE2,ATTRIBUTE3,ATTRIBUTE4,ATTRIBUTE5,CREATION_DATE,CREATED_BY,LAST_UPDATE_DATE,LAST_UPDATED_BY
            from :p_source_pod.CR_USER_HOOKS where HOOK_CODE=x.HOOK_CODE;
            commit;
    end loop;
    end;

	 --Lookup details
    begin
        for i in get_lookup_details(l_project_id) loop
            l_lookup_set_id:=null;
            --Delete Existing Lookup Values from Destination POD
            delete from :p_destinaion_pod.CR_LOOKUP_VALUES
                where LOOKUP_SET_ID in (select LOOKUP_SET_ID from :p_destinaion_pod.CR_LOOKUP_SETS where LOOKUP_SET_CODE=i.LOOKUP_SET_CODE);
            commit;
            --Delete Existing Lookup Sets from Destination POD
            delete from :p_destinaion_pod.CR_LOOKUP_SETS where LOOKUP_SET_CODE=i.LOOKUP_SET_CODE;
            commit;
            --Insert Lookup Sets into Destination POD
            insert into :p_destinaion_pod.CR_LOOKUP_SETS(LOOKUP_SET_NAME,LOOKUP_SET_CODE,DESCRIPTION,RELATED_TO,LOOKUP_FLAG,ATTRIBUTE1,ATTRIBUTE2,ATTRIBUTE3,ATTRIBUTE4,ATTRIBUTE5,LAST_UPDATED_BY,LAST_UPDATE_DATE,CREATION_DATE,CREATED_BY)
            select LOOKUP_SET_NAME,LOOKUP_SET_CODE,DESCRIPTION,RELATED_TO,LOOKUP_FLAG,ATTRIBUTE1,ATTRIBUTE2,ATTRIBUTE3,ATTRIBUTE4,ATTRIBUTE5,LAST_UPDATED_BY,LAST_UPDATE_DATE,CREATION_DATE,CREATED_BY from :p_source_pod.CR_LOOKUP_SETS
            where LOOKUP_SET_ID=i.LOOKUP_SET_ID and LOOKUP_SET_CODE=i.LOOKUP_SET_CODE;
            commit;

            select distinct LOOKUP_SET_ID into l_lookup_set_id
            from :p_destinaion_pod.CR_LOOKUP_SETS where LOOKUP_SET_CODE=i.LOOKUP_SET_CODE;
            --Insert Lookup Values into Destination POD
            insert into :p_destinaion_pod.CR_LOOKUP_VALUES(LOOKUP_VALUE,LOOKUP_SET_ID,ACTUAL_VALUE,ATTRIBUTE1,ATTRIBUTE2,ATTRIBUTE3,ATTRIBUTE4,ATTRIBUTE5,ENABLED_FLAG,LAST_UPDATED_BY,LAST_UPDATE_DATE,CREATION_DATE,CREATED_BY)
            select LOOKUP_VALUE,l_lookup_set_id,ACTUAL_VALUE,ATTRIBUTE1,ATTRIBUTE2,ATTRIBUTE3,ATTRIBUTE4,ATTRIBUTE5,ENABLED_FLAG,LAST_UPDATED_BY,LAST_UPDATE_DATE,CREATION_DATE,CREATED_BY from :p_source_pod.CR_LOOKUP_VALUES
            WHERE LOOKUP_SET_ID=i.LOOKUP_SET_ID;
            COMMIT;
        end loop;
    end;

  --Mapping Sets
    BEGIN
        FOR i IN get_mapping_details(l_project_id) LOOP
            IF i.mapping_type = 'Formula' THEN
                DELETE FROM :p_destinaion_pod.cr_formula_sets
                WHERE
                    formula_set_id = i.mapping_set_id;

                COMMIT;
                INSERT INTO :p_destinaion_pod.cr_formula_sets (
                    formula_set_name,
                    formula_set_code,
                    description,
                    formula_type,
                    formula_text,
                    count_of_params,
                    attribute1,
                    attribute2,
                    attribute3,
                    attribute4,
                    attribute5,
                    last_updated_by,
                    last_update_date,
                    creation_date,
                    created_by
                )
                    SELECT
                        formula_set_name,
                        formula_set_code,
                        description,
                        formula_type,
                        formula_text,
                        count_of_params,
                        attribute1,
                        attribute2,
                        attribute3,
                        attribute4,
                        attribute5,
                        last_updated_by,
                        last_update_date,
                        creation_date,
                        created_by
                    FROM
                        :p_source_pod.cr_formula_sets
                    WHERE
                            formula_set_id = i.mapping_set_id
                        AND formula_set_code = i.code;

                COMMIT;
            ELSE
                DELETE FROM :p_destinaion_pod.cr_mapping_values
                WHERE
                    map_set_id IN (
                        SELECT
                            map_set_id
                        FROM
                            :p_destinaion_pod.cr_mapping_sets
                        WHERE
                            map_set_code = i.code
                    );

                COMMIT;
                DELETE FROM :p_destinaion_pod.cr_mapping_sets
                WHERE
                    map_set_code = i.code;

                COMMIT;

                    dbms_output.put_line('Dlete Mapping  data');
                    dbms_output.put_line(i.code);
                    dbms_output.put_line(i.mapping_set_id);

				l_lookup_set_id:=null;
                select count(lookup_set_id) into l_lookup_check from :p_source_pod.cr_mapping_sets
                where MAP_SET_ID=i.mapping_set_id and LOOKUP_SET_ID is not null;

                if l_lookup_check>0 then
                select nvl(dl.lookup_set_id,null) into l_lookup_set_id
                    from :p_destinaion_pod.CR_LOOKUP_SETS dl,
                         :p_source_pod.cr_mapping_sets sm,
                         :p_source_pod.CR_LOOKUP_SETS sl
                    where
                        sm.MAP_SET_ID=i.mapping_set_id
                        and sm.LOOKUP_SET_ID=sl.LOOKUP_SET_ID
                        and sl.LOOKUP_SET_CODE=dl.LOOKUP_SET_CODE;

                end if;

                INSERT INTO :p_destinaion_pod.cr_mapping_sets (
                    map_set_name,
                    map_set_code,
                    map_set_type,
                    valiadtion_type,
                    lookup_set_id,
                    sql_query,
                    attribute1,
                    attribute2,
                    attribute3,
                    attribute4,
                    attribute5,
                    last_updated_by,
                    last_update_date,
                    creation_date,
                    created_by
                )
                    SELECT
                        map_set_name,
                        map_set_code,
                        map_set_type,
                        valiadtion_type,
                        l_lookup_set_id,
                        sql_query,
                        attribute1,
                        attribute2,
                        attribute3,
                        attribute4,
                        attribute5,
                        last_updated_by,
                        last_update_date,
                        creation_date,
                        created_by
                    FROM
                        :p_source_pod.cr_mapping_sets
                    WHERE
                            map_set_code = i.code
                        AND map_set_id = i.mapping_set_id;

                COMMIT;
                SELECT
                    map_set_id
                INTO l_map_set_id
                FROM
                    :p_destinaion_pod.cr_mapping_sets
                WHERE
                    map_set_code = i.code;

                INSERT INTO :p_destinaion_pod.cr_mapping_values (
                    map_set_id,
                    source_field1,
                    source_field2,
                    source_field3,
                    target_value,
                    enabled_flag,
                    attribute1,
                    attribute2,
                    attribute3,
                    attribute4,
                    attribute5,
                    last_updated_by,
                    last_update_date,
                    creation_date,
                    created_by
                )
                    SELECT
                        l_map_set_id,
                        source_field1,
                        source_field2,
                        source_field3,
                        target_value,
                        enabled_flag,
                        attribute1,
                        attribute2,
                        attribute3,
                        attribute4,
                        attribute5,
                        last_updated_by,
                        last_update_date,
                        creation_date,
                        created_by
                    FROM
                        :p_source_pod.cr_mapping_values
                    WHERE
                        map_set_id = i.mapping_set_id;

                COMMIT;
            END IF;
        END LOOP;
            dbms_output.put_line('Insert Map  data');
    END;

 ]';
    l_query_2    CLOB DEFAULT q'[
   --Source Meta Data
    BEGIN

            DELETE FROM :p_destinaion_pod.cr_source_columns
            WHERE
                table_id IN (
                select table_id from :p_destinaion_pod.cr_source_tables
                where TABLE_NAME in (
                    SELECT
                        TABLE_NAME
                    FROM
                        :p_source_pod.cr_source_tables
                    WHERE
                        table_id in (
                        SELECT
                        metadata_table_id
                        FROM
                        :p_source_pod.cr_src_template_hdrs
                        WHERE
                        project_id = l_project_id))
                );

            COMMIT;
            DELETE FROM :p_destinaion_pod.cr_source_tables
            WHERE
                TABLE_NAME IN (
                    SELECT
                        TABLE_NAME
                    FROM
                        :p_source_pod.cr_source_tables
                    WHERE
                        table_id in (
                        SELECT
                        metadata_table_id
                        FROM
                        :p_source_pod.cr_src_template_hdrs
                        WHERE
                        project_id = l_project_id)
                );
            COMMIT;

            DELETE FROM :p_destinaion_pod.CR_CLOUD_COLUMNS
            WHERE
                table_id IN (
                select table_id from :p_destinaion_pod.CR_CLOUD_TABLES
                where TABLE_NAME in (
                    SELECT
                        TABLE_NAME
                    FROM
                        :p_source_pod.CR_CLOUD_TABLES
                    WHERE
                        table_id in (
                        SELECT
                        metadata_table_id
                        FROM
                        :p_source_pod.CR_CLD_TEMPLATE_HDRS
                        WHERE
                        project_id = l_project_id))
                );

            COMMIT;
            DELETE FROM :p_destinaion_pod.CR_CLOUD_TABLES
            WHERE
                TABLE_NAME IN (
                    SELECT
                        TABLE_NAME
                    FROM
                        :p_source_pod.CR_CLOUD_TABLES
                    WHERE
                        table_id in (
                        SELECT
                        metadata_table_id
                        FROM
                        :p_source_pod.CR_CLD_TEMPLATE_HDRS
                        WHERE
                        project_id = l_project_id)
                );
            COMMIT;
        dbms_output.put_line('Source Meta Data');
        FOR i IN get_src_temp_details(l_project_id) LOOP
            dbms_output.put_line(i.src_template_id);
            dbms_output.put_line(i.src_template_code);

            DELETE FROM :p_destinaion_pod.cr_src_template_cols
            WHERE
                src_template_id IN ( SELECT
                        src_template_id
                    FROM
                        :p_destinaion_pod.cr_src_template_hdrs
                    WHERE
                        src_template_code = i.src_template_code );
            commit;

            DELETE FROM :p_destinaion_pod.cr_src_template_hdrs
            WHERE
                src_template_code IN ( i.src_template_code );

            COMMIT;

                dbms_output.put_line('Dlete Source Meta data');
        END LOOP;
        commit;
        --Insert Source Meta data
        FOR i IN get_src_temp_id(l_project_id) LOOP
            l_source_table_id := NULL;
            l_source_table_id := :p_destinaion_pod.cr_src_table_id_s.nextval; -- Destincation pod

            INSERT INTO :p_destinaion_pod.cr_source_tables
                SELECT
                    l_source_table_id,
                    table_name,
                    user_table_name,
                    description,
                    object_id,
                    application_id,
                    auto_size,
                    table_type,
                    initial_extent,
                    next_extent,
                    min_extents,
                    max_extents,
                    pct_increase,
                    ini_trans,
                    max_trans,
                    pct_free,
                    pct_used,
                    hosted_support_style,
                    irep_comments,
                    irep_annotations,
                    attribute1,
                    attribute2,
                    attribute3,
                    attribute4,
                    attribute5,
                    creation_date,
                    created_by,
                    last_update_date,
                    last_updated_by
                FROM
                    :p_source_pod.cr_source_tables
                WHERE
                    table_id = (
                        SELECT
                            metadata_table_id
                        FROM
                            :p_source_pod.cr_src_template_hdrs
                        WHERE
                            src_template_code = i.src_template_code
                    );

            COMMIT;
            INSERT INTO :p_destinaion_pod.cr_source_columns
                SELECT
                    l_source_table_id,
                    column_id,
                    column_name,
                    user_column_name,
                    description,
                    application_id,
                    column_sequence,
                    column_type,
                    width,
                    null_allowed_flag,
                    translate_flag,
                    flexfield_usage_code,
                    flexfield_application_id,
                    flexfield_name,
                    flex_value_set_application_id,
                    flex_value_set_id,
                    default_value,
                    precision,
                    scale,
                    irep_comments,
                    attribute1,
                    attribute2,
                    attribute3,
                    attribute4,
                    attribute5,
                    creation_date,
                    created_by,
                    last_update_date,
                    last_updated_by
                FROM
                    :p_source_pod.cr_source_columns
                WHERE
                    table_id = (
                        SELECT
                            metadata_table_id
                        FROM
                            :p_source_pod.cr_src_template_hdrs
                        WHERE
                            src_template_code = i.src_template_code
                    );

            COMMIT;

            INSERT INTO :p_destinaion_pod.cr_src_template_hdrs (
        src_template_name,
        src_template_code,
        project_id,
        parent_object_id,
        object_id,
        metadata_table_id,
        staging_table_name,
        normalize_data_flag,
        view_name,
        attribute1,
        attribute2,
        attribute3,
        attribute4,
        attribute5,
        creation_date,
        created_by,
        last_update_date,
        last_updated_by
    )
        SELECT
            src_template_name,
            src_template_code,
            project_id,
            parent_object_id,
            object_id,
            l_source_table_id,
            null,
            normalize_data_flag,
            view_name,
            attribute1,
            attribute2,
            attribute3,
            attribute4,
            attribute5,
            creation_date,
            created_by,
            last_update_date,
            last_updated_by
        FROM
            :p_source_pod.cr_src_template_hdrs
        WHERE
            SRC_TEMPLATE_ID=i.SRC_TEMPLATE_ID;-- Source Temp Headers
    COMMIT;
    SELECT
        src_template_id
    INTO l_src_temp_id
    FROM
        :p_destinaion_pod.cr_src_template_hdrs
    WHERE SRC_TEMPLATE_CODE=i.SRC_TEMPLATE_CODE;

                      FOR REC IN ( SELECT
                            l_src_temp_id src_template_id,
                            column_name,
                        column_type,
                        width,
                        display_seq,
                        selected,
                        unique_trans_ref,
                        attribute1,
                        attribute2,
                        attribute3,
                        attribute4,
                        attribute5,
                        creation_date,
                        created_by,
                        last_update_date,
                        last_updated_by
                        FROM
                            :p_source_pod.cr_src_template_cols
                        WHERE
                            src_template_id = i.SRC_TEMPLATE_ID
                        ORDER BY
                            column_id)
                    LOOP
                    INSERT INTO :p_destinaion_pod.cr_src_template_cols (
                        src_template_id,
                        column_name,
                        column_type,
                        width,
                        display_seq,
                        selected,
                        unique_trans_ref,
                        attribute1,
                        attribute2,
                        attribute3,
                        attribute4,
                        attribute5,
                        creation_date,
                        created_by,
                        last_update_date,
                        last_updated_by
                    ) values
                    (rec.src_template_id,
                    rec.column_name,
                        rec.column_type,
                        rec.width,
                        rec.display_seq,
                        rec.selected,
                        rec.unique_trans_ref,
                        rec.attribute1,
                        rec.attribute2,
                        rec.attribute3,
                        rec.attribute4,
                        rec.attribute5,
                        rec.creation_date,
                        rec.created_by,
                        rec.last_update_date,
                        rec.last_updated_by
                    );
                    COMMIT;
            end loop;
            commit;

            --Drop Existing Source Staging table_name
            l_table_chek:=0;
            select count(table_name) into l_table_chek from ALL_TABLES where owner=':p_destinaion_pod' and table_name=i.STAGING_TABLE_NAME;
            if (l_table_chek>0)
            then
            l_drop_stmt:='DROP TABLE '||':p_destinaion_pod'||'.'||i.STAGING_TABLE_NAME;
            --execute IMMEDIATE l_drop_stmt;
            commit;
            end if;
            --Create Source Stgaing Table
             begin
                :p_destinaion_pod.CR_CREATE_STG_TABLE_PROC(l_source_table_id,l_src_temp_id,i.src_template_code,'SOURCE','',l_ret_code,l_ret_msg);
                end;

        END LOOP;
        dbms_output.put_line('Insert Source meta  data');
    END;
 ]';
    l_query_3    CLOB DEFAULT q'[
   BEGIN
        FOR i IN get_cld_temp_details(l_project_id) LOOP
            dbms_output.put_line(i.cld_template_id);

            DELETE FROM :p_destinaion_pod.cr_cld_template_cols
            WHERE
                cld_template_id IN ( i.cld_template_id );

            DELETE FROM :p_destinaion_pod.cr_cld_template_hdrs
            WHERE
                cld_template_id IN ( i.cld_template_id );

            COMMIT;
                dbms_output.put_line('Dlete Cloud Meta data');
        END LOOP;
        --Insert Cloud MetaData
        FOR i IN get_cld_temp_id(l_project_id) LOOP
            l_cloud_table_id := :p_destinaion_pod.cr_cld_table_id_s.nextval;
            INSERT INTO :p_destinaion_pod.cr_cloud_tables
                SELECT
                    l_cloud_table_id,
                    table_name,
                    physical_table_name,
                    user_table_name,
                    description,
                    object_id,
                    parent_object_id,
                    application_short_name,
                    table_type,
                    hosted_support_style,
                    logical,
                    mls_support_model,
                    status,
                    deploy_to,
                    extension_of_table,
                    short_name,
                    shared_object,
                    conflict_resolution,
                    tablespace_type,
                    select_allowed,
                    insert_allowed,
                    update_allowed,
                    delete_allowed,
                    truncate_allowed,
                    maintain_partition,
                    exchange_partition,
                    maintain_index,
                    flashback_allowed,
                    enable_audit,
                    ora_edition_context,
                    attribute1,
                    attribute2,
                    attribute3,
                    attribute4,
                    attribute5,
                    creation_date,
                    created_by,
                    last_update_date,
                    last_updated_by
                FROM
                    :p_source_pod.cr_cloud_tables
                WHERE
                    table_id IN (
                        SELECT
                            metadata_table_id
                        FROM
                            :p_source_pod.cr_cld_template_hdrs
                        WHERE
                            cld_template_code = i.cld_template_code
                    );

            COMMIT;
            INSERT INTO :p_destinaion_pod.cr_cloud_columns (
                column_id,
                column_name,
                physical_column_name,
                user_column_name,
                description,
                table_id,
                object_id,
                status,
                short_name,
                ora_edition_context,
                column_sequence,
                column_type,
                width,
                null_allowed_flag,
                translate_flag,
                precision,
                scale,
                domain_code,
                denorm_path,
                routing_mode,
                cloud_version,
                eligible_to_be_secured,
                security_classification,
                sec_classification_override,
                attribute1,
                attribute2,
                attribute3,
                attribute4,
                attribute5,
                creation_date,
                created_by,
                last_update_date,
                last_updated_by
            )
                SELECT
                    column_id,
                    column_name,
                    physical_column_name,
                    user_column_name,
                    description,
                    l_cloud_table_id,
                    object_id,
                    status,
                    short_name,
                    ora_edition_context,
                    column_sequence,
                    column_type,
                    width,
                    null_allowed_flag,
                    translate_flag,
                    precision,
                    scale,
                    domain_code,
                    denorm_path,
                    routing_mode,
                    cloud_version,
                    eligible_to_be_secured,
                    security_classification,
                    sec_classification_override,
                    attribute1,
                    attribute2,
                    attribute3,
                    attribute4,
                    attribute5,
                    creation_date,
                    created_by,
                    last_update_date,
                    last_updated_by
                FROM
                    :p_source_pod.cr_cloud_columns
                WHERE
                    table_id IN (
                        SELECT
                            metadata_table_id
                        FROM
                            :p_source_pod.cr_cld_template_hdrs
                        WHERE
                            cld_template_code = i.cld_template_code
                    );

            COMMIT;
            INSERT INTO :p_destinaion_pod.cr_cld_template_hdrs (
                cld_template_name,
                cld_template_code,
                cloud_version,
                project_id,
                parent_object_id,
                object_id,
                metadata_table_id,
                src_template_id,
                staging_table_name,
                view_name,
                primary_template_flag,
                attribute1,
                attribute2,
                attribute3,
                attribute4,
                attribute5,
                creation_date,
                created_by,
                last_update_date,
                last_updated_by
            )
                SELECT
                    cld_template_name,
                    cld_template_code,
                    cloud_version,
                    project_id,
                    parent_object_id,
                    object_id,
                    l_cloud_table_id,
                    l_src_temp_id,
                    NULL,
                    view_name,
                    primary_template_flag,
                    attribute1,
                    attribute2,
                    attribute3,
                    attribute4,
                    attribute5,
                    creation_date,
                    created_by,
                    last_update_date,
                    last_updated_by
                FROM
                    :p_source_pod.cr_cld_template_hdrs
                WHERE
                    cld_template_id = i.cld_template_id;

            COMMIT;
            SELECT
                cld_template_id
            INTO l_cld_temp_id
            FROM
                :p_destinaion_pod.cr_cld_template_hdrs
            WHERE
                cld_template_code = i.cld_template_code;


            FOR l_get_cld_temp_cols_details IN get_cld_temp_cols_details(i.cld_template_id) LOOP
                l_map_set_id := NULL;
                l_src_col_id := NULL;
                IF l_get_cld_temp_cols_details.source_column_id IS NOT NULL THEN
                    SELECT
                        nvl(column_id,null)
                    INTO l_src_col_id
                    FROM
                        :p_destinaion_pod.cr_src_template_cols
                    WHERE
                        src_template_id IN (
                            SELECT
                                src_template_id
                            FROM
                                :p_destinaion_pod.cr_src_template_hdrs
                            WHERE
                                object_id = i.OBJECT_ID
                                AND PROJECT_ID=l_project_id
                        )
                        AND column_name = (
                            SELECT
                                column_name
                            FROM
                                :p_source_pod.cr_src_template_cols
                            WHERE
                                    column_id = l_get_cld_temp_cols_details.source_column_id
                                AND src_template_id = (
                                    SELECT
                                        src_template_id
                                    FROM
                                        :p_source_pod.cr_src_template_hdrs
                                    WHERE
                                        object_id = i.OBJECT_ID
                                        AND PROJECT_ID=l_project_id
                                )
                        );

                END IF;

                IF
                    l_get_cld_temp_cols_details.mapping_type NOT IN ( 'Formula', 'As-Is', 'Constant' )
                    AND l_get_cld_temp_cols_details.mapping_set_id IS NOT NULL
                THEN
                    select case
                    when exists(SELECT
                                1
                            FROM
                                :p_source_pod.cr_mapping_sets
                            WHERE
                                map_set_id = l_get_cld_temp_cols_details.mapping_set_id) then (SELECT
                        map_set_id

                    FROM
                        :p_destinaion_pod.cr_mapping_sets
                    WHERE
                        map_set_code = (
                            SELECT
                                map_set_code
                            FROM
                                :p_source_pod.cr_mapping_sets
                            WHERE
                                map_set_id = l_get_cld_temp_cols_details.mapping_set_id
                        ))
                        else  null end INTO l_map_set_id from dual;

                END IF;

                IF
                    l_get_cld_temp_cols_details.mapping_type IN ( 'Formula' )
                    AND l_get_cld_temp_cols_details.mapping_set_id IS NOT NULL
                THEN
                select case
                when exists(SELECT
                                distinct 1
                            FROM
                                :p_source_pod.cr_formula_sets
                            WHERE
                                formula_set_id = l_get_cld_temp_cols_details.mapping_set_id)
                then (SELECT
                        formula_set_id
                    FROM
                        :p_destinaion_pod.cr_formula_sets
                    WHERE
                        formula_set_code = (
                            SELECT
                                formula_set_code
                            FROM
                                :p_source_pod.cr_formula_sets
                            WHERE
                                formula_set_id = l_get_cld_temp_cols_details.mapping_set_id
                        ))
                else null end into l_map_set_id from dual;

                END IF;

                INSERT INTO :p_destinaion_pod.cr_cld_template_cols (
                    column_name,
                    cld_template_id,
                    description,
                    column_type,
                    width,
                    display_seq,
                    null_allowed_flag,
                    unique_trans_ref,
                    selected,
                    source_column_id,
                    mapping_type,
                    mapping_set_id,
                    mapping_value1,
                    mapping_value2,
                    mapping_value3,
                    mapping_value4,
                    mapping_value5,
                    attribute1,
                    attribute2,
                    attribute3,
                    attribute4,
                    attribute5,
                    creation_date,
                    created_by,
                    last_update_date,
                    last_updated_by
                ) VALUES (
                    l_get_cld_temp_cols_details.column_name,
                    l_cld_temp_id,
                    l_get_cld_temp_cols_details.description,
                    l_get_cld_temp_cols_details.column_type,
                    l_get_cld_temp_cols_details.width,
                    l_get_cld_temp_cols_details.display_seq,
                    l_get_cld_temp_cols_details.null_allowed_flag,
                    l_get_cld_temp_cols_details.unique_trans_ref,
                    l_get_cld_temp_cols_details.selected,
                    l_src_col_id,
                    l_get_cld_temp_cols_details.mapping_type,
                    l_map_set_id,
                    l_get_cld_temp_cols_details.mapping_value1,
                    l_get_cld_temp_cols_details.mapping_value2,
                    l_get_cld_temp_cols_details.mapping_value3,
                    l_get_cld_temp_cols_details.mapping_value4,
                    l_get_cld_temp_cols_details.mapping_value5,
                    l_get_cld_temp_cols_details.attribute1,
                    l_get_cld_temp_cols_details.attribute2,
                    l_get_cld_temp_cols_details.attribute3,
                    l_get_cld_temp_cols_details.attribute4,
                    l_get_cld_temp_cols_details.attribute5,
                    l_get_cld_temp_cols_details.creation_date,
                    l_get_cld_temp_cols_details.created_by,
                    l_get_cld_temp_cols_details.last_update_date,
                    l_get_cld_temp_cols_details.last_updated_by
                );

                COMMIT;
            END LOOP;
            l_table_chek:=0;
             --Drop Existing Cloud Staging table_name
            select count(table_name) into l_table_chek from ALL_TABLES where owner=':p_destinaion_pod' and table_name=i.STAGING_TABLE_NAME;
            if (l_table_chek>0)
            then
            l_drop_stmt:='DROP TABLE '||':p_destinaion_pod'||'.'||i.STAGING_TABLE_NAME;
            --execute IMMEDIATE l_drop_stmt;
            commit;
            end if;
            --Create Cloud Staging Table
                begin
                :p_destinaion_pod.CR_CREATE_STG_TABLE_PROC(l_cloud_table_id,l_cld_temp_id,i.cld_template_code,'CLOUD','',l_ret_code,l_ret_msg);
                end;
    --UserHooks
    dbms_output.put_line('--User Hooks--');
    dbms_output.put_line(i.cld_template_id);
    begin
        for x in get_userhook_details(i.cld_template_id) loop
            begin
            DBMS_LOB.createtemporary(l_uh_clob, TRUE);
            DBMS_LOB.APPEND (l_uh_clob,'CREATE OR REPLACE ');
            for k in (select text from all_source
                        where type='PROCEDURE'
                        and owner=upper(':p_source_pod')
                        AND NAME=upper(x.userhook)
                        order by line)
            loop
                DBMS_LOB.APPEND(l_uh_clob,k.text);
            end loop;
            l_uh_clob:=replace(l_uh_clob,'PROCEDURE ','PROCEDURE '||':p_destinaion_pod'||'.');
            --dbms_output.put_line(l_uh_clob);
                begin
                execute immediate l_uh_clob;
                exception when others then
                dbms_output.put_line(sqlerrm);
                end
                commit;
            end;
        end loop;
        dbms_output.put_line('--User Hooks Completed--');
    end;

    --Insert CR_HOOK_USAGES Data
        l_uh_check:=0;
        select count(*) into l_uh_check from :p_source_pod.CR_HOOK_USAGES where template_id=i.cld_template_id;

        IF l_uh_check > 0 THEN
        for k in (SELECT DISTINCT
        c.hook_id t_hook_id,
        b.hook_id s_hook_id
        FROM
        :p_source_pod.cr_hook_usages a,
        :p_source_pod.cr_user_hooks  b,
        :p_destinaion_pod.cr_user_hooks    c
        WHERE
            c.hook_code = b.hook_code
        AND a.template_id = i.cld_template_id
        AND a.hook_id = b.hook_id)
        loop
            insert into :p_destinaion_pod.CR_HOOK_USAGES(HOOK_ID,TEMPLATE_ID,USAGE_TYPE,ATTRIBUTE1,ATTRIBUTE2,ATTRIBUTE3,ATTRIBUTE4,ATTRIBUTE5,CREATION_DATE,CREATED_BY,LAST_UPDATE_DATE,LAST_UPDATED_BY)
            select k.t_hook_id,l_cld_temp_id,USAGE_TYPE,ATTRIBUTE1,ATTRIBUTE2,ATTRIBUTE3,ATTRIBUTE4,ATTRIBUTE5,CREATION_DATE,CREATED_BY,LAST_UPDATE_DATE,LAST_UPDATED_BY
            from :p_source_pod.cr_hook_usages where template_id = i.cld_template_id and HOOK_ID=k.s_hook_id;
            commit;
        end loop;
    END IF;

        END LOOP;
        dbms_output.put_line('Insert Cld Meta  data');
    END;

        --Object Grouping
    begin


    for x in get_exist_object_group_details(l_project_id) loop
     --Delete existing Object Grouping Details

     delete from :p_destinaion_pod.CR_OBJECT_GROUP_LINES
            where GROUP_ID in (select GROUP_ID from EMPTY.CR_OBJECT_GROUP_HDRS
                                    where GROUP_CODE=x.GROUP_CODE and project_id=l_project_id);

    delete from :p_destinaion_pod.CR_OBJECT_GROUP_HDRS where GROUP_CODE=x.GROUP_CODE and project_id=l_project_id;
    commit;

    insert into :p_destinaion_pod.CR_OBJECT_GROUP_HDRS (PROJECT_ID, PARENT_OBJECT_ID, GROUP_NAME, GROUP_CODE, DESCRIPTION, ATTRIBUTE1, ATTRIBUTE2, ATTRIBUTE3, ATTRIBUTE4, ATTRIBUTE5, CREATION_DATE, CREATED_BY, LAST_UPDATE_DATE, LAST_UPDATED_BY)
    select PROJECT_ID, PARENT_OBJECT_ID, GROUP_NAME, GROUP_CODE, DESCRIPTION, ATTRIBUTE1, ATTRIBUTE2, ATTRIBUTE3, ATTRIBUTE4, ATTRIBUTE5, CREATION_DATE, CREATED_BY, LAST_UPDATE_DATE, LAST_UPDATED_BY from :p_source_pod.CR_OBJECT_GROUP_HDRS where GROUP_CODE=x.GROUP_CODE and project_id=l_project_id;
    commit;

    select GROUP_ID into l_GROUP_ID from :p_destinaion_pod.CR_OBJECT_GROUP_HDRS where GROUP_CODE=x.GROUP_CODE and project_id=l_project_id;

    insert into :p_destinaion_pod.CR_OBJECT_GROUP_LINES(GROUP_ID, OBJECT_ID, SEQUENCE, ATTRIBUTE1, ATTRIBUTE2, ATTRIBUTE3, ATTRIBUTE4, ATTRIBUTE5, CREATION_DATE, CREATED_BY, LAST_UPDATE_DATE, LAST_UPDATED_BY)
    select l_GROUP_ID, OBJECT_ID, SEQUENCE, ATTRIBUTE1, ATTRIBUTE2, ATTRIBUTE3, ATTRIBUTE4, ATTRIBUTE5, CREATION_DATE, CREATED_BY, LAST_UPDATE_DATE, LAST_UPDATED_BY from :p_source_pod.CR_OBJECT_GROUP_LINES
                        where GROUP_ID in (select GROUP_ID from :p_source_pod.CR_OBJECT_GROUP_HDRS
                                    where GROUP_CODE=x.GROUP_CODE and project_id=l_project_id);
    commit;


    end loop;

    end;

END;
 ]';

BEGIN
    dbms_lob.createtemporary(l_final_clob, true);
    dbms_lob.append(l_final_clob, l_query_1);
    dbms_lob.append(l_final_clob, l_query_2);
    dbms_lob.append(l_final_clob, l_query_3);

    l_final_clob := replace(l_final_clob, ':p_source_pod', p_source_pod);
    l_final_clob := replace(l_final_clob, ':p_destinaion_pod', p_destinaion_pod);
    l_final_clob := replace(l_final_clob, ':p_project_name', p_project_name);

    dbms_output.put_line('---------Final Clob-------------');



    EXECUTE IMMEDIATE l_final_clob;
    p_msg := 'POD DETAILS COPIED SUCCESSFULLY';
    p_result := 'Y';
    dbms_output.put_line(p_msg);
EXCEPTION
    WHEN OTHERS THEN
        p_msg := 'POD DETAILS COPY Failed'||sqlerrm;
        p_result := 'N';
        dbms_output.put_line(p_msg);
END;

 $#$

create or replace PROCEDURE cr_copy_proc(
    p_source_pod     IN VARCHAR2,
    p_destinaion_pod IN VARCHAR2,
    p_project_name   IN VARCHAR2,
    p_msg            OUT VARCHAR2,
    p_result         OUT VARCHAR2
) AS

    l_final_clob CLOB;
    l_query_1    CLOB DEFAULT q'[
 DECLARE
    TYPE varchartab IS
        TABLE OF VARCHAR2(420);
    TYPE numtab IS
        TABLE OF NUMBER;
    l_object_codes         varchartab;
    l_object_id            numtab;
    l_object_code          varchartab;
    l_src_template_id      numtab;
    l_cld_template_id      numtab;
    l_parent_object        varchartab;
    l_source_table_id      NUMBER;
    l_projectexists        NUMBER; -- Variable to store whether the project exists (1) or not (0)
    l_project_id           NUMBER;
    l_src_temp_id          NUMBER;
    l_cld_temp_id          NUMBER;
    l_obj_list             VARCHAR2(2000);
    l_cloud_table_id       NUMBER;
    l_map_set_count        NUMBER;
    l_map_set_id           NUMBER;
    l_formula_count        NUMBER;
    l_count                NUMBER;
    l_cld_count            NUMBER;
    l_src_col_id           NUMBER;
    l_dest_src_temp_check  NUMBER;
    l_dest_cld_temp_check  NUMBER;
    l_map_set_check        NUMBER;
    l_uh_clob clob;
    l_HOOK_ID number;
    l_uh_check number;
    l_ret_code varchar2(250);
    l_ret_msg varchar2(250);
    l_drop_stmt varchar2(2000);
    l_table_chek number;
	l_lookup_set_id NUMBER;
    l_lookup_check number;
    CURSOR get_src_temp_details (
        l_project_id IN NUMBER
    ) IS
    SELECT
        src_template_id,
        src_template_code,
        STAGING_TABLE_NAME
    FROM
        :p_destinaion_pod.cr_src_template_hdrs
    WHERE
        src_template_code in (select src_template_code from :p_source_pod.cr_src_template_hdrs where project_id = l_project_id);

    CURSOR get_cld_temp_details (
        l_project_id IN NUMBER
    ) IS
    SELECT
        cld_template_id,
        cld_template_code,
        STAGING_TABLE_NAME
    FROM
        :p_destinaion_pod.cr_cld_template_hdrs
    WHERE
         project_id = l_project_id;

    CURSOR get_src_temp_id (
        l_project_id IN NUMBER
    ) IS
    SELECT
        src_template_id,
        src_template_code,STAGING_TABLE_NAME
    FROM
        :p_source_pod.cr_src_template_hdrs
    WHERE
        project_id = l_project_id;

    CURSOR get_cld_temp_id (
        l_project_id IN NUMBER
    ) IS
    SELECT
        cld_template_id,
        cld_template_code,
        object_id,STAGING_TABLE_NAME
    FROM
        :p_source_pod.cr_cld_template_hdrs
    WHERE
        project_id = l_project_id;

    CURSOR get_cld_temp_cols_details (
        p_template_id IN NUMBER
    ) IS
    SELECT
        *
    FROM
        :p_source_pod.cr_cld_template_cols
    WHERE
        cld_template_id = p_template_id
    ORDER BY
        column_id;

    CURSOR get_mapping_details (
        l_project_id IN NUMBER
    ) IS
    SELECT DISTINCT
        cols.mapping_set_id,
        cols.mapping_type,
        CASE
            WHEN cols.mapping_type IN ( 'One to One', 'Two to One', 'Three to One' ) THEN
                (
                    SELECT
                        map_set_code
                    FROM
                        :p_source_pod.cr_mapping_sets
                    WHERE
                        map_set_id = cols.mapping_set_id
                )
            WHEN cols.mapping_type IN ( 'Formula' ) THEN
                (
                    SELECT
                        formula_set_code
                    FROM
                        :p_source_pod.cr_formula_sets
                    WHERE
                        formula_set_id = cols.mapping_set_id
                )
        END code
    FROM
        :p_source_pod.cr_cld_template_hdrs hdrs,
        :p_source_pod.cr_cld_template_cols cols,
        :p_source_pod.cr_formula_sets f,
        :p_source_pod.cr_mapping_sets m
    WHERE
            hdrs.project_id = l_project_id
        AND hdrs.cld_template_id = cols.cld_template_id
        AND mapping_type IN ( 'One to One', 'Two to One', 'Three to One', 'Formula' )
        and (cols.mapping_set_id=f.formula_set_id or cols.mapping_set_id=m.map_set_id);

    CURSOR get_userhook_details (
        l_cld_template_id IN NUMBER
    ) IS
    select distinct dbms_lob.substr(cuh.HOOK_TEXT,instr(cuh.HOOK_TEXT,'(')-1) userhook
    from :p_source_pod.CR_HOOK_USAGES chu,
    :p_source_pod.CR_USER_HOOKS cuh
    where chu.TEMPLATE_ID=l_cld_template_id
    and chu.HOOK_ID=cuh.HOOK_ID;

    CURSOR get_exist_uh_details (
        l_cld_template_id IN NUMBER
    ) IS
    select distinct chu.HOOK_ID,cuh.HOOK_CODE,dbms_lob.substr(cuh.HOOK_TEXT,instr(cuh.HOOK_TEXT,'(')-1) userhook
    from :p_source_pod.CR_HOOK_USAGES chu,
    :p_source_pod.CR_USER_HOOKS cuh
    where chu.TEMPLATE_ID in (select cld_template_id
                            from :p_source_pod.cr_cld_template_hdrs
                            WHERE project_id = l_project_id)
    and chu.HOOK_ID=cuh.HOOK_ID;

	CURSOR get_lookup_details (
        l_project_id IN NUMBER
    ) IS
    SELECT DISTINCT
        ls.LOOKUP_SET_ID,
        ls.LOOKUP_SET_CODE
    FROM
        :p_source_pod.cr_cld_template_hdrs hdrs,
        :p_source_pod.cr_cld_template_cols cols,
        :p_source_pod.cr_mapping_sets m,
        :p_source_pod.CR_LOOKUP_SETS ls
    WHERE
            hdrs.project_id = l_project_id
        AND hdrs.cld_template_id = cols.cld_template_id
        AND  cols.mapping_set_id=m.map_set_id
        and m.LOOKUP_SET_ID=ls.LOOKUP_SET_ID;

BEGIN
    -- Check if the project exists in the table
    l_projectexists := 0;
    SELECT
        nvl(COUNT(project_name), 0)
    INTO l_projectexists
    FROM
        :p_destinaion_pod.cr_projects
    WHERE
        project_name = ':p_project_name';

    SELECT
        project_id
    INTO l_project_id
    FROM
        :p_source_pod.cr_projects
    WHERE
            project_name = ':p_project_name'
        AND ROWNUM = 1;

    IF l_projectexists > 0 THEN
        DELETE FROM :p_destinaion_pod.cr_projects
        WHERE
            project_id = l_project_id;

        DELETE FROM :p_destinaion_pod.cr_project_objects
        WHERE
            project_id = l_project_id;

        DELETE FROM :p_destinaion_pod.cr_proj_activities
        WHERE
            project_id = l_project_id;

        COMMIT;
            dbms_output.put_line('Dlete proj  data');
    END IF;

    --Inserting from the Source pod to destintion pod (Project Details )

    INSERT INTO :p_destinaion_pod.cr_projects
        SELECT
            *
        FROM
            :p_source_pod.cr_projects
        WHERE
            project_id = l_project_id;

    COMMIT;
    INSERT INTO :p_destinaion_pod.cr_project_objects
        SELECT
            *
        FROM
            :p_source_pod.cr_project_objects
        WHERE
            project_id = l_project_id;

    COMMIT;
    INSERT INTO :p_destinaion_pod.cr_proj_activities (
        project_id,
        seq,
        task_num,
        task_name,
        object_id,
        task_type,
        pre_req_task,
        start_date,
        end_date,
        weightage,
        complete_percentage,
        legacy_resource_id,
        task_status,
        destination_resource_id,
        task_owner_id,
        completion_flag,
        cloud_resource_id,
        integrator_resource_id,
        client_resource_id,
        attribute1,
        attribute2,
        attribute3,
        attribute4,
        attribute5,
        last_updated_by,
        last_update_date,
        creation_date,
        created_by
    )
        SELECT
            project_id,
            seq,
            task_num,
            task_name,
            object_id,
            task_type,
            pre_req_task,
            start_date,
            end_date,
            weightage,
            complete_percentage,
            legacy_resource_id,
            task_status,
            destination_resource_id,
            task_owner_id,
            completion_flag,
            cloud_resource_id,
            integrator_resource_id,
            client_resource_id,
            attribute1,
            attribute2,
            attribute3,
            attribute4,
            attribute5,
            last_updated_by,
            last_update_date,
            creation_date,
            created_by
        FROM
            :p_source_pod.cr_proj_activities
        WHERE
            project_id = l_project_id;

    COMMIT;
            dbms_output.put_line('Insert proj  data');

    -- Delete Existing Userhooks data
    begin
    for x in (select distinct cuh.HOOK_CODE
    from :p_source_pod.CR_HOOK_USAGES chu,
    :p_source_pod.CR_USER_HOOKS cuh
    where chu.TEMPLATE_ID in (select cld_template_id
                            from :p_source_pod.cr_cld_template_hdrs
                            WHERE project_id = l_project_id)
    and chu.HOOK_ID=cuh.HOOK_ID)
    loop
        delete from :p_destinaion_pod.CR_HOOK_USAGES
                where HOOK_ID in (select distinct HOOK_ID from :p_destinaion_pod.CR_USER_HOOKS where HOOK_CODE=x.HOOK_CODE);
                commit;
            delete from :p_destinaion_pod.CR_USER_HOOKS where HOOK_CODE=x.HOOK_CODE;
            commit;
            insert into :p_destinaion_pod.CR_USER_HOOKS(
            HOOK_TYPE,HOOK_NAME,HOOK_CODE,DESCRIPTION,HOOK_TEXT,ATTRIBUTE1,ATTRIBUTE2,ATTRIBUTE3,ATTRIBUTE4,ATTRIBUTE5,CREATION_DATE,CREATED_BY,LAST_UPDATE_DATE,LAST_UPDATED_BY)
            select HOOK_TYPE,HOOK_NAME,HOOK_CODE,DESCRIPTION,HOOK_TEXT,ATTRIBUTE1,ATTRIBUTE2,ATTRIBUTE3,ATTRIBUTE4,ATTRIBUTE5,CREATION_DATE,CREATED_BY,LAST_UPDATE_DATE,LAST_UPDATED_BY
            from :p_source_pod.CR_USER_HOOKS where HOOK_CODE=x.HOOK_CODE;
            commit;
    end loop;
    end;

	 --Lookup details
    begin
        for i in get_lookup_details(l_project_id) loop
            l_lookup_set_id:=null;
            --Delete Existing Lookup Values from Destination POD
            delete from :p_destinaion_pod.CR_LOOKUP_VALUES
                where LOOKUP_SET_ID in (select LOOKUP_SET_ID from :p_destinaion_pod.CR_LOOKUP_SETS where LOOKUP_SET_CODE=i.LOOKUP_SET_CODE);
            commit;
            --Delete Existing Lookup Sets from Destination POD
            delete from :p_destinaion_pod.CR_LOOKUP_SETS where LOOKUP_SET_CODE=i.LOOKUP_SET_CODE;
            commit;
            --Insert Lookup Sets into Destination POD
            insert into :p_destinaion_pod.CR_LOOKUP_SETS(LOOKUP_SET_NAME,LOOKUP_SET_CODE,DESCRIPTION,RELATED_TO,LOOKUP_FLAG,ATTRIBUTE1,ATTRIBUTE2,ATTRIBUTE3,ATTRIBUTE4,ATTRIBUTE5,LAST_UPDATED_BY,LAST_UPDATE_DATE,CREATION_DATE,CREATED_BY)
            select LOOKUP_SET_NAME,LOOKUP_SET_CODE,DESCRIPTION,RELATED_TO,LOOKUP_FLAG,ATTRIBUTE1,ATTRIBUTE2,ATTRIBUTE3,ATTRIBUTE4,ATTRIBUTE5,LAST_UPDATED_BY,LAST_UPDATE_DATE,CREATION_DATE,CREATED_BY from :p_source_pod.CR_LOOKUP_SETS
            where LOOKUP_SET_ID=i.LOOKUP_SET_ID and LOOKUP_SET_CODE=i.LOOKUP_SET_CODE;
            commit;

            select distinct LOOKUP_SET_ID into l_lookup_set_id
            from :p_destinaion_pod.CR_LOOKUP_SETS where LOOKUP_SET_CODE=i.LOOKUP_SET_CODE;
            --Insert Lookup Values into Destination POD
            insert into :p_destinaion_pod.CR_LOOKUP_VALUES(LOOKUP_VALUE,LOOKUP_SET_ID,ACTUAL_VALUE,ATTRIBUTE1,ATTRIBUTE2,ATTRIBUTE3,ATTRIBUTE4,ATTRIBUTE5,ENABLED_FLAG,LAST_UPDATED_BY,LAST_UPDATE_DATE,CREATION_DATE,CREATED_BY)
            select LOOKUP_VALUE,l_lookup_set_id,ACTUAL_VALUE,ATTRIBUTE1,ATTRIBUTE2,ATTRIBUTE3,ATTRIBUTE4,ATTRIBUTE5,ENABLED_FLAG,LAST_UPDATED_BY,LAST_UPDATE_DATE,CREATION_DATE,CREATED_BY from :p_source_pod.CR_LOOKUP_VALUES
            WHERE LOOKUP_SET_ID=i.LOOKUP_SET_ID;
            COMMIT;
        end loop;
    end;

  --Mapping Sets
    BEGIN
        FOR i IN get_mapping_details(l_project_id) LOOP
            IF i.mapping_type = 'Formula' THEN
                DELETE FROM :p_destinaion_pod.cr_formula_sets
                WHERE
                    formula_set_id = i.mapping_set_id;

                COMMIT;
                INSERT INTO :p_destinaion_pod.cr_formula_sets (
                    formula_set_name,
                    formula_set_code,
                    description,
                    formula_type,
                    formula_text,
                    count_of_params,
                    attribute1,
                    attribute2,
                    attribute3,
                    attribute4,
                    attribute5,
                    last_updated_by,
                    last_update_date,
                    creation_date,
                    created_by
                )
                    SELECT
                        formula_set_name,
                        formula_set_code,
                        description,
                        formula_type,
                        formula_text,
                        count_of_params,
                        attribute1,
                        attribute2,
                        attribute3,
                        attribute4,
                        attribute5,
                        last_updated_by,
                        last_update_date,
                        creation_date,
                        created_by
                    FROM
                        :p_source_pod.cr_formula_sets
                    WHERE
                            formula_set_id = i.mapping_set_id
                        AND formula_set_code = i.code;

                COMMIT;
            ELSE
                DELETE FROM :p_destinaion_pod.cr_mapping_values
                WHERE
                    map_set_id IN (
                        SELECT
                            map_set_id
                        FROM
                            :p_destinaion_pod.cr_mapping_sets
                        WHERE
                            map_set_code = i.code
                    );

                COMMIT;
                DELETE FROM :p_destinaion_pod.cr_mapping_sets
                WHERE
                    map_set_code = i.code;

                COMMIT;

                    dbms_output.put_line('Dlete Mapping  data');
                    dbms_output.put_line(i.code);
                    dbms_output.put_line(i.mapping_set_id);

				l_lookup_set_id:=null;
                select count(lookup_set_id) into l_lookup_check from :p_source_pod.cr_mapping_sets
                where MAP_SET_ID=i.mapping_set_id and LOOKUP_SET_ID is not null;

                if l_lookup_check>0 then
                select nvl(dl.lookup_set_id,null) into l_lookup_set_id
                    from :p_destinaion_pod.CR_LOOKUP_SETS dl,
                         :p_source_pod.cr_mapping_sets sm,
                         :p_source_pod.CR_LOOKUP_SETS sl
                    where
                        sm.MAP_SET_ID=i.mapping_set_id
                        and sm.LOOKUP_SET_ID=sl.LOOKUP_SET_ID
                        and sl.LOOKUP_SET_CODE=dl.LOOKUP_SET_CODE;

                end if;

                INSERT INTO :p_destinaion_pod.cr_mapping_sets (
                    map_set_name,
                    map_set_code,
                    map_set_type,
                    valiadtion_type,
                    lookup_set_id,
                    sql_query,
                    attribute1,
                    attribute2,
                    attribute3,
                    attribute4,
                    attribute5,
                    last_updated_by,
                    last_update_date,
                    creation_date,
                    created_by
                )
                    SELECT
                        map_set_name,
                        map_set_code,
                        map_set_type,
                        valiadtion_type,
                        l_lookup_set_id,
                        sql_query,
                        attribute1,
                        attribute2,
                        attribute3,
                        attribute4,
                        attribute5,
                        last_updated_by,
                        last_update_date,
                        creation_date,
                        created_by
                    FROM
                        :p_source_pod.cr_mapping_sets
                    WHERE
                            map_set_code = i.code
                        AND map_set_id = i.mapping_set_id;

                COMMIT;
                SELECT
                    map_set_id
                INTO l_map_set_id
                FROM
                    :p_destinaion_pod.cr_mapping_sets
                WHERE
                    map_set_code = i.code;

                INSERT INTO :p_destinaion_pod.cr_mapping_values (
                    map_set_id,
                    source_field1,
                    source_field2,
                    source_field3,
                    target_value,
                    enabled_flag,
                    attribute1,
                    attribute2,
                    attribute3,
                    attribute4,
                    attribute5,
                    last_updated_by,
                    last_update_date,
                    creation_date,
                    created_by
                )
                    SELECT
                        l_map_set_id,
                        source_field1,
                        source_field2,
                        source_field3,
                        target_value,
                        enabled_flag,
                        attribute1,
                        attribute2,
                        attribute3,
                        attribute4,
                        attribute5,
                        last_updated_by,
                        last_update_date,
                        creation_date,
                        created_by
                    FROM
                        :p_source_pod.cr_mapping_values
                    WHERE
                        map_set_id = i.mapping_set_id;

                COMMIT;
            END IF;
        END LOOP;
            dbms_output.put_line('Insert Map  data');
    END;

 ]';
    l_query_2    CLOB DEFAULT q'[
   --Source Meta Data
    BEGIN

            DELETE FROM :p_destinaion_pod.cr_source_columns
            WHERE
                table_id IN (
                select table_id from :p_destinaion_pod.cr_source_tables
                where TABLE_NAME in (
                    SELECT
                        TABLE_NAME
                    FROM
                        :p_source_pod.cr_source_tables
                    WHERE
                        table_id in (
                        SELECT
                        metadata_table_id
                        FROM
                        :p_source_pod.cr_src_template_hdrs
                        WHERE
                        project_id = l_project_id))
                );

            COMMIT;
            DELETE FROM :p_destinaion_pod.cr_source_tables
            WHERE
                TABLE_NAME IN (
                    SELECT
                        TABLE_NAME
                    FROM
                        :p_source_pod.cr_source_tables
                    WHERE
                        table_id in (
                        SELECT
                        metadata_table_id
                        FROM
                        :p_source_pod.cr_src_template_hdrs
                        WHERE
                        project_id = l_project_id)
                );
            COMMIT;

            DELETE FROM :p_destinaion_pod.CR_CLOUD_COLUMNS
            WHERE
                table_id IN (
                select table_id from :p_destinaion_pod.CR_CLOUD_TABLES
                where TABLE_NAME in (
                    SELECT
                        TABLE_NAME
                    FROM
                        :p_source_pod.CR_CLOUD_TABLES
                    WHERE
                        table_id in (
                        SELECT
                        metadata_table_id
                        FROM
                        :p_source_pod.CR_CLD_TEMPLATE_HDRS
                        WHERE
                        project_id = l_project_id))
                );

            COMMIT;
            DELETE FROM :p_destinaion_pod.CR_CLOUD_TABLES
            WHERE
                TABLE_NAME IN (
                    SELECT
                        TABLE_NAME
                    FROM
                        :p_source_pod.CR_CLOUD_TABLES
                    WHERE
                        table_id in (
                        SELECT
                        metadata_table_id
                        FROM
                        :p_source_pod.CR_CLD_TEMPLATE_HDRS
                        WHERE
                        project_id = l_project_id)
                );
            COMMIT;
        dbms_output.put_line('Source Meta Data');
        FOR i IN get_src_temp_details(l_project_id) LOOP
            dbms_output.put_line(i.src_template_id);
            dbms_output.put_line(i.src_template_code);

            DELETE FROM :p_destinaion_pod.cr_src_template_cols
            WHERE
                src_template_id IN ( SELECT
                        src_template_id
                    FROM
                        :p_destinaion_pod.cr_src_template_hdrs
                    WHERE
                        src_template_code = i.src_template_code );
            commit;

            DELETE FROM :p_destinaion_pod.cr_src_template_hdrs
            WHERE
                src_template_code IN ( i.src_template_code );

            COMMIT;

                dbms_output.put_line('Dlete Source Meta data');
        END LOOP;
        commit;
        --Insert Source Meta data
        FOR i IN get_src_temp_id(l_project_id) LOOP
            l_source_table_id := NULL;
            l_source_table_id := :p_destinaion_pod.cr_src_table_id_s.nextval; -- Destincation pod

            INSERT INTO :p_destinaion_pod.cr_source_tables
                SELECT
                    l_source_table_id,
                    table_name,
                    user_table_name,
                    description,
                    object_id,
                    application_id,
                    auto_size,
                    table_type,
                    initial_extent,
                    next_extent,
                    min_extents,
                    max_extents,
                    pct_increase,
                    ini_trans,
                    max_trans,
                    pct_free,
                    pct_used,
                    hosted_support_style,
                    irep_comments,
                    irep_annotations,
                    attribute1,
                    attribute2,
                    attribute3,
                    attribute4,
                    attribute5,
                    creation_date,
                    created_by,
                    last_update_date,
                    last_updated_by
                FROM
                    :p_source_pod.cr_source_tables
                WHERE
                    table_id = (
                        SELECT
                            metadata_table_id
                        FROM
                            :p_source_pod.cr_src_template_hdrs
                        WHERE
                            src_template_code = i.src_template_code
                    );

            COMMIT;
            INSERT INTO :p_destinaion_pod.cr_source_columns
                SELECT
                    l_source_table_id,
                    column_id,
                    column_name,
                    user_column_name,
                    description,
                    application_id,
                    column_sequence,
                    column_type,
                    width,
                    null_allowed_flag,
                    translate_flag,
                    flexfield_usage_code,
                    flexfield_application_id,
                    flexfield_name,
                    flex_value_set_application_id,
                    flex_value_set_id,
                    default_value,
                    precision,
                    scale,
                    irep_comments,
                    attribute1,
                    attribute2,
                    attribute3,
                    attribute4,
                    attribute5,
                    creation_date,
                    created_by,
                    last_update_date,
                    last_updated_by
                FROM
                    :p_source_pod.cr_source_columns
                WHERE
                    table_id = (
                        SELECT
                            metadata_table_id
                        FROM
                            :p_source_pod.cr_src_template_hdrs
                        WHERE
                            src_template_code = i.src_template_code
                    );

            COMMIT;

            INSERT INTO :p_destinaion_pod.cr_src_template_hdrs (
        src_template_name,
        src_template_code,
        project_id,
        parent_object_id,
        object_id,
        metadata_table_id,
        staging_table_name,
        normalize_data_flag,
        view_name,
        attribute1,
        attribute2,
        attribute3,
        attribute4,
        attribute5,
        creation_date,
        created_by,
        last_update_date,
        last_updated_by
    )
        SELECT
            src_template_name,
            src_template_code,
            project_id,
            parent_object_id,
            object_id,
            l_source_table_id,
            null,
            normalize_data_flag,
            view_name,
            attribute1,
            attribute2,
            attribute3,
            attribute4,
            attribute5,
            creation_date,
            created_by,
            last_update_date,
            last_updated_by
        FROM
            :p_source_pod.cr_src_template_hdrs
        WHERE
            SRC_TEMPLATE_ID=i.SRC_TEMPLATE_ID;-- Source Temp Headers
    COMMIT;
    SELECT
        src_template_id
    INTO l_src_temp_id
    FROM
        :p_destinaion_pod.cr_src_template_hdrs
    WHERE SRC_TEMPLATE_CODE=i.SRC_TEMPLATE_CODE;

                      FOR REC IN ( SELECT
                            l_src_temp_id src_template_id,
                            column_name,
                        column_type,
                        width,
                        display_seq,
                        selected,
                        unique_trans_ref,
                        attribute1,
                        attribute2,
                        attribute3,
                        attribute4,
                        attribute5,
                        creation_date,
                        created_by,
                        last_update_date,
                        last_updated_by
                        FROM
                            :p_source_pod.cr_src_template_cols
                        WHERE
                            src_template_id = i.SRC_TEMPLATE_ID
                        ORDER BY
                            column_id)
                    LOOP
                    INSERT INTO :p_destinaion_pod.cr_src_template_cols (
                        src_template_id,
                        column_name,
                        column_type,
                        width,
                        display_seq,
                        selected,
                        unique_trans_ref,
                        attribute1,
                        attribute2,
                        attribute3,
                        attribute4,
                        attribute5,
                        creation_date,
                        created_by,
                        last_update_date,
                        last_updated_by
                    ) values
                    (rec.src_template_id,
                    rec.column_name,
                        rec.column_type,
                        rec.width,
                        rec.display_seq,
                        rec.selected,
                        rec.unique_trans_ref,
                        rec.attribute1,
                        rec.attribute2,
                        rec.attribute3,
                        rec.attribute4,
                        rec.attribute5,
                        rec.creation_date,
                        rec.created_by,
                        rec.last_update_date,
                        rec.last_updated_by
                    );
                    COMMIT;
            end loop;
            commit;

            --Drop Existing Source Staging table_name
            l_table_chek:=0;
            select count(table_name) into l_table_chek from ALL_TABLES where owner=':p_destinaion_pod' and table_name=i.STAGING_TABLE_NAME;
            if (l_table_chek>0)
            then
            l_drop_stmt:='DROP TABLE '||':p_destinaion_pod'||'.'||i.STAGING_TABLE_NAME;
            --execute IMMEDIATE l_drop_stmt;
            commit;
            end if;
            --Create Source Stgaing Table
             begin
                :p_destinaion_pod.CR_CREATE_STG_TABLE_PROC(l_source_table_id,l_src_temp_id,i.src_template_code,'SOURCE','',l_ret_code,l_ret_msg);
                end;

        END LOOP;
        dbms_output.put_line('Insert Source meta  data');
    END;
 ]';
    l_query_3    CLOB DEFAULT q'[
   BEGIN
        FOR i IN get_cld_temp_details(l_project_id) LOOP
            dbms_output.put_line(i.cld_template_id);

            DELETE FROM :p_destinaion_pod.cr_cld_template_cols
            WHERE
                cld_template_id IN ( i.cld_template_id );

            DELETE FROM :p_destinaion_pod.cr_cld_template_hdrs
            WHERE
                cld_template_id IN ( i.cld_template_id );

            COMMIT;
                dbms_output.put_line('Dlete Cloud Meta data');
        END LOOP;
        --Insert Cloud MetaData
        FOR i IN get_cld_temp_id(l_project_id) LOOP
            l_cloud_table_id := :p_destinaion_pod.cr_cld_table_id_s.nextval;
            INSERT INTO :p_destinaion_pod.cr_cloud_tables
                SELECT
                    l_cloud_table_id,
                    table_name,
                    physical_table_name,
                    user_table_name,
                    description,
                    object_id,
                    parent_object_id,
                    application_short_name,
                    table_type,
                    hosted_support_style,
                    logical,
                    mls_support_model,
                    status,
                    deploy_to,
                    extension_of_table,
                    short_name,
                    shared_object,
                    conflict_resolution,
                    tablespace_type,
                    select_allowed,
                    insert_allowed,
                    update_allowed,
                    delete_allowed,
                    truncate_allowed,
                    maintain_partition,
                    exchange_partition,
                    maintain_index,
                    flashback_allowed,
                    enable_audit,
                    ora_edition_context,
                    attribute1,
                    attribute2,
                    attribute3,
                    attribute4,
                    attribute5,
                    creation_date,
                    created_by,
                    last_update_date,
                    last_updated_by
                FROM
                    :p_source_pod.cr_cloud_tables
                WHERE
                    table_id IN (
                        SELECT
                            metadata_table_id
                        FROM
                            :p_source_pod.cr_cld_template_hdrs
                        WHERE
                            cld_template_code = i.cld_template_code
                    );

            COMMIT;
            INSERT INTO :p_destinaion_pod.cr_cloud_columns (
                column_id,
                column_name,
                physical_column_name,
                user_column_name,
                description,
                table_id,
                object_id,
                status,
                short_name,
                ora_edition_context,
                column_sequence,
                column_type,
                width,
                null_allowed_flag,
                translate_flag,
                precision,
                scale,
                domain_code,
                denorm_path,
                routing_mode,
                cloud_version,
                eligible_to_be_secured,
                security_classification,
                sec_classification_override,
                attribute1,
                attribute2,
                attribute3,
                attribute4,
                attribute5,
                creation_date,
                created_by,
                last_update_date,
                last_updated_by
            )
                SELECT
                    column_id,
                    column_name,
                    physical_column_name,
                    user_column_name,
                    description,
                    l_cloud_table_id,
                    object_id,
                    status,
                    short_name,
                    ora_edition_context,
                    column_sequence,
                    column_type,
                    width,
                    null_allowed_flag,
                    translate_flag,
                    precision,
                    scale,
                    domain_code,
                    denorm_path,
                    routing_mode,
                    cloud_version,
                    eligible_to_be_secured,
                    security_classification,
                    sec_classification_override,
                    attribute1,
                    attribute2,
                    attribute3,
                    attribute4,
                    attribute5,
                    creation_date,
                    created_by,
                    last_update_date,
                    last_updated_by
                FROM
                    :p_source_pod.cr_cloud_columns
                WHERE
                    table_id IN (
                        SELECT
                            metadata_table_id
                        FROM
                            :p_source_pod.cr_cld_template_hdrs
                        WHERE
                            cld_template_code = i.cld_template_code
                    );

            COMMIT;
            INSERT INTO :p_destinaion_pod.cr_cld_template_hdrs (
                cld_template_name,
                cld_template_code,
                cloud_version,
                project_id,
                parent_object_id,
                object_id,
                metadata_table_id,
                src_template_id,
                staging_table_name,
                view_name,
                primary_template_flag,
                attribute1,
                attribute2,
                attribute3,
                attribute4,
                attribute5,
                creation_date,
                created_by,
                last_update_date,
                last_updated_by
            )
                SELECT
                    cld_template_name,
                    cld_template_code,
                    cloud_version,
                    project_id,
                    parent_object_id,
                    object_id,
                    l_cloud_table_id,
                    l_src_temp_id,
                    NULL,
                    view_name,
                    primary_template_flag,
                    attribute1,
                    attribute2,
                    attribute3,
                    attribute4,
                    attribute5,
                    creation_date,
                    created_by,
                    last_update_date,
                    last_updated_by
                FROM
                    :p_source_pod.cr_cld_template_hdrs
                WHERE
                    cld_template_id = i.cld_template_id;

            COMMIT;
            SELECT
                cld_template_id
            INTO l_cld_temp_id
            FROM
                :p_destinaion_pod.cr_cld_template_hdrs
            WHERE
                cld_template_code = i.cld_template_code;


            FOR l_get_cld_temp_cols_details IN get_cld_temp_cols_details(i.cld_template_id) LOOP
                l_map_set_id := NULL;
                l_src_col_id := NULL;
                IF l_get_cld_temp_cols_details.source_column_id IS NOT NULL THEN
                    SELECT
                        nvl(column_id,null)
                    INTO l_src_col_id
                    FROM
                        :p_destinaion_pod.cr_src_template_cols
                    WHERE
                        src_template_id IN (
                            SELECT
                                src_template_id
                            FROM
                                :p_destinaion_pod.cr_src_template_hdrs
                            WHERE
                                object_id = i.OBJECT_ID
                                AND PROJECT_ID=l_project_id
                        )
                        AND column_name = (
                            SELECT
                                column_name
                            FROM
                                :p_source_pod.cr_src_template_cols
                            WHERE
                                    column_id = l_get_cld_temp_cols_details.source_column_id
                                AND src_template_id = (
                                    SELECT
                                        src_template_id
                                    FROM
                                        :p_source_pod.cr_src_template_hdrs
                                    WHERE
                                        object_id = i.OBJECT_ID
                                        AND PROJECT_ID=l_project_id
                                )
                        );

                END IF;

                IF
                    l_get_cld_temp_cols_details.mapping_type NOT IN ( 'Formula', 'As-Is', 'Constant' )
                    AND l_get_cld_temp_cols_details.mapping_set_id IS NOT NULL
                THEN
                    select case
                    when exists(SELECT
                                1
                            FROM
                                :p_source_pod.cr_mapping_sets
                            WHERE
                                map_set_id = l_get_cld_temp_cols_details.mapping_set_id) then (SELECT
                        map_set_id

                    FROM
                        :p_destinaion_pod.cr_mapping_sets
                    WHERE
                        map_set_code = (
                            SELECT
                                map_set_code
                            FROM
                                :p_source_pod.cr_mapping_sets
                            WHERE
                                map_set_id = l_get_cld_temp_cols_details.mapping_set_id
                        ))
                        else  null end INTO l_map_set_id from dual;

                END IF;

                IF
                    l_get_cld_temp_cols_details.mapping_type IN ( 'Formula' )
                    AND l_get_cld_temp_cols_details.mapping_set_id IS NOT NULL
                THEN
                select case
                when exists(SELECT
                                distinct 1
                            FROM
                                :p_source_pod.cr_formula_sets
                            WHERE
                                formula_set_id = l_get_cld_temp_cols_details.mapping_set_id)
                then (SELECT
                        formula_set_id
                    FROM
                        :p_destinaion_pod.cr_formula_sets
                    WHERE
                        formula_set_code = (
                            SELECT
                                formula_set_code
                            FROM
                                :p_source_pod.cr_formula_sets
                            WHERE
                                formula_set_id = l_get_cld_temp_cols_details.mapping_set_id
                        ))
                else null end into l_map_set_id from dual;

                END IF;

                INSERT INTO :p_destinaion_pod.cr_cld_template_cols (
                    column_name,
                    cld_template_id,
                    description,
                    column_type,
                    width,
                    display_seq,
                    null_allowed_flag,
                    unique_trans_ref,
                    selected,
                    source_column_id,
                    mapping_type,
                    mapping_set_id,
                    mapping_value1,
                    mapping_value2,
                    mapping_value3,
                    mapping_value4,
                    mapping_value5,
                    attribute1,
                    attribute2,
                    attribute3,
                    attribute4,
                    attribute5,
                    creation_date,
                    created_by,
                    last_update_date,
                    last_updated_by
                ) VALUES (
                    l_get_cld_temp_cols_details.column_name,
                    l_cld_temp_id,
                    l_get_cld_temp_cols_details.description,
                    l_get_cld_temp_cols_details.column_type,
                    l_get_cld_temp_cols_details.width,
                    l_get_cld_temp_cols_details.display_seq,
                    l_get_cld_temp_cols_details.null_allowed_flag,
                    l_get_cld_temp_cols_details.unique_trans_ref,
                    l_get_cld_temp_cols_details.selected,
                    l_src_col_id,
                    l_get_cld_temp_cols_details.mapping_type,
                    l_map_set_id,
                    l_get_cld_temp_cols_details.mapping_value1,
                    l_get_cld_temp_cols_details.mapping_value2,
                    l_get_cld_temp_cols_details.mapping_value3,
                    l_get_cld_temp_cols_details.mapping_value4,
                    l_get_cld_temp_cols_details.mapping_value5,
                    l_get_cld_temp_cols_details.attribute1,
                    l_get_cld_temp_cols_details.attribute2,
                    l_get_cld_temp_cols_details.attribute3,
                    l_get_cld_temp_cols_details.attribute4,
                    l_get_cld_temp_cols_details.attribute5,
                    l_get_cld_temp_cols_details.creation_date,
                    l_get_cld_temp_cols_details.created_by,
                    l_get_cld_temp_cols_details.last_update_date,
                    l_get_cld_temp_cols_details.last_updated_by
                );

                COMMIT;
            END LOOP;
            l_table_chek:=0;
             --Drop Existing Cloud Staging table_name
            select count(table_name) into l_table_chek from ALL_TABLES where owner=':p_destinaion_pod' and table_name=i.STAGING_TABLE_NAME;
            if (l_table_chek>0)
            then
            l_drop_stmt:='DROP TABLE '||':p_destinaion_pod'||'.'||i.STAGING_TABLE_NAME;
            --execute IMMEDIATE l_drop_stmt;
            commit;
            end if;
            --Create Cloud Staging Table
                begin
                :p_destinaion_pod.CR_CREATE_STG_TABLE_PROC(l_cloud_table_id,l_cld_temp_id,i.cld_template_code,'CLOUD','',l_ret_code,l_ret_msg);
                end;
    --UserHooks
    dbms_output.put_line('--User Hooks--');
    dbms_output.put_line(i.cld_template_id);
    begin
        for x in get_userhook_details(i.cld_template_id) loop
            begin
            DBMS_LOB.createtemporary(l_uh_clob, TRUE);
            DBMS_LOB.APPEND (l_uh_clob,'CREATE OR REPLACE ');
            for k in (select text from all_source
                        where type='PROCEDURE'
                        and owner=upper(':p_source_pod')
                        AND NAME=upper(x.userhook)
                        order by line)
            loop
                DBMS_LOB.APPEND(l_uh_clob,k.text);
            end loop;
            l_uh_clob:=replace(l_uh_clob,'PROCEDURE ','PROCEDURE '||':p_destinaion_pod'||'.');
            --dbms_output.put_line(l_uh_clob);
                begin
                execute immediate l_uh_clob;
                exception when others then
                dbms_output.put_line(sqlerrm);
                end
                commit;
            end;
        end loop;
        dbms_output.put_line('--User Hooks Completed--');
    end;

    --Insert CR_HOOK_USAGES Data
        l_uh_check:=0;
        select count(*) into l_uh_check from :p_source_pod.CR_HOOK_USAGES where template_id=i.cld_template_id;

        IF l_uh_check > 0 THEN
        for k in (SELECT DISTINCT
        c.hook_id t_hook_id,
        b.hook_id s_hook_id
        FROM
        :p_source_pod.cr_hook_usages a,
        :p_source_pod.cr_user_hooks  b,
        :p_destinaion_pod.cr_user_hooks    c
        WHERE
            c.hook_code = b.hook_code
        AND a.template_id = i.cld_template_id
        AND a.hook_id = b.hook_id)
        loop
            insert into :p_destinaion_pod.CR_HOOK_USAGES(HOOK_ID,TEMPLATE_ID,USAGE_TYPE,ATTRIBUTE1,ATTRIBUTE2,ATTRIBUTE3,ATTRIBUTE4,ATTRIBUTE5,CREATION_DATE,CREATED_BY,LAST_UPDATE_DATE,LAST_UPDATED_BY)
            select k.t_hook_id,l_cld_temp_id,USAGE_TYPE,ATTRIBUTE1,ATTRIBUTE2,ATTRIBUTE3,ATTRIBUTE4,ATTRIBUTE5,CREATION_DATE,CREATED_BY,LAST_UPDATE_DATE,LAST_UPDATED_BY
            from :p_source_pod.cr_hook_usages where template_id = i.cld_template_id and HOOK_ID=k.s_hook_id;
            commit;
        end loop;
    END IF;

        END LOOP;
        dbms_output.put_line('Insert Cld Meta  data');
    END;
END;
 ]';

BEGIN
    dbms_lob.createtemporary(l_final_clob, true);
    dbms_lob.append(l_final_clob, l_query_1);
    dbms_lob.append(l_final_clob, l_query_2);
    dbms_lob.append(l_final_clob, l_query_3);

    l_final_clob := replace(l_final_clob, ':p_source_pod', p_source_pod);
    l_final_clob := replace(l_final_clob, ':p_destinaion_pod', p_destinaion_pod);
    l_final_clob := replace(l_final_clob, ':p_project_name', p_project_name);


    EXECUTE IMMEDIATE l_final_clob;
    p_msg := 'POD DETAILS COPIED SUCCESSFULLY';
    p_result := 'Y';
    dbms_output.put_line(p_msg);
EXCEPTION
    WHEN OTHERS THEN
        p_msg := 'POD DETAILS COPY Failed'||sqlerrm;
        p_result := 'N';
        dbms_output.put_line(p_msg);
END;

$#$
create or replace PROCEDURE CR_SRC_RECORD_DETAILS_PROC (
    p_src_template_id  IN NUMBER,
    p_src_data_criteria IN VARCHAR,
    p_batch_name       IN VARCHAR2 DEFAULT NULL,
    p_clob_src_file    OUT CLOB,
    p_ret_code         OUT VARCHAR2,
    p_ret_msg          OUT VARCHAR2
) AS
TYPE varchartab IS TABLE OF VARCHAR2(32000);
TYPE clobtab IS TABLE OF clob;
    v_sql VARCHAR2(10000);
    l_query              CLOB;
    v_cursor SYS_REFCURSOR;
    l_src_col_tab      varchartab;
    l_clob_tab         clobtab;
    l_src_stg_table_name VARCHAR2(2000);
    l_cols               CLOB;
    l_final_clob         CLOB := '';
    l_header             CLOB;
BEGIN
    p_ret_code := 'SUCCESS';
    p_ret_msg := 'SUCCESS';

    SELECT staging_table_name
    INTO l_src_stg_table_name
    FROM CR_SRC_TEMPLATE_HDRS
    WHERE SRC_TEMPLATE_ID = p_src_template_id;

    SELECT column_name
    BULK COLLECT INTO l_src_col_tab
    FROM all_tab_columns
    WHERE table_name = l_src_stg_table_name
    ORDER BY column_id;

    FOR i IN l_src_col_tab.FIRST .. l_src_col_tab.LAST LOOP
        l_cols := l_cols
                  || ''''
                  || '"'
                  || ''''
                  ||'||replace(src_stg.'
                  ||l_src_col_tab(i)
                  ||',chr(13),'''')'
                  || '||'
                  || ''''
                  || '"'
                  || ''''
                  || '||'
                  || ''''
                  || ','
                  || ''''
                  || '||';

l_header :=l_header||'"'||l_src_col_tab(i)||'" ,';


    END LOOP;

    l_header := Substr(l_header,0,Length(l_header)-1);
    l_cols := Substr(l_cols,0,Length(l_cols)-7);

    IF p_src_data_criteria = 'TOTAL_RECORDS' THEN
        l_query := 'SELECT ' || l_cols|| ' FROM ' || l_src_stg_table_name || ' src_stg WHERE CR_BATCH_NAME = ' ||''''||p_batch_name||'''';
    ELSIF p_src_data_criteria = 'PROCESSED_RECORDS' THEN
        l_query := 'SELECT ' || l_cols|| ' FROM '  || l_src_stg_table_name || ' src_stg WHERE Validation_Flag = ''VS'' AND CR_BATCH_NAME = ' ||''''||p_batch_name||'''';
    ELSIF p_src_data_criteria = 'FAILED_RECORDS' THEN
        l_query := 'SELECT ' || l_cols|| ' FROM ' || l_src_stg_table_name || ' src_stg WHERE (Validation_Flag = ''VF'' OR Validation_Flag = ''DUPLICATE'') AND CR_BATCH_NAME = ' ||''''||p_batch_name||'''';
    END IF;

l_final_clob :=l_final_clob||l_header||chr(10);
    OPEN v_cursor FOR l_query;
    LOOP
        FETCH v_cursor
        BULK COLLECT INTO l_clob_tab LIMIT 100;
        EXIT WHEN l_clob_tab.COUNT = 0;

        FOR i IN 1 .. l_clob_tab.LAST LOOP
            l_final_clob := l_final_clob || l_clob_tab(i) || CHR(10);
        END LOOP;
    END LOOP;
    p_clob_src_file := l_final_clob;

    CLOSE v_cursor;

EXCEPTION
    WHEN OTHERS THEN
        p_ret_code := 'ERROR';
        p_ret_msg := SQLERRM;
END CR_SRC_RECORD_DETAILS_PROC;
$#$
 CREATE OR REPLACE PROCEDURE cr_batch_process_details_proc (
    p_src_temp_id      IN NUMBER,
    p_object_id        IN NUMBER,
    p_source_count     IN NUMBER,
    p_batch_name       IN VARCHAR2,
    p_no_batchs        IN NUMBER,
    p_batch_post_split IN CLOB,
    p_duplicate_batch  IN VARCHAR2,
    p_duplicate_count  IN VARCHAR2,
    P_TOTAL_RECORDS IN NUMBER
) IS
    PRAGMA autonomous_transaction;
BEGIN
    INSERT INTO cr_batch_process_details (
        src_temp_id,
        object_id,
        source_count,
        batch_name,
        no_of_batch_split,
        batch_name_post_split,
        duplicate_batch_name,
        duplicate_count,
        TOTAL_FUR_PROCESS_RECORDS
    ) VALUES (
        p_src_temp_id,
        p_object_id,
        p_source_count,
        p_batch_name,
         p_no_batchs,
        p_batch_post_split,
        p_duplicate_batch,
        p_duplicate_count,
        P_TOTAL_RECORDS
    );

    COMMIT;
END;

$#$



CREATE OR REPLACE PROCEDURE cr_src_data_batch_proc (
    p_staging_table_name        IN VARCHAR2,
    p_batch_name                IN VARCHAR2,
    p_batch_size                IN NUMBER,
    p_parent_staging_table_name IN VARCHAR2 DEFAULT NULL,
    p_parent_column             IN VARCHAR2 DEFAULT NULL,
    p_msg                       OUT VARCHAR2,
    p_result                    OUT VARCHAR2,
    p_batch_names_out           OUT VARCHAR2,
    p_duplicate_rec_count       OUT NUMBER
) IS

    TYPE varchartab IS
        TABLE OF VARCHAR2(32000);
    l_orig_trans_id   varchartab;
    l_batch_name      varchartab;
    cur               SYS_REFCURSOR;
    v_offset          NUMBER DEFAULT 0;
    v_count           NUMBER;
    v_limit           NUMBER;
    l_duplicate_count NUMBER;
    l_batch_name_out  CLOB;
    p_dup_batch_name  VARCHAR2(240);
    v_start_query     CLOB := q'[UPDATE :TABLE_NAME t
SET t.CR_BATCH_NAME = ']';
    v_end_query       CLOB := q'[' WHERE t.rowid IN (
    SELECT rowid
    FROM (
        SELECT A.*, ROW_NUMBER() OVER (ORDER BY 1) AS rn
        FROM :TABLE_NAME A
        WHERE CR_BATCH_NAME = ':P_BATCH_NAME'
        AND  NVL(VALIDATION_FLAG,'N') <> 'DUPLICATE'
    )
    WHERE rn >  ]';
    l_gen_batch_name  VARCHAR2(420);
    l_object_id       NUMBER;
    l_temp_id         NUMBER;
BEGIN
    SELECT
        src_template_id,
        object_id
    INTO
        l_temp_id,
        l_object_id
    FROM
        cr_src_template_hdrs
    WHERE
        staging_table_name = p_staging_table_name;

    IF p_parent_staging_table_name IS NULL THEN
        v_limit := p_batch_size;
        v_start_query := replace(v_start_query, ':TABLE_NAME', p_staging_table_name);
        v_end_query := replace(v_end_query, ':P_BATCH_NAME', p_batch_name);
        v_end_query := replace(v_end_query, ':TABLE_NAME', p_staging_table_name);
        EXECUTE IMMEDIATE 'SELECT COUNT(1) FROM '
                          || p_staging_table_name
                          || ' where cr_batch_name = '
                          || ''''
                          || p_batch_name
                          || q'[' and validation_flag = 'DUPLICATE' ]'
        INTO l_duplicate_count;

        EXECUTE IMMEDIATE 'UPDATE  '
                          || p_staging_table_name
                          || ' SET CR_BATCH_NAME '
                          || ' = '''
                          || p_batch_name
                          || '_DUPLICATE'''
                          || ' where cr_batch_name = '
                          || ''''
                          || p_batch_name
                          || ''' and validation_flag = '
                          || ''''
                          || 'DUPLICATE'
                          || '''';

        EXECUTE IMMEDIATE 'SELECT COUNT(1) FROM '
                          || p_staging_table_name
                          || ' where cr_batch_name = '
                          || ''''
                          || p_batch_name
                          || ''''
        INTO v_count;

        FOR i IN 1..ceil(v_count / v_limit) LOOP
            l_gen_batch_name := p_batch_name
                                || '_'
                                || lpad(lpad(i,5,'0'), 10, 'CR20_');
            BEGIN
                EXECUTE IMMEDIATE v_start_query
                                  || l_gen_batch_name
                                  || v_end_query
                                  || to_char(v_offset)
                                  || ' and rn <= '
                                  || to_char(v_offset + v_limit)
                                  || ')';

            EXCEPTION
                WHEN OTHERS THEN
                    raise_application_error(-2002, sqlerrm);
            END;

            COMMIT;
            l_batch_name_out := l_batch_name_out
                                || l_gen_batch_name
                                || ',';
        END LOOP;

        l_batch_name_out := substr(l_batch_name_out, 0, length(l_batch_name_out) - 1);
        p_batch_names_out := l_batch_name_out;
        p_msg := 'SUCCESS';
        p_result := 'Y';
        p_duplicate_rec_count := l_duplicate_count;
        IF l_duplicate_count > 0 THEN
            p_dup_batch_name := p_batch_name || '_DUPLICATE';

            p_batch_names_out := p_batch_names_out
                                 || ','
                                 || p_dup_batch_name;
        ELSE
            p_dup_batch_name := NULL;
        END IF;

        cr_batch_process_details_proc(l_temp_id, l_object_id, v_count, p_batch_name, ceil(v_count / v_limit),
                                     p_batch_names_out, p_dup_batch_name, l_duplicate_count,(v_count - l_duplicate_count));

        COMMIT;
    ELSE
        BEGIN
            EXECUTE IMMEDIATE 'SELECT COUNT(1) FROM '
                              || p_staging_table_name
                              || ' where cr_batch_name = '
                              || ''''
                              || p_batch_name
                              || q'[' and validation_flag = 'DUPLICATE' ]'
            INTO l_duplicate_count;

            EXECUTE IMMEDIATE 'UPDATE  '
                              || p_staging_table_name
                              || ' SET CR_BATCH_NAME '
                              || ' = '''
                              || p_batch_name
                              || '_DUPLICATE'''
                              || ' where cr_batch_name = '
                              || ''''
                              || p_batch_name
                              || '''';

            EXECUTE IMMEDIATE ' SELECT DISTINCT CR_BATCH_NAME FROM '
                              || p_parent_staging_table_name
                              || ' where cr_batch_name like '
                              || ''''
                              || p_batch_name
                              || '%'''
            BULK COLLECT
            INTO l_batch_name;

        EXCEPTION
            WHEN OTHERS THEN
                p_msg := 'Please make sure that the Batch exists in Parent Table :' || p_batch_name;
                p_result := 'N';
                p_batch_names_out := ' ';
        END;

        FOR batch IN l_batch_name.first..l_batch_name.last LOOP
            EXECUTE IMMEDIATE 'UPDATE '
                              || p_staging_table_name
                              || 'SET CR_BATCH_NAME = '
                              || ''''
                              || l_batch_name(batch)
                              || ''' where cr_batch_name = '
                              || ''''
                              || p_batch_name
                              || ''' and '
                              || p_parent_column
                              || ' in (select distinct '
                              || p_parent_column
                              || ' from '
                              || p_parent_staging_table_name
                              || ' where cr_batch_name = '
                              || ''''
                              || l_batch_name(batch)
                              || ''')';

            COMMIT;
        END LOOP;

        p_msg := 'SUCCESS';
        p_result := 'Y';
        p_batch_names_out := ' ';
        p_duplicate_rec_count := l_duplicate_count;
        cr_batch_process_details_proc(l_temp_id, l_object_id, v_count, p_batch_name, NULL,
                                     '', p_batch_name || '_DUPLICATE', l_duplicate_count,(v_count - l_duplicate_count));

    END IF;

EXCEPTION
    WHEN OTHERS THEN
        p_msg := sqlerrm;
        p_result := 'N';
        p_batch_names_out := ' ';
        p_duplicate_rec_count := 0;
END;
$#$
