create or replace PROCEDURE cr_custom_table_modify_proc (
    p_table_id       IN NUMBER,
    p_column_name    IN VARCHAR2,
    p_column_type    IN VARCHAR2,
    p_operation_type IN VARCHAR2,
    p_display_seq    IN NUMBER,
    p_user_id        IN VARCHAR2,
    p_ret_msg        OUT VARCHAR2,
    p_ret_code       OUT VARCHAR2
) IS

    l_custom_table_id     NUMBER;
    l_metadata_table_id   NUMBER;
    l_cust_table_name     VARCHAR2(240);
    l_metadata_table_name VARCHAR2(240);
    l_max_col_seq         NUMBER;
    l_cols                CLOB;
    TYPE varchartab IS
        TABLE OF VARCHAR2(4200);
    l_cust_cols           varchartab;
    CURSOR get_table_details (
        p_cust_table_id NUMBER
    ) IS
    SELECT
        ctd.custom_table_id,
        ctd.custom_table_name,
        ct.table_id   metadata_table_id,
        ct.table_name metadata_table_name
    FROM
        cr_custom_source_table_dtls ctd,
        cr_custom_tables            ct
    WHERE
            ctd.metadata_table_id = ct.table_id
        AND ctd.custom_table_id = p_cust_table_id;

    CURSOR get_cust_cols (
        l_metadata_table_id NUMBER
    ) IS
    SELECT
        ' add('
        || rtrim((column_name
                  || ' '
                  ||
                  CASE
                      WHEN column_type IS NULL THEN
                          'VARCHAR2(400)'
                      ELSE
                          (decode(upper(column_type),
                                  'V',
                                  'VARCHAR2('
                                  || nvl(width, 400)
                                  || ')',
                                  'D',
                                  'VARCHAR2(2400)',
                                  'N',
                                  'NUMBER',
                                  'L',
                                  'LONG',
                                  upper(column_type)))
                                  ||decode (NULL_ALLOWED_FLAG,'N','  NOT NULL',NULL)
                  END
                  || ','),
                 ',')
        || ')' sql_data
    FROM
        cr_custom_columns
    WHERE
        table_id = l_metadata_table_id
    ORDER BY
        column_sequence ASC;

BEGIN
    BEGIN
        OPEN get_table_details(p_table_id);
        FETCH get_table_details INTO
            l_custom_table_id,
            l_cust_table_name,
            l_metadata_table_id,
            l_metadata_table_name;
        IF get_table_details%notfound THEN
            p_ret_code := 'N';
            p_ret_msg := 'No data found for the provided table ID.';

  INSERT INTO cr_log_messages (
            proc_name,
            reference_key,
            log_message,
            dynamic_query,
            user_id,
            creation_date,
            created_by
        ) VALUES (
            'CR_CUSTOM_TABLE_MODIFY_PROC',
            'Custom_table_id : ' || p_table_id,
            'No data found for the provided table ID.',
            'No data found for the provided table ID. with table_id '||p_table_id ,
            p_user_id,
            sysdate,
            p_user_id
        );
