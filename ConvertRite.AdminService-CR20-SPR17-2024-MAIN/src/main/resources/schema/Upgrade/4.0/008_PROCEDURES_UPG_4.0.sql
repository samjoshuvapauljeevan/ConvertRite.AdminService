CREATE OR REPLACE PROCEDURE cr_preload_metadata_proc (
    p_project_id            NUMBER,
    p_target_system_version IN VARCHAR2,
    p_user_id               IN VARCHAR2,
    p_ret_code              OUT VARCHAR2,
    p_ret_msg               OUT VARCHAR2
) IS

    lc_proc                   VARCHAR2(2000) DEFAULT 'CR_PRELOAD_METADATA_PROC';
    l_cld_metadata_table_name VARCHAR2(1000);
    l_cld_tbl_exist_chk       NUMBER;
    ln_cld_table_id           NUMBER;
    l_table_id                NUMBER;
    l_p_object_id             NUMBER;
    CURSOR c_setup_details IS
    SELECT
        a.project_id,
        a.object_id,
        a.cld_metadata_table_name
    FROM
        cr_preload_cld_setup_status a,
        cr_project_objects          b
    WHERE
            a.project_id = b.project_id
        AND a.object_id = b.object_id
        AND a.project_id = p_project_id
        AND a.cld_setup_status = '0. Setup Initiated'
      --  AND a.cld_setup_error_message IS NULL -- this is not required to handle retry mechanism
        AND b.parent_object_code IS NOT NULL; -- Only for child objects Cloud setups will be created.

    TYPE pre_load_details_tab IS
        TABLE OF c_setup_details%rowtype;
    l_preload_det_tab         pre_load_details_tab;
    l_err_meta_data_tbl_exp EXCEPTION;
    l_err_data_count EXCEPTION;
    l_tables_rec_count        NUMBER;
    l_columns_rec_count       NUMBER;
    l_cld_template_code       VARCHAR2(1000);
    l_cld_template_name       VARCHAR2(1000);
    l_cloud_meta_data_count   NUMBER;
    l_interface_column_count  NUMBER;
