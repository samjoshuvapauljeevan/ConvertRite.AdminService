CREATE OR REPLACE FUNCTION raise_exception_func
RETURN VARCHAR2 IS
BEGIN
    RAISE case_not_found;
END raise_exception_func;
$#$

CREATE OR REPLACE FUNCTION raise_exception_func ( p_cloud_column IN VARCHAR2 )
RETURN VARCHAR2 IS
BEGIN
    raise_application_error(-20001, ' Error :' || p_cloud_column,TRUE);
END raise_exception_func;
$#$

CREATE OR REPLACE FUNCTION cr_fetch_onetoone_sql_func ( p_cld_column_name VARCHAR2, p_src_column_name VARCHAR2, p_mapping_id IN NUMBER)
RETURN CLOB
    IS
    l_case_stmt CLOB;
BEGIN
    SELECT
        'CASE '
        || field
        || ' ELSE  raise_exception_func('
        || ''''
        || p_cld_column_name
        || ''''
        || ') END'
    INTO l_case_stmt
    FROM
        (
            SELECT
                LISTAGG('WHEN '
                        ||'NVL(base_table.'|| p_src_column_name||','''||'NULL'||''')'
                        || ' = '
                        ||'q'
                        || ''''
                        ||'['
                         ||lines.source_field1
                        ||']'
                        || ''''
                        || ' THEN '
                        || ''''
                        || lines.target_value
                        || '''',
                        ' ') WITHIN GROUP(
                    ORDER BY
                        lines.source_field1
                ) field,
                p_cld_column_name,
                p_src_column_name
            FROM cr_mapping_values  lines
            WHERE lines.map_set_id = p_mapping_id
              AND  lines.ENABLED_FLAG = 'Y'
        );

    RETURN l_case_stmt;
END CR_FETCH_ONETOONE_SQL_FUNC;
$#$

CREATE OR REPLACE   FUNCTION cr_fetch_twotoone_sql_func ( p_src_column_name1 VARCHAR2, p_src_column_name2 VARCHAR2, p_mapping_id IN NUMBER )
RETURN CLOB IS
    TYPE varchartab IS
        TABLE OF VARCHAR2(32000);
        l_type              VARCHAR2(15);
        l_clob              CLOB;
        l_sourcefield1_tab  varchartab;
        l_sourcefield2_tab  varchartab;
        l_coud_val_tab      varchartab;
BEGIN
    SELECT
        NVL(source_field1,'NULL'),
        NVL(source_field2,'NULL'),
        target_value
    BULK COLLECT
    INTO
        l_sourcefield1_tab,
        l_sourcefield2_tab,
        l_coud_val_tab
    FROM
        cr_mapping_values
    WHERE
        map_set_id = p_mapping_id;
    l_clob := l_clob || '( SELECT CASE';
    IF l_sourcefield1_tab.count > 0 THEN
        FOR i IN l_sourcefield1_tab.first..l_sourcefield1_tab.last LOOP
            l_clob := l_clob
                      || ' '
                      || ' WHEN '
                      || 'NVL(base_table.'
                      || p_src_column_name1
                      || ' ,''NULL'') = '
                      || ''''
                      || l_sourcefield1_tab(i)
                      || ''''
                      || ' AND '
                      || 'NVL(base_table.'
                      || p_src_column_name2
                      || ' ,''NULL'') = '
                      || ''''
                      || l_sourcefield2_tab(i)
                      || ''''
                      || ' THEN '
                      || ''''
                      || l_coud_val_tab(i)
                      || '''';
        END LOOP;
    END IF;
    l_clob := l_clob
              || ' ELSE   raise_exception_func('
        || ''' No valid Mappings for  '
        || p_src_column_name1
         ||','|| p_src_column_name2
        || ''''
        || ') END'
        || ' FROM '
        || 'DUAL ' ;
    l_clob := l_clob||' )';

    RETURN l_clob;
END CR_FETCH_TWOTOONE_SQL_FUNC;

$#$

CREATE OR REPLACE FUNCTION CR_FETCH_FORMULA_SQL_FUNC ( p_formula_id IN NUMBER )
RETURN CLOB IS
    l_clob CLOB;
BEGIN
    SELECT
        formula_text
    INTO l_clob
    FROM
        cr_formula_sets
    WHERE
        formula_set_id = p_formula_id;

    l_clob := replace(l_clob, ':orig_trans_id', 'base_table.orig_trans_id');

    RETURN '('
           || l_clob
           || ')';
END CR_FETCH_FORMULA_SQL_FUNC;
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
        nvl(a.info_value, 'NULL')
         cloud_success,
        nvl(b.info_value, 'NULL')
         cloud_failure
    FROM
        cr_object_information a,
       cr_object_information b
    WHERE
            a.info_type = 'RECON_CLOUD_SUCCESS'
        AND b.info_type = 'RECON_CLOUD_FAIL'
        AND a.object_id = b.object_id
        AND a.object_id = p_object_id;
    l_src_rec_cnt_sql             VARCHAR2(1000) DEFAULT 'SELECT COUNT(1) FROM ';
    l_src_rec_count               NUMBER DEFAULT 0;
    l_cld_rec_cnt_sql             VARCHAR2(1000) DEFAULT 'SELECT COUNT(1) FROM ';
    l_cld_rec_count               NUMBER DEFAULT 0;
    l_src_vf_rec_sql              VARCHAR2(1000) DEFAULT 'SELECT COUNT(1) FROM ';
    l_src_vf_rec_count            NUMBER DEFAULT 0;
    l_src_vf_where_clause         VARCHAR2(1000) DEFAULT q'[ WHERE nvl(validation_flag,'N')='VF']';
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
    l_cloud_success_sql           VARCHAR2(8000);
    l_cloud_success_rec           NUMBER DEFAULT 0;
    l_load_request_id             VARCHAR2(240);
    l_batch_query                 VARCHAR2(2000) := ' SELECT DISTINCT CR_BATCH_NAME FROM ';
BEGIN
    FOR cld_transform_rec IN cld_transform_cur LOOP
        EXECUTE IMMEDIATE l_batch_query || cld_transform_rec.src_stg_table_name
        BULK COLLECT
        INTO batch_name;
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
                    l_cloud_int_rej_sql;
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
            dbms_output.put_line(l_cloud_int_rej_sql);
            BEGIN
                l_cloud_int_rej_sql := replace(l_cloud_int_rej_sql, ':cld_cols', 'cld_stg.cr_batch_name');
                l_cloud_int_rej_sql := replace(l_cloud_int_rej_sql, ':cld_stg_table', cld_transform_rec.cld_stg_table_name);
                l_cloud_int_rej_sql := replace(l_cloud_int_rej_sql, ':cr_batch_name', batch_name(i));
                l_cloud_int_rej_sql := replace(l_cloud_int_rej_sql, ':load_request_id', l_load_request_id);
                EXECUTE IMMEDIATE 'SELECT COUNT(1) FROM ('
                                  || l_cloud_int_rej_sql
                                  || ')'
                INTO l_cloud_int_rej_rec;
            EXCEPTION
                WHEN OTHERS THEN
                    l_cloud_int_rej_rec := 0;
            END;
            BEGIN
                l_cloud_success_sql := replace(l_cloud_success_sql, ':cld_cols', 'cld_stg.cr_batch_name');
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
                                                                                         l_untrans_rec_count, l_cloud_int_rej_rec, l_cloud_success_rec
                                                                                         , batch_name(i), l_load_request_id);
        END LOOP;
    END LOOP;
    RETURN l_transform_stats_tab;
END cr_fetch_transform_stats_func;
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
                                          || regexp_substr(regexp_substr(l_base_columns, '[^,]+', 1, i), '[^ ]+', 1, 2);
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
                                || '"'
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