commit;
            RETURN;
        END IF;

        CLOSE get_table_details;
        SELECT
            MAX(column_id)
        INTO l_max_col_seq
        FROM
            cr_custom_columns
        WHERE
            table_id = l_metadata_table_id;

        SELECT
            LISTAGG(replace(column_name,
                            CHR(10),
                            ''),
                    ',') WITHIN GROUP(
            ORDER BY
                column_sequence ASC
            )
        INTO l_cols
        FROM
            cr_custom_columns
        WHERE
                table_id = l_metadata_table_id
            AND column_name <> p_column_name;

        -- Log RENAME operation
        INSERT INTO cr_log_messages (
            proc_name,
            reference_key,
            log_message,
            dynamic_query,
            user_id,
            creation_date,
            created_by
        ) VALUES (
            'CR_CUSTOM_TABLE_MODIFY_PROC',
            'Custom_table_id : ' || p_table_id,
            'RENAME ' || l_cust_table_name || ' TO ' || l_cust_table_name || '_BKUP',
            'RENAME ' || l_cust_table_name || ' TO ' || l_cust_table_name || '_BKUP',
            p_user_id,
            sysdate,
            p_user_id
        );

        EXECUTE IMMEDIATE 'RENAME '
                          || l_cust_table_name
                          || ' TO '
                          || l_cust_table_name
                          || '_BKUP';

        IF p_operation_type = 'UPDATE' THEN
            UPDATE cr_custom_columns
            SET
                column_name = p_column_name,
                column_sequence = p_display_seq,
                column_type = p_column_type,
                width = decode(p_column_type, 'V', 2000, 'N', NULL,'D',2400,
                               NULL)
            WHERE
                table_id = l_metadata_table_id
                and column_name = p_column_name;

            COMMIT;

            -- Log update operation
            INSERT INTO cr_log_messages (
                proc_name,
                reference_key,
                log_message,
                dynamic_query,
                user_id,
                creation_date,
                created_by
            ) VALUES (
                'CR_CUSTOM_TABLE_MODIFY_PROC',
                'Custom_table_id : ' || p_table_id,
                'Record Updated',
                'UPDATE cr_custom_columns SET column_name = ' || p_column_name || ' WHERE table_id = ' || l_metadata_table_id,
                p_user_id,
                sysdate,
                p_user_id
            );
        ELSIF p_operation_type = 'INSERT' THEN
            INSERT INTO cr_custom_columns (
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
                creation_date,
                created_by,
                last_update_date,
                last_updated_by
            ) VALUES (
                l_metadata_table_id,
                l_max_col_seq + 1,
                p_column_name,
                p_column_name,
                NULL,
                200,
                p_display_seq,
                p_column_type,
                decode(p_column_type, 'V', 2000, 'N', NULL,
                       NULL),
                'Y',
                'N',
                'N',
                0,
                NULL,
                0,
                0,
                NULL,
                0,
                0,
                NULL,
                NULL,
                NULL,
                NULL,
                NULL,
		NULL,
                sysdate,
                p_user_id,
                sysdate,
                p_user_id
            );

            COMMIT;

            -- Log insert operation
            INSERT INTO cr_log_messages (
                proc_name,
                reference_key,
                log_message,
                dynamic_query,
                user_id,
                creation_date,
                created_by
            ) VALUES (
                'CR_CUSTOM_TABLE_MODIFY_PROC',
                'Custom_table_id : ' || p_table_id,
                'Record Inserted',
                'INSERT INTO cr_custom_columns VALUES (...)',
                p_user_id,
                sysdate,
                p_user_id
            );
        ELSE
            DELETE FROM cr_custom_columns
            WHERE
                    table_id = l_metadata_table_id
                AND column_name = p_column_name;

            COMMIT;

            -- Log delete operation
            INSERT INTO cr_log_messages (
                proc_name,
                reference_key,
                log_message,
                dynamic_query,
                user_id,
                creation_date,
                created_by
            ) VALUES (
                'CR_CUSTOM_TABLE_MODIFY_PROC',
                'Custom_table_id : ' || p_table_id,
                'Record Deleted',
                'DELETE FROM cr_custom_columns WHERE table_id = ' || l_metadata_table_id,
                p_user_id,
                sysdate,
                p_user_id
            );
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            p_ret_code := 'N';
            p_ret_msg := 'Error during table modification: ' || sqlerrm;
            INSERT INTO cr_log_messages (
                proc_name,
                reference_key,
                log_message,
                dynamic_query,
                user_id,
                creation_date,
                created_by
            ) VALUES (
                'CR_CUSTOM_TABLE_MODIFY_PROC',
                'Custom_table_id : ' || p_table_id,
                p_ret_msg,
                'Error during table modification',
                p_user_id,
                sysdate,
                p_user_id
            );
            
            EXECUTE IMMEDIATE 'RENAME '||l_cust_table_name || '_BKUP TO '||l_cust_table_name;

            RETURN;
    END;

    BEGIN
        -- Log table creation
        INSERT INTO cr_log_messages (
            proc_name,
            reference_key,
            log_message,
            dynamic_query,
            user_id,
            creation_date,
            created_by
        ) VALUES (
            'CR_CUSTOM_TABLE_MODIFY_PROC',
            'Custom_table_id : ' || p_table_id,
            'CREATE TABLE ' || l_cust_table_name || ' (CR_BATCH_NAME VARCHAR2(2000))',
            'CREATE TABLE ' || l_cust_table_name || ' (CR_BATCH_NAME VARCHAR2(2000))',
            p_user_id,
            sysdate,
            p_user_id
        );

        EXECUTE IMMEDIATE 'CREATE TABLE '
                          || l_cust_table_name
                          || ' (CR_BATCH_NAME VARCHAR2(2000))';

        OPEN get_cust_cols(l_metadata_table_id);
        FETCH get_cust_cols
        BULK COLLECT INTO l_cust_cols;
        FOR i IN l_cust_cols.first..l_cust_cols.last LOOP
            EXECUTE IMMEDIATE 'ALTER TABLE '
                              || l_cust_table_name
                              || l_cust_cols(i);

            -- Log alter table operation
            INSERT INTO cr_log_messages (
                proc_name,
                reference_key,
                log_message,
                dynamic_query,
                user_id,
                creation_date,
                created_by
            ) VALUES (
                'CR_CUSTOM_TABLE_MODIFY_PROC',
                'Custom_table_id : ' || p_table_id,
                'ALTER TABLE ' || l_cust_table_name || l_cust_cols(i),
                'ALTER TABLE ' || l_cust_table_name || l_cust_cols(i),
                p_user_id,
                sysdate,
                p_user_id
            );
        END LOOP;

        CLOSE get_cust_cols;
    EXCEPTION
        WHEN OTHERS THEN
            p_ret_code := 'N';
            p_ret_msg := 'Error during table creation or alteration: ' || sqlerrm;
            INSERT INTO cr_log_messages (
                proc_name,
                reference_key,
                log_message,
                dynamic_query,
                user_id,
                creation_date,
                created_by
            ) VALUES (
                'CR_CUSTOM_TABLE_MODIFY_PROC',
                'Custom_table_id : ' || p_table_id,
                p_ret_msg,
                'Error during table creation or alteration',
                p_user_id,
                sysdate,
                p_user_id
            );

            RETURN;
    END;

    BEGIN
        -- Log data insertion
        INSERT INTO cr_log_messages (
            proc_name,
            reference_key,
            log_message,
            dynamic_query,
            user_id,
            creation_date,
            created_by
        ) VALUES (
            'CR_CUSTOM_TABLE_MODIFY_PROC',
            'Custom_table_id : ' || p_table_id,
            'Inserting data into ' || l_cust_table_name,
            'INSERT INTO ' || l_cust_table_name || ' (cr_batch_name,' || l_cols || ') SELECT cr_batch_name,' || l_cols || ' FROM ' || l_cust_table_name || '_BKUP',
            p_user_id,
            sysdate,
            p_user_id
        );

        EXECUTE IMMEDIATE 'INSERT INTO '
                          || l_cust_table_name
                          || ' (cr_batch_name,'
                          || l_cols
                          || ') SELECT cr_batch_name,'
                          || l_cols
                          || ' FROM '
                          || l_cust_table_name
                          || '_BKUP';

        COMMIT;

        -- Log successful data insertion
        INSERT INTO cr_log_messages (
            proc_name,
            reference_key,
            log_message,
            dynamic_query,
            user_id,
            creation_date,
            created_by
        ) VALUES (
            'CR_CUSTOM_TABLE_MODIFY_PROC',
            'Custom_table_id : ' || p_table_id,
            'Data inserted successfully',
            'INSERT INTO ' || l_cust_table_name || ' (cr_batch_name,' || l_cols || ') SELECT cr_batch_name,' || l_cols || ' FROM ' || l_cust_table_name || '_BKUP',
            p_user_id,
            sysdate,
            p_user_id
        );

        -- Log backup table drop
        INSERT INTO cr_log_messages (
            proc_name,
            reference_key,
            log_message,
            dynamic_query,
            user_id,
            creation_date,
            created_by
        ) VALUES (
            'CR_CUSTOM_TABLE_MODIFY_PROC',
            'Custom_table_id : ' || p_table_id,
            'Backup table dropped successfully',
            'DROP TABLE ' || l_cust_table_name || '_BKUP',
            p_user_id,
            sysdate,
            p_user_id
        );

        EXECUTE IMMEDIATE 'DROP TABLE '
                          || l_cust_table_name
                          || '_BKUP';

    EXCEPTION
        WHEN OTHERS THEN
            p_ret_code := 'N';
            p_ret_msg := 'Error during data insertion or backup table drop: ' || sqlerrm;
            INSERT INTO cr_log_messages (
                proc_name,
                reference_key,
                log_message,
                dynamic_query,
                user_id,
                creation_date,
                created_by
            ) VALUES (
                'CR_CUSTOM_TABLE_MODIFY_PROC',
                'Custom_table_id : ' || p_table_id,
                p_ret_msg,
                'Error during data insertion or backup table drop',
                p_user_id,
                sysdate,
                p_user_id
            );

            RETURN;
    END;

    p_ret_code := 'Y';
    p_ret_msg := 'SUCCESS';
