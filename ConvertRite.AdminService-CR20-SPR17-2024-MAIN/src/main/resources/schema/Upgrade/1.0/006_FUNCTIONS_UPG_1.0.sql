
create or replace FUNCTION cr_replace_clob

(

  in_source  IN CLOB,

  in_search  IN VARCHAR2,

  in_replace IN CLOB

) 

RETURN CLOB 

IS

  l_pos pls_integer;

BEGIN

  l_pos := instr(in_source, in_search);

  IF l_pos > 0 THEN

    RETURN substr(in_source, 1, l_pos-1)

        || in_replace

        || substr(in_source, l_pos+LENGTH(in_search));

  END IF;

  RETURN in_source;

END cr_replace_clob;
$#$
create or replace FUNCTION cr_fetch_transform_stats_func RETURN cr_transform_stats_type_tab IS

    l_transform_stats_tab         cr_transform_stats_type_tab := cr_transform_stats_type_tab();
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
  AND src.staging_table_name IS NOT NULL;

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
BEGIN
FOR cld_transform_rec IN cld_transform_cur LOOP
        EXECUTE IMMEDIATE l_batch_query || cld_transform_rec.src_stg_table_name
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
           -- dbms_output.put_line(l_cloud_int_rej_sql);
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
                        l_cloud_success_rec := 0;
END;

                l_transform_stats_tab.extend();
                l_transform_stats_tab(l_transform_stats_tab.count) := cr_transform_stats_type(cld_transform_rec.cloud_template_id, cld_transform_rec.cloud_template_name
                , cld_transform_rec.project_id, cld_transform_rec.project, cld_transform_rec.parent_object_id,
                                                                                             cld_transform_rec.parent_object_code, cld_transform_rec.object_id
                                                                                             , cld_transform_rec.object, cld_transform_rec.src_stg_table_name
                                                                                             , cld_transform_rec.cld_stg_table_name,
                                                                                             l_src_rec_count, l_cld_rec_count, l_src_vf_rec_count
                                                                                             , l_src_vs_rec_count, l_src_unverified_rec_count
                                                                                             ,
                                                                                             l_vs_trans_rec_count, l_vs_untrans_rec_count
                                                                                             , l_vf_trans_rec_count, l_vf_untrans_rec_count
                                                                                             , l_unknwn_rec_count,
                                                                                             l_untrans_rec_count, l_cloud_int_rej_rec
                                                                                             , l_cloud_success_rec, batch_name(i), l_load_request_id
                                                                                             );

END LOOP;
END IF;
END LOOP;
RETURN l_transform_stats_tab;
END cr_fetch_transform_stats_func;

$#$
CREATE OR REPLACE FUNCTION CR_RECON_BASE_FAIL_FUNC (
    p_cld_template_id IN NUMBER,
    p_batch_name      IN VARCHAR2
) RETURN CLOB IS

    TYPE clobtab IS
        TABLE OF CLOB;
    l_col_tab         clobtab;
    l_clob_tab        clobtab;
    l_cols            CLOB;
    l_cols_final      CLOB;
    l_start           CLOB := q'[ '"'|| src_stg.]';
    l_end             CLOB := q'[||'"'||','||]';
    l_project_id      NUMBER;
    l_parent_obj_id   NUMBER;
    l_obj_id          NUMBER;
    l_obj_name        VARCHAR2(420);
    l_cld_stg_table   VARCHAR2(420);
    l_fail_query      CLOB;
    l_load_request_id VARCHAR2(240);
    l_base_columns    CLOB;
    l_comma_count     NUMBER;
    l_col_header      CLOB;
    l_base_col_header CLOB;
    l_query           CLOB;
    l_final_clob      CLOB;
    cur               SYS_REFCURSOR;
    l_src_stag_table  VARCHAR2(420);
    l_src_temp_id     NUMBER;
BEGIN
SELECT
    project_id,
    parent_object_id,
    object_id,
    object_name,
    staging_table_name,
    src_template_id
INTO
    l_project_id,
    l_parent_obj_id,
    l_obj_id,
    l_obj_name,
    l_cld_stg_table,
    l_src_temp_id
FROM
    cr_cld_template_hdrs_v
WHERE
    cld_template_id = p_cld_template_id;

SELECT
    staging_table_name
INTO l_src_stag_table
FROM
    cr_src_template_hdrs
WHERE
    src_template_id = l_src_temp_id;

SELECT
    to_clob(column_name)
        BULK COLLECT
INTO l_col_tab
FROM
    all_tab_columns
WHERE
    table_name = l_src_stag_table
  AND COLUMN_NAME NOT IN ('VALIDATION_FLAG','ERROR_MSG')
ORDER BY
    column_id;

