create or replace FUNCTION cr_copy_func (
    p_source_pod     IN VARCHAR2,
    p_destinaion_pod IN VARCHAR2,
    p_project_name   IN VARCHAR2,
    p_object_id      IN VARCHAR2 DEFAULT NULL,
    p_copy_id        IN VARCHAR2
) RETURN CLOB AS
    PRAGMA autonomous_transaction;
    l_final_clob          CLOB;
    l_obj_count           NUMBER;
    l_msg                 CLOB;
    l_log                 CLOB;
    l_copy_status         VARCHAR2(240);
    l_query_1             CLOB DEFAULT q'[
DECLARE
    TYPE varchartab IS TABLE OF VARCHAR2(420);
    TYPE numtab IS TABLE OF NUMBER;
        l_error_flag varchar2(1);
    l_log                 CLOB;l_object_codes        varchartab;
    v_count number ;
    l_object_id           numtab;
    l_object_code         varchartab;
    l_src_template_id     numtab;
    l_cld_template_id     numtab;
    l_fs_count            NUMBER;
    l_ms_count            NUMBER;
    l_parent_object       varchartab;
    l_source_table_id     NUMBER;
    l_projectexists       NUMBER; -- Variable to store whether the project exists (1) or not (0)
    l_object_num          NUMBER;  
    l_objectexists        NUMBER;  
    l_object_ids          NUMBER;
    l_project_id          NUMBER;
    l_src_temp_id         NUMBER;
    l_cld_temp_id         NUMBER;
    l_obj_list            VARCHAR2(2000);
    l_cloud_table_id      NUMBER;
    l_map_set_count       NUMBER;
    l_map_set_id          NUMBER;
    l_formula_count       NUMBER;
    l_count               NUMBER;
    l_cld_count           NUMBER;
    l_src_col_id          NUMBER;
    l_dest_src_temp_check NUMBER;
    l_dest_cld_temp_check NUMBER;
    l_map_set_check       NUMBER;l_uh_clob             CLOB;l_hook_id             NUMBER;
    l_uh_check            NUMBER;
    l_ret_code            VARCHAR2(250);
    l_ret_msg             VARCHAR2(250);
    l_drop_stmt           VARCHAR2(2000);
    l_table_chek          NUMBER;
    l_lookup_set_id       NUMBER;
    l_lookup_check        NUMBER;
    l_group_id            NUMBER;
       e_project_not_found EXCEPTION;
    CURSOR get_src_temp_details (
        l_project_id IN NUMBER
    ) IS
    SELECT
        src_template_id,
        src_template_code,
        staging_table_name,
        object_id 
    FROM
        :p_destinaion_pod.cr_src_template_hdrs
    WHERE
        src_template_code IN (
            SELECT src_template_code
            FROM :p_source_pod.cr_src_template_hdrs
            WHERE project_id = l_project_id :OBJECT_WHERE_CLAUSE   );
    CURSOR get_cld_temp_details (
        l_project_id IN NUMBER
    ) IS
    SELECT
        cld_template_id,
        cld_template_code,
        staging_table_name
    FROM
        :p_destinaion_pod.cr_cld_template_hdrs
    WHERE
            project_id = l_project_id :OBJECT_WHERE_CLAUSE  
        ;
    CURSOR get_src_temp_id (
        l_project_id IN NUMBER
    ) IS
    SELECT
        src_template_id, src_template_code, staging_table_name
    FROM
        :p_source_pod.cr_src_template_hdrs
    WHERE
            project_id = l_project_id :OBJECT_WHERE_CLAUSE  
        ;
    CURSOR get_cld_temp_id (
        l_project_id IN NUMBER
    ) IS
    SELECT
        cld_template_id, cld_template_code, object_id, staging_table_name
    FROM :p_source_pod.cr_cld_template_hdrs
    WHERE
            project_id = l_project_id :OBJECT_WHERE_CLAUSE   ;
    CURSOR get_cld_temp_cols_details (
        p_template_id IN NUMBER
    ) IS
    SELECT
        *
    FROM :p_source_pod.cr_cld_template_cols
    WHERE cld_template_id = p_template_id ORDER BY column_id;
    CURSOR get_mapping_details ( l_project_id IN NUMBER ) IS
    SELECT DISTINCT cols.mapping_set_id, cols.mapping_type,
        CASE
            WHEN cols.mapping_type IN ( 'One to One', 'Two to One', 'Three to One' ) THEN
                ( SELECT
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
        :p_source_pod.cr_cld_template_hdrs hdrs, :p_source_pod.cr_cld_template_cols cols
    WHERE
            hdrs.project_id = l_project_id
        AND hdrs.cld_template_id = cols.cld_template_id
        AND mapping_type IN ( 'One to One', 'Two to One', 'Three to One', 'Formula' )
        :OBJECT_WHERE_CLAUSE ;
    CURSOR get_userhook_details ( l_cld_template_id IN NUMBER ) IS
    SELECT DISTINCT dbms_lob.substr(cuh.hook_text, instr(cuh.hook_text, '(') - 1) userhook
    FROM :p_source_pod.cr_hook_usages chu, :p_source_pod.cr_user_hooks  cuh
    WHERE chu.template_id = l_cld_template_id AND chu.hook_id = cuh.hook_id
    and cuh.hook_type = 'PLSQL';
    CURSOR get_exist_uh_details (  l_cld_template_id IN NUMBER ) IS
    SELECT DISTINCT
        chu.hook_id,
        cuh.hook_code,
        dbms_lob.substr(cuh.hook_text,
                        instr(cuh.hook_text, '(') - 1) userhook
    FROM
        :p_source_pod.cr_hook_usages chu,
        :p_source_pod.cr_user_hooks  cuh
    WHERE
        chu.template_id IN (
            SELECT
                cld_template_id
            FROM
                :p_source_pod.cr_cld_template_hdrs
            WHERE
                    project_id = l_project_id
                :OBJECT_WHERE_CLAUSE  
        )
        AND chu.hook_id = cuh.hook_id;
    CURSOR get_lookup_details (
        l_project_id IN NUMBER
    ) IS
    SELECT DISTINCT
        ls.lookup_set_id,
        ls.lookup_set_code
    FROM
        :p_source_pod.cr_cld_template_hdrs hdrs,
        :p_source_pod.cr_cld_template_cols cols,
        :p_source_pod.cr_mapping_sets      m,
        :p_source_pod.cr_lookup_sets       ls
    WHERE
            hdrs.project_id = l_project_id
        :OBJECT_WHERE_CLAUSE  
        AND hdrs.cld_template_id = cols.cld_template_id
        AND cols.mapping_set_id = m.map_set_id
        AND m.lookup_set_id = ls.lookup_set_id;
    CURSOR get_exist_object_group_details (
        l_project_id IN NUMBER
    ) IS
    SELECT
        group_id,
        project_id,
        group_code
    FROM
        :p_source_pod.cr_object_group_hdrs
    WHERE
        project_id = l_project_id;
BEGIN
    l_projectexists := 0;
BEGIN
    SELECT
        nvl(COUNT(project_name),
            0)
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
 EXCEPTION
        WHEN NO_DATA_FOUND THEN
             l_error_flag := 'Y';
            l_log := l_log || 'Project information not available in the Source POD: ' || ':p_project_name' || ' - Error: ' || 'NO_DATA_FOUND' || chr(10);
       RAISE e_project_not_found;
      WHEN OTHERS THEN
            l_error_flag := 'Y';
           l_log := l_log || 'Unexpected error occurred while retrieving Project ID in the Source POD: ' || ':p_project_name' || ' - Error: ' || SQLERRM || chr(10);          
		  RAISE e_project_not_found;
    END;
    l_log := l_log
             || '-------------------- Start Project Details : '
             || ':p_project_name'
             || '-------------------- '
             || chr(10)
             || chr(10);
        DELETE FROM :p_destinaion_pod.cr_projects
        WHERE
            project_id = l_project_id;
            DELETE FROM :p_destinaion_pod.cr_project_objects
            WHERE
                    project_id = l_project_id
                :OBJECT_WHERE_CLAUSE  
                :PROJECT_WHERE_CLAUSE
                ;
        COMMIT;
            DELETE FROM :p_destinaion_pod.cr_proj_activities
            WHERE
                    project_id = l_project_id
                :OBJECT_WHERE_CLAUSE   
                  ;
                COMMIT;
        l_log := l_log
                 || 'Deleted  existing setups for the  Project : '
                 || ':p_project_name'
                 || chr(10);
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
                project_id = l_project_id
            :OBJECT_WHERE_CLAUSE  
             :PROJECT_WHERE_CLAUSE
            ;
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
                project_id = l_project_id
            :OBJECT_WHERE_CLAUSE  
            ;
    COMMIT;
           l_log := l_log
             || 'Project, Project Objects and Project Activities are successfully inserted for the selected Project : '
             || ':p_project_name'
             || chr(10);
    l_log := l_log
             || chr(10)
             || ' ------------------- End Of Copying Project Setup Details ------------------- '
             || chr(10);
    BEGIN
        l_log := l_log
                 || ' ------------------- User Hook Details  ------------------- '
                 || chr(10)
                 || chr(10);
BEGIN
 SELECT COUNT(DISTINCT cuh.hook_code)
    INTO v_count
    FROM :p_source_pod.cr_hook_usages chu
    , :p_source_pod.cr_user_hooks cuh
         where chu.hook_id = cuh.hook_id
    and  chu.template_id IN (
        SELECT cld_template_id
        FROM :p_source_pod.cr_cld_template_hdrs
        WHERE project_id = l_project_id
    );
    IF v_count = 0 THEN
        l_log := l_log || 'No User Hooks associated with Cloud Templates for  project_id: ' || l_project_id || chr(10);
    ELSE
            FOR x IN (
                SELECT DISTINCT
                    cuh.hook_code
                FROM
                    :p_source_pod.cr_hook_usages chu,
                    :p_source_pod.cr_user_hooks  cuh
                WHERE
                    chu.template_id IN (
                        SELECT
                            cld_template_id
                        FROM
                            :p_source_pod.cr_cld_template_hdrs
                        WHERE
                            project_id = l_project_id
                            :OBJECT_WHERE_CLAUSE 
                    )
                    AND chu.hook_id = cuh.hook_id
            ) LOOP
                BEGIN
                    DELETE FROM :p_destinaion_pod.cr_hook_usages
                    WHERE
                        hook_id IN (
                            SELECT DISTINCT
                                hook_id
                            FROM
                                :p_destinaion_pod.cr_user_hooks
                            WHERE
                                hook_code = x.hook_code
                        );
                    COMMIT;
                    DELETE FROM :p_destinaion_pod.cr_user_hooks
                    WHERE
                        hook_code = x.hook_code;
                    l_log := l_log
                             || 'Deleting Existing Userhooks with same hook_code : '
                             || x.hook_code
                             || chr(10);
                    COMMIT;
                    INSERT INTO :p_destinaion_pod.cr_user_hooks (
                        hook_type,
                        hook_name,
                        hook_code,
                        description,
                        hook_text,
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
                            hook_type,
                            hook_name,
                            hook_code,
                            description,
                            hook_text,
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
                            :p_source_pod.cr_user_hooks
                        WHERE
                            hook_code = x.hook_code;
                    l_log := l_log
                             || 'Inserting hook_code : '
                             || x.hook_code
                             || chr(10);
                    COMMIT;
                EXCEPTION
                    WHEN OTHERS THEN
                    l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error occurred while copying the hook_code: '
                                 || x.hook_code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                        ROLLBACK;
                END;
            END LOOP;
            l_log := l_log
                     || chr(10)
                     || '-------------------- End of User Hook Details --------------------'
                     || chr(10);
                     end if ;
        EXCEPTION
            WHEN OTHERS THEN
            l_error_flag := 'Y';
                l_log := l_log
                         || 'Error occurred in User Hook block - Error: '
                         || sqlerrm
                         || chr(10);
                ROLLBACK;
        END;
      l_log := l_log || '---------------------- Start of Copying Lookup Details ----------------- ';
        BEGIN
            FOR i IN get_lookup_details(l_project_id) LOOP
                BEGIN
                    l_lookup_set_id := NULL;
                    DELETE FROM :p_destinaion_pod.cr_lookup_values
                    WHERE
                        lookup_set_id IN (
                            SELECT
                                lookup_set_id
                            FROM
                                :p_destinaion_pod.cr_lookup_sets
                            WHERE
                                lookup_set_code = i.lookup_set_code
                        );
                    DELETE FROM :p_destinaion_pod.cr_lookup_sets
                    WHERE
                        lookup_set_code = i.lookup_set_code;
                    l_log := l_log
                             || 'Deleted LookupsetCode  : '
                             || i.lookup_set_code
                             || chr(10);
                    COMMIT;
                    BEGIN
                        INSERT INTO :p_destinaion_pod.cr_lookup_sets (
                            lookup_set_name,
                            lookup_set_code,
                            description,
                            related_to,
                            lookup_flag,
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
                                lookup_set_name,
                                lookup_set_code,
                                description,
                                related_to,
                                lookup_flag,
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
                                :p_source_pod.cr_lookup_sets
                            WHERE
                                    lookup_set_id = i.lookup_set_id
                                AND lookup_set_code = i.lookup_set_code;
                        l_log := l_log
                                 || 'Inserting Lookup Set :'
                                 || i.lookup_set_code
                                 || ' with Lookup_set_id '
                                 || i.lookup_set_id
                                 || chr(10);
                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS THEN
                        l_error_flag := 'Y';
                            l_log := l_log
                                     || 'Error occurred during Insert for Lookup Set Code: '
                                     || i.lookup_set_code
                                     || ' - Error: '
                                     || sqlerrm
                                     || chr(10);
                            ROLLBACK;
                    END;
            BEGIN
                    SELECT DISTINCT
                        lookup_set_id
                    INTO l_lookup_set_id
                    FROM
                        :p_destinaion_pod.cr_lookup_sets
                    WHERE
                        lookup_set_code = i.lookup_set_code;
                         EXCEPTION
                WHEN NO_DATA_FOUND THEN
                l_error_flag := 'Y';
                    l_log := l_log
                             || 'No Lookup Set ID found for Lookup Set Code: '
                             || i.lookup_set_code
                             || chr(10);
                    l_lookup_set_id := NULL; -- Ensure l_lookup_set_id is null if no data is found
                WHEN OTHERS THEN
                    l_log := l_log
                             || 'Error occurred while retrieving Lookup Set ID for Code: '
                             || i.lookup_set_code
                             || ' - Error: '
                             || sqlerrm
                             || chr(10);
                    ROLLBACK;
            END;
                    BEGIN
                        INSERT INTO :p_destinaion_pod.cr_lookup_values (
                            lookup_value,
                            lookup_set_id,
                            actual_value,
                            attribute1,
                            attribute2,
                            attribute3,
                            attribute4,
                            attribute5,
                            enabled_flag,
                            last_updated_by,
                            last_update_date,
                            creation_date,
                            created_by
                        )
                            SELECT
                                lookup_value,
                                l_lookup_set_id,
                                actual_value,
                                attribute1,
                                attribute2,
                                attribute3,
                                attribute4,
                                attribute5,
                                enabled_flag,
                                last_updated_by,
                                last_update_date,
                                creation_date,
                                created_by
                            FROM
                                :p_source_pod.cr_lookup_values
                            WHERE
                                lookup_set_id = i.lookup_set_id;
                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS THEN
                        l_error_flag := 'Y';
                            l_log := l_log
                                     || 'Error occurred during Insert for Lookup Values of Lookup Set Code: '
                                     || i.lookup_set_code
                                     || ' - Error: '
                                     || sqlerrm
                                     || chr(10);
                            ROLLBACK;
                    END;
                    l_log := l_log || '---------------------- Start of Copying Lookup Details ----------------- '||chr(10);
                EXCEPTION
                    WHEN OTHERS THEN
                    l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error occurred with Lookup Set Code: '
                                 || i.lookup_set_code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                        ROLLBACK;
                END;
            END LOOP;
        EXCEPTION
            WHEN OTHERS THEN
            l_error_flag := 'Y';
                l_log := l_log
                         || 'Error occurred in Lookup Set  block - Error: '
                         || sqlerrm
                         || chr(10);
                ROLLBACK;
        END;
          l_log := l_log||
                     chr(10)|| '-------------------- End of Copying Lookup Set Details  --------------------'||chr(10);
        BEGIN
            l_log := l_log
                     || '-------------------- Mapping set /Formula set Details --------------------'
                     || chr(10)
                     || chr(10);
            FOR i IN get_mapping_details(l_project_id) LOOP
                BEGIN
                    IF i.mapping_type = 'Formula' THEN
                        DELETE FROM :p_destinaion_pod.cr_formula_sets
                        WHERE
                            formula_set_id = i.mapping_set_id;
                        SELECT
                            COUNT(DISTINCT formula_set_code)
                        INTO l_fs_count
                        FROM
                            :p_destinaion_pod.cr_formula_sets
                        WHERE
                            formula_set_code = i.code;
                        IF l_fs_count < 1 THEN
                            BEGIN
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
                                l_log := l_log
                                         || 'Formula Set Inserted with ID : '
                                         || i.mapping_set_id
                                         || ' , Set_code :'
                                         || i.code
                                         || chr(10);
                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS THEN
                                l_error_flag := 'Y';
                                    l_log := l_log
                                             || 'Error occurred during Insert for Formula Set with ID: '
                                             || i.mapping_set_id
                                             || ' , Set_code :'
                                             || i.code
                                             || ' - Error: '
                                             || sqlerrm
                                             || chr(10);
                                    ROLLBACK;
                            END;
                        ELSE
                            BEGIN
                                DELETE FROM :p_destinaion_pod.cr_formula_sets
                                WHERE
                                    formula_set_code = i.code;
                                l_log := l_log
                                         || 'Formula Set Deleted  Code '
                                         || i.code
                                         || chr(10);
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
                                l_log := l_log
                                         || 'Formula Set Inserted with ID : '
                                         || i.mapping_set_id
                                         || ' , Set_code :'
                                         || i.code
                                         || chr(10);
                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS THEN
                                l_error_flag := 'Y';
                                    l_log := l_log
                                             || 'Error occurred during Insert/Delete for Formula Set with ID: '
                                             || i.mapping_set_id
                                             || ' , Set_code :'
                                             || i.code
                                             || ' - Error: '
                                             || sqlerrm
                                             || chr(10);
                                    ROLLBACK;
                            END;
                        END IF;
                    ELSE
 ]';
    l_query_1_1           CLOB := q'[
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
                        DELETE FROM :p_destinaion_pod.cr_mapping_sets
                        WHERE
                            map_set_code = i.code;
                        l_log := l_log
                                 || 'Deleted  Mapping_set with the code  : '
                                 || i.code
                                 || chr(10);
                        l_lookup_set_id := NULL;
                        SELECT
                            COUNT(lookup_set_id)
                        INTO l_lookup_check
                        FROM
                            :p_source_pod.cr_mapping_sets
                        WHERE
                                map_set_id = i.mapping_set_id
                            AND lookup_set_id IS NOT NULL AND lookup_set_id <> 0;
                        IF l_lookup_check > 0 THEN
                            SELECT
                                nvl(dl.lookup_set_id, NULL)
                            INTO l_lookup_set_id
                            FROM
                                :p_destinaion_pod.cr_lookup_sets        dl,
                                :p_source_pod.cr_mapping_sets sm,
                                :p_source_pod.cr_lookup_sets  sl
                            WHERE
                                    sm.map_set_id = i.mapping_set_id
                                AND sm.lookup_set_id = sl.lookup_set_id
                                AND sl.lookup_set_code = dl.lookup_set_code;
                        END IF;
                        SELECT
                            COUNT(DISTINCT map_set_code)
                        INTO l_ms_count
                        FROM
                            :p_destinaion_pod.cr_mapping_sets
                        WHERE
                            map_set_code = i.code;
                        IF l_ms_count < 1 THEN
                            BEGIN
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
                                l_log := l_log
                                         || 'Mapping Set Inserted with ID : '
                                         || i.mapping_set_id
                                         || ' , Set_code :'
                                         || i.code
                                         || chr(10);
                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS THEN
                                l_error_flag := 'Y';
                                    l_log := l_log
                                             || 'Error occurred during Insert for Mapping Set with ID: '
                                             || i.mapping_set_id
                                             || ' , Set_code :'
                                             || i.code
                                             || ' - Error: '
                                             || sqlerrm
                                             || chr(10);
                                    ROLLBACK;
                            END;
                        ELSE
                            BEGIN
                                DELETE FROM :p_destinaion_pod.cr_mapping_sets
                                WHERE
                                    map_set_code = i.code;
                                l_log := l_log
                                         || 'Deleted  Mapping_set with the code  : '
                                         || i.code
                                         || chr(10);
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
                                l_log := l_log
                                         || 'Mapping Set Inserted with ID : '
                                         || i.mapping_set_id
                                         || ' , Set_code :'
                                         || i.code
                                         || chr(10);
                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS THEN
                                l_error_flag := 'Y';
                                    l_log := l_log
                                             || 'Error occurred during Insert/Delete for Mapping Set with ID: '
                                             || i.mapping_set_id
                                             || ' , Set_code :'
                                             || i.code
                                             || ' - Error: '
                                             || sqlerrm
                                             || chr(10);
                                    ROLLBACK;
                            END;
                        END IF;
                        SELECT
                            map_set_id
                        INTO l_map_set_id
                        FROM
                            :p_destinaion_pod.cr_mapping_sets
                        WHERE
                            map_set_code = i.code;
                        BEGIN
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
                        EXCEPTION
                            WHEN OTHERS THEN
                            l_error_flag := 'Y';
                                l_log := l_log
                                         || 'Error occurred during Insert for Mapping Values with Map Set ID: '
                                         || i.mapping_set_id
                                         || ' , Set_code :'
                                         || i.code
                                         || ' - Error: '
                                         || sqlerrm
                                         || chr(10);
                                ROLLBACK;
                        END;
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                    l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error for Mapping/Formula Set with ID: '
                                 || i.mapping_set_id
                                 || ' , Set_code :'
                                 || i.code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                        ROLLBACK;
                END;
            END LOOP;
            l_log := l_log
                     || chr(10)
                     || '-------------------- End of Mapping/Formula_details --------------------'
                     || chr(10);
        END;]';
    l_query_2             CLOB DEFAULT q'[
        BEGIN
            l_log := l_log
                     || chr(10)
                     || '-------------------- Source Template Setup details --------------------'
                     || chr(10);
            dbms_output.put_line('Source Meta Data');
            FOR i IN get_src_temp_details(l_project_id) LOOP
            dbms_output.put_line('Source Metadata Deletion ');
            Begin
            BEGIN
                DELETE FROM :p_destinaion_pod.cr_source_columns
                WHERE
                    table_id IN (
                        SELECT
                            table_id
                        FROM
                            :p_destinaion_pod.cr_source_tables
                        WHERE
                            table_name IN (
                                SELECT
                                    table_name
                                FROM
                                    :p_source_pod.cr_source_tables
                                WHERE
                                    table_id IN (
                                        SELECT
                                            metadata_table_id
                                        FROM
                                            :p_source_pod.cr_src_template_hdrs
                                        WHERE
                                                project_id = l_project_id
                                            and object_id = i.object_id 
                                    )
                            )
                    );
                COMMIT;
            EXCEPTION
                WHEN OTHERS THEN
                l_error_flag := 'Y';
                    l_log := l_log
                             || 'Error during deletion from cr_source_columns - Error: '
                             || sqlerrm
                             || chr(10);
                    ROLLBACK;
            END;
            BEGIN
                DELETE FROM :p_destinaion_pod.cr_source_tables
                WHERE
                    table_name IN (
                        SELECT
                            table_name
                        FROM
                            :p_source_pod.cr_source_tables
                        WHERE
                            table_id IN (
                                SELECT
                                    metadata_table_id
                                FROM
                                    :p_source_pod.cr_src_template_hdrs
                                WHERE
                                        project_id = l_project_id
                                    and object_id = i.object_id 
                            )
                    );
                COMMIT;
            EXCEPTION
                WHEN OTHERS THEN
                l_error_flag := 'Y';
                    l_log := l_log
                             || 'Error during deletion from cr_source_tables - Error: '
                             || sqlerrm
                             || chr(10);
                    ROLLBACK;
            END;
            BEGIN
                DELETE FROM :p_destinaion_pod.cr_cloud_columns
                WHERE
                    table_id IN (
                        SELECT
                            table_id
                        FROM
                            :p_destinaion_pod.cr_cloud_tables
                        WHERE
                            table_name IN (
                                SELECT
                                    table_name
                                FROM
                                    :p_source_pod.cr_cloud_tables
                                WHERE
                                    table_id IN (
                                        SELECT
                                            metadata_table_id
                                        FROM
                                            :p_source_pod.cr_cld_template_hdrs
                                        WHERE
                                                project_id = l_project_id
                                            and object_id = i.object_id 
                                    )
                            )
                    );
                COMMIT;
            EXCEPTION
                WHEN OTHERS THEN
                l_error_flag := 'Y';
                    l_log := l_log
                             || 'Error during deletion from cr_cloud_columns - Error: '
                             || sqlerrm
                             || chr(10);
                    ROLLBACK ;
            END;
            BEGIN
                DELETE FROM :p_destinaion_pod.cr_cloud_tables
                WHERE
                    table_name IN (
                        SELECT
                            table_name
                        FROM
                            :p_source_pod.cr_cloud_tables
                        WHERE
                            table_id IN (
                                SELECT
                                    metadata_table_id
                                FROM
                                    :p_source_pod.cr_cld_template_hdrs
                                WHERE
                                        project_id = l_project_id
                                    and object_id = i.object_id 
                            )
                    );
                COMMIT;
                  l_log := l_log
                             || 'Deleted CLD TABLE for Object ID: '||i.object_id
                             || chr(10);
            EXCEPTION
                WHEN OTHERS THEN
                l_error_flag := 'Y';
                    l_log := l_log
                             || 'Error during deletion from cr_cloud_tables - Error: '
                             || sqlerrm
                             || chr(10);
                    ROLLBACK ;
            END;
            end ; 
            dbms_output.put_Line('End of Source Metadata Deletion ');
                BEGIN
                    DELETE FROM :p_destinaion_pod.cr_src_template_cols
                    WHERE
                        src_template_id IN (
                            SELECT
                                src_template_id
                            FROM
                                :p_destinaion_pod.cr_src_template_hdrs
                            WHERE
                                src_template_code = i.src_template_code
                        );
                    DELETE FROM :p_destinaion_pod.cr_src_template_hdrs
                    WHERE
                        src_template_code = i.src_template_code;
                    COMMIT;
                    dbms_output.put_line('Deleted Source Meta data');
                    l_log := l_log
                             || 'Source Template Setups Deleted for  :'
                             || i.src_template_code
                             || chr(10);
                EXCEPTION
                    WHEN OTHERS THEN
                    l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error during deletion of Source Template Setups for :'
                                 || i.src_template_code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                        ROLLBACK ;
                END;
            END LOOP;
            COMMIT;
            l_log := l_log
                     || chr(10)
                     || chr(10);
            FOR i IN get_src_temp_id(l_project_id) LOOP
                BEGIN
                    l_source_table_id := NULL;
                    l_source_table_id := :p_destinaion_pod.cr_src_table_id_s.nextval; -- Destination pod
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
                EXCEPTION
                    WHEN OTHERS THEN
                    l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error during insertion into cr_source_tables - Error: '
                                 || sqlerrm
                                 || chr(10);
                        ROLLBACK ;
                END;
                BEGIN
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
                EXCEPTION
                    WHEN OTHERS THEN
                    l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error during insertion into cr_source_columns - Error: '
                                 || sqlerrm
                                 || chr(10);
                        ROLLBACK ;
                END;
                BEGIN
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
                        FROM
                            :p_source_pod.cr_src_template_hdrs
                        WHERE
                            src_template_id = i.src_template_id;-- Source Temp Headers
                    COMMIT;
                EXCEPTION
                    WHEN OTHERS THEN
                    l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error during insertion into cr_src_template_hdrs - Error: '
                                 || sqlerrm
                                 || chr(10);
                        ROLLBACK ;
                END;
                BEGIN
                    SELECT
                        src_template_id
                    INTO l_src_temp_id
                    FROM
                        :p_destinaion_pod.cr_src_template_hdrs
                    WHERE
                        src_template_code = i.src_template_code;
                    FOR rec IN (
                        SELECT
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
                            src_template_id = i.src_template_id
                        ORDER BY
                            column_id
                    ) LOOP
                        BEGIN
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
                            ) VALUES (
                                rec.src_template_id,
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
                        EXCEPTION
                            WHEN OTHERS THEN
                            l_error_flag := 'Y';
                                l_log := l_log
                                         || 'Error during insertion into cr_src_template_cols for column: '
                                         || rec.column_name
                                         || ' - Error: '
                                         || sqlerrm
                                         || chr(10);
                                ROLLBACK ;
                        END;
                    END LOOP;
                    l_log := l_log
                             || 'Source Template Setups Created for Template_code  :'
                             || i.src_template_code
                             || chr(10);
                    COMMIT;
                EXCEPTION
                    WHEN OTHERS THEN
                    l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error during processing of Source Template Setups for :'
                                 || i.src_template_code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                        ROLLBACK ;
                END;
                l_table_chek := 0;
                BEGIN
                    SELECT
                        COUNT(table_name)
                    INTO l_table_chek
                    FROM
                        all_tables
                    WHERE
                            owner = ':p_destinaion_pod'
                        AND table_name = i.staging_table_name;
                    IF ( l_table_chek > 0 ) THEN
                        l_drop_stmt := 'DROP TABLE '
                                       || ':p_destinaion_pod'
                                       || '.'
                                       || i.staging_table_name;
                        EXECUTE IMMEDIATE l_drop_stmt;
                        COMMIT;
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                    l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error during dropping of staging table: '
                                 || i.staging_table_name
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                END;
                BEGIN
                    :p_destinaion_pod.cr_create_stg_table_proc(l_source_table_id, l_src_temp_id, i.src_template_code, 'SOURCE', '',
                                                       l_ret_code, l_ret_msg);
                    l_log := l_log
                             || 'Source Staging Table created for Template_code :'
                             || i.src_template_code
                             || chr(10);
                EXCEPTION
                    WHEN OTHERS THEN
                    l_error_flag := 'Y';
                        dbms_output.put_line(' Failed to Create Staging Table for ' || i.src_template_code);
                        l_log := l_log
                                 || 'Failed to Create  Source Staging Table for :'
                                 || i.src_template_code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                END;
            END LOOP;
            dbms_output.put_line('Insert Source meta  data');
            l_log := l_log
                     || chr(10)
                     || '------------------End of Source Template Setups ------------------'
                     || chr(10)
                     || chr(10);
        EXCEPTION
            WHEN OTHERS THEN
            l_error_flag := 'Y';
                l_log := l_log
                         || 'Error - Error: '
                         || sqlerrm
                         || chr(10);
                ROLLBACK ;
        END;
 ]';
    l_query_3             CLOB DEFAULT q'[ 
        BEGIN
            l_log := l_log
                     || '------------------ Cloud  Template Setups  ------------------'
                     || chr(10)
                     || chr(10);
            FOR i IN get_cld_temp_details(l_project_id) LOOP
                BEGIN
                    DELETE FROM :p_destinaion_pod.cr_cld_template_cols WHERE
                        cld_template_id IN ( i.cld_template_id );
                    DELETE FROM :p_destinaion_pod.cr_cld_template_hdrs
                    WHERE cld_template_id IN ( i.cld_template_id );
                    l_log := l_log || ' Deleted Cloud Template Setups for : '
                             || i.cld_template_code || chr(10);
                  DELETE FROM :p_destinaion_pod.cr_hook_usages
                    WHERE template_id IN ( i.cld_template_id );
                    l_log := l_log || ' Deleted Hook Usages for Cloud Template Code : '
                             || i.cld_template_code || chr(10);                             
                EXCEPTION
                    WHEN OTHERS THEN
                    l_error_flag := 'Y';
                        l_log := l_log || 'Error deleting Cloud Template Setups for : '
                                 || i.cld_template_code|| ' - Error: '|| sqlerrm|| chr(10);
                        ROLLBACK;
                END;
            END LOOP;
            l_log := l_log || chr(10) || chr(10);
            FOR i IN get_cld_temp_id(l_project_id) LOOP
                BEGIN
                    l_cloud_table_id := :p_destinaion_pod.cr_cld_table_id_s.nextval;
                    INSERT INTO :p_destinaion_pod.cr_cloud_tables
                        SELECT
                            l_cloud_table_id, table_name, physical_table_name,  user_table_name, description,
                            object_id,  parent_object_id,  application_short_name, table_type, hosted_support_style,
                            logical, mls_support_model, status,
                            deploy_to, extension_of_table, short_name,
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
                EXCEPTION
                    WHEN OTHERS THEN
                    l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error inserting into cr_cloud_tables for template code: '
                                 || i.cld_template_code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);                        
                        ROLLBACK;
                END;
                BEGIN
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
                EXCEPTION
                    WHEN OTHERS THEN
                    l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error inserting into cr_cloud_columns for template code: '
                                 || i.cld_template_code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                        ROLLBACK;
                END;
                BEGIN
                    SELECT
                        nvl(src_template_id, NULL)
                    INTO l_src_temp_id
                    FROM
                        :p_destinaion_pod.cr_src_template_hdrs
                    WHERE
                        object_id = (
                            SELECT
                                object_id
                            FROM
                                :p_source_pod.cr_cld_template_hdrs
                            WHERE
                                cld_template_id = i.cld_template_id
                        );
                EXCEPTION
                    WHEN OTHERS THEN
                    l_error_flag := 'Y';
                        l_src_temp_id := NULL;
                        l_log := l_log
                                 || 'Error retrieving source template id for : '
                                 || i.cld_template_code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                END;
                BEGIN
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
                        FROM
                            :p_source_pod.cr_cld_template_hdrs
                        WHERE
                            cld_template_id = i.cld_template_id;
                    COMMIT;
                    l_log := l_log
                                 || 'Inserted CLD Template HDR for : '
                                 || i.cld_template_code
                                 || chr(10);
                EXCEPTION
                    WHEN OTHERS THEN
                    l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error inserting into cr_cld_template_hdrs for template code: '
                                 || i.cld_template_code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                        ROLLBACK ;
                END;
                BEGIN
                    SELECT
                        cld_template_id
                    INTO l_cld_temp_id
                    FROM
                        :p_destinaion_pod.cr_cld_template_hdrs
                    WHERE
                        cld_template_code = i.cld_template_code;
                        l_log := l_log
                                 || 'Retrieved cld_template_id from destination : '
                                 || l_cld_temp_id
                                 || chr(10);
                EXCEPTION
                    WHEN OTHERS THEN
                    l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error retrieving cloud template id for : '
                                 || i.cld_template_code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                END;
                FOR l_get_cld_temp_cols_details IN get_cld_temp_cols_details(i.cld_template_id) LOOP
                    l_map_set_id := NULL;
                    l_src_col_id := NULL;
                    BEGIN
                        IF l_get_cld_temp_cols_details.source_column_id IS NOT NULL THEN
                            SELECT
                                nvl(column_id, NULL)
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
                                            object_id = i.object_id
                                        AND project_id = l_project_id
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
                                                    object_id = i.object_id
                                                AND project_id = l_project_id
                                        )
                                );
                        END IF;
                    EXCEPTION
                        WHEN OTHERS THEN
                        l_error_flag := 'Y';
                            l_src_col_id := NULL;
                            l_log := l_log
                                     || '****Error while getting Source column ID, please check the mappings for ****'
                                     || i.cld_template_code
                                     || chr(10);
                    END;
                    BEGIN
                        IF
                            l_get_cld_temp_cols_details.mapping_type NOT IN ( 'Formula', 'As-Is', 'Constant' )
                            AND l_get_cld_temp_cols_details.mapping_set_id IS NOT NULL
                        THEN
                            SELECT
                                CASE
                                    WHEN EXISTS (
                                        SELECT
                                            1
                                        FROM
                                            :p_source_pod.cr_mapping_sets
                                        WHERE
                                            map_set_id = l_get_cld_temp_cols_details.mapping_set_id
                                    ) THEN
                                        (
                                            SELECT
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
                                                )
                                        )
                                    ELSE
                                        NULL
                                END
                            INTO l_map_set_id
                            FROM
                                dual;
                        END IF;
                        IF
                            l_get_cld_temp_cols_details.mapping_type IN ( 'Formula' )
                            AND l_get_cld_temp_cols_details.mapping_set_id IS NOT NULL
                        THEN
                            SELECT
                                CASE
                                    WHEN EXISTS (
                                        SELECT DISTINCT
                                            1
                                        FROM
                                            :p_source_pod.cr_formula_sets
                                        WHERE
                                            formula_set_id = l_get_cld_temp_cols_details.mapping_set_id
                                    ) THEN
                                        (
                                            SELECT
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
                                                )
                                        )
                                    ELSE
                                        NULL
                                END
                            INTO l_map_set_id
                            FROM
                                dual;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS THEN
                        l_error_flag := 'Y';
                            l_map_set_id := NULL;
                            l_log := l_log
                                     || '*** Error in mapping set/formula set logic for : '
                                     || i.cld_template_code
                                     || ' - Error: '
                                     || sqlerrm
                                     || '*** '||chr(10);
                    END;
                    BEGIN
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
                       -- l_log := l_log
                         --        || 'CLD Columns INSERTED'
                            --     || chr(10);
                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS THEN
                        l_error_flag := 'Y';
                            l_log := l_log
                                     || 'Error inserting into cr_cld_template_cols for template code: '
                                     || i.cld_template_code
                                     || ' - Error: '
                                     || sqlerrm
                                     || chr(10);
                            ROLLBACK;
                    END;
                END LOOP;
                BEGIN
                    l_log := l_log
                             || 'Cld Template Setups created for object: '
                             || i.cld_template_code
                             || chr(10);
                    l_table_chek := 0;
                    SELECT
                        COUNT(table_name)
                    INTO l_table_chek
                    FROM
                        all_tables
                    WHERE
                            owner = ':p_destinaion_pod'
                        AND table_name = i.staging_table_name;
                    IF l_table_chek > 0 THEN
                        l_drop_stmt := 'DROP TABLE :p_destinaion_pod.' || i.staging_table_name;
                        EXECUTE IMMEDIATE l_drop_stmt;
                        COMMIT;
                    END IF;
                    BEGIN
                        :p_destinaion_pod.cr_create_stg_table_proc(l_cloud_table_id, l_cld_temp_id, i.cld_template_code, 'CLOUD', '',
                                                           l_ret_code, l_ret_msg);
                        l_log := l_log
                                 || 'Cloud Staging Table Created for object_code: '
                                 || i.cld_template_code
                                 || chr(10);
                    EXCEPTION
                        WHEN OTHERS THEN
                        l_error_flag := 'Y';
                            l_log := l_log
                                     || 'Error creating Cloud Staging Table for object_code: '
                                     || i.cld_template_code
                                     || ' - Error: '
                                     || sqlerrm
                                     || chr(10);
                    END;
                EXCEPTION
                    WHEN OTHERS THEN
                    l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error processing Cloud Template Setups for object: '
                                 || i.cld_template_code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                        ROLLBACK;
                END;
                BEGIN
                    dbms_output.put_line('--User Hooks--');
                    FOR x IN get_userhook_details(i.cld_template_id) LOOP
                        BEGIN
                            dbms_lob.createtemporary(l_uh_clob, TRUE);
                            dbms_lob.append(l_uh_clob, 'CREATE OR REPLACE ');
                            FOR k IN (
                                SELECT
                                    text
                                FROM
                                    all_source
                                WHERE
                                        type = 'PROCEDURE'
                                    AND owner = upper(':p_source_pod')
                                    AND name = upper(x.userhook)
                                ORDER BY
                                    line
                            ) LOOP
                                dbms_lob.append(l_uh_clob, k.text);
                            END LOOP;
                            l_uh_clob := replace(l_uh_clob, 'PROCEDURE ', 'PROCEDURE '
                                                                          || ':p_destinaion_pod'
                                                                          || '.');
                            l_uh_clob := replace(l_uh_clob, 'procedure ', 'procedure '
                                                                          || ':p_destinaion_pod'
                                                                          || '.');