EXCEPTION
    WHEN OTHERS THEN
        p_ret_code := 'N';
        p_ret_msg := 'Unexpected error: ' || sqlerrm;
        INSERT INTO cr_log_messages (
            proc_name,
            reference_key,
            log_message,
            dynamic_query,
            user_id,
            creation_date,
            created_by
        ) VALUES (
            'CR_CUSTOM_TABLE_MODIFY_PROC',
            'Custom_table_id : ' || p_table_id,
            p_ret_msg,
            'Unexpected error in procedure',
            p_user_id,
            sysdate,
            p_user_id
        );

END cr_custom_table_modify_proc; 
$#$
CREATE OR REPLACE PROCEDURE cr_fetch_transform_stats_proc (
    p_user_id         IN VARCHAR2,
    p_cld_template_id IN NUMBER,
    p_batch_name      IN VARCHAR2,
    p_ret_code        OUT VARCHAR2,
    p_ret_msg         OUT VARCHAR2
) IS

    TYPE varchartab IS
        TABLE OF VARCHAR2(2000);
    batch_name                    varchartab;
    CURSOR cld_transform_cur IS
    SELECT
        cld.cld_template_id    cloud_template_id,
        cld.cld_template_name  cloud_template_name,
        cld.project_id,
        cp.project_name        project,
        cld.parent_object_id,
        po.object_code         parent_object_code,
        cld.object_id,
        co.object_code         object_code,
        co.object_name         object,
        src.staging_table_name src_stg_table_name,
        cld.staging_table_name cld_stg_table_name
    FROM
        cr_cld_template_hdrs cld,
        cr_src_template_hdrs src,
        cr_projects          cp,
        cr_project_objects   po,
        cr_project_objects   co
    WHERE
            cp.project_id = cld.project_id
        AND po.project_id = cp.project_id
        AND po.object_id = cld.parent_object_id
        AND co.project_id = cp.project_id
        AND co.object_id = cld.object_id
        AND cld.src_template_id IS NOT NULL
        AND cld.staging_table_name IS NOT NULL
        AND cld.src_template_id = src.src_template_id
        AND src.staging_table_name IS NOT NULL
        AND cld.cld_template_id = p_cld_template_id;

    CURSOR get_object_query (
        p_object_id VARCHAR
    ) IS
    SELECT
        nvl(a.info_value, 'NULL') cloud_success,
        nvl(b.info_value, 'NULL') cloud_failure,
        nvl(c.info_value, 'NULL') cloud_fail_count
    FROM
        cr_object_information a,
        cr_object_information b,
        cr_object_information c
    WHERE
            a.info_type = 'RECON_CLOUD_SUCCESS'
        AND b.info_type = 'RECON_CLOUD_FAIL'
        AND c.info_type = 'RECON_CLOUD_FAIL_COUNT'
        AND a.object_id = b.object_id
        AND a.object_id = c.object_id
        AND a.object_id = p_object_id;

    l_src_rec_cnt_sql             VARCHAR2(1000) DEFAULT 'SELECT COUNT(1) FROM ';
    l_src_rec_count               NUMBER DEFAULT 0;
    l_cld_rec_cnt_sql             VARCHAR2(1000) DEFAULT 'SELECT COUNT(1) FROM ';
    l_cld_rec_count               NUMBER DEFAULT 0;
    l_src_vf_rec_sql              VARCHAR2(1000) DEFAULT 'SELECT COUNT(1) FROM ';
    l_src_vf_rec_count            NUMBER DEFAULT 0;
    l_src_vf_where_clause         VARCHAR2(1000) DEFAULT q'[ WHERE nvl(validation_flag,'N') IN ('VF','DUPLICATE')]';
    l_src_vs_sql                  VARCHAR2(1000) DEFAULT 'SELECT COUNT(1) FROM ';
    l_src_vs_rec_count            NUMBER DEFAULT 0;
    l_src_vs_where_clause         VARCHAR2(1000) DEFAULT q'[ WHERE nvl(validation_flag,'N')='VS']';
    l_src_unverified_sql          VARCHAR2(1000) DEFAULT 'SELECT COUNT(1) FROM ';
    l_src_unverified_rec_count    NUMBER DEFAULT 0;
    l_src_unverified_where_clause VARCHAR2(1000) DEFAULT q'[ WHERE nvl(validation_flag,'N')='N']';
    l_vs_trans_sql                VARCHAR2(1000);
    l_vs_trans_rec_count          NUMBER DEFAULT 0;
    l_vs_trans_where_clause       VARCHAR2(1000) DEFAULT q'[ nvl(validation_flag,'N')='VS']';
    l_vs_untrans_sql              VARCHAR2(1000);
    l_vs_untrans_rec_count        NUMBER DEFAULT 0;
    l_vs_untrans_where_clause     VARCHAR2(1000) DEFAULT q'[ nvl(validation_flag,'N')='VS']';
    l_vf_trans_sql                VARCHAR2(1000);
    l_vf_trans_rec_count          NUMBER DEFAULT 0;
    l_vf_trans_where_clause       VARCHAR2(1000) DEFAULT q'[ nvl(validation_flag,'N')='VF']';
    l_vf_untrans_sql              VARCHAR2(1000);
    l_vf_untrans_rec_count        NUMBER DEFAULT 0;
    l_vf_untrans_where_clause     VARCHAR2(1000) DEFAULT q'[ nvl(validation_flag,'N')='VF']';
    l_unknwn_rec_sql              VARCHAR2(1000);
    l_unknwn_rec_count            NUMBER DEFAULT 0;
    l_unknwn_rec_where_clause     VARCHAR2(1000) DEFAULT q'[ 1=1]';
    l_untrans_rec_sql             VARCHAR2(1000);
    l_untrans_rec_count           NUMBER DEFAULT 0;
    l_untrans_rec_where_clause    VARCHAR2(1000) DEFAULT q'[ 1=1]';
    l_cloud_int_rej_rec           NUMBER DEFAULT 0;
    l_cloud_int_rej_sql           VARCHAR2(8000);
    l_cloud_int_rej_count_sql     VARCHAR2(8000);
    l_cloud_success_sql           VARCHAR2(8000);
    l_cloud_success_rec           NUMBER DEFAULT 0;
    l_load_request_id             VARCHAR2(240);
    l_batch_query                 VARCHAR2(2000) := ' SELECT DISTINCT CR_BATCH_NAME FROM ';
    l_count                       NUMBER;
    l_ret_code                    VARCHAR2(250);
    l_ret_msg                     VARCHAR2(2500);
