/*
********************************************************************************************
* Project                 : ConvertRite
* Application             : ADMIN services
* Title                   : CREATE_TABLES
* Script Name             : CREATE_TABLES
* Description and Purpose : Script to create the master tables of convertRite in Postgres DB
* Created by              : sampaul.jeevan
* Change History          : 1.0
*===========================================================================================
* S.NO |    Date     |                 Reason                                		    |
*  1   |             | Intial                                                		    |
*  2   | 03-FEB-2025 | Combined all the upgrade scripts                      		    |
*  3   | 19-FEB-2025 |Added from upgrade 5.0 @sampaul.jeevan 19 FEB 2025   		    |
*===========================================================================================
*/


CREATE TABLE cr_admin_login (
	user_id serial4 NOT NULL,
	user_name varchar(150) NOT NULL,
	password varchar(400) NOT NULL,
	creation_date date NULL,
	created_by varchar(150) NULL,
	last_update_date date NULL,
	last_update_by varchar(150) NULL,
	CONSTRAINT cr_admin_login_pkey PRIMARY KEY (user_id)
);

CREATE TABLE cr_modules (
	module_id serial4 NOT NULL,
	module_name varchar(150) NULL,
	module_code varchar(150) NULL,
	user_module_name varchar(150) NULL,
	creation_date date NULL,
	created_by varchar(150) NULL,
	last_update_date date NULL,
	last_update_by varchar(150) NULL,
	CONSTRAINT cr_modules_pkey PRIMARY KEY (module_id)
);

CREATE TABLE cr_objects (
	object_id serial4 NOT NULL,
	object_name varchar(150) NULL,
	object_code varchar(150) NULL,
	user_object_name varchar(150) NULL,
	module_code varchar(150) NULL,
	parent_object_id int4 NULL,
	fbdi_sheet varchar(150) NULL,
	hdl_sheet varchar(150) NULL,
	loader_endpoint varchar(350) NULL,
	re_con_query text NULL,
	sequence_in_parent int4 NULL,
	interface_table_name varchar(150) NULL,
	rejection_table_name varchar(150) NULL,
	ctl_file_name varchar(150) NULL,
	xlsm_file_name varchar(150) NULL,
	immediate_parent varchar NULL,
	batch_size int4 NULL,
	base_tables varchar NULL,
	creation_date date NULL,
	created_by varchar(150) NULL,
	last_update_date date NULL,
	last_update_by varchar(150) NULL,
	--  added by sampaul.jeevan from UPD 1.0 START
	ATTRIBUTE1 VARCHAR(240),
	ATTRIBUTE2 VARCHAR(240),
	ATTRIBUTE3 VARCHAR(240),
	ATTRIBUTE4 VARCHAR(240),
	ATTRIBUTE5 VARCHAR(240),
	ATTRIBUTE6 VARCHAR(240),
	ATTRIBUTE7 VARCHAR(240),
	ATTRIBUTE8 VARCHAR(240),
	ATTRIBUTE9 VARCHAR(240),
	ATTRIBUTE10 VARCHAR(240),
	ATTRIBUTE11 VARCHAR(240),
	ATTRIBUTE12 VARCHAR(240),
	ATTRIBUTE13 VARCHAR(240),
	ATTRIBUTE14 VARCHAR(240),
	ATTRIBUTE15 VARCHAR(240),
	--  added by sampaul.jeevan from UPD 1.0 END
	CONVERSION_TYPE VARCHAR(255),--  added by sampaul.jeevan from UPD 2.0
	CLD_TEMPLATE_CODE VARCHAR(50),--  added by sampaul.jeevan from UPD 3.0, 4.0 --> varchar(430)to varchar(50)
	CLD_METADATA_TABLE_NAME VARCHAR(50),--  added by sampaul.jeevan from UPD 3.0, 4.0 --> varchar(430)to varchar(50)
	CLD_TEMPLATE_NAME VARCHAR(50),--  added by sampaul.jeevan from UPD 4.0
	CONSTRAINT cr_objects_pkey PRIMARY KEY (object_id)
);