--                            EXECUTE IMMEDIATE l_uh_clob;
--                            l_log := l_log || ' USER Hook Related object Execution Completed  ' || x.userhook || chr(10);
                        EXCEPTION
                            WHEN OTHERS THEN
--                            l_error_flag := 'Y';
--                                l_log := l_log || 'USER Hook Related object Execution USER Hook: '
--                                         || x.userhook|| ' - Error: '|| sqlerrm|| chr(10)||l_uh_clob;
NULL; -- NEED TO REMOVE WHILE HANDLING THE PACKAGES/PROCEDURES/FUNCTIONS LOGIC
                        END;
                    END LOOP;
                    dbms_output.put_line('--User Hooks Completed--');
                EXCEPTION
                    WHEN OTHERS THEN
                    l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error processing USER Hooks for template: '
                                 || i.cld_template_code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                END;
                BEGIN
                    l_uh_check := 0;
                    SELECT
                        COUNT(*)
                    INTO l_uh_check
                    FROM
                        :p_source_pod.cr_hook_usages
                    WHERE
                        template_id = i.cld_template_id;
                    IF l_uh_check > 0 THEN
                        FOR k IN (
                            SELECT DISTINCT
                                c.hook_id t_hook_id,
                                b.hook_id s_hook_id,
                                b.hook_code s_hook_code
                            FROM
                                :p_source_pod.cr_hook_usages a,
                                :p_source_pod.cr_user_hooks  b,
                                :p_destinaion_pod.cr_user_hooks        c
                            WHERE
                                    c.hook_code = b.hook_code
                                AND a.template_id = i.cld_template_id
                                AND a.hook_id = b.hook_id
                        ) LOOP
                            INSERT INTO :p_destinaion_pod.cr_hook_usages (
                                hook_id,
                                template_id,
                                usage_type,
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
                                    k.t_hook_id,
                                    l_cld_temp_id,
                                    usage_type,
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
                                    :p_source_pod.cr_hook_usages
                                WHERE
                                        template_id = i.cld_template_id
                                    AND hook_id = k.s_hook_id;
                            COMMIT;
                            l_log := l_log
                                 || 'User Hook Usage Inserted in target POD for HOOK: '||k.s_hook_code
                                 || chr(10);
                        END LOOP;
                    END IF;
                EXCEPTION
                    WHEN OTHERS THEN
                    l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error inserting into cr_hook_usages for template code: '
                                 || i.cld_template_code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                        ROLLBACK;
                END;
            END LOOP;
            dbms_output.put_line('Insert Cld Meta data');
            l_log := l_log
                     || chr(10)
                     || ' ------------------End of Cloud Template Setups ***********************'
                     || chr(10);
        EXCEPTION
            WHEN OTHERS THEN
            l_error_flag := 'Y';
                l_log := l_log
                         || 'Error in Cloud Template Setups - Error: '
                         || sqlerrm
                         || chr(10);
                ROLLBACK;
        END;
 ]';
    l_query_4             CLOB := q'[ 
    BEGIN
            FOR x IN get_exist_object_group_details(l_project_id) LOOP
                BEGIN
                    DELETE FROM :p_destinaion_pod.cr_object_group_lines
                    WHERE
                        group_id IN (
                            SELECT
                                group_id
                            FROM
                                :p_destinaion_pod.cr_object_group_hdrs
                            WHERE
                                    group_code = x.group_code
                                AND project_id = l_project_id
                        );
                    DELETE FROM :p_destinaion_pod.cr_object_group_hdrs
                    WHERE
                            group_code = x.group_code
                        AND project_id = l_project_id;
                    COMMIT;
                EXCEPTION
                    WHEN OTHERS THEN
                    l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error deleting object group details for group_code: '
                                 || x.group_code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                        ROLLBACK;
                END;
                BEGIN
                    INSERT INTO :p_destinaion_pod.cr_object_group_hdrs (
                        project_id,
                        parent_object_id,
                        group_name,
                        group_code,
                        description,
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
                            project_id,
                            parent_object_id,
                            group_name,
                            group_code,
                            description,
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
                            :p_source_pod.cr_object_group_hdrs
                        WHERE
                                group_code = x.group_code
                            AND project_id = l_project_id;
                    COMMIT;
                EXCEPTION
                    WHEN OTHERS THEN
                    l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error inserting into cr_object_group_hdrs for group_code: '
                                 || x.group_code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                        ROLLBACK;
                END;
                BEGIN
                    SELECT
                        group_id
                    INTO l_group_id
                    FROM
                        :p_destinaion_pod.cr_object_group_hdrs
                    WHERE
                            group_code = x.group_code
                        AND project_id = l_project_id;
                EXCEPTION
                    WHEN no_data_found THEN
             l_error_flag := 'Y';
                        l_log := l_log
                                 || 'No group_id found for group_code: '
                                 || x.group_code
                                 || chr(10);
                        l_group_id := NULL;
                    WHEN OTHERS THEN
                        l_log := l_log
                                 || 'Error retrieving group_id for group_code: '
                                 || x.group_code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                        ROLLBACK;
                END;
                BEGIN
                    INSERT INTO :p_destinaion_pod.cr_object_group_lines (
                        group_id,
                        object_id,
                        sequence,
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
                            l_group_id,
                            object_id,
                            sequence,
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
                            :p_source_pod.cr_object_group_lines
                        WHERE
                            group_id IN (
                                SELECT
                                    group_id
                                FROM
                                    :p_source_pod.cr_object_group_hdrs
                                WHERE
                                        group_code = x.group_code
                                    AND project_id = l_project_id
                            );
                    COMMIT;
                EXCEPTION
                    WHEN OTHERS THEN
               l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error inserting into cr_object_group_lines for group_code: '
                                 || x.group_code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                        ROLLBACK;
                END;
            END LOOP;
        EXCEPTION
            WHEN OTHERS THEN
        l_error_flag := 'Y';
                l_log := l_log
                         || 'Error processing object group details - Error: '
                         || sqlerrm
                         || chr(10);
                ROLLBACK;
        END;
BEGIN
    FOR i IN (  SELECT
                     ms.map_set_id   AS mapping_set_id,
                     ms.map_set_type AS mapping_type,
                     ms.map_set_code AS code,
                     ms.lookup_set_id as lookup_set_id ,
                     ls.lookup_set_code as lookup_set_code
                FROM
                    :p_source_pod.cr_mapping_sets ms,
                    :p_source_pod.cr_lookup_sets ls 
                WHERE
                ms.lookup_set_id = ls.lookup_set_id(+) and 
                    ms.map_set_code NOT IN (
                        SELECT DISTINCT
                            map_set_code
                        FROM
                            :p_destinaion_pod.cr_mapping_sets
                    )
                UNION
                SELECT
                    fs.formula_set_id   AS mapping_set_id,
                    fs.formula_type     AS mapping_type,
                    fs.formula_set_code AS code,
                    null as lookup_set_id ,
                    null as look_set_code 
                FROM
                    :p_source_pod.cr_formula_sets fs
                WHERE
                    fs.formula_set_code NOT IN (
                        SELECT DISTINCT
                            formula_set_code
                        FROM
                            :p_destinaion_pod.cr_formula_sets
                    )
    ) LOOP
        BEGIN
            IF i.lookup_set_id IS NOT NULL AND i.lookup_set_code IS NOT NULL THEN
                l_lookup_set_id := NULL;
                DELETE FROM :p_destinaion_pod.cr_lookup_values
                WHERE
                    lookup_set_id IN (
                        SELECT
                            lookup_set_id
                        FROM
                            :p_destinaion_pod.cr_lookup_sets
                        WHERE
                            lookup_set_code = i.LOOKUP_SET_CODE
                    );
                DELETE FROM :p_destinaion_pod.cr_lookup_sets
                WHERE
                    lookup_set_code = i.LOOKUP_SET_CODE;
                l_log := l_log
                         || 'Deleted LookupsetCode  : '
                         || i.code
                         || chr(10);
                COMMIT;
                BEGIN
                    INSERT INTO :p_destinaion_pod.cr_lookup_sets (
                        lookup_set_name,
                        lookup_set_code,
                        description,
                        related_to,
                        lookup_flag,
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
                        lookup_set_name,
                        lookup_set_code,
                        description,
                        related_to,
                        lookup_flag,
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
                        :p_source_pod.cr_lookup_sets
                    WHERE
                        lookup_set_id = i.lookup_set_id;
                    l_log := l_log
                             || 'Inserting Lookup Set :'
                             || i.code
                             || ' with Lookup_set_id '
                             || i.lookup_set_id
                             || chr(10);
                    COMMIT;
                EXCEPTION
                    WHEN OTHERS THEN
                        l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error occurred during Insert for Lookup Set Code: '
                                 || i.code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                        ROLLBACK;
                END;
                BEGIN
                    SELECT DISTINCT
                        lookup_set_id
                    INTO l_lookup_set_id
                    FROM
                        :p_destinaion_pod.cr_lookup_sets
                    WHERE
                        lookup_set_code = i.LOOKUP_SET_CODE;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        l_error_flag := 'Y';
                        l_log := l_log
                                 || 'No Lookup Set ID found for Lookup Set Code: '
                                 || i.code
                                 || chr(10);
                        l_lookup_set_id := NULL; -- Ensure l_lookup_set_id is null if no data is found
                    WHEN OTHERS THEN
                        l_log := l_log
                                 || 'Error occurred while retrieving Lookup Set ID for Code: '
                                 || i.code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                        ROLLBACK;
                END;
                BEGIN
                    INSERT INTO :p_destinaion_pod.cr_lookup_values (
                        lookup_value,
                        lookup_set_id,
                        actual_value,
                        attribute1,
                        attribute2,
                        attribute3,
                        attribute4,
                        attribute5,
                        enabled_flag,
                        last_updated_by,
                        last_update_date,
                        creation_date,
                        created_by
                    )
                    SELECT
                        lookup_value,
                        l_lookup_set_id,
                        actual_value,
                        attribute1,
                        attribute2,
                        attribute3,
                        attribute4,
                        attribute5,
                        enabled_flag,
                        last_updated_by,
                        last_update_date,
                        creation_date,
                        created_by
                    FROM
                        :p_source_pod.cr_lookup_values
                    WHERE
                        lookup_set_id = i.lookup_set_id;
                    COMMIT;
                EXCEPTION
                    WHEN OTHERS THEN
                        l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error occurred during Insert for Lookup Values of Lookup Set Code: '
                                 || i.code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                        ROLLBACK;
                END;
                l_log := l_log || '---------------------- Start of Copying Lookup Details ----------------- '||chr(10);
            END IF;
              IF i.mapping_type IN ( 'One to One', 'Two to One', 'Three to One' ) THEN
                BEGIN
                    DELETE FROM :p_destinaion_pod.cr_mapping_values
                    WHERE map_set_id = (
                        SELECT map_set_id
                        FROM :p_destinaion_pod.cr_mapping_sets
                        WHERE map_set_code = i.code
                    );
                    DELETE FROM :p_destinaion_pod.cr_mapping_sets
                    WHERE map_set_code = i.code;
                    COMMIT;
                EXCEPTION
                    WHEN OTHERS THEN
                        l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error deleting existing mapping sets/values for code '
                                 || i.code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                        ROLLBACK;
                END;
                BEGIN
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
                        i.code,
                        map_set_type,
                        valiadtion_type,
                        l_lookup_set_id, -- added to bring linked lookup sets 
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
                   l_log := l_log
                                 || 'Mapping set inserted for code ' || i.code 
                                 || CHR(10);
                EXCEPTION
                    WHEN OTHERS THEN
                        l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error inserting mapping set for code '
                                 || i.code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                        ROLLBACK;
                END;
                BEGIN
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
                        (
                            SELECT
                                map_set_id
                            FROM
                                :p_destinaion_pod.cr_mapping_sets
                            WHERE
                                map_set_code = i.code
                        ),
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
                    dbms_output.put_line('Mapping values inserted for code ' || i.code);
                    l_log := l_log
                                 || 'Mapping set Values inserted for code ' || i.code 
                                 || CHR(10);
                EXCEPTION
                    WHEN OTHERS THEN
                        l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error inserting mapping values for code '
                                 || i.code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                        ROLLBACK;
                END;
            ELSE
                BEGIN
                    DELETE FROM :p_destinaion_pod.cr_formula_sets
                    WHERE formula_set_code = i.code;
                    COMMIT;
                EXCEPTION
                    WHEN OTHERS THEN
                        l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error deleting existing formula set for code '
                                 || i.code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                        ROLLBACK;
                END;
                BEGIN
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
                        i.code,
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
                    dbms_output.put_line('Formula set inserted for code ' || i.code);
                    l_log := l_log
                                 || 'Formula set inserted for code ' || i.code 
                                 || CHR(10);
                EXCEPTION
                    WHEN OTHERS THEN
                        l_error_flag := 'Y';
                        l_log := l_log
                                 || 'Error inserting formula set for code '
                                 || i.code
                                 || ' - Error: '
                                 || sqlerrm
                                 || chr(10);
                        ROLLBACK;
                END;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                l_error_flag := 'Y';
                l_log := l_log
                         || 'Error processing mapping/formula set with code '
                         || i.code
                         || ' - Error: '
                         || sqlerrm
                         || chr(10);
                ROLLBACK;
        END;
    END LOOP;
    l_log := l_log
             || ' *** All the formula/Mapping Sets Migrated (which are not linked to any Cloud )*** '
             || chr(10);
EXCEPTION
    WHEN OTHERS THEN
        l_error_flag := 'Y';
        l_log :=
        l_log
        || 'Error during migration of formula/mapping sets - Error: ' || sqlerrm || chr ( 10 );
        rollback;
        end;
        if l_error_flag = 'Y'
        then 
        l_log := '-----------------------------------------------------------------------------------'||CHR(10)||
        '****** Please Check the Log file for Detailed Errors ******'||chr(10)||
        '----------------------------------------------------------------------------------------------------'
        ||CHR(10)||l_log;
end if;
          INSERT INTO cr_copy_log (
          copy_id ,
                source_pod, destination_pod, object_ids,  project_name, log_clob,
                creation_date, STATUS, ERROR_MSG
            ) VALUES (
                ':COPY_ID' ,  ':p_source_pod', ':p_destinaion_pod',
                ':p_object_ids',
                ':p_project_name',
                l_log,
                sysdate,
                DECODE(l_error_flag,'Y','WARNING','SUCCESS'),
                'POD DETAILS COPIED SUCCESSFULLY'
            );
        COMMIT;
END;
EXCEPTION
   WHEN e_project_not_found THEN
        l_error_flag := 'Y';
             l_log := l_log || 'Project information not available in the Source POD: ' || ':p_project_name' || ' - Error: ' || 'NO_DATA_FOUND' || chr(10);
         	   INSERT INTO cr_copy_log (
          copy_id ,
                source_pod,
                destination_pod,
                object_ids,
                project_name,
                log_clob,
                creation_date,
                STATUS,
                ERROR_MSG
            ) VALUES (
                ':COPY_ID' ,
                ':p_source_pod',
                ':p_destinaion_pod',
                ':p_object_ids',
                ':p_project_name',
                l_log,
                sysdate,
                DECODE(l_error_flag,'Y','WARNING','SUCCESS'),
                'Project information not available in the Source POD:  ' || ':p_project_name' || ' - Error: '
            ); 
            COMMIT;
            RETURN;
              RETURN;
    WHEN OTHERS THEN
          INSERT INTO cr_copy_log (
          copy_id ,
                source_pod,
                destination_pod,
                object_ids,
                project_name,
                log_clob,
                creation_date,
                STATUS,
                ERROR_MSG
            ) VALUES (
                ':COPY_ID' ,
                ':p_source_pod',
                ':p_destinaion_pod',
                ':p_object_ids',
                ':p_project_name',
                l_log,
                sysdate,
                DECODE(l_error_flag,'Y','WARNING','SUCCESS'),
                'Unexpected error while performing copy :  ' || ':p_project_name' || ' - Error: '
            );  COMMIT ; 
    END;]';
    l_object_where_clause VARCHAR2(240) := ':OBJECT_WHERE_CLAUSE';
    l_obj_ids             CLOB;
BEGIN
    dbms_lob.createtemporary(l_final_clob, TRUE);
    dbms_lob.append(l_final_clob, l_query_1);
    dbms_lob.append(l_final_clob, l_query_1_1);
    dbms_lob.append(l_final_clob, l_query_2);
    dbms_lob.append(l_final_clob, l_query_3);
    dbms_lob.append(l_final_clob, l_query_4);
    l_final_clob := replace(l_final_clob, ':p_source_pod', p_source_pod);
    l_final_clob := replace(l_final_clob, ':p_destinaion_pod', p_destinaion_pod);
    l_final_clob := replace(l_final_clob, ':p_project_name', p_project_name);
    l_final_clob := replace(l_final_clob, ':COPY_ID', p_copy_id);
    IF p_object_id IS NULL THEN
        l_final_clob := replace(l_final_clob, ':OBJECT_WHERE_CLAUSE', ' ');
        l_final_clob := replace(l_final_clob, ':P_OBJECT_ID', nvl(p_object_id, 'null'));
        l_final_clob := replace(l_final_clob, ':PROJECT_WHERE_CLAUSE', ' ');
        l_final_clob := replace(l_final_clob, ':p_object_ids', p_object_id);
        BEGIN
            dbms_output.put_line('EXECUTING THE FINAL_BLOCK');
            EXECUTE IMMEDIATE l_final_clob;
            BEGIN
                UPDATE cr_copy_log
                SET
                    dynamic_sql = l_final_clob
                WHERE
                    copy_id = p_copy_id;
                COMMIT;
                SELECT
                    nvl(log_clob, NULL),
                    status
                INTO
                    l_log,
                    l_copy_status
                FROM
                    cr_copy_log
                WHERE
                    copy_id = p_copy_id;
            END;
            COMMIT;
            RETURN 'STATUS : '
                   || l_copy_status
                   || chr(10)
                   || l_log;
        EXCEPTION
            WHEN OTHERS THEN
                l_msg := 'POD COPY FAILED '
                         || chr(10)
                         || sqlerrm;
                INSERT INTO cr_copy_log (
                    copy_id,
                    source_pod,
                    destination_pod,
                    object_ids,
                    project_name,
                    dynamic_sql,
                    creation_date,
                    status,
                    error_msg
                ) VALUES (
                    p_copy_id,
                    p_source_pod,
                    p_destinaion_pod,
                    p_object_id,
                    p_project_name,
                    l_final_clob,
                    sysdate,
                    'ERROR',
                    l_msg
                );
                COMMIT;
                RETURN 'POD DETAILS COPY Failed ' || sqlerrm;
                ROLLBACK;
        END;
    ELSE
        l_obj_count := regexp_count(p_object_id, ',') + 1;
        BEGIN
            l_obj_count := regexp_count(p_object_id, ',') + 1;
            FOR i IN 1..l_obj_count LOOP
                l_obj_ids := l_obj_ids
                             || ''''
                             || trim(regexp_substr(p_object_id, '[^,]+', 1, i))
                             || ''',';
            END LOOP;
            l_obj_ids := substr(l_obj_ids, 0, length(l_obj_ids) - 1);
        EXCEPTION
            WHEN OTHERS THEN
                l_msg := 'POD COPY FAILED '
                         || chr(10)
                         || sqlerrm;
        END;
        l_final_clob := replace(l_final_clob, ':PROJECT_WHERE_CLAUSE', q'[ OR object_code IN (
        SELECT DISTINCT
            parent_object_code
        FROM
            :p_source_pod.cr_project_objects
        WHERE
                project_id = l_project_id 
                :OBJECT_WHERE_CLAUSE
    )]');
        l_final_clob := replace(l_final_clob, ':OBJECT_WHERE_CLAUSE', 'and OBJECT_ID in ( :OBJECT_ID )');
        l_final_clob := replace(l_final_clob, ':OBJECT_ID', l_obj_ids);
        l_final_clob := replace(l_final_clob, ':p_object_ids', p_object_id);
        l_final_clob := replace(l_final_clob, ':P_OBJECT_ID', l_obj_ids);
        l_final_clob := replace(l_final_clob, ':p_source_pod', p_source_pod);
        BEGIN
            EXECUTE IMMEDIATE l_final_clob;
            BEGIN
                UPDATE cr_copy_log
                SET
                    dynamic_sql = l_final_clob
                WHERE
                    copy_id = p_copy_id;
                COMMIT;
                SELECT
                    nvl(log_clob, NULL),
                    status
                INTO
                    l_log,
                    l_copy_status
                FROM
                    cr_copy_log
                WHERE
                    copy_id = p_copy_id;
            END;
        EXCEPTION
            WHEN OTHERS THEN
                l_msg := 'POD COPY FAILED '
                         || chr(10)
                         || sqlerrm;
                INSERT INTO cr_copy_log (
                    copy_id,
                    source_pod,
                    destination_pod,
                    object_ids,
                    project_name,
                    dynamic_sql,
                    creation_date,
                    status,
                    error_msg
                ) VALUES (
                    p_copy_id,
                    p_source_pod,
                    p_destinaion_pod,
                    p_object_id,
                    p_project_name,
                    l_final_clob,
                    sysdate,
                    'ERROR',
                    l_msg
                );
                COMMIT;
        END;
        RETURN 'STATUS : '
               || l_copy_status
               || chr(10)
               || l_log;
    END IF;
END cr_copy_func;
$#$