dbms_lob.createtemporary(l_cols, false);
    dbms_lob.createtemporary(l_cols_final, false);
    dbms_lob.createtemporary(l_col_header, false);
    dbms_lob.createtemporary(l_query, false);
    dbms_lob.createtemporary(l_final_clob, false);
BEGIN
SELECT
    nvl(info_value, 'NULL'),
    nvl(additional_information1, NULL),
    nvl(regexp_count(additional_information1, ','),
        0)
INTO
    l_fail_query,
    l_base_columns,
    l_comma_count
FROM
    cr_object_information
WHERE
    info_type = 'RECON_CLOUD_FAIL'
  AND object_id = l_obj_id;

EXCEPTION
        WHEN OTHERS THEN
            l_fail_query := NULL;
            l_base_columns := NULL;
END;

BEGIN
SELECT
    nvl(load_request_id, NULL)
INTO l_load_request_id
FROM
    cr_cloud_job_status
WHERE
    object_id = l_obj_id
  AND batch_name = p_batch_name;

EXCEPTION
        WHEN OTHERS THEN
            l_load_request_id := NULL;
END;

FOR i IN l_col_tab.first..l_col_tab.last LOOP
        dbms_lob.append(l_cols, l_start);
        dbms_lob.append(l_cols, to_clob(replace(l_col_tab(i), chr(10), '')));

        dbms_lob.append(l_cols, l_end);
        dbms_lob.append(l_col_header, '"'
                                      || to_clob(replace(l_col_tab(i), chr(10), ''))
                                      || '",');

END LOOP;

l_col_header := l_col_header||q'["INTERFACE_ERROR"]';
    l_comma_count := l_comma_count + 1;
    --l_col_header := substr(l_col_header, 0, length(l_col_header) - 1);
    l_cols := substr(l_cols, 0, length(l_cols) - 7);
    l_fail_query := replace(l_fail_query, ':cr_batch_name', p_batch_name);
    l_fail_query := replace(l_fail_query, ':load_request_id', l_load_request_id);
    l_fail_query := replace(l_fail_query, ':cld_stg_table', l_cld_stg_table);
    l_fail_query := replace(l_fail_query, ':src_stg_table', l_src_stag_table);
    l_fail_query := cr_replace_clob(l_fail_query, ':src_cols', l_cols);
    l_query := l_fail_query;

   l_final_clob := null;
BEGIN
OPEN cur FOR l_query;

LOOP
FETCH cur
            BULK COLLECT INTO l_clob_tab LIMIT 1000;
            EXIT WHEN l_clob_tab.count = 0;
FOR x IN 1..l_clob_tab.count LOOP

           l_final_clob:= l_final_clob|| l_clob_tab(x)||'"' || chr(10);
--                dbms_lob.append(l_final_clob, l_clob_tab(x)
--                                              || chr(10));
END LOOP;

END LOOP;

EXCEPTION


        WHEN OTHERS THEN

            l_final_clob := 'Error While Retriving the Data..please check the details   ';
END;
    if l_final_clob is  not null then
     l_final_clob := l_col_header ||chr(10)||l_final_clob;
end if;



RETURN l_final_clob;
END;
$#$


 create or replace FUNCTION cr_recon_base_succ_func (
    p_cld_template_id IN NUMBER,
    p_batch_name      IN VARCHAR2
) RETURN CLOB IS

    TYPE clobtab IS
        TABLE OF CLOB;
    l_col_tab         clobtab;
    l_clob_tab        clobtab;
    l_cols            CLOB;
    l_cols_final      CLOB;
    l_base_clob       CLOB;
    l_start           CLOB := q'[ '"'|| src_stg.]';
    l_end             CLOB := q'[||'"'||','||]';
    l_project_id      NUMBER;
    l_parent_obj_id   NUMBER;
    l_obj_id          NUMBER;
    l_obj_name        VARCHAR2(420);
    l_cld_stg_table   VARCHAR2(420);
    l_success_query   CLOB;
    l_load_request_id VARCHAR2(240);
    l_base_columns    CLOB;
    l_comma_count     NUMBER;
    l_col_header      CLOB;
    l_base_col_header CLOB;
    l_query           CLOB;
    l_final_clob      CLOB;
    cur               SYS_REFCURSOR;
    l_src_stag_table  VARCHAR2(420);
    l_src_temp_id     NUMBER;