CREATE TABLE cr_object_information (
    obj_info_id serial4 NOT NULL,
    object_id int4 NOT NULL,
    info_type varchar(250),
    info_value TEXT,
    info_description varchar(400),
    additional_information1 text NULL,
    additional_information2 text NULL,
    additional_information3 text NULL,
    additional_information4 text NULL,
    additional_information5 text NULL,
    creation_date date NULL,
    created_by varchar(150) NULL,
    last_update_date date NULL,
    last_update_by varchar(150) NULL,
	--  added by sampaul.jeevan from UPD 1.0 START
	ATTRIBUTE1 VARCHAR(240),
	ATTRIBUTE2 VARCHAR(240),
	ATTRIBUTE3 VARCHAR(240),
	ATTRIBUTE4 VARCHAR(240),
	ATTRIBUTE5 VARCHAR(240),
	ATTRIBUTE6 VARCHAR(240),
	ATTRIBUTE7 VARCHAR(240),
	ATTRIBUTE8 VARCHAR(240),
	ATTRIBUTE9 VARCHAR(240),
	ATTRIBUTE10 VARCHAR(240),
	ATTRIBUTE11 VARCHAR(240),
	ATTRIBUTE12 VARCHAR(240),
	ATTRIBUTE13 VARCHAR(240),
	ATTRIBUTE14 VARCHAR(240),
	ATTRIBUTE15 VARCHAR(240),
	--  added by sampaul.jeevan from UPD 1.0 END
    CONSTRAINT cr_object_information_object_id_fkey FOREIGN KEY (object_id) REFERENCES cr_objects(object_id)
);

CREATE TABLE cr_client_information (
	client_id serial4 NOT NULL,
	client_name varchar(300) NOT NULL,
	client_logo bytea NULL,
	client_logo_file_name varchar(50) NULL,
	client_logo_file_type varchar(25) NULL,
	creation_date date NULL,
	created_by varchar(150) NULL,
	last_update_date date NULL,
	last_update_by varchar(150) NULL,
	CONSTRAINT cr_client_information_pkey PRIMARY KEY (client_id)
);

CREATE TABLE cr_license_information (
	license_id serial4 NOT NULL,
	license_key varchar(200) NULL,
	pod_limit int4 NULL,
	project_limit varchar NULL,
	effective_start_date date NULL,
	effective_end_date date NULL,
	creation_date date NULL,
	created_by varchar(150) NULL,
	last_update_date date NULL,
	last_update_by varchar(150) NULL,
	Additional_Feature VARCHAR(500), -- Added from upgrade 5.0 @sampaul.jeevan 19 FEB 2025
	CONSTRAINT cr_license_information_license_key_key UNIQUE (license_key),
	CONSTRAINT cr_license_information_pkey PRIMARY KEY (license_id)
);

CREATE TABLE cr_licensed_objects (
    obj_license_link_id serial4 NOT NULL,
	object_id int4 NULL,
	license_id int4 NULL,
	creation_date date NULL,
	created_by varchar(150) NULL,
	last_update_date date NULL,
	last_update_by varchar(150) NULL,
	CONSTRAINT cr_licensed_objects_license_id_fkey FOREIGN KEY (license_id) REFERENCES cr_license_information(license_id),
	CONSTRAINT cr_licensed_objects_object_id_fkey FOREIGN KEY (object_id) REFERENCES cr_objects(object_id)
);

CREATE TABLE cr_client_license_links (
	client_license_link_id serial4 NOT NULL,
	client_id int4 NOT NULL,
	license_id int4 UNIQUE NOT NULL,
	creation_date date NULL,
	created_by varchar(150) NULL,
	last_update_date date NULL,
	last_update_by varchar(150) NULL,
	CONSTRAINT cr_client_license_links_pkey PRIMARY KEY (client_license_link_id)
);