BEGIN
    FOR cld_transform_rec IN cld_transform_cur LOOP
        EXECUTE IMMEDIATE l_batch_query
                          || cld_transform_rec.src_stg_table_name
                          || ' where CR_BATCH_NAME='
                          || ''''
                          || p_batch_name
                          || ''''
        BULK COLLECT
        INTO batch_name;

        IF batch_name.count > 0 THEN
            FOR i IN batch_name.first..batch_name.last LOOP
                l_src_rec_count := 0;
                l_cld_rec_count := 0;
                l_src_vf_rec_count := 0;
                l_src_vs_rec_count := 0;
                l_src_unverified_rec_count := 0;
                l_vs_trans_rec_count := 0;
                l_vs_untrans_rec_count := 0;
                l_vf_trans_rec_count := 0;
                l_vf_untrans_rec_count := 0;
                l_unknwn_rec_count := 0;
                l_untrans_rec_count := 0;
                l_cloud_int_rej_rec := 0;
                l_cloud_success_rec := 0;
                l_cloud_int_rej_sql := NULL;
                l_cloud_success_sql := NULL;
                l_vs_trans_sql := q'[ SELECT COUNT(1) FROM (
        SELECT
            orig_trans_id
        FROM
            :CLOUD_TABLE WHERE CR_BATCH_NAME = ':BATCH_NAME'
        INTERSECT
        SELECT
            orig_trans_id
        FROM
            :SOURCE_TABLE
        WHERE :WHERE_CLAUSE  AND CR_BATCH_NAME = ':BATCH_NAME' )]';
                l_vs_untrans_sql := q'[ SELECT COUNT(1) FROM (
        SELECT
            orig_trans_id
        FROM
            :SOURCE_TABLE
        WHERE :WHERE_CLAUSE AND  CR_BATCH_NAME = ':BATCH_NAME'
        MINUS
        SELECT
            orig_trans_id
        FROM
            :CLOUD_TABLE WHERE  CR_BATCH_NAME = ':BATCH_NAME')]';
                l_vf_trans_sql := q'[ SELECT COUNT(1) FROM (
        SELECT
            orig_trans_id
        FROM
            :CLOUD_TABLE WHERE CR_BATCH_NAME = ':BATCH_NAME'
        INTERSECT
        SELECT
            orig_trans_id
        FROM
            :SOURCE_TABLE
        WHERE :WHERE_CLAUSE  AND CR_BATCH_NAME = ':BATCH_NAME' )]';
                l_vf_untrans_sql := q'[ SELECT COUNT(1) FROM (
        SELECT
            orig_trans_id
        FROM
            :SOURCE_TABLE
        WHERE :WHERE_CLAUSE AND CR_BATCH_NAME = ':BATCH_NAME'
        MINUS
        SELECT
            orig_trans_id
        FROM
            :CLOUD_TABLE  WHERE  CR_BATCH_NAME = ':BATCH_NAME')]';
                l_unknwn_rec_sql := q'[ SELECT COUNT(1) FROM (
        SELECT
            orig_trans_id
        FROM
            :CLOUD_TABLE WHERE  CR_BATCH_NAME = ':BATCH_NAME'
        MINUS
        SELECT
            orig_trans_id
        FROM
            :SOURCE_TABLE
        WHERE :WHERE_CLAUSE AND CR_BATCH_NAME = ':BATCH_NAME' )]';
                l_untrans_rec_sql := q'[ SELECT COUNT(1) FROM (
    SELECT
            orig_trans_id
        FROM
            :SOURCE_TABLE
        WHERE :WHERE_CLAUSE AND CR_BATCH_NAME = ':BATCH_NAME'
        MINUS
        SELECT
            orig_trans_id
        FROM
            :CLOUD_TABLE  WHERE  CR_BATCH_NAME = ':BATCH_NAME')]';
                EXECUTE IMMEDIATE l_src_rec_cnt_sql
                                  || cld_transform_rec.src_stg_table_name
                                  || ' WHERE CR_BATCH_NAME = '
                                  || ''''
                                  || batch_name(i)
                                  || ''''
                INTO l_src_rec_count;

                EXECUTE IMMEDIATE l_cld_rec_cnt_sql
                                  || cld_transform_rec.cld_stg_table_name
                                  || ' WHERE CR_BATCH_NAME = '
                                  || ''''
                                  || batch_name(i)
                                  || ''''
                INTO l_cld_rec_count;

                EXECUTE IMMEDIATE l_src_vf_rec_sql
                                  || cld_transform_rec.src_stg_table_name
                                  || l_src_vf_where_clause
                                  || ' AND CR_BATCH_NAME = '
                                  || ''''
                                  || batch_name(i)
                                  || ''''
                INTO l_src_vf_rec_count;

                EXECUTE IMMEDIATE l_src_vs_sql
                                  || cld_transform_rec.src_stg_table_name
                                  || l_src_vs_where_clause
                                  || ' AND CR_BATCH_NAME = '
                                  || ''''
                                  || batch_name(i)
                                  || ''''
                INTO l_src_vs_rec_count;

                EXECUTE IMMEDIATE l_src_unverified_sql
                                  || cld_transform_rec.src_stg_table_name
                                  || l_src_unverified_where_clause
                                  || ' AND CR_BATCH_NAME = '
                                  || ''''
                                  || batch_name(i)
                                  || ''''
                INTO l_src_unverified_rec_count;

                l_vs_trans_sql := replace(l_vs_trans_sql, ':CLOUD_TABLE', cld_transform_rec.cld_stg_table_name);
                l_vs_trans_sql := replace(l_vs_trans_sql, ':SOURCE_TABLE', cld_transform_rec.src_stg_table_name);
                l_vs_trans_sql := replace(l_vs_trans_sql, ':WHERE_CLAUSE', l_vs_trans_where_clause);
                l_vs_trans_sql := replace(l_vs_trans_sql, ':BATCH_NAME', batch_name(i));
                EXECUTE IMMEDIATE l_vs_trans_sql
                INTO l_vs_trans_rec_count;
                l_vs_untrans_sql := replace(l_vs_untrans_sql, ':CLOUD_TABLE', cld_transform_rec.cld_stg_table_name);
                l_vs_untrans_sql := replace(l_vs_untrans_sql, ':SOURCE_TABLE', cld_transform_rec.src_stg_table_name);
                l_vs_untrans_sql := replace(l_vs_untrans_sql, ':WHERE_CLAUSE', l_vs_untrans_where_clause);
                l_vs_untrans_sql := replace(l_vs_untrans_sql, ':BATCH_NAME', batch_name(i));
                EXECUTE IMMEDIATE l_vs_untrans_sql
                INTO l_vs_untrans_rec_count;
                l_vf_trans_sql := replace(l_vf_trans_sql, ':CLOUD_TABLE', cld_transform_rec.cld_stg_table_name);
                l_vf_trans_sql := replace(l_vf_trans_sql, ':SOURCE_TABLE', cld_transform_rec.src_stg_table_name);
                l_vf_trans_sql := replace(l_vf_trans_sql, ':WHERE_CLAUSE', l_vf_trans_where_clause);
                l_vf_trans_sql := replace(l_vf_trans_sql, ':BATCH_NAME', batch_name(i));
                EXECUTE IMMEDIATE l_vf_trans_sql
                INTO l_vf_trans_rec_count;
                l_vf_untrans_sql := replace(l_vf_untrans_sql, ':CLOUD_TABLE', cld_transform_rec.cld_stg_table_name);
                l_vf_untrans_sql := replace(l_vf_untrans_sql, ':SOURCE_TABLE', cld_transform_rec.src_stg_table_name);
                l_vf_untrans_sql := replace(l_vf_untrans_sql, ':WHERE_CLAUSE', l_vf_untrans_where_clause);
                l_vf_untrans_sql := replace(l_vf_untrans_sql, ':BATCH_NAME', batch_name(i));
                EXECUTE IMMEDIATE l_vf_untrans_sql
                INTO l_vf_untrans_rec_count;
                l_unknwn_rec_sql := replace(l_unknwn_rec_sql, ':CLOUD_TABLE', cld_transform_rec.cld_stg_table_name);
                l_unknwn_rec_sql := replace(l_unknwn_rec_sql, ':SOURCE_TABLE', cld_transform_rec.src_stg_table_name);
                l_unknwn_rec_sql := replace(l_unknwn_rec_sql, ':WHERE_CLAUSE', l_unknwn_rec_where_clause);
                l_unknwn_rec_sql := replace(l_unknwn_rec_sql, ':BATCH_NAME', batch_name(i));
                EXECUTE IMMEDIATE l_unknwn_rec_sql
                INTO l_unknwn_rec_count;
                l_untrans_rec_sql := replace(l_untrans_rec_sql, ':CLOUD_TABLE', cld_transform_rec.cld_stg_table_name);
                l_untrans_rec_sql := replace(l_untrans_rec_sql, ':SOURCE_TABLE', cld_transform_rec.src_stg_table_name);
                l_untrans_rec_sql := replace(l_untrans_rec_sql, ':WHERE_CLAUSE', l_untrans_rec_where_clause);
                l_untrans_rec_sql := replace(l_untrans_rec_sql, ':BATCH_NAME', batch_name(i));
                EXECUTE IMMEDIATE l_untrans_rec_sql
                INTO l_untrans_rec_count;
                BEGIN
                    OPEN get_object_query(cld_transform_rec.object_id);
                    FETCH get_object_query INTO
                        l_cloud_success_sql,
                        l_cloud_int_rej_sql,
                        l_cloud_int_rej_count_sql;
                END;

                CLOSE get_object_query;
                BEGIN
                    SELECT
                        load_request_id
                    INTO l_load_request_id
                    FROM
                        cr_cloud_job_status
                    WHERE
                            batch_name = batch_name(i)
                        AND object_id = cld_transform_rec.object_id;

                EXCEPTION
                    WHEN OTHERS THEN
                        l_load_request_id := NULL;
                END;

                BEGIN
                    l_cloud_int_rej_sql := replace(l_cloud_int_rej_sql, ':cld_cols', 'cld_stg.cr_batch_name');
                    l_cloud_int_rej_sql := replace(l_cloud_int_rej_sql, ':cld_stg_table', cld_transform_rec.cld_stg_table_name);
                    l_cloud_int_rej_sql := replace(l_cloud_int_rej_sql, ':cr_batch_name', batch_name(i));
                    l_cloud_int_rej_sql := replace(l_cloud_int_rej_sql, ':load_request_id', l_load_request_id);
