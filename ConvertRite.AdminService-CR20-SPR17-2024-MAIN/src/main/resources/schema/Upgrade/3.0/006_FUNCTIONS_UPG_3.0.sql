CREATE OR REPLACE FUNCTION cr_fetch_onetoone_sql_func (
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
                       || 'DECODE(NVL(base_table.'
                       || p_src_column_name
                       || ','
                       || Q'[NULL),NULL,'NULL',BASE_TABLE.]'
                       || p_src_column_name
                       || ')'
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
                    || '    FOR VALUE : ''||BASE_TABLE.'
                    || p_src_column_name
                    || ') END';

    RETURN l_final_clob;
END cr_fetch_onetoone_sql_func;
$#$
create or replace FUNCTION cr_fetch_twotoone_sql_func ( p_src_column_name1 VARCHAR2, p_src_column_name2 VARCHAR2, p_mapping_id IN NUMBER )
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
        ||'''||' -- added to handle error value 
        || '    FOR VALUE : ''||BASE_TABLE.'
                    || p_src_column_name1
                    ||'||'','''
                    || '||BASE_TABLE.'
                    || p_src_column_name2 -- added to handle error value
        || ') END'
        || ' FROM '
        || 'DUAL ' ;
    l_clob := l_clob||' )';
    RETURN l_clob;
END CR_FETCH_TWOTOONE_SQL_FUNC;
$#$