CREATE TABLE cr_pod_information (
	pod_id serial4 NOT NULL,
	pod_name varchar(50) NULL,
	pod_db_host varchar(250) NULL,
	pod_db_user varchar(150) NULL,
	pod_db_password varchar(400) NULL,
	pod_tablespace_size varchar(10),
	pod_target_url varchar(500) NULL,
	pod_target_user varchar(150) NULL,
	pod_target_password varchar(150) NULL,
	license_id int4 NOT NULL,
	client_id int4 NOT NULL,
	creation_date date NULL,
	created_by varchar(150) NULL,
	last_update_date date NULL,
	last_update_by varchar(150) NULL,
	scheduled_job_flag VARCHAR(1) NOT NULL DEFAULT 'N', --  added by sampaul.jeevan from UPD 1.0
	CONSTRAINT cr_pod_information_pkey PRIMARY KEY (pod_id),
	CONSTRAINT cr_pod_information_license_id_fkey FOREIGN KEY (license_id) REFERENCES cr_license_information(license_id),
	CONSTRAINT cr_pod_information_name_key UNIQUE (pod_name, client_id)
);

CREATE TABLE cr_cloud_login_details (
	credential_id serial4 NOT NULL,
	client_id int4 NOT NULL,
	pod_id int4 NOT NULL,
	url varchar(500) NULL,
	module_code varchar(150) NULL,
	username varchar(150) NULL,
	password varchar(150) NULL,
	creation_date date NULL,
	created_by varchar(150) NULL,
	last_update_date date NULL,
	last_update_by varchar(150) NULL,
	CONSTRAINT cr_cloud_login_details_pkey PRIMARY KEY (credential_id)
);

CREATE TABLE cr_cloud_import_object_links (
	cloud_import_object_link_id serial4 NOT NULL,
	credential_id int4 NULL,
	object_id int4 NULL,
	creation_date date NULL,
	created_by varchar(150) NULL,
	last_update_date date NULL,
	last_update_by varchar(150) NULL,
	CONSTRAINT cr_cloud_import_object_links_pkey PRIMARY KEY (cloud_import_object_link_id)
);

CREATE TABLE cr_client_admin_information (
	client_admin_id serial4 NOT NULL,
	client_id int4 NULL,
	client_admin_name varchar(200) NULL,
	client_admin_user_name varchar(150) NULL,
	client_admin_password varchar(400) NULL,
	effective_start_date date NULL,
	effective_end_date date NULL,
	creation_date date NULL,
	created_by varchar(150) NULL,
	last_update_date date NULL,
	last_update_by varchar(150) NULL,
	is_first_time_login VARCHAR(255) NULL, --added by sampaul.jeevan from UPD 2.0
	CONSTRAINT cr_client_admin_information_pkey PRIMARY KEY (client_admin_id),
	CONSTRAINT cr_client_admin_information_name_key UNIQUE (client_admin_user_name),
	CONSTRAINT cr_client_admin_information_client_id_fkey FOREIGN KEY (client_id) REFERENCES cr_client_information(client_id)
);

CREATE TABLE cr_client_admin_pod_access (
    client_admin_pod_link serial4 NOT NULL,
	client_admin_id int4 NULL,
	pod_id int4 NULL,
	creation_date date NULL,
	created_by varchar(150) NULL,
	last_update_date date NULL,
	last_update_by varchar(150) NULL,
	CONSTRAINT cr_client_admin_pod_access_client_admin_id_fkey FOREIGN KEY (client_admin_id) REFERENCES cr_client_admin_information(client_admin_id),
	CONSTRAINT cr_client_admin_pod_access_pod_id_fkey FOREIGN KEY (pod_id) REFERENCES cr_pod_information(pod_id)
);

CREATE TABLE cr_object_customizations (
    customization_id serial4 NOT NULL,
    object_id int4 NOT NULL,
    client_id int4 NOT NULL,
    customization_type varchar(250) NULL,
    customization_text TEXT,
    description varchar(400),
    additional_information1 text NULL,
    additional_information2 text NULL,
    additional_information3 text NULL,
    additional_information4 text NULL,
    additional_information5 text NULL,
    creation_date date NULL,
    created_by varchar(150) NULL,
    last_update_date date NULL,
    last_update_by varchar(150) NULL
);

