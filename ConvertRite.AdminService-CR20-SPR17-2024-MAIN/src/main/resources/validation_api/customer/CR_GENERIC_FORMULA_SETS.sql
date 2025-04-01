DECLARE
    l_mandatory_chk NUMBER;
    l_date_convert  NUMBER;
BEGIN
    BEGIN
        SELECT
            COUNT(1)
        INTO l_mandatory_chk
        FROM
            cr_formula_sets
        WHERE
            formula_set_name = 'CR_MANDATORY_CHK';

    EXCEPTION
        WHEN OTHERS THEN
            l_mandatory_chk := 0;
    END;

    IF ( l_mandatory_chk = 0 ) THEN
        INSERT INTO cr_formula_sets (
            formula_set_name,
            formula_set_code,
            description,
            formula_type,
            formula_text,
            count_of_params,
            creation_date,
            created_by
        ) VALUES (
            'CR_MANDATORY_CHK',
            'CR_MANDATORY_CHK',
            'Mandatory Column Check',
            'SQL',
            q'[cr_generic_validations_pkg.cr_check_mandatory(base_table.orig_system_reference,'ORIG_SYSTEM_REFERENCE')]',
            2,
            TO_DATE(sysdate, 'DD-MM-RR'),
            'CR20'
        );

    END IF;

    BEGIN
        SELECT
            COUNT(1)
        INTO l_date_convert
        FROM
            cr_formula_sets
        WHERE
            formula_set_name = 'CR_DATE_CONVERT';

    EXCEPTION
        WHEN OTHERS THEN
            l_date_convert := 0;
    END;

    IF ( l_date_convert = 0 ) THEN
        INSERT INTO cr_formula_sets (
            formula_set_name,
            formula_set_code,
            description,
            formula_type,
            formula_text,
            count_of_params,
            creation_date,
            created_by
        ) VALUES (
            'CR_DATE_CONVERT',
            'CR_DATE_CONVERT',
            'Date Convert Formula',
            'SQL',
            'cr_generic_validations_pkg.cr_date_convert(base_table.creation_date)',
            1,
            TO_DATE(sysdate, 'DD-MM-RR'),
            'CR20'
        );

    END IF;

    COMMIT;
END;
$#$