--                EXECUTE IMMEDIATE 'SELECT COUNT(1) FROM ('
--                                  || l_cloud_int_rej_sql
--                                  || ')'
--                INTO l_cloud_int_rej_rec;
                EXCEPTION
                    WHEN OTHERS THEN
                        l_cloud_int_rej_rec := 0;
                END;

                BEGIN
                    l_cloud_int_rej_count_sql := replace(l_cloud_int_rej_count_sql, ':load_request_id', l_load_request_id);
                    EXECUTE IMMEDIATE l_cloud_int_rej_count_sql
                    INTO l_cloud_int_rej_rec;
                EXCEPTION
                    WHEN OTHERS THEN
                        l_ret_code := 'N';
                        l_ret_msg := 'Error in Rejection Count Query:' || sqlerrm;
                        l_cloud_int_rej_rec := 0;
                END;

                BEGIN
                    l_cloud_success_sql := replace(l_cloud_success_sql, ':src_cols', 'cld_stg.cr_batch_name');
                    l_cloud_success_sql := replace(l_cloud_success_sql, ':src_stg_table', cld_transform_rec.src_stg_table_name);
                    l_cloud_success_sql := replace(l_cloud_success_sql, ':cld_stg_table', cld_transform_rec.cld_stg_table_name);
                    l_cloud_success_sql := replace(l_cloud_success_sql, ':cr_batch_name', batch_name(i));
                    l_cloud_success_sql := replace(l_cloud_success_sql, ':load_request_id', l_load_request_id);
                    EXECUTE IMMEDIATE ' SELECT COUNT(1) FROM ( '
                                      || l_cloud_success_sql
                                      || ') '
                    INTO l_cloud_success_rec;
                EXCEPTION
                    WHEN OTHERS THEN
                        l_ret_code := 'N';
                        IF l_ret_msg IS NOT NULL THEN
                            l_ret_msg := l_ret_msg
                                         || ' , '
                                         || 'Error in Recon Success Query:'
                                         || sqlerrm;
                        ELSE
                           -- p_ret_code := 'N';
                            l_ret_msg := 'Error in Recon Success Query:' || sqlerrm;
                        END IF;

                        l_cloud_success_rec := 0;
                END;

                UPDATE cr_transform_stats
                SET
                    LATEST_FLAG = 'N',
                    last_updated_date = sysdate,
                    last_updated_by = p_user_id
                WHERE
                        cloud_template_id = p_cld_template_id
                    AND cr_batch_name = p_batch_name;

                COMMIT;
                INSERT INTO cr_log_messages (
                    proc_name,
                    log_message,
                    reference_key,
                    creation_date
                ) VALUES (
                    'cr_fetch_transform_stats_func',
                    'Proceeding to insert data into CR_TRANSFORM_STATS for ' || cld_transform_rec.cloud_template_name,
                    'Cloud template id:'
                    || p_cld_template_id
                    || ', Batch Name:'
                    || p_batch_name,
                    sysdate
                );

                COMMIT;
                INSERT INTO cr_transform_stats (
                    cloud_template_id,
                    cloud_template_name,
                    project_id,
                    project,
                    parent_object_id,
                    parent_object_code,
                    object_id,
                    object,
                    src_stg_table_name,
                    cld_stg_table_name,
                    total_source_records,
                    total_cloud_records,
                    validation_failed,
                    validation_passed,
                    source_unverfied,
                    vs_trans_rec,
                    vs_untrans_rec,
                    vf_trans_rec,
                    vf_untrans_rec,
                    cloud_unkown_records,
                    total_untrans_rec,
                    cloud_int_rej_rec,
                    cloud_success_rec,
                    cr_batch_name,
                    load_request_id,
                    creation_date,
                    created_by,
                    LATEST_FLAG,
                    comments
                ) VALUES (
                    cld_transform_rec.cloud_template_id,
                    cld_transform_rec.cloud_template_name,
                    cld_transform_rec.project_id,
                    cld_transform_rec.project,
                    cld_transform_rec.parent_object_id,
                    cld_transform_rec.parent_object_code,
                    cld_transform_rec.object_id,
                    cld_transform_rec.object,
                    cld_transform_rec.src_stg_table_name,
                    cld_transform_rec.cld_stg_table_name,
                    l_src_rec_count,
                    l_cld_rec_count,
                    l_src_vf_rec_count,
                    l_src_vs_rec_count,
                    l_src_unverified_rec_count,
                    l_vs_trans_rec_count,
                    l_vs_untrans_rec_count,
                    l_vf_trans_rec_count,
                    l_vf_untrans_rec_count,
                    l_unknwn_rec_count,
                    l_untrans_rec_count,
                    l_cloud_int_rej_rec,
                    l_cloud_success_rec,
                    batch_name(i),
                    l_load_request_id,
                    sysdate,
                    p_user_id,
                    'Y',
                    l_ret_msg
                );
