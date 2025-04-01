DECLARE
    l_cld_template_code_count         NUMBER;
    l_cld_metadata_table_count        NUMBER;
    l_cld_template_name_count         NUMBER;
    l_cr_target_column_records        NUMBER;
    l_cr_preload_status               NUMBER;
    l_async_process_status            NUMBER;
    l_bank_err_cld_template           NUMBER;
    l_cr_proj_activities              NUMBER;
    l_indx_formula1                   NUMBER;
    l_indx_formula2                   NUMBER;
    l_bank_err_cld_status             NUMBER;
    l_bank_branch_cld_template        NUMBER;
    l_bank_branch_status              NUMBER;
    l_bank_country_name               NUMBER;
    l_cr_ebs_connection_details_count NUMBER;
    l_cr_sqlextraction_bind_var_dtls_count NUMBER;
    l_cr_query_bind_var_cols_count    NUMBER;
BEGIN

-- Check if the table column count exists
    BEGIN
        SELECT
            COUNT(*)
        INTO l_cld_template_code_count
        FROM
            all_tab_columns
        WHERE
                table_name = 'CR_OBJECTS'
            AND column_name = 'CLD_TEMPLATE_CODE';

        IF l_cld_template_code_count = 0 THEN
            EXECUTE IMMEDIATE ' ALTER TABLE CR_OBJECTS ADD CLD_TEMPLATE_CODE VARCHAR2(50)';
        END IF;
    END;

    BEGIN
        SELECT
            COUNT(*)
        INTO l_cld_metadata_table_count
        FROM
            all_tab_columns
        WHERE
                table_name = 'CR_OBJECTS'
            AND column_name = 'CLD_METADATA_TABLE_NAME';

        IF l_cld_metadata_table_count = 0 THEN
            EXECUTE IMMEDIATE ' ALTER TABLE CR_OBJECTS ADD CLD_METADATA_TABLE_NAME VARCHAR2(50)';
        END IF;
    END;

    BEGIN
        SELECT
            COUNT(*)
        INTO l_cld_template_name_count
        FROM
            all_tab_columns
        WHERE
                table_name = 'CR_OBJECTS'
            AND column_name = 'CLD_TEMPLATE_NAME';

        IF l_cld_template_name_count = 0 THEN
            EXECUTE IMMEDIATE ' ALTER TABLE CR_OBJECTS ADD CLD_TEMPLATE_NAME VARCHAR2(50)';
        END IF;
    END;

    BEGIN
        SELECT
            COUNT(*)
        INTO l_cr_target_column_records
        FROM
            all_tables
        WHERE
            table_name = 'CR_TARGET_INTF_COLUMN_LIST';

        IF l_cr_target_column_records = 0 THEN
            EXECUTE IMMEDIATE '
           CREATE TABLE CR_TARGET_INTF_COLUMN_LIST (
    COLUMN_LIST_ID NUMBER  GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
    TARGET_SYSTEM VARCHAR2(1000),
    TARGET_SYSTEM_VERSION VARCHAR2(1000),
    OBJECT_ID NUMBER NOT NULL,
    COLUMN_NAME VARCHAR2(1000) NOT NULL,
    PHYSICAL_COLUMN_NAME VARCHAR2(1000) NOT NULL,
    USER_COLUMN_NAME VARCHAR2(1000) NOT NULL,
    COLUMN_DESCRPTION VARCHAR2(1000),
    COLUMN_SEQUENCE VARCHAR2(1000),
    COLUMN_TYPE VARCHAR2(1000),
    COLUMN_WIDTH VARCHAR2(1000),
    NULL_ALLOWED_FLAG VARCHAR2(1000),
    TRANSLATE_FLAG VARCHAR2(1),
    PRECISION VARCHAR2(1000),
    SCALE VARCHAR2(1000),
    DOMAIN_CODE VARCHAR2(1000),
    DENORM_PATH VARCHAR2(1000),
    ROUTING_MODE VARCHAR2(1000),
    CLOUD_VERSION VARCHAR2(1000),
    ELIGIBLE_TO_BE_SECURED VARCHAR2(1000),
    SECURITY_CLASSIFICATION VARCHAR2(1000),
    SEC_CLASSIFICATION_OVERRIDE VARCHAR2(1000),
    ATTRIBUTE1 VARCHAR2(150),
    ATTRIBUTE2 VARCHAR2(150),
    ATTRIBUTE3 VARCHAR2(150),
    ATTRIBUTE4 VARCHAR2(150),
    ATTRIBUTE5 VARCHAR2(150),
    CREATION_DATE DATE NOT NULL,
    CREATED_BY VARCHAR2(200) NOT NULL,
    LAST_UPDATE_DATE DATE,
    LAST_UPDATED_BY VARCHAR2(200)

)';
        END IF;
    END;

    BEGIN
        SELECT
            COUNT(*)
        INTO l_cr_preload_status
        FROM
            all_tables
        WHERE
            table_name = 'CR_PRELOAD_CLD_SETUP_STATUS';

        IF l_cr_preload_status = 0 THEN
            EXECUTE IMMEDIATE '
           CREATE TABLE CR_PRELOAD_CLD_SETUP_STATUS 
   (	SETUP_ID NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	PROJECT_ID NUMBER, 
	OBJECT_ID NUMBER, 
	CLD_METADATA_TABLE_NAME VARCHAR2(50) , 
	CLD_TEMPLATE_NAME VARCHAR2(50) , 
	CLD_TEMPLATE_CODE VARCHAR2(50) , 
	CLD_STAGING_TABLE_NAME VARCHAR2(100) , 
	VAL_SYNC_TABLES VARCHAR2(4000) , 
	VAL_PKG_EXECUTION VARCHAR2(4000) , 
	CLD_SETUP_STATUS VARCHAR2(200) , 
	CLD_SETUP_ERROR_MESSAGE VARCHAR2(4000) , 
	VAL_PKG_STATUS VARCHAR2(200) , 
	VAL_PKG_ERROR_MESSAGE VARCHAR2(4000) , 
	ATTRIBUTE1 VARCHAR2(150) , 
	ATTRIBUTE2 VARCHAR2(150) , 
	ATTRIBUTE3 VARCHAR2(150) , 
	ATTRIBUTE4 VARCHAR2(150) , 
	ATTRIBUTE5 VARCHAR2(150) , 
	CREATION_DATE DATE NOT NULL ENABLE, 
	CREATED_BY VARCHAR2(200)  NOT NULL ENABLE, 
	LAST_UPDATE_DATE DATE NOT NULL ENABLE, 
	LAST_UPDATED_BY VARCHAR2(200)  NOT NULL ENABLE
  )';
        END IF;
    END;

    BEGIN
        SELECT
            COUNT(*)
        INTO l_async_process_status
        FROM
            all_tab_columns
        WHERE
                table_name = 'CR_ASYNC_PROCESS_STATUS'
            AND column_name = 'BATCH_NAME';

        IF l_async_process_status = 0 THEN
            EXECUTE IMMEDIATE ' ALTER TABLE CR_ASYNC_PROCESS_STATUS ADD BATCH_NAME VARCHAR2(300)';
        END IF;
    END;

    BEGIN
        SELECT
            COUNT(*)
        INTO l_bank_err_cld_template
        FROM
            all_tab_columns
        WHERE
                table_name = 'CR_CREATE_BANK_ACCOUNT_ERRORS'
            AND column_name = 'CLOUD_TEMPLATE_ID';

        IF l_bank_err_cld_template = 0 THEN
            EXECUTE IMMEDIATE ' ALTER TABLE CR_CREATE_BANK_ACCOUNT_ERRORS ADD cloud_template_id NUMBER';
        END IF;
    END;

    BEGIN
        SELECT
            COUNT(1)
        INTO l_cr_proj_activities
        FROM
            all_tab_columns
        WHERE
                table_name = 'CR_PROJ_ACTIVITIES'
            AND column_name = 'TASK_NAME'
            AND data_length = 200;

        IF l_cr_proj_activities = 0 THEN
            EXECUTE IMMEDIATE 'ALTER TABLE CR_PROJ_ACTIVITIES MODIFY (TASK_NAME VARCHAR2(200))';
        END IF;
    END;

    BEGIN
        SELECT
            COUNT(*)
        INTO l_indx_formula1
        FROM
            user_indexes
        WHERE
                table_name = 'CR_FORMULA_SETS'
            AND index_name = 'CR_FORMULA_SET_U1';

        IF l_indx_formula1 = 0 THEN
            EXECUTE IMMEDIATE 'CREATE UNIQUE INDEX CR_FORMULA_SET_U1  ON cr_formula_sets (FORMULA_SET_NAME)';
        END IF;
    END;

    BEGIN
        SELECT
            COUNT(*)
        INTO l_indx_formula2
        FROM
            user_indexes
        WHERE
                table_name = 'CR_FORMULA_SETS'
            AND index_name = 'CR_FORMULA_SET_U2';

        IF l_indx_formula2 = 0 THEN
            EXECUTE IMMEDIATE 'CREATE UNIQUE INDEX CR_FORMULA_SET_U2  ON cr_formula_sets (FORMULA_SET_CODE)';
        END IF;
    END;

    BEGIN
        SELECT
            COUNT(*)
        INTO l_bank_err_cld_status
        FROM
            all_tab_columns
        WHERE
                table_name = 'CR_CREATE_BANK_ACCOUNT_ERRORS'
            AND column_name = 'STATUS';

        IF l_bank_err_cld_status = 0 THEN
            EXECUTE IMMEDIATE ' ALTER TABLE CR_CREATE_BANK_ACCOUNT_ERRORS ADD STATUS VARCHAR2(240)';
        END IF;
    END;

    BEGIN
        SELECT
            COUNT(*)
        INTO l_bank_branch_cld_template
        FROM
            all_tab_columns
        WHERE
                table_name = 'CR_CREATE_BANK_BRANCH_ERRORS'
            AND column_name = 'CLOUD_TEMPLATE_ID';

        IF l_bank_branch_cld_template = 0 THEN
            EXECUTE IMMEDIATE ' ALTER TABLE CR_CREATE_BANK_BRANCH_ERRORS ADD cloud_template_id NUMBER';
        END IF;
    END;

    BEGIN
        SELECT
            COUNT(*)
        INTO l_bank_branch_status
        FROM
            all_tab_columns
        WHERE
                table_name = 'CR_CREATE_BANK_BRANCH_ERRORS'
            AND column_name = 'STATUS';

        SELECT
            COUNT(*)
        INTO l_bank_country_name
        FROM
            all_tab_columns
        WHERE
                table_name = 'CR_CREATE_BANK_BRANCH_ERRORS'
            AND column_name = 'COUNTRY_NAME';

        IF l_bank_branch_status = 0 THEN
            EXECUTE IMMEDIATE ' ALTER TABLE CR_CREATE_BANK_BRANCH_ERRORS ADD STATUS VARCHAR2(240)';
        END IF;
        IF l_bank_country_name = 0 THEN
            EXECUTE IMMEDIATE 'ALTER TABLE CR_CREATE_BANK_BRANCH_ERRORS ADD COUNTRY_NAME VARCHAR2(300)';
        END IF;
    END;

    BEGIN
        SELECT
            COUNT(*)
        INTO l_cr_ebs_connection_details_count
        FROM
            all_tab_columns
        WHERE
                table_name = 'CR_EBS_CONNECTION_DETAILS'
            AND column_name = 'CONNECTION_TYPE';

        IF l_cr_ebs_connection_details_count = 0 THEN
            EXECUTE IMMEDIATE ' ALTER TABLE CR_EBS_CONNECTION_DETAILS ADD CONNECTION_TYPE VARCHAR2(255)';
        END IF;
    END;

    BEGIN
        SELECT
            COUNT(*)
        INTO l_cr_sqlextraction_bind_var_dtls_count
        FROM
            all_tab_columns
        WHERE
            table_name = 'CR_SQLEXTRACTION_BIND_VAR_DTLS';

        IF l_cr_sqlextraction_bind_var_dtls_count = 0 THEN
            EXECUTE IMMEDIATE '
                CREATE TABLE CR_SQLEXTRACTION_BIND_VAR_DTLS 
   (	BIND_VARIABLE_ID NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	MODULE VARCHAR2(100 BYTE) , 
	PARENT_OBJECT_ID NUMBER, 
	OBJECT_ID NUMBER, 
	TEMPLATE_NAME VARCHAR2(100 BYTE) , 
	CLD_TEMPLATE_ID NUMBER, 
	SRC_TEMPLATE_ID NUMBER, 
	BATCH_NAME VARCHAR2(100 BYTE) , 
	BIND_VARIABLE VARCHAR2(100 BYTE) , 
	BIND_VARIABLE_VALUE VARCHAR2(100 BYTE) , 
	BIND_WHERE_CLOB CLOB , 
	ATTRIBUTE1 VARCHAR2(100 BYTE) , 
	ATTRIBUTE2 VARCHAR2(100 BYTE) , 
	ATTRIBUTE3 VARCHAR2(100 BYTE) , 
	ATTRIBUTE4 VARCHAR2(100 BYTE) , 
	ATTRIBUTE5 VARCHAR2(100 BYTE) , 
	CREATED_BY VARCHAR2(50 BYTE) , 
	CREATION_DATE DATE, 
	LAST_UPDATED_BY VARCHAR2(50 BYTE) , 
	LAST_UPDATE_DATE DATE
   )';
        END IF;
    END;

    BEGIN
        SELECT
            COUNT(*)
        INTO l_cr_query_bind_var_cols_count
        FROM
            all_tab_columns
        WHERE
            table_name = 'CR_QUERY_BIND_VAR_COLS';

        IF l_cr_query_bind_var_cols_count = 0 THEN
            EXECUTE IMMEDIATE ' CREATE TABLE CR_QUERY_BIND_VAR_COLS 
   (	OBJECT_ID NUMBER, 
	BIND_VAR_COL_NAME VARCHAR2(240 BYTE)
   )';
        END IF;
    END;

END;

$#$