BEGIN
    SELECT
        project_id,
        parent_object_id,
        object_id,
        object_name,
        staging_table_name,
        src_template_id
    INTO
        l_project_id,
        l_parent_obj_id,
        l_obj_id,
        l_obj_name,
        l_cld_stg_table,
        l_src_temp_id
    FROM
        cr_cld_template_hdrs_v
    WHERE
        cld_template_id = p_cld_template_id;

    SELECT
        staging_table_name
    INTO l_src_stag_table
    FROM
        cr_src_template_hdrs
    WHERE
        src_template_id = l_src_temp_id;

    SELECT
        to_clob(column_name)
    BULK COLLECT
    INTO l_col_tab
    FROM
        all_tab_columns
    WHERE
        table_name = l_src_stag_table
    ORDER BY
        column_id;

    dbms_lob.createtemporary(l_cols, FALSE);
    dbms_lob.createtemporary(l_base_clob, FALSE);
    dbms_lob.createtemporary(l_cols_final, FALSE);
    dbms_lob.createtemporary(l_col_header, FALSE);
    dbms_lob.createtemporary(l_base_col_header, FALSE);
    dbms_lob.createtemporary(l_query, FALSE);
    dbms_lob.createtemporary(l_final_clob, FALSE);
    BEGIN
        SELECT
            nvl(info_value, 'NULL'),
            nvl(additional_information1, NULL),
            nvl(regexp_count(additional_information1, ','),
                0)
        INTO
            l_success_query,
            l_base_columns,
            l_comma_count
        FROM
            cr_object_information
        WHERE
                info_type = 'RECON_CLOUD_SUCCESS'
            AND object_id = l_obj_id;

    EXCEPTION
        WHEN OTHERS THEN
            l_success_query := NULL;
            l_base_columns := NULL;
    END;

    BEGIN
        SELECT
            nvl(load_request_id, NULL)
        INTO l_load_request_id
        FROM
            cr_cloud_job_status
        WHERE
                object_id = l_obj_id
            AND batch_name = p_batch_name;

    EXCEPTION
        WHEN OTHERS THEN
            l_load_request_id := NULL;
    END;

    FOR i IN l_col_tab.first..l_col_tab.last LOOP
        dbms_lob.append(l_cols, l_start);
        dbms_lob.append(l_cols, to_clob(replace(l_col_tab(i), chr(10), '')));

        dbms_lob.append(l_cols, l_end);
        dbms_lob.append(l_col_header, '"'
                                      || to_clob(replace(l_col_tab(i), chr(10), ''))
                                      || '",');

    END LOOP;

    l_comma_count := l_comma_count + 1;
    FOR i IN 1..l_comma_count LOOP
      l_base_clob := l_base_clob ||q'['"'||]'
                       || regexp_substr(regexp_substr(l_base_columns, '[^,]+', 1, i), '[^ ]+', 1, 1)
                       || l_end;
                       --|| '"';
                l_base_col_header := l_base_col_header || '"'
                                          || regexp_substr(regexp_substr(l_base_columns, '[^,]+', 1, i), '[^ ]+', 1, 2)|| '",';