--end if;

            END LOOP;

        END IF;

    END LOOP;

    IF l_ret_code = 'N' THEN
        p_ret_code := 'N';
        p_ret_msg := l_ret_msg;
        INSERT INTO cr_log_messages (
            proc_name,
            log_message,
            reference_key,
            creation_date
        ) VALUES (
            'cr_fetch_transform_stats_func',
            'cr_fetch_transform_stats_func is Failed',
            p_ret_msg,
            sysdate
        );

        COMMIT;
    ELSE
        p_ret_code := 'Y';
        p_ret_msg := 'SUCCESS';
        INSERT INTO cr_log_messages (
            proc_name,
            log_message,
            reference_key,
            creation_date
        ) VALUES (
            'cr_fetch_transform_stats_func',
            'cr_fetch_transform_stats_func is Completed Successfully',
            'Cloud template id:'
            || p_cld_template_id
            || ', Batch Name:'
            || p_batch_name,
            sysdate
        );

        COMMIT;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        p_ret_code := 'N';
        p_ret_msg := 'Unexected Error: ' || sqlerrm;
        INSERT INTO cr_log_messages (
            proc_name,
            log_message,
            reference_key,
            creation_date
        ) VALUES (
            'cr_fetch_transform_stats_func',
            'cr_fetch_transform_stats_func is Failed',
            p_ret_msg,
            sysdate
        );

        COMMIT;