BEGIN
    -- Initial setup
    p_ret_code := 'SUCCESS';
    p_ret_msg := 'SUCCESS';

    -- Log start of the procedure
    cr_audit_log_msg_proc(p_user_id, lc_proc, ' ,project_id: '
                                              || p_project_id
                                              || ' ,Target system version: '
                                              || p_target_system_version, ' STARTING OF the procedure ', NULL);

    -- Insert initial records if they don't already exist
    BEGIN
        INSERT INTO cr_preload_cld_setup_status (
            project_id,
            object_id,
            cld_setup_status,
            val_pkg_status,
            creation_date,
            created_by,
            last_update_date,
            last_updated_by
        )
            SELECT
                project_id,
                object_id,
                '0. Setup Initiated',
                '0. Setup Initiated',
                sysdate,
                p_user_id,
                sysdate,
                p_user_id
            FROM
                cr_project_objects
            WHERE
                    project_id = p_project_id
                AND NOT EXISTS (
                    SELECT
                        1
                    FROM
                        cr_preload_cld_setup_status
                    WHERE
                            cr_preload_cld_setup_status.project_id = cr_project_objects.project_id
                        AND cr_preload_cld_setup_status.object_id = cr_project_objects.object_id
                );

        IF ( SQL%rowcount > 0 ) THEN
            --p_ret_msg := substr('The  data successfully  process in cr_preload_cld_setup_status' || SQL%rowcount, 1, 5000);
            cr_audit_log_msg_proc(p_user_id, lc_proc, ' ,project_id: '
                                                      || p_project_id
                                                      || ' ,Target system version: '
                                                      || p_target_system_version, 'Records inserted into cr_preload_cld_setup_status for processing: '
                                                      || SQL%rowcount, NULL);

            COMMIT;
        ELSE
            --p_ret_msg := substr('No data available to process in cr_preload_cld_setup_status' || SQL%rowcount, 1, 5000);
            cr_audit_log_msg_proc(p_user_id, lc_proc, ' ,project_id: '
                                                      || p_project_id
                                                      || ' ,Target system version: '
                                                      || p_target_system_version, 'No New Records to insert into cr_preload_cld_setup_status. 
													  Proceeding to process Error records (Considered the execution as Retry setup creation)', NULL);

            --RAISE l_err_data_count;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            p_ret_code := 'ERROR';
            p_ret_msg := substr('Error while Inserting Data into cr_preload_cld_setup_status table. Error: ' || sqlerrm, 1, 5000);
            cr_audit_log_msg_proc(p_user_id, lc_proc, ' ,project_id: '
                                                      || p_project_id
                                                      || ' ,Target system version: '
                                                      || p_target_system_version, p_ret_msg, NULL);

            RETURN;
    END;

    -- Fetch data in bulk using the cursor

    OPEN c_setup_details;
    FETCH c_setup_details
    BULK COLLECT INTO l_preload_det_tab;
    CLOSE c_setup_details;
    cr_audit_log_msg_proc(p_user_id, lc_proc, ' ,project_id: '
                                              || p_project_id
                                              || ' ,Target system version: '
                                              || p_target_system_version, 'Records Picked to Process: ' || l_preload_det_tab.count, NULL
                                              );

    -- Process the fetched data 
    FOR i IN l_preload_det_tab.first..l_preload_det_tab.last LOOP
        -- Example processing: Print each fetched row
        BEGIN
            cr_audit_log_msg_proc(p_user_id, lc_proc, ' ,project_id: '
                                                      || l_preload_det_tab(i).project_id
                                                      || 'Processing for Object_ID: '
                                                      || l_preload_det_tab(i).object_id
                                                      || ' ,Target system version: '
                                                      || p_target_system_version, ' Inside the Loop to Process Metadata for 
                                                      Object Object_ID: ' || l_preload_det_tab(i).object_id, NULL);
        --Fetch the MetaDataTable Name   from cr_objects Starts
            l_cld_metadata_table_name := NULL;
            l_cld_template_code := NULL;
            l_cld_template_name := NULL;
            BEGIN
                SELECT
                    cld_template_code,
                    cld_template_name,
                    cld_metadata_table_name
                INTO
                    l_cld_template_code,
                    l_cld_template_name,
                    l_cld_metadata_table_name
                FROM
                    cr_objects
                WHERE
                    object_id = l_preload_det_tab(i).object_id;

                cr_audit_log_msg_proc(p_user_id, lc_proc, ' ,project_id: '
                                                          || l_preload_det_tab(i).project_id
                                                          || 'Processing for Object_ID: '
                                                          || l_preload_det_tab(i).object_id
                                                          || ' ,Target system version: '
                                                          || p_target_system_version, 'The Cloud MetaData details fetched.  
                                                            CLD_TEMPLATE_CODE: '
                                                                                      || l_cld_template_code
                                                                                      || ', CLD_TEMPLATE_NAME: '
                                                                                      || l_cld_template_name
                                                                                      || ',CLD_METADATA_TABLE_NAME: '
                                                                                      || l_cld_metadata_table_name, NULL);

            EXCEPTION
                WHEN OTHERS THEN
                    p_ret_code := 'WARNING';
                    p_ret_msg := substr('Error While Fetching Cloud Metadata information for the Object. Error: ' || sqlerrm, 1, 5000
                    );
                    cr_audit_log_msg_proc(p_user_id, lc_proc, ' ,project_id: '
                                                              || l_preload_det_tab(i).project_id
                                                              || 'Processing for Object_ID: '
                                                              || l_preload_det_tab(i).object_id
                                                              || ' ,Target system version: '
                                                              || p_target_system_version, p_ret_msg, NULL);

                    RAISE l_err_meta_data_tbl_exp; -- skip the object from further processing
            END;

            IF ( l_cld_template_code IS NULL OR l_cld_template_name IS NULL OR l_cld_metadata_table_name IS NULL ) THEN
                p_ret_code := 'WARNING';
                p_ret_msg := 'Either Metadata Table Name or Template Code, Template Name are NULL';
                RAISE l_err_meta_data_tbl_exp;
            ELSE
               -- proceeding to fetch Interface columns

                l_cld_tbl_exist_chk := 0;
                l_tables_rec_count := 0;
                l_columns_rec_count := 0;
                l_interface_column_count := 0;
                ln_cld_table_id := NULL;
                SELECT
                    COUNT(1)
                INTO l_interface_column_count
                FROM
                    cr_target_intf_column_list
                WHERE
                        object_id = l_preload_det_tab(i).object_id
                    AND target_system_version = p_target_system_version;

                cr_audit_log_msg_proc(p_user_id, lc_proc, ' ,project_id: '
                                                          || l_preload_det_tab(i).project_id
                                                          || 'Processing for Object_ID: '
                                                          || l_preload_det_tab(i).object_id
                                                          || ' ,Target system version: '
                                                          || p_target_system_version, 'cr_target_intf_column_list count: ' || l_interface_column_count
                                                          , NULL);

                IF ( l_interface_column_count = 0 ) THEN
                    p_ret_code := 'WARNING';
                    p_ret_msg := 'Interface Columns doesnot exists in cr_target_intf_column_list table for the object';
                    RAISE l_err_meta_data_tbl_exp;
                ELSE
                 -- interface columns exists proceeding further
                 -- chk if table already exists in CR_CLOUD_TABLES
                    BEGIN
                        SELECT
                            COUNT(1)
                        INTO l_cld_tbl_exist_chk
                        FROM
                            cr_cloud_tables
                        WHERE
                            table_name = l_cld_metadata_table_name;

                    EXCEPTION
                        WHEN OTHERS THEN
                            p_ret_code := 'WARNING';
                            p_ret_msg := substr('Error while checking if MetaDataTable already exists in the POD. ERROR:' || sqlerrm,
                            1, 5000);
                            RAISE l_err_meta_data_tbl_exp;
                    END;

                    IF l_cld_tbl_exist_chk > 0 THEN
                        cr_audit_log_msg_proc(p_user_id, lc_proc, ' ,project_id: '
                                                                  || l_preload_det_tab(i).project_id
                                                                  || 'Processing for Object_ID: '
                                                                  || l_preload_det_tab(i).object_id
                                                                  || ' ,Target system version: '
                                                                  || p_target_system_version, 'MetaData table already exists in the POD.'
                                                                  , NULL);

                        p_ret_code := 'WARNING';
                        p_ret_msg := 'MetaData table already exists in the POD';
                        RAISE l_err_meta_data_tbl_exp;
                    ELSE
                        ln_cld_table_id := cr_cld_table_id_s.nextval;
                        cr_audit_log_msg_proc(p_user_id, lc_proc, ' ,project_id: '
                                                                  || l_preload_det_tab(i).project_id
                                                                  || 'Processing for Object_ID: '
                                                                  || l_preload_det_tab(i).object_id
                                                                  || ' ,Target system version: '
                                                                  || p_target_system_version
                                                                  || 'cloud MetaData Table Name: '
                                                                  || l_cld_metadata_table_name, ' Proceeding to insert into cloud tables with Table_ID: '
                                                                  || ln_cld_table_id, NULL);

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
                                l_cld_metadata_table_name,
                                l_cld_metadata_table_name,
                                l_cld_metadata_table_name,
                                NULL,
                                'META DATA',
                                'T',
                                l_preload_det_tab(i).object_id,
                                sysdate,
                                p_user_id,
                                sysdate,
                                p_user_id
                            );

                            l_tables_rec_count := SQL%rowcount;
                            cr_audit_log_msg_proc(p_user_id, lc_proc, ' ,project_id: '
                                                                      || l_preload_det_tab(i).project_id
                                                                      || 'Processing for Object_ID: '
                                                                      || l_preload_det_tab(i).object_id
                                                                      || ' ,Target system version: '
                                                                      || p_target_system_version
                                                                      || 'cloud MetaData Table Name: '
                                                                      || l_cld_metadata_table_name, ' Cloud TableName Inserted. COUNT of Rows Inserted into CLD table:'
                                                                      || l_tables_rec_count, NULL);

                            INSERT INTO cr_cloud_columns (
                                column_id,
                                table_id,
                                ora_edition_context,
                                object_id,
                                column_name,
                                physical_column_name,
                                user_column_name,
                                description,
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
                                    column_list_id,
                                    ln_cld_table_id target_system,
                                    target_system_version,
                                    object_id,
                                    column_name,
                                    physical_column_name,
                                    user_column_name,
                                    column_descrption,
                                    column_sequence,
                                    column_type,
                                    column_width,
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
                                    cr_target_intf_column_list
                                WHERE
                                        object_id = l_preload_det_tab(i).object_id
                                    AND target_system_version = p_target_system_version;

                            l_columns_rec_count := SQL%rowcount;
                            cr_audit_log_msg_proc(p_user_id, lc_proc, ' ,project_id: '
                                                                      || l_preload_det_tab(i).project_id
                                                                      || 'Processing for Object_ID: '
                                                                      || l_preload_det_tab(i).object_id
                                                                      || ' ,Target system version: '
                                                                      || p_target_system_version
                                                                      || 'cloud table id :'
                                                                      || ln_cld_table_id
                                                                      || ' l_columns_rec_count. before '
                                                                      || l_columns_rec_count, NULL);

                            IF (
                                l_tables_rec_count = 1
                                AND l_columns_rec_count = l_interface_column_count
                            ) THEN
                                UPDATE cr_preload_cld_setup_status
                                SET
                                    cld_setup_status = '1. MetaData Created Successfully',
                                    cld_template_code = l_cld_template_code,
                                    cld_template_name = l_cld_template_name,
                                    cld_metadata_table_name = l_cld_metadata_table_name,
                                    cld_setup_error_message = NULL, -- error message to be updatd to NULL to handle retry scenarios
                                    last_update_date = sysdate,
                                    last_updated_by = p_user_id
                                WHERE
                                        project_id = p_project_id
                                    AND object_id = l_preload_det_tab(i).object_id;

                                cr_audit_log_msg_proc(p_user_id, lc_proc, ' ,project_id: '
                                                                          || l_preload_det_tab(i).project_id
                                                                          || 'Processing for Object_ID: '
                                                                          || l_preload_det_tab(i).object_id
                                                                          || ' ,Target system version: '
                                                                          || p_target_system_version
                                                                          || 'cloud table id :'
                                                                          || ln_cld_table_id, ' Metadata Created successfully. COMMIT the change.'
                                                                          || SQL%rowcount, NULL);

                                COMMIT;
                            ELSE
                                p_ret_code := 'WARNING';
                                p_ret_msg := 'Issue with columns insertion into cr_cloud_columns from cr_target_intf_column_list.';
                                cr_audit_log_msg_proc(p_user_id, lc_proc, ' ,project_id: '
                                                                          || l_preload_det_tab(i).project_id
                                                                          || 'Processing for Object_ID: '
                                                                          || l_preload_det_tab(i).object_id
                                                                          || ' ,Target system version: '
                                                                          || p_target_system_version
                                                                          || 'cloud table id :'
                                                                          || ln_cld_table_id, ' Metadata not created Correctly. Rollback the change.'
                                                                          || SQL%rowcount, NULL);

                                ROLLBACK;
                                RAISE l_err_meta_data_tbl_exp;
                            END IF;

                        EXCEPTION
                            WHEN OTHERS THEN
                                p_ret_code := 'WARNING';
                                p_ret_msg := substr('Exception while creating METADATA. ERROR: ' || sqlerrm, 1, 5000);
                                cr_audit_log_msg_proc(p_user_id, lc_proc, ' ,project_id: '
                                                                          || l_preload_det_tab(i).project_id
                                                                          || 'Processing for Object_ID: '
                                                                          || l_preload_det_tab(i).object_id
                                                                          || ' ,Target system version: '
                                                                          || p_target_system_version, p_ret_msg || 'ROLLBACK the inserts of TABLES and COLUMNS'
                                                                          , NULL);

                                ROLLBACK;--In case any failure need to Rollback
                                RAISE l_err_meta_data_tbl_exp;
                        END;

                    END IF;

                END IF;

            END IF;

        EXCEPTION
            WHEN l_err_meta_data_tbl_exp THEN
                UPDATE cr_preload_cld_setup_status
                SET
                    cld_setup_error_message = p_ret_msg,
                    cld_template_code = l_cld_template_code,
                    cld_template_name = l_cld_template_name,
                    cld_metadata_table_name = l_cld_metadata_table_name,
                    last_update_date = sysdate,
                    last_updated_by = p_user_id
                WHERE
                        project_id = l_preload_det_tab(i).project_id
                    AND object_id = l_preload_det_tab(i).object_id;

                cr_audit_log_msg_proc(p_user_id, lc_proc, ' ,project_id: '
                                                          || l_preload_det_tab(i).project_id
                                                          || 'Processing for Object_ID: '
                                                          || l_preload_det_tab(i).object_id
                                                          || ' ,Target system version:  '
                                                          || p_target_system_version
                                                          || ' ,User id: '
                                                          || p_user_id, 'In User Defined Exception L_ERR_META_DATA_TBL_EXP, 
                                                          SKIP the object from further processing', NULL);

                COMMIT;
            WHEN OTHERS THEN
                p_ret_code := 'WARNING';
                p_ret_msg := substr('Unexpected Error while Processing the Metadata details for the Object: ' || sqlerrm, 1, 5000);
                cr_audit_log_msg_proc(p_user_id, lc_proc, ' ,project_id: '
                                                          || l_preload_det_tab(i).project_id
                                                          || 'Processing for Object_ID: '
                                                          || l_preload_det_tab(i).object_id
                                                          || ' ,Target system version:  '
                                                          || p_target_system_version
                                                          || ' ,User id: '
                                                          || p_user_id, p_ret_msg, NULL);

                UPDATE cr_preload_cld_setup_status
                SET
                    cld_setup_error_message = p_ret_msg,
                    cld_template_code = l_cld_template_code,
                    cld_template_name = l_cld_template_name,
                    cld_metadata_table_name = l_cld_metadata_table_name,
                    last_update_date = sysdate,
                    last_updated_by = p_user_id
                WHERE
                        project_id = l_preload_det_tab(i).project_id
                    AND object_id = l_preload_det_tab(i).object_id;

                COMMIT;
        END;
    END LOOP;

    cr_audit_log_msg_proc(p_user_id, lc_proc, ',project_id: '
                                              || p_project_id
                                              || ' ,Target system version: '
                                              || p_target_system_version, ' Successfully Completed the procedure ', NULL);

EXCEPTION
    WHEN OTHERS THEN
        p_ret_code := 'ERROR';
        p_ret_msg := substr('Process ended in Unexpected Error: ' || sqlerrm, 1, 5000);
        cr_audit_log_msg_proc(p_user_id, lc_proc, ',project_id: '
                                                  || p_project_id
                                                  || ' ,Target system version: '
                                                  || p_target_system_version
                                                  || ' ,User id: '
                                                  || p_user_id, p_ret_msg, NULL);

END cr_preload_metadata_proc;
$#$
create or replace PROCEDURE cr_fbdi_filegen_proc (
    p_cld_template_id IN NUMBER,
    p_batch_name      IN VARCHAR2,
    p_clob_fbdi_file  OUT CLOB,
    p_result_code     OUT VARCHAR2,
    p_result_msg      OUT VARCHAR2
) 
/*
*******************************************************************************
* Project                        : ConvertRite
* Application                    :
* Title                          : cr_fbdi_filegen_proc
* Program Name                   : cr_fbdi_filegen_proc
* Description and Purpose        : Proc to generate FBDI in ConvertRite
* Created by                     : sampaul.jeevan
* Change History                 : 1.0
*==============================================================================
* S.NO |    Date      |                 Reason                                |
*  1   |              | Intial                                                |
*  2   | 07-JAN-2025  | Added Condition to check Validation Flag and error msg|
*==============================================================================
*/
IS
    TYPE varchartab IS
        TABLE OF CLOB;
    TYPE clobtab IS
        TABLE OF CLOB;
    l_clob_tab      clobtab;
    l_clob          CLOB;
    l_header_flag   VARCHAR2(240);
    l_header_cols   CLOB;
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
            CASE
                WHEN column_type IN ( 'V' ) THEN
                    ''''
                    || '"'
                    || ''''
                    || '||'
                    || 'REPLACE('
                    || column_name
                    || ','
                    || ''''
                    || '"'
                    || ''''
                    || ','
                    || ''''
                    || '""'
                    || ''''
                    || ')'
                    || '||'
                    || ''''
                    || '"'
                    || ''''
                    || '||'
                    || ''''
                    || ','
                    || ''''
                    || '||'
            /*   WHEN column_type = 'N' THEN
                    ''''
                    || ''''
                    || '||'
                    || column_name
                    || '||'
                    || ''''
                    || ','
                    || ''''
                    || '||'*/
                ELSE
                    /*''''
                    || '"'
                    || ''''
                    || '||'
                    || column_name
                    || '||'
                    || ''''
                    || '"'
                    || ''''
                    || '||'
                    || ''''
                    || ','
                    || ''''
                    || '||'*/
                     ''''
                    || ''''
                    || '||'
                    || column_name
                    || '||'
                    || ''''
                    || ','
                    || ''''
                    || '||'
            END AS col_expression
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
            CASE
                WHEN column_type = 'D' THEN
                    ''''
                    || '||'
                    || 'TO_CHAR('
                    || column_name
                    || ','
                    || ''''
                    || l_date_format
                    || ''''
                    || ')'
                    || '||'
                    || ''''
                    || '"'
                    || ''''
                    || ','
                    || ''''
                    || '||'
                WHEN column_type = 'V' THEN
                    ''''
                    || '"'
                    || ''''
                    || '||'
                    || 'REPLACE('
                    || column_name
                    || ','
                    || ''''
                    || '"'
                    || ''''
                    || ','
                    || ''''
                    || '""'
                    || ''''
                    || ')'
                    || '||'
                    || ''''
                    || '"'
                    || ''''
                    || '||'
                    || ''''
                    || ','
                    || ''''
                    || '||'
               /* WHEN column_type = 'N' THEN
                    ''''
                    || ''''
                    || '||'
                    || column_name
                    || '||'
                    || ''''
                    || ','
                    || ''''
                    || '||'*/
                ELSE
                   /* ''''
                    || '"'
                    || ''''
                    || '||'
                    || column_name
                    || '||'
                    || ''''
                    || '"'
                    || ''''
                    || '||'
                    || ''''
                    || ','
                    || ''''
                    || '||'
                    */
                     ''''
                    || ''''
                    || '||'
                    || column_name
                    || '||'
                    || ''''
                    || ','
                    || ''''
                    || '||'
            END AS col_expression
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
        l_cols := l_cols || l_col_tab(t);
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
             || ''''
             || 'AND NVL(VALIDATION_FLAG, ''VS'') = ''VS'' 
             AND NVL(ERROR_MSG,''SUCCESS'') = ''SUCCESS''' 
             -- Change 1.0 by sampaul.jeevan
             ;
    BEGIN
        SELECT
            nvl(info_value, 'N')
        INTO l_header_flag
        FROM
            cr_object_information
        WHERE
                upper(info_type) = 'INCLUDE HEADERS IN THE FILE TO BE IMPORTED'
            AND object_id = l_obj_id;
    EXCEPTION
        WHEN OTHERS THEN
            l_header_flag := 'N';
    END;
    IF l_header_flag = 'Y' THEN
        SELECT
            LISTAGG('"' || b.user_column_name, '",') WITHIN GROUP(
            ORDER BY
                a.display_seq ASC
            )
            || '"'
        INTO l_header_cols
        FROM
            cr_cld_template_cols a,
            cr_cloud_columns     b,
            cr_cld_template_hdrs c
        WHERE
                a.cld_template_id = p_cld_template_id
            AND a.display_seq IS NOT NULL
            AND c.cld_template_id = a.cld_template_id
            AND c.metadata_table_id = b.table_id
            AND upper(a.column_name) = upper(b.user_column_name)
        ORDER BY
            nvl(a.display_seq, 9999999999) ASC;
        l_clob := l_header_cols || chr(10);
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
                                                    || ''''
                                                    || 'AND NVL(VALIDATION_FLAG,
                                                        ''VS'') = ''VS'' 
                                                        AND NVL(ERROR_MSG,
                                                        ''SUCCESS'') = 
                                                        ''SUCCESS''' 
                                                -- Change 1.0 by sampaul.jeevan
                                                    );
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
              CASE WHEN utc.data_type NOT IN ( 'DATE','CLOB','NUMBER' ) AND utc.data_type NOT LIKE '%TIMESTAMP%'
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

create or replace PROCEDURE cr_populate_orig_trans_id_proc (
    p_template_id IN NUMBER,
    p_table_name  IN VARCHAR2,
    p_user_id     IN VARCHAR2,
    p_batch_name  IN VARCHAR2,
    p_ret_code    OUT VARCHAR2,
    p_ret_msg     OUT VARCHAR2
) 
/*
*******************************************************************************
* Project                        : ConvertRite
* Application                    :
* Title                          : cr_populate_orig_trans_id_proc
* Program Name                   : cr_populate_orig_trans_id_proc
* Description and Purpose        : Proc to generate orig_trans_id
* Created by                     : sampaul.jeevan
* Change History                 : 1.0
*==============================================================================
* S.NO |    Date    |                 Reason                                   |
*  1   |            | Intial                                                   |
*  2   | 07-JAN-2025| Optimized the condition for performance                  |
*==============================================================================
*/
IS
    lc_duplicate_chk_flag                VARCHAR2(50) DEFAULT 'N';
    a_cols varchar2(240);
    lc_prog                              VARCHAR2(2000) DEFAULT 'CR_POPULATE_ORIG_TRANS_ID_PROC';
    lc_unique_trans_cols_list            VARCHAR2(2000);
    lc_denorm_orig_trans_upd_sql         VARCHAR2(2500) DEFAULT 'UPDATE '
                                                        || p_table_name
                                                        || q'[ set orig_trans_id = :COLUMN_LIST]'
                                                        || ' where src_template_id = '
                                                        || p_template_id
                                                        || q'[ AND CR_BATCH_NAME = ']'
                                                        || p_batch_name
                                                        || '''';
    lc_denorm_update_duplicate           VARCHAR2(5000) DEFAULT q'[UPDATE :TABLE_NAME a SET a.validation_flag = 'DUPLICATE',
                                                                                            a.error_msg = 'DUPLICATE DATA IDENTIFIED FOR COLUMN(S) COMBINATION : '|| ]'
                                                      || 'q'
                                                      || '''['
                                                      || q'[':COLUMN_LIST']'
                                                      || ']'''
                                                      || q'[ WHERE a.rowid NOT IN ( SELECT MIN(b.rowid) FROM :TABLE_NAME b   WHERE b.orig_trans_id = a.orig_trans_id
                                                               AND cr_batch_name = ':P_BATCH_NAME'
                                                                                                                                                                                                         )
                                                               AND cr_batch_name = ':P_BATCH_NAME']';-- Changes made by @sampaul.jeevan
    lc_denorm_update_duplicate_first_row VARCHAR2(5000) DEFAULT q'[UPDATE :TABLE_NAME a SET a.validation_flag = 'DUPLICATE',
                                                                                            a.error_msg = 'DUPLICATE DATA IDENTIFIED FOR COLUMN(S) COMBINATION : '|| ]'
                                                                || 'q'
                                                                || '''['
                                                                || q'[':COLUMN_LIST']'
                                                                || ']'''
                                                                || q'[ WHERE orig_trans_id  IN ( SELECT DISTINCT orig_trans_id
                                                                                                                                                                          FROM :TABLE_NAME b
                                                                                                                                                                          WHERE B.VALIDATION_FLAG = 'DUPLICATE'
                                                                         AND cr_batch_name = ':P_BATCH_NAME'
                                                                                                                                                                          )
                                                                         AND cr_batch_name = ':P_BATCH_NAME']';  -- Changes made by @sampaul.jeevan
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
    LISTAGG('a.'||column_name, '||'
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
a_cols := replace(lc_unique_trans_cols_list,'a.','b.');
lc_unique_trans_cols_list := replace(lc_unique_trans_cols_list,'a.','');
dbms_output.put_line(a_cols);
    IF lc_duplicate_chk_flag = 'Y' THEN
BEGIN
            IF lc_unique_trans_cols_list IS NOT NULL THEN
                lc_denorm_orig_trans_upd_sql := replace(lc_denorm_orig_trans_upd_sql, ':COLUMN_LIST', lc_unique_trans_cols_list);
                dbms_output.put_line(lc_denorm_orig_trans_upd_sql);
EXECUTE IMMEDIATE lc_denorm_orig_trans_upd_sql;
COMMIT;
lc_denorm_update_duplicate := replace(lc_denorm_update_duplicate, ':TABLE_NAME', p_table_name);
                lc_denorm_update_duplicate := replace(lc_denorm_update_duplicate, ':P_BATCH_NAME', p_batch_name);
                lc_denorm_update_duplicate := replace(lc_denorm_update_duplicate, ':COLUMN_LIST', nvl(A_COLS, ''));
                               lc_denorm_update_duplicate := replace(lc_denorm_update_duplicate, ':B_COLUMN_LIST', nvl(REPLACE(A_COLS,'b.','a.'), ''));
                                dbms_output.put_line(lc_denorm_update_duplicate);
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
dbms_output.put_line(lc_denorm_update_duplicate_first_row);
dbms_output.put_line(lc_denorm_update_duplicate);
EXCEPTION
    WHEN OTHERS THEN
        p_ret_code := 'ERROR';
        p_ret_msg := 'Unexpected error in CR_POPULATE_ORIG_TRANS_ID_PROC. Error: ' || sqlerrm;
END cr_populate_orig_trans_id_proc;

$#$
create or replace PROCEDURE CR_CREATE_STG_TABLE_PROC (
    p_table_id         IN NUMBER,
    p_template_id      IN NUMBER,
    p_template_code    IN VARCHAR2,
    p_calling_env      IN VARCHAR2,
    p_user_id          IN VARCHAR2,     
    p_ret_code         OUT VARCHAR2,
    P_ret_msg          OUT VARCHAR2
) 
/*
*******************************************************************************
* Project                        : ConvertRite
* Application                    :
* Title                          : CR_CREATE_STG_TABLE_PROC
* Program Name                   : CR_CREATE_STG_TABLE_PROC
* Description and Purpose        : Proc to generate FBDI in ConvertRite
* Created by                     : sampaul.jeevan
* Change History                 : 1.0
*==============================================================================
* S.NO |    Date    |                 Reason                                   |
*  1   |            | Intial                                                   |
*  2   | 07-JAN-2025| Added Validation Flag and err_msg cols to cld staging tbl|
*  3   | 16-JAN-2025| changed size of cr_batch_name col in src and clg stg tbl |
*  4   | 13-FEB-2025| data and TIMESTAMP to varchar2 in cloud staging table    |
*==============================================================================
*/
AS
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
                || ' ' || CASE WHEN cc.column_type IS NULL THEN 'VARCHAR2(400)' ELSE (decode(upper(cc.column_type), 'V', 'VARCHAR2(' || nvl(cc.width,400) || ')', 'D', 'VARCHAR2(100)',
                'N', 'NUMBER', 'L', 'LONG','TIMESTAMP','VARCHAR2(100)', upper(cc.column_type)) ) END || ','),     ',')|| ')' sql_data ---V4 
          FROM cr_cloud_columns  cc
         WHERE cc.table_id = p_table_id
           AND cc.column_name IN ( SELECT column_name 
                                     FROM cr_cld_template_cols
                                    WHERE cld_template_id = p_template_id
                )
         ORDER BY COLUMN_SEQUENCE;  --->  data and TIMESTAMP to varchar2 in cloud staging table  
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
                     || ' ADD (CR_LOAD_ID NUMBER,CR_BATCH_NAME VARCHAR2(2000))'; -- Changes made by @sampaul.jeevan reduced cr_batch_name col size from 2400 to 2000
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
                     || ' ADD (CR_LOAD_ID NUMBER,CR_BATCH_NAME VARCHAR2(2000),VALIDATION_FLAG VARCHAR2(2000), ERROR_MSG VARCHAR2(4000))';-- Changes made by @sampaul.jeevan reduced cr_batch_name col size from 2400 to 2000
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
) 
/*
*******************************************************************************
* Project                        : ConvertRite
* Application                    :
* Title                          : CR_CLD_TRANSFORM_MAIN_PROC
* Program Name                   : CR_CLD_TRANSFORM_MAIN_PROC
* Description and Purpose        : Proc to Transform the data from src stg tbl
* Created by                     : sampaul.jeevan
* Change History                 : 1.0
*=========================================================================================
* S.NO |    Date      |                 Reason                                           |
*  1   |              | Intial                                                           |
*  2   | 08-JAN-2025  | Added Condition to check Validation Flag and errmsg in l_end_proc|
*=========================================================================================
*/
IS
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
                                           WHERE  CR_BATCH_NAME = ':P_BATCH_NAME'
                                           AND NVL(VALIDATION_FLAG,'VS') = 'VS'
                                           AND NVL(ERROR_MSG,'SUCCESS') = 'SUCCESS'; 
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
                                          END;]'; -- Added Condition to check Validation Flag and errmsg in l_end_proc while calculating l_cld_record_count by @sampaul.jeevan
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
              CASE WHEN utc.data_type NOT IN ( 'DATE','CLOB','NUMBER' ) AND utc.data_type NOT LIKE '%TIMESTAMP%'
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
