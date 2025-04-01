---------functions
create or replace FUNCTION cr_fetch_onetoone_sql_func (
    p_cld_column_name VARCHAR2,
    p_src_column_name VARCHAR2,
    p_mapping_id      IN NUMBER
) RETURN CLOB 
/*
******************************************************************************************************
* Project                        : ConvertRite
* Application                    :
* Title                          : cr_fetch_onetoone_sql_func
* Program Name                   : cr_fetch_onetoone_sql_func
* Description and Purpose        : One to One Mapping in ConvertRite
* Created by                     : sampaul.jeevan
* Change History                 : 1.0
*=====================================================================================================
* S.NO |    Date      |                 Reason                                                       |
*  1   |              | Intial                                                                       |
*  2   | 21-FEB-2025  | Added condition to allow additional values                                   |
*=====================================================================================================
*/

IS

    TYPE varchartab IS
        TABLE OF VARCHAR2(2400);
    l_src_value                   varchartab;
    l_target_value                varchartab;
    l_allow_additional_value_flag VARCHAR2(1);
    l_final_clob                  CLOB;
    l_out_query                   CLOB;
BEGIN
    SELECT
        allow_additional_value_flag
    INTO l_allow_additional_value_flag
    FROM
        cr_mapping_sets
    WHERE
        map_set_id = p_mapping_id;

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

    IF l_allow_additional_value_flag = 'Y' THEN
        l_final_clob := ' CASE '
                        || l_out_query
                        || ' ELSE '
                        || ' BASE_TABLE.'
                        || p_src_column_name
                        || ' END';
    ELSE
        l_final_clob := ' CASE '
                        || l_out_query
                        || ' ELSE  raise_exception_func('
                        || ''''
                        || p_cld_column_name
                        || '    FOR VALUE : ''||BASE_TABLE.'
                        || p_src_column_name
                        || ') END';
    END IF;

    RETURN l_final_clob;
END cr_fetch_onetoone_sql_func;
$#$