END cr_fetch_transform_stats_proc;

$#$
create or replace PROCEDURE cr_fbdi_filegen_proc (
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
    L_HEADER_FLAG varchar2(240);
    L_HEADER_COLS clob ;
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
       begin      
                SELECT
            nvl(info_value, 'N')
        INTO l_header_flag
        FROM
            cr_object_information
        WHERE
                upper(info_type) = 'INCLUDE HEADERS IN THE FILE TO BE IMPORTED'
            AND object_id = l_obj_id;
            exception when others then
            l_header_flag := 'N' ;
            end ;
        IF l_header_flag = 'Y' THEN
            SELECT
                 LISTAGG('"' || b.user_column_name, '",') WITHIN GROUP(
                ORDER BY
                    a.display_seq ASC
                )
                || '"'
           INTO l_header_cols
            FROM
                cr_cld_template_cols a ,
                cr_cloud_columns b ,
                cr_cld_template_hdrs c
            WHERE
                    a.cld_template_id = p_cld_template_id
                AND a.display_seq IS NOT NULL
                and c.cld_template_id = a.cld_templatE_id
                and c.METADATA_TABLE_ID = b.table_id 
                and upper(a.column_name) = upper(b.user_column_name)

            ORDER BY
                nvl(a.display_seq, 9999999999) ASC;
l_clob := l_header_cols||chr(10);
        END IF;
    dbms_output.put_line(l_sql);
    BEGIN
        OPEN cur FOR l_sql;
        LOOP
            FETCH cur
            BULK COLLECT INTO l_clob_tab LIMIT 1000;
            EXIT WHEN l_clob_tab.count = 0;
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
       dbms_output.put_line('SQLERRM:' || p_result_msg);
END cr_fbdi_filegen_proc;

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
                                           WHERE validation_flag IN ('VF','DUPLICATE')
                                             AND CR_BATCH_NAME = ':P_BATCH_NAME';
                                             
                                             SELECT COUNT(*)
                                            INTO l_cld_record_count
                                            FROM :TABLE_NAME
                                           WHERE  CR_BATCH_NAME = ':P_BATCH_NAME';
                                           
                                           UPDATE CR_PROCESS_REQUESTS SET 
                                           CLD_RECORD_COUNT = l_cld_record_count
                                           WHERE CLD_TEMPLATE_ID = :CLD_TEMPLATE_ID 
                                           AND  CR_BATCH_NAME = ':P_BATCH_NAME'
                                          AND request_id = :P_REQUEST_ID ; 
                                           
                                           
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
  and cuh.hook_type = 'PLSQL' -- ADDED TO PICK ONLY PLSQL USERHOOKS
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
               l_pre_clob := l_pre_clob || user_hooks_rec.hook_text ||';'|| chr(10);
               l_pre_clob := replace(l_pre_clob, ':P_BATCH_NAME', p_batch_name);
            ELSIF user_hooks_rec.usage_type = 'POST_HOOK'
            THEN
               l_post_clob := l_post_clob || user_hooks_rec.hook_text ||';'||  chr(10);
               l_post_clob := replace(l_post_clob, ':P_BATCH_NAME', p_batch_name);
            ELSE
               l_pre_clob := l_pre_clob||'null;';
               l_post_clob :=  l_post_clob||'null;';
            END IF;
      END LOOP;
EXCEPTION
WHEN OTHERS THEN
            l_pre_clob := 'null;';
            l_post_clob := 'null;';
END;
    l_pre_clob := NVL(l_pre_clob,'null;');
    l_post_clob := NVL(l_post_clob,'null;');
    dbms_output.put_line('l_pre_clob: '||l_pre_clob);
    dbms_output.put_line('l_post_clob: '||l_post_clob);
INSERT INTO CR_LOG_MESSAGES (PROC_NAME ,REFERENCE_KEY,Log_message,DYNAMIC_QUERY,USER_ID,CREATION_DATE,CREATED_BY)
VALUES ('CR_CLD_TRANSFORM_MAIN_PROC','p_cloud_template_id: '||p_cloud_template_id,'l_pre_clob: '||l_pre_clob,NULL,NULL,SYSDATE,NULL);
COMMIT;
INSERT INTO CR_LOG_MESSAGES (PROC_NAME ,REFERENCE_KEY,Log_message,DYNAMIC_QUERY,USER_ID,CREATION_DATE,CREATED_BY)
VALUES ('CR_CLD_TRANSFORM_MAIN_PROC','p_cloud_template_id: '||p_cloud_template_id,'l_post_clob: '||l_post_clob,NULL,NULL,SYSDATE,NULL);
COMMIT;
if p_reprocess_flag = 'Y' then
	execute immediate ' update '||l_src_stg_table||Q'[ set validation_flag = null, error_msg = null  where  NVL(validation_flag,'DUPLICATE') <> 'DUPLICATE'  AND cr_batch_name = ]'||''''||p_batch_name||'''' ;
commit;
end if;
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
    l_end_proc := replace(l_end_proc, ':TABLE_NAME', p_cloud_table_name);
    l_end_proc := replace(l_end_proc, ':CLD_TEMPLATE_ID', p_cloud_template_id);
    l_end_proc := replace(l_end_proc, ':P_JOB_ID', p_job_id);
    l_end_proc := replace(l_end_proc, ':P_REQUEST_ID', p_request_id);
    l_end_proc := replace(l_end_proc, ':P_BATCH_NAME', p_batch_name);
    l_insert_col := substr(l_insert_col, 2);
    l_cld_cols := substr(l_cld_cols, 2);
    l_main_clob := 'DECLARE '
                   || chr(10)
                   || 'l_err_msg clob; l_vs_num  NUMBER; l_vf_num    NUMBER; l_tot_count NUMBER; l_cld_record_count number ;'
                   || l_local_vars
                   || chr(10);
    l_main_clob := l_main_clob
                   || 'BEGIN'
                   || chr(10)
                   || l_pre_clob
                   || ' commit; '
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
                   || ' commit; ';
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