CREATE TABLE cr_master_db_information (
    master_db_credential_id serial4 NOT NULL,
	client_id int4 NOT NULL,
	license_id int4 NOT NULL,
	master_db_host varchar(250) NULL,
	master_db_user_name varchar(150) NULL,
	master_db_password varchar(400) NULL,
	creation_date date NULL,
	created_by varchar(150) NULL,
	last_update_date date NULL,
	last_update_by varchar(150) NULL,
	CONSTRAINT cr_master_db_information_client_id_fkey FOREIGN KEY (client_id) REFERENCES cr_client_information(client_id),
	CONSTRAINT cr_master_db_information_license_id_fkey FOREIGN KEY (license_id) REFERENCES cr_license_information(license_id)
);

CREATE TABLE cr_roles(
	role_id serial4 NOT NULL,
	role_name varchar(100),
	description varchar(400),
	pod_id int4 NOT NULL,
	client_id int4,
	creation_date date NULL,
	created_by varchar(150) NULL,
	last_update_date date NULL,
	last_update_by varchar(150) NULL,
	CONSTRAINT cr_roles_name_key UNIQUE (role_name, pod_id)
);

CREATE TABLE cr_role_obj_links(
	obj_role_link_id serial4 NOT NULL,
	object_id int4 NULL,
	role_id int4 NULL,
	creation_date date NULL,
	created_by varchar(150) NULL,
	last_update_date date NULL,
	last_update_by varchar(150) NULL
);

CREATE TABLE cr_users(
	user_id serial4 NOT NULL,
	user_name varchar(150),
	person_name varchar(200),
	password varchar(400),
	email varchar(200),
	user_login_type varchar(400),
	client_id int4 NOT NULL,
	creation_date date NULL,
	created_by varchar(150) NULL,
	last_update_date date NULL,
	last_update_by varchar(150) NULL,
	is_first_time_login VARCHAR(255),-- added by sampaul.jeevan from UPD 2.0
	CONSTRAINT cr_users_user_email_key UNIQUE (email)
);

CREATE TABLE cr_user_role_links(
	user_role_link_id serial4 NOT NULL,
	user_id int4 NOT NULL,
	role_id int4 NOT NULL,
	creation_date date NULL,
	created_by varchar(150) NULL,
	last_update_date date NULL,
	last_update_by varchar(150) NULL
);

CREATE TABLE cr_projects (
	project_id serial4 NOT NULL,
	client_id int4 NOT NULL,
	project_name varchar(250) NULL,
	project_code varchar(250) UNIQUE NOT NULL,
	pod_id int4 NOT NULL,
	creation_date date NULL,
	created_by varchar(150) NULL,
	last_update_date date NULL,
	last_update_by varchar(150) NULL,
	CONSTRAINT cr_projects_pkey PRIMARY KEY (project_id)
);

CREATE TABLE cr_project_objects (
	project_obj_link_id serial4 NOT NULL,
	project_id int4 NOT NULL,
	object_id int4 NOT NULL,
	creation_date date NULL,
	created_by varchar(150) NULL,
	last_update_date date NULL,
	last_update_by varchar(150) NULL,
	CONSTRAINT cr_project_objects_pkey PRIMARY KEY (project_obj_link_id)
);

CREATE TABLE cr_cloud_data_process (
	id serial4 NOT NULL,
	destination_type varchar(100) NULL,
    table_name varchar(250) NULL,
    batchsize int4 NULL,
    meta_data text NULL,
    sqlquery text NULL,
    pod_id int4 NULL,
    lookup_flag varchar(1) NULL,
    scheduled_job_call varchar(1) NULL,
    attribute1 varchar(150) NULL,
	attribute2 varchar(150) NULL,
	attribute3 varchar(150) NULL,
	attribute4 varchar(150) NULL,
	attribute5 varchar(150) NULL,
	creation_date timestamp NULL,  --Altered the type to timestamp from date by sampaul.jeevan from UPD 1.0
    created_by varchar(50) NULL,
    last_update_date timestamp NULL, --Altered the type to timestamp from date by sampaul.jeevan from UPD 1.0
    last_updated_by varchar(50) NULL
);

