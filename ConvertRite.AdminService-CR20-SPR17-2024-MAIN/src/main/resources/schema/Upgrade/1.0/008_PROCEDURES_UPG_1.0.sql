create or replace PROCEDURE cr_populate_orig_trans_id_proc (
    p_template_id IN NUMBER,
    p_table_name  IN VARCHAR2,
    p_user_id     IN VARCHAR2,
    p_batch_name  IN VARCHAR2,
    p_ret_code    OUT VARCHAR2,
    p_ret_msg     OUT VARCHAR2
) IS

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
                                                      || q'[ WHERE a.rowid NOT IN ( SELECT MIN(b.rowid)
                                                                                                                                                                                                         FROM :TABLE_NAME b
                                                                                                                                                                                                         WHERE :B_COLUMN_LIST = :COLUMN_LIST
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
EXECUTE IMMEDIATE lc_denorm_orig_trans_upd_sql;
COMMIT;


lc_denorm_update_duplicate := replace(lc_denorm_update_duplicate, ':TABLE_NAME', p_table_name);
                lc_denorm_update_duplicate := replace(lc_denorm_update_duplicate, ':P_BATCH_NAME', p_batch_name);
                lc_denorm_update_duplicate := replace(lc_denorm_update_duplicate, ':COLUMN_LIST', nvl(A_COLS, ''));
                               lc_denorm_update_duplicate := replace(lc_denorm_update_duplicate, ':B_COLUMN_LIST', nvl(REPLACE(A_COLS,'b.','a.'), ''));
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
create or replace PROCEDURE CR_CLD_TRANSFORM_ASYNC_PROC (
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
                                  || ' WHERE nvl(CR_BATCH_NAME,'
                                  || ''''
                                  || 'XXX'
                                  || ''''
                                  || ') = '
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
                                           WHERE validation_flag IN ('VF','DUPLICATE')
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
                   -- dbms_output.put_line(i.code);
                   -- dbms_output.put_line(i.mapping_set_id);

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
           -- dbms_output.put_line(i.src_template_id);
           -- dbms_output.put_line(i.src_template_code);

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
           -- dbms_output.put_line(i.cld_template_id);

            DELETE FROM :p_destinaion_pod.cr_cld_template_cols
            WHERE
                cld_template_id IN ( i.cld_template_id );

            DELETE FROM :p_destinaion_pod.cr_cld_template_hdrs
            WHERE
                cld_template_id IN ( i.cld_template_id );

            COMMIT;
               -- dbms_output.put_line('Dlete Cloud Meta data');
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
   -- dbms_output.put_line(i.cld_template_id);
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
      --  dbms_output.put_line('Object Grouping');
    begin


    for x in get_exist_object_group_details(l_project_id) loop
     --Delete existing Object Grouping Details

     delete from :p_destinaion_pod.CR_OBJECT_GROUP_LINES
            where GROUP_ID in (select GROUP_ID from :p_destinaion_pod.CR_OBJECT_GROUP_HDRS
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
    --dbms_output.put_line('Object Grouping Completed');

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
        p_msg := 'POD DETAILS COPY Failed '||sqlerrm;
        p_result := 'N';
        dbms_output.put_line(p_msg);
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
         IF p_batch_names_out IS NOT NULL THEN

            p_batch_names_out := p_batch_names_out
                                 || ','
                                 || p_dup_batch_name;
                                 ELSE
                                 p_batch_names_out :=p_dup_batch_name;
                                 END IF ;
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
create or replace PROCEDURE CR_CVR_UPDATE_PROC (
    p_cld_table_name IN VARCHAR2,
    p_src_temp_id    IN NUMBER,
    p_batch_name     IN VARCHAR2,
    p_ledger_name in varchar2,
    p_ccid_column_name in varchar2
) IS

    p_src_table_name VARCHAR2(240);
    l_object_code    VARCHAR2(240);
    l_ccid_column    VARCHAR2(240);
    l_ledger_name    VARCHAR2(240);
    l_tot_count number;
    L_VS_NUM number;
    L_VF_NUM number;
    l_query          CLOB DEFAULT Q'[DECLARE

CURSOR C1 IS
 SELECT A.ORIG_TRANS_ID ,
            b.CR_batch_name,
            a.:CCID_COLUMN_NAME,
            b.ERROR_MESSAGE,
            b.ERROR_CODE,
            b.STATUS,
            b.CCID
        FROM
            :P_CLD_TABLE_NAME  a,
            CR_VALIDATE_CVR_CCID  b
        WHERE
                a.:CCID_COLUMN_NAME = b.CCID and
                upper(B.CLOUD_STAGING_TABLE_NAME) = UPPER(':P_CLD_TABLE_NAME')
                 AND A.CR_BATCH_NAME = B.CR_BATCH_NAME
            AND b.CR_batch_name = ':P_BATCH_NAME' ;

            TYPE CURTAB IS TABLE OF C1%ROWTYPE;
            L_REC_TYPE CURTAB;

BEGIN

OPEN C1;
--LOOP
FETCH C1 BULK COLLECT INTO L_REC_TYPE;

CLOSE C1;

FOR I IN L_REC_TYPE.FIRST..L_REC_TYPE.LAST
LOOP
UPDATE :P_SRC_TABLE_NAME
            SET
                VALIDATION_FLAG = DECODE(l_rec_type(i).STATUS,'Valid','VS','Invalid','VF'),
                error_msg = (case when l_rec_type(i).ERROR_MESSAGE is null then 'SUCCESS'
                when l_rec_type(i).ERROR_CODE ='GL_ADFDI_SEGMENT_NOTEXIST' then 'CVR_ERROR : '||l_rec_type(i).ERROR_MESSAGE || '-' ||l_rec_type(i).CCID
                ELSE 'CVR_ERROR : '||l_rec_type(i).ERROR_MESSAGE END )
            WHERE
                ORIG_TRANS_ID  = l_rec_type(i).ORIG_TRANS_ID
                AND CR_BATCH_NAME  = l_rec_type(i).CR_BATCH_NAME;
                commit;

            COMMIT;

            dbms_output.put_line (l_rec_type(i).STATUS||'  '||l_rec_type(i).ERROR_MESSAGE ||'  '||l_rec_type(i).ORIG_TRANS_ID);




--DBMS_OUTPUT.PUT_LINE(l_rec_type(i).ORIG_TRANS_ID||l_rec_type(i).BATCH_NAME||l_rec_type(i).ERROR_MESSAGE||l_rec_type(i).ERROR_CODE||l_rec_type(i).STATUS);

END LOOP; --UPDATING LOOP

commit;

--END LOOP;-- DATA RETRIVAL LOOP


DELETE FROM :P_CLD_TABLE_NAME  WHERE ORIG_TRANS_ID IN 

(select distinct orig_trans_id from :P_SRC_TABLE_NAME
NAME where validation_flag  = 'VF' AND ERROR_MSG LIKE '%CVR_ERROR%' and  CR_batch_name = ':P_BATCH_NAME' )
             AND CR_BATCH_NAME = ':P_BATCH_NAME' ;
             commit;



END;
]';
BEGIN
SELECT STAGING_TABLE_NAME into p_src_table_name  FROM CR_SRC_TEMPLATE_HDRS
WHERE SRC_TEMPLATE_ID = p_src_temp_id;
    l_query := replace(l_query, ':P_CLD_TABLE_NAME', p_cld_table_name);
    l_query := replace(l_query, ':P_SRC_TABLE_NAME', p_src_table_name);
    l_query := replace(l_query, ':P_BATCH_NAME', p_batch_name);
    l_query := replace(l_query, ':CCID_COLUMN_NAME', p_ccid_column_name);

DBMS_OUTPUT.PUT_LINE(L_QUERY);
    EXECUTE IMMEDIATE l_query;
    commit;
END;
$#$
CREATE OR REPLACE PROCEDURE CR_FBDI_FILEGEN_PROC(
    p_cld_template_id IN NUMBER,
    p_batch_name      IN VARCHAR2,
    p_clob_fbdi_file  OUT CLOB,
    p_result_code out varchar2,
    p_result_msg out varchar2

) IS

    TYPE varchartab IS
        TABLE OF clob;
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
    x             INT;
    cur             SYS_REFCURSOR;

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
            nvl(
                display_seq, 9999999999
            ) ASC;

    ELSE
        SELECT
            decode(
                column_type, 'D', 'TO_CHAR('
                                  || column_name
                                  || ','
                                  || ''''
                                  || l_date_format
                                  || ''''
                                  || ')', column_name
            )
        BULK COLLECT
        INTO l_col_tab
        FROM
            cr_cld_template_cols
        WHERE
            cld_template_id = p_cld_template_id
            AND display_seq IS NOT NULL
        ORDER BY
            nvl(
                display_seq, 9999999999
            ) ASC;

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

    l_cols := substr(l_cols,0,length(l_cols) - 7);

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

        CLOSE cur;
    EXCEPTION
        WHEN OTHERS THEN
            insert_into_log_proc(
                                p_cld_template_id,
                                'SELECT  '
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
            );

            RAISE;
    END;

    p_clob_fbdi_file := l_clob;
    p_result_code:='Y';
    p_result_msg:='SUCCESS';
    exception when others then
    p_result_code:='N';
    p_result_msg:='Unexpected error in CR_FBDI_FILEGEN_PROC: '||SQLERRM;
END cr_fbdi_filegen_proc;
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
        WHERE nvl(validation_flag,'N') IN ('VF','DUPLICATE') and cr_batch_name = ]'||''''||p_batch_name ||'''';
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
