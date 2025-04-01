-- Procedures files
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
******************************************************************************************************
* Project                        : ConvertRite
* Application                    :
* Title                          : CR_CLD_TRANSFORM_MAIN_PROC
* Program Name                   : CR_CLD_TRANSFORM_MAIN_PROC
* Description and Purpose        : Proc to Transform the data from src stg tbl
* Created by                     : sampaul.jeevan
* Change History                 : 1.0
*=====================================================================================================
* S.NO |    Date      |                 Reason                                                       |
*  1   |              | Intial                                                                       |
*  2   | 08-JAN-2025  | Added Condition to check Validation Flag and errmsg in l_end_proc            |
*  3   | 17-FEB-2025  | Calling convert_to_yyyy_mm_dd Fuction if the data type of the column is date |
*  4   | 04-MAR-2025  | Handling Case Sensitivity in User hook                                       |
*=====================================================================================================
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
    || nvl(CASE
            WHEN a.source_field IS NULL THEN
                NULL
            WHEN
                a.source_field IS NOT NULL
                AND a.column_type = 'D'
            THEN
                'convert_to_yyyy_mm_dd('||a.source_field||')'
            ELSE a.source_field 
        END, 'NULL')   ---> If the data type of the column is date then directly applying the data conversion formula by @sampaul.jeevan
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
              ctc.column_type,
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
       upper(cuh.hook_text) hook_text,
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
