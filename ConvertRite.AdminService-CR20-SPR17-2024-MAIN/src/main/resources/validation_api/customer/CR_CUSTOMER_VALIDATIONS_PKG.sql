CREATE OR REPLACE PACKAGE cr_customer_validations_pkg IS
    FUNCTION cr_cust_class (
        i_v_cust_class VARCHAR2
    ) RETURN VARCHAR2;

    FUNCTION cr_fs_prof_get_party_num (
        i_v_party VARCHAR2
    ) RETURN VARCHAR2;

    FUNCTION cr_fs_prof_get_acc_num (
        i_v_acc VARCHAR2
    ) RETURN VARCHAR2;

    FUNCTION cr_address_line1 (
        i_v_add_line1 VARCHAR2
    ) RETURN VARCHAR2;

    FUNCTION cr_fs_orig_system_reference_check (
        i_v_orig_sys_ref VARCHAR2,
        i_v_table_name   VARCHAR2
    ) RETURN VARCHAR2;

    FUNCTION cr_fs_cust_orig_sys_ref (
        i_v_cust_orig_system_reference VARCHAR2
    ) RETURN VARCHAR2;

    FUNCTION cr_fs_party_site_check (
        i_v_party_site_orig_system_reference VARCHAR2
    ) RETURN VARCHAR2;

    FUNCTION cr_fs_cust_party_site_num_check (
        i_v_customer_number VARCHAR2
    ) RETURN VARCHAR2;

END cr_customer_validations_pkg;
$#$

CREATE OR REPLACE PACKAGE BODY cr_customer_validations_pkg IS

    FUNCTION cr_cust_class (
        i_v_cust_class VARCHAR2
    ) RETURN VARCHAR2 IS
        v_cust_class VARCHAR2(2000);
    BEGIN
        SELECT DISTINCT
            lookup_code
        INTO v_cust_class
        FROM
            fnd_lookup_values
        WHERE
                lookup_type = 'CUSTOMER CLASS'
            AND upper(lookup_code) = upper(i_v_cust_class);

        RETURN v_cust_class;
    END cr_cust_class;

    FUNCTION cr_fs_prof_get_party_num (
        i_v_party VARCHAR2
    ) RETURN VARCHAR2 IS
        v_party_num VARCHAR2(250);
    BEGIN
        BEGIN
            SELECT
                party_number
            INTO v_party_num
            FROM
                hz_parties
            WHERE
                orig_system_reference = upper(i_v_party);

        EXCEPTION
            WHEN OTHERS THEN
                v_party_num := 0;
               --ROLLBACK; 
        END;

        RETURN v_party_num;
    END cr_fs_prof_get_party_num;

    FUNCTION cr_fs_prof_get_acc_num (
        i_v_acc VARCHAR2
    ) RETURN VARCHAR2 IS
        v_acc_num VARCHAR2(250);
    BEGIN
        BEGIN
            SELECT
                account_number
            INTO v_acc_num
            FROM
                hz_cust_accounts
            WHERE
                orig_system_reference = upper(i_v_acc);

        EXCEPTION
            WHEN OTHERS THEN
                v_acc_num := 0;
               --ROLLBACK; 
        END;

        RETURN v_acc_num;
    END cr_fs_prof_get_acc_num;

    FUNCTION cr_address_line1 (
        i_v_add_line1 VARCHAR2
    ) RETURN VARCHAR2 IS
        v_chr_name VARCHAR2(2000);
    BEGIN
        SELECT
            CASE
                WHEN nvl(i_v_add_line1, '-') IN ( '-', '--', '*', '---', '-     -' ) THEN
                    cr_transform_utils_pkg.raise_exception('Address Line 1 cannot be NULL')
                ELSE
                    i_v_add_line1
            END
        INTO v_chr_name
        FROM
            dual;

        RETURN v_chr_name;
    END cr_address_line1;

    FUNCTION cr_fs_orig_system_reference_check (
        i_v_orig_sys_ref VARCHAR2,
        i_v_table_name   VARCHAR2
    ) RETURN VARCHAR2 IS
        v_chr_name VARCHAR2(2000);
    BEGIN
        SELECT
            CASE
                WHEN upper(i_v_orig_sys_ref) NOT IN (
                    SELECT
                        upper(orig_system_reference)
                    FROM
                        hz_orig_sys_references
                    WHERE
                            owner_table_name = i_v_table_name
                        AND upper(orig_system_reference) = upper(i_v_orig_sys_ref)
                ) THEN
                    cr_transform_utils_pkg.raise_exception('Orig System Ref doesnt exist in fusion' || i_v_orig_sys_ref)
                ELSE
                    i_v_orig_sys_ref
            END
        INTO v_chr_name
        FROM
            dual;

        RETURN v_chr_name;
    END cr_fs_orig_system_reference_check;

    FUNCTION cr_fs_cust_orig_sys_ref (
        i_v_cust_orig_system_reference VARCHAR2
    ) RETURN VARCHAR2 IS
        v_chr_name VARCHAR2(2000);
    BEGIN
        SELECT
            CASE
                WHEN upper(i_v_cust_orig_system_reference) IN (
                    SELECT
                        upper(orig_system_reference)
                    FROM
                        hz_parties
                ) THEN
                    i_v_cust_orig_system_reference
                ELSE
                    cr_transform_utils_pkg.raise_exception('Does Not Exists in Fusion cust original system reference ' || i_v_cust_orig_system_reference
                    )
            END
        INTO v_chr_name
        FROM
            dual;

        RETURN v_chr_name;
    END cr_fs_cust_orig_sys_ref;

    FUNCTION cr_fs_party_site_check (
        i_v_party_site_orig_system_reference VARCHAR2
    ) RETURN VARCHAR2 IS
        v_chr_name VARCHAR2(2000);
    BEGIN
        SELECT
            CASE
                WHEN upper(i_v_party_site_orig_system_reference) IN (
                    SELECT
                        upper(orig_system_reference)
                    FROM
                        hz_party_sites
                ) THEN
                    cr_transform_utils_pkg.raise_exception(concat('Already Exists in Fusion party_site original system reference ', i_v_party_site_orig_system_reference
                    ))
                ELSE
                    i_v_party_site_orig_system_reference
            END
        INTO v_chr_name
        FROM
            dual;

        RETURN v_chr_name;
    END cr_fs_party_site_check;

    FUNCTION cr_fs_cust_party_site_num_check (
        i_v_customer_number VARCHAR2
    ) RETURN VARCHAR2 IS
        v_chr_name VARCHAR2(2000);
    BEGIN
        SELECT
            CASE
                WHEN EXISTS (
                    SELECT
                        1
                    FROM
                        hz_party_sites
                    WHERE
                        party_site_number = i_v_customer_number
                ) THEN
                    cr_transform_utils_pkg.raise_exception('Party_site_number  Already Exists  for this Customer ' || i_v_customer_number
                    )
                ELSE
                    i_v_customer_number
            END
        INTO v_chr_name
        FROM
            dual;

        RETURN v_chr_name;
    END cr_fs_cust_party_site_num_check;

END cr_customer_validations_pkg;
$#$

