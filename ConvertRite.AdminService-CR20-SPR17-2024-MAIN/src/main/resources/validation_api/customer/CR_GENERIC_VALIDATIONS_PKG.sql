CREATE OR REPLACE PACKAGE cr_generic_validations_pkg IS
    FUNCTION cr_date_convert (
        i_v_start_date VARCHAR2
    ) RETURN DATE;

    FUNCTION cr_check_mandatory (
        i_v_name_check  VARCHAR2,
        i_v_column_name VARCHAR2
    ) RETURN VARCHAR2;

END cr_generic_validations_pkg;
$#$
CREATE OR REPLACE PACKAGE BODY cr_generic_validations_pkg IS

    FUNCTION cr_date_convert (
        i_v_start_date VARCHAR2
    ) RETURN DATE AS
    BEGIN
        RETURN ( TO_DATE ( to_char(TO_DATE(i_v_start_date, 'YYYY/MM/DD'),
                                   'YYYY/MM/DD'), 'YYYY/MM/DD' ) );
    END cr_date_convert;

    FUNCTION cr_check_mandatory (
        i_v_name_check  VARCHAR2,
        i_v_column_name VARCHAR2
    ) RETURN VARCHAR2 IS
        v_chr_name VARCHAR2(2000);
    BEGIN
        SELECT
            CASE
                WHEN i_v_name_check IS NULL THEN
                    cr_transform_utils_pkg.raise_exception('Mandatory Field cannot be NULL :' || i_v_column_name)
                ELSE
                    i_v_name_check
            END
        INTO v_chr_name
        FROM
            dual;

        RETURN v_chr_name;
    END cr_check_mandatory;

END cr_generic_validations_pkg;
$#$