--        dbms_lob.append(l_base_clob, q'['"'||]');
--        dbms_lob.append(l_base_clob, regexp_substr(regexp_substr(l_base_columns, '[^,]+', 1, i), '[^ ]+', 1, 1));
--
--        dbms_lob.append(l_base_clob, l_end);
--        dbms_lob.append(l_base_col_header, '"'
--                                           || regexp_substr(regexp_substr(l_base_columns, '[^,]+', 1, i), '[^ ]+', 1, 2)
--                                           || '",');

    END LOOP;

dbms_lob.append(l_cols, l_base_clob);
    dbms_lob.append(l_col_header, upper(l_base_col_header));

    l_col_header := substr(l_col_header, 0, length(l_col_header) - 1);

    l_cols := substr(l_cols, 0, length(l_cols) - 7);
    l_success_query := replace(l_success_query, ':cr_batch_name', p_batch_name);
    l_success_query := replace(l_success_query, ':load_request_id', l_load_request_id);
    l_success_query := replace(l_success_query, ':cld_stg_table', l_cld_stg_table);
    l_success_query := replace(l_success_query, ':src_stg_table', l_src_stag_table);
    l_success_query := cr_replace_clob(l_success_query, ':src_cols', l_cols);
    l_query := l_success_query;
    dbms_lob.append(l_final_clob, l_col_header || chr(10));
    BEGIN
        OPEN cur FOR l_query;

        LOOP
            FETCH cur
            BULK COLLECT INTO l_clob_tab LIMIT 1000;
            EXIT WHEN l_clob_tab.count = 0;
            FOR x IN 1..l_clob_tab.count LOOP
                l_final_clob := l_final_clob
                                || l_clob_tab(x)
                                || chr(10);
--                dbms_lob.append(l_final_clob, l_clob_tab(x)
--                                              || chr(10));
            END LOOP;

        END LOOP;

    EXCEPTION
        WHEN OTHERS THEN
       -- raise_application_error(-20001,substr(sqlerrm,0,20000));
            l_final_clob := 'Error While Retriving the Data..please check the details   ';
    END;

    RETURN l_final_clob;
END;
$#$
create or replace function  cr_copy_func(
    p_source_pod     IN VARCHAR2,
    p_destinaion_pod IN VARCHAR2,
    p_project_name   IN VARCHAR2
) return clob AS

PRAGMA AUTONOMOUS_TRANSACTION ;
    l_final_clob CLOB;
    l_query_1    CLOB DEFAULT q'[
DECLARE
    TYPE varchartab IS
        TABLE OF VARCHAR2(420);
    TYPE numtab IS
        TABLE OF NUMBER;
    l_object_codes        varchartab;
    l_object_id           numtab;
    l_object_code         varchartab;
    l_src_template_id     numtab;
    l_cld_template_id     numtab;
      L_FS_COUNT NUMBER;
    L_MS_COUNT NUMBER;
    l_parent_object       varchartab;
    l_source_table_id     NUMBER;
    l_projectexists       NUMBER; -- Variable to store whether the project exists (1) or not (0)
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
    l_map_set_check       NUMBER;
    l_uh_clob             CLOB;
    l_hook_id             NUMBER;
    l_uh_check            NUMBER;
    l_ret_code            VARCHAR2(250);
    l_ret_msg             VARCHAR2(250);
    l_drop_stmt           VARCHAR2(2000);
    l_table_chek          NUMBER;
    l_lookup_set_id       NUMBER;
    l_lookup_check        NUMBER;
    l_group_id            NUMBER;
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
        :p_source_pod.cr_cld_template_cols cols
    WHERE
            hdrs.project_id = l_project_id
        AND hdrs.cld_template_id = cols.cld_template_id
        AND mapping_type IN ( 'One to One', 'Two to One', 'Three to One', 'Formula' );

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
                    SELECT COUNT(DISTINCT formula_set_code) INTO L_FS_COUNT FROM :p_destinaion_pod.cr_formula_sets WHERE formula_set_code = I.CODE;

                IF L_FS_COUNT <1 THEN


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
                DELETE :p_destinaion_pod.cr_formula_sets WHERE FORMULA_SET_CODE = I.CODE;
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
                END IF;
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
SELECT COUNT(DISTINCT MAP_set_code) INTO L_MS_COUNT FROM :p_destinaion_pod.cr_MAPPING_sets WHERE MAP_set_code = I.CODE;
IF L_MS_COUNT < 1 THEN
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
                else
                DELETE :p_destinaion_pod.cr_mapping_sets WHERE map_set_code = I.CODE;
                COMMIT;
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
                END IF;
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
            STAGING_TABLE_NAME,
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
            execute IMMEDIATE l_drop_stmt;
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
            select nvl(src_template_id ,null) into l_src_temp_id from :p_destinaion_pod.cr_src_template_hdrs where object_id = (select object_id from  :p_source_pod.cr_cld_template_hdrs
                WHERE
                    cld_template_id = i.cld_template_id);
            -- added to fix same src_template_id for all cld templates

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
                BEGIN
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
  exception when others then 
                   l_src_col_id := NULL;
                        end;

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
            execute IMMEDIATE l_drop_stmt;
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
WHERE
        group_code = x.group_code
    AND project_id = l_project_id);
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

    --dbms_output.put_line(l_final_clob);

BEGIN
  EXECUTE IMMEDIATE l_final_clob;
  return 
  'POD DETAILS COPIED SUCCESSFULLY';
  EXCEPTION WHEN OTHERS THEN
   return 
   'POD DETAILS COPY Failed '||sqlerrm;
  END ;
END;
$#$
create or replace FUNCTION cr_fetch_onetoone_sql_func (
    p_cld_column_name VARCHAR2,
    p_src_column_name VARCHAR2,
    p_mapping_id      IN NUMBER
) RETURN CLOB IS

    TYPE varchartab IS
        TABLE OF VARCHAR2(2400);
    l_src_value    varchartab;
    l_target_value varchartab;
    l_final_clob   CLOB;
    l_out_query    CLOB;
BEGIN
    SELECT DISTINCT
        source_field1,
        target_value
    BULK COLLECT
    INTO
        l_src_value,
        l_target_value
    FROM
        cr_mapping_values
    WHERE
            map_set_id = p_mapping_id
        AND enabled_flag = 'Y';

    FOR i IN l_src_value.first..l_src_value.last LOOP
        l_out_query := l_out_query
                       || ' WHEN '
                       || 'NVL(base_table.'
                       || p_src_column_name
                       || ','''
                       || 'NULL'
                       || ''')'
                       || ' = '
                       || 'q'
                       || ''''
                       || '['
                       || l_src_value(i)
                       || ']'
                       || ''''
                       || ' THEN '
                       || ''''
                       || l_target_value(i)
                       || '''';
    END LOOP;

    l_final_clob := ' CASE '
                    || l_out_query
                    || ' ELSE  raise_exception_func('
                    || ''''
                    || p_cld_column_name
                    || ''''
                    || ') END ';

    RETURN l_final_clob;
END;
$#$