CREATE TABLE cr_cloud_status_information (
	status_id serial4 NOT NULL,
	request_id varchar(100) NULL,
	entity_id int4 NULL,
	status varchar(20) NULL,
	attribute1 TEXT,      --  Altered the type to TEXT from Varchar(150) by sampaul.jeevan from UPD 1.0
	attribute2 varchar(150) NULL,
	creation_date timestamp NULL, --Altered the type to timestamp from date by sampaul.jeevan from UPD 2.0
    created_by varchar(50) NULL,
    last_update_date timestamp NULL, --Altered the type to timestamp from date by sampaul.jeevan from UPD 2.0
	last_updated_by varchar(50) NULL,
	SYNC_TYPE VARCHAR(240), 			--  added by sampaul.jeevan from UPD 1.0
	ERROR_MESSAGE TEXT					--  added by sampaul.jeevan from UPD 1.0
);

CREATE
OR REPLACE VIEW public.cr_cloud_data_process_view  --  added by sampaul.jeevan from UPD 1.0
AS
SELECT ccdp.id,
       ccdp.sqlquery,
       ccdp.destination_type,
       ccdp.attribute1,
       ccdp.attribute2,
       ccdp.attribute3,
       ccdp.attribute4,
       ccdp.attribute5,
       ccdp.last_updated_by,
       ccdp.last_update_date,
       ccsi.creation_date,
       ccdp.created_by,
       ccdp.lookup_flag,
       ccdp.scheduled_job_call,
       ccdp.pod_id,
       ccdp.table_name,
       ccdp.meta_data,
       ccdp.batchsize,
       ccsi.request_id,
       ccsi.status,
       ccsi.status_id,
       ccsi.attribute1 AS status_error_msg,
	   ccsi.attribute2 AS sync_api_call --  added by sampaul.jeevan from UPD 2.0
FROM cr_cloud_data_process ccdp,
     cr_cloud_status_information ccsi
WHERE ccdp.id = ccsi.entity_id;

CREATE TABLE cr_sql_execution_log  --  added by sampaul.jeevan from UPD 1.0
(
    id            SERIAL PRIMARY KEY,
    client_id     INTEGER,
    pod_id        INTEGER,
    sql_file_path VARCHAR(255),
    created_time  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    success       BOOLEAN,
    CONSTRAINT fk_sql_execution_log_client
        FOREIGN KEY (client_id)
            REFERENCES cr_client_information (client_id),
    CONSTRAINT fk_sql_execution_log_pod
        FOREIGN KEY (pod_id)
            REFERENCES cr_pod_information (pod_id)
);

-- added by sampaul.jeevan from UPD 2.0
CREATE TABLE cr_data_sync_execution_log --  added by sampaul.jeevan from UPD 2.0
(
    sync_id            SERIAL PRIMARY KEY,
    client_id     INTEGER,
    pod_id        INTEGER,
    table_name    VARCHAR(150),
    creation_date  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    success       BOOLEAN,
    error_msg     TEXT
);	

-- added by sampaul.jeevan from UPD 2.0
CREATE TABLE cr_email_notifications (
	notification_id serial4 NOT NULL,
	to_email VARCHAR(255),
	from_email VARCHAR(255),
	subject VARCHAR(255),
	status VARCHAR(255),
	role VARCHAR(255),
	creation_date date,
	created_by VARCHAR(255),
	last_update_date date,
	last_updated_by VARCHAR(255)
);


CREATE OR REPLACE VIEW public.cr_object_information_view -- added by sampaul.jeevan from UPD 2.0
AS select coi.object_id  ,co.parent_object_id ,coi.info_value  from cr_object_information coi , cr_objects co  where
    coi.info_type ='Sequence'  and coi.object_id =co.object_id and coi.info_value <> '';

truncate table cr_master_db_information;-- added by sampaul.jeevan from UPD 3.0

