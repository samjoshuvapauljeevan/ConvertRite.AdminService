DECLARE
    l_cust_orig_sys_chk   NUMBER;
    l_fs_party_site_check NUMBER;
BEGIN
    BEGIN
        SELECT
            COUNT(1)
        INTO l_cust_orig_sys_chk
        FROM
            cr_formula_sets
        WHERE
            formula_set_name = 'CR_CUST_ORIG_SYS_CHK';

    EXCEPTION
        WHEN OTHERS THEN
            l_cust_orig_sys_chk := 0;
    END;

    IF ( l_cust_orig_sys_chk = 0 ) THEN
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
            'CR_CUST_ORIG_SYS_CHK',
            'CR_CUST_ORIG_SYS_CHK',
            'Chk on Cust Orig Sys ref',
            'SQL',
            'cr_customer_validations_pkg.cr_fs_cust_orig_sys_ref(base_table.orig_system_reference)',
            1,
            TO_DATE(sysdate, 'DD-MM-RR'),
            'CR20'
        );

    END IF;

    BEGIN
        SELECT
            COUNT(1)
        INTO l_fs_party_site_check
        FROM
            cr_formula_sets
        WHERE
            formula_set_name = 'CR_FS_PARTY_SITE_CHECK';

    EXCEPTION
        WHEN OTHERS THEN
            l_fs_party_site_check := 0;
    END;

    IF ( l_fs_party_site_check = 0 ) THEN
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
            'CR_FS_PARTY_SITE_CHECK',
            'CR_FS_PARTY_SITE_CHECK',
            'Party Site Check',
            'SQL',
            'cr_customer_validations_pkg.cr_fs_party_site_check(base_table.orig_system_reference)',
            1,
            TO_DATE(sysdate, 'DD-MM-RR'),
            'CR20'
        );

    END IF;

    COMMIT;
END;
$#$