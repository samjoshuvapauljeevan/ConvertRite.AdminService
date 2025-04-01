DECLARE
    l_bank_Country_name Number;
    l_allow_additional_value_flag Number;
BEGIN
    BEGIN
        SELECT
            COUNT(*)
        INTO l_bank_Country_name
        FROM
            all_tab_columns
        WHERE
            table_name = 'CR_CREATE_BANK_BRANCH_ERRORS'
            AND column_name = 'COUNTRY_NAME';
        If l_bank_Country_name = 0 THEN
            EXECUTE IMMEDIATE 'ALTER TABLE CR_CREATE_BANK_BRANCH_ERRORS ADD COUNTRY_NAME VARCHAR2(300)';
        END IF;
    END;

    BEGIN
        SELECT
            COUNT(*)
        INTO l_allow_additional_value_flag
        FROM
            all_tab_columns
        WHERE
                table_name = 'CR_MAPPING_SETS'
            AND column_name = 'ALLOW_ADDITIONAL_VALUE_FLAG';
    
        IF l_allow_additional_value_flag = 0 THEN
            EXECUTE IMMEDIATE ' ALTER TABLE cr_mapping_sets ADD allow_additional_value_flag VARCHAR2(50)';
        END IF;
    END;
END;
$#$