CREATE TABLE CR_VALIDATION_OBJECTS ( -- added by sampaul.jeevan from UPD 4.0
    VAL_OBJECT_ID SERIAL PRIMARY KEY,
    VAL_OBJECT_SOURCE VARCHAR(50) NOT NULL DEFAULT 'INITIAL_SETUP',
    VAL_OBJECT_TYPE VARCHAR(59) NOT NULL,
    OBJECT_ID INTEGER REFERENCES cr_objects(object_id) NOT NULL,
    VAL_SYNC_TABLES VARCHAR(2000),
    VAL_OBJECT_NAME VARCHAR(255) NOT NULL UNIQUE,
    CREATED_BY VARCHAR(255) NOT NULL,
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_BY VARCHAR(255),
    UPDATED_AT TIMESTAMP
);

CREATE TABLE CR_VAL_PKG_EXEC_AUDIT ( -- added by sampaul.jeevan from UPD 4.0
    AUDIT_ID SERIAL PRIMARY KEY,
    OBJECT_ID INTEGER REFERENCES cr_objects(object_id),
    VAL_OBJECT_ID INTEGER REFERENCES CR_VALIDATION_OBJECTS(VAL_OBJECT_ID),
    POD_ID INTEGER NOT NULL,
    IS_SUCCESS BOOLEAN NOT NULL,
    ERROR_MESSAGE TEXT,
    CREATED_BY VARCHAR(255) NOT NULL,
    CREATION_DATE TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

create table cr_target_intf_column_list ( -- added by sampaul.jeevan from UPD 4.0
    column_list_id serial4 not null,
    target_system varchar(1000) null,
    target_system_version varchar(1000) null,
    object_id int4 not null,
    column_name varchar(1000) not null,
    physical_column_name varchar(1000) not null,
    user_column_name varchar(1000) not null,
    column_descrption varchar(1000) null,
    column_sequence varchar(1000) null,
    column_type varchar(1000) null,
    column_width varchar(1000) null,
    null_allowed_flag varchar(1000) null,
    translate_flag varchar(1) null,
    "precision" varchar(1000) null,
    "scale" varchar(1000) null,
    domain_code varchar(1000) null,
    denorm_path varchar(1000) null,
    routing_mode varchar(1000) null,
    cloud_version varchar(1000) null,
    eligible_to_be_secured varchar(1000) null,
    security_classification varchar(1000) null,
    sec_classification_override varchar(1000) null,
    attribute1 varchar(150) null,
    attribute2 varchar(150) null,
    attribute3 varchar(150) null,
    attribute4 varchar(150) null,
    attribute5 varchar(150) null,
    creation_date date not null,
    created_by varchar(200) not null,
    last_update_date date null,
    last_updated_by varchar(200) null,
    constraint cr_target_intf_column_list_pkey primary key (column_list_id)
);


-- added by sampaul.jeevan from UPD 4.0
Drop SEQUENCE CR_TARGET_INTF_COLUMN_LIST_COLUMN_LIST_ID_SEQ; -- Added as we are getting a error as it already exist
CREATE SEQUENCE CR_TARGET_INTF_COLUMN_LIST_COLUMN_LIST_ID_SEQ
    INCREMENT BY 1
    MINVALUE 1
    MAXVALUE 2147483647
    START 1
    CACHE 1
    NO CYCLE;

-- Added from upgrade 5.0 @sampaul.jeevan 19 FEB 2025
CREATE TABLE cr_rs_pod_information (
	pod_id serial4 NOT NULL,
	pod_name varchar(50),
	pod_db_host varchar(250),
	pod_db_user varchar(150),
	pod_db_password varchar(400),
	pod_tablespace_size varchar(10),
	pod_target_url varchar(500),
	pod_target_user varchar(150),
	pod_target_password varchar(150),
	license_id int4 NOT NULL,
	client_id int4 NOT NULL,
	creation_date date,
	created_by varchar(150),
	last_update_date date,
	last_update_by varchar(150),
	scheduled_job_flag varchar(1) DEFAULT 'N',
	CONSTRAINT cr_rs_pod_information_name_key UNIQUE (pod_name, client_id),
	CONSTRAINT cr_rs_pod_information_pkey PRIMARY KEY (pod_id),
	CONSTRAINT cr_rs_pod_information_license_id_fkey FOREIGN KEY (license_id) REFERENCES public.cr_license_information(license_id)
);

