CREATE OR REPLACE VIEW cr_src_template_hdrs_v AS
    SELECT
        th.src_template_id,
        src_template_code,
        src_template_name,
        th.project_id,
        cp.project_name,
        th.parent_object_id,
        po.object_name parent_object_name,
        th.object_id,
        co.object_name object_name,
	co.module_name,
        th.metadata_table_id,
        st.table_name  metadata_table_name,
        th.staging_table_name,
        th.view_name,
        th.normalize_data_flag,
        th.attribute1,
        th.attribute2,
        th.attribute3,
        th.attribute4,
        th.attribute5,
        th.last_updated_by,
        th.last_update_date,
        th.creation_date,
        th.created_by
    FROM
        cr_src_template_hdrs th,
        cr_projects          cp,
        cr_project_objects   po,
        cr_project_objects   co,
        cr_source_tables     st
    WHERE
            1 = 1 
        AND cp.project_id = th.project_id
        AND po.project_id = cp.project_id
        AND po.object_id = th.parent_object_id
        AND co.project_id = cp.project_id
        AND co.object_id = th.object_id
        AND st.table_id = th.metadata_table_id
$#$

CREATE OR REPLACE VIEW CR_CLD_TEMPLATE_HDRS_V AS
    SELECT
        cth.cld_template_id,
        cld_template_code,
        cld_template_name,
        cloud_version,
        cth.project_id,
        cp.project_name,
        cth.parent_object_id,
        po.object_name parent_object_name,
        cth.object_id,
        co.object_name object_name,
	co.module_name,
        cth.metadata_table_id,
        ct.table_name  metadata_table_name,
        cth.src_template_id,
        sth.src_template_name source_template_name,
        cth.staging_table_name,
        cth.view_name,
        cth.primary_template_flag,
        cth.attribute1,
        cth.attribute2,
        cth.attribute3,
        cth.attribute4,
        cth.attribute5,
        cth.last_updated_by,
        cth.last_update_date,
        cth.creation_date,
        cth.created_by
    FROM
        cr_cld_template_hdrs cth,
        cr_projects          cp,
        cr_project_objects   po,
        cr_project_objects   co,
        cr_cloud_tables      ct,
        cr_src_template_hdrs sth
    WHERE
            1 = 1
        AND cp.project_id = cth.project_id
        AND po.project_id = cp.project_id
        AND po.object_id = cth.parent_object_id
        AND co.project_id = cp.project_id
        AND co.object_id = cth.object_id
        AND ct.table_id (+) = cth.metadata_table_id
        AND sth.src_template_id (+) = cth.src_template_id
$#$

CREATE OR REPLACE FORCE VIEW CR_FBDI_HDRS_VIEW AS
    SELECT
        fbdi.fbdi_template_id,
        fbdi.fbdi_template_name,
        fbdi.project_id,
        proj.project_name,
        fbdi.parent_object_id  parent_object_id,
        parent_obj.object_name parent_object_name,
        fbdi.object_id         object_id,
        obj.object_name        object_name,
	obj.module_name,
        fbdi.sheet_name,
        fbdi.api,
        fbdi.cloud_version
    FROM
        cr_fbdi_template_hdrs fbdi,
        cr_projects           proj,
        cr_project_objects    parent_obj,
        cr_project_objects    obj
    WHERE
            fbdi.project_id = proj.project_id
        AND fbdi.parent_object_id = parent_obj.object_id
        AND fbdi.object_id = obj.object_id
        AND fbdi.project_id = parent_obj.project_id
        AND fbdi.project_id = obj.project_id
$#$

CREATE OR REPLACE VIEW CR_OBJECT_GROUP_HDRS_V AS
    select
        hdrs.group_id,
        hdrs.group_name,
        hdrs.group_code,
        hdrs.project_id,cp.project_name,
        hdrs.parent_object_id,
        cpo.object_name parent_object_name,
	cpo.module_name,
        hdrs.description,
        hdrs.attribute1,
        hdrs.attribute2,
        hdrs.attribute3,
        hdrs.attribute4,
        hdrs.attribute5,
        hdrs.creation_date,
        hdrs.created_by,
        hdrs.last_update_date,
        hdrs.last_updated_by
    from CR_OBJECT_GROUP_HDRS hdrs, cr_project_objects cpo,cr_projects cp
    where hdrs.project_id = cp.project_id
    AND hdrs.project_id = cpo.project_id
    AND hdrs.parent_object_id = cpo.object_id
$#$

CREATE OR REPLACE VIEW CR_OBJECT_GROUP_LINES_V AS
    select
        lines. obj_grp_line_id,
        lines.group_id,
        lines.object_id,
        cpo.object_name,
	cpo.module_name,
        lines.sequence,
        lines.attribute1,
        lines.attribute2,
        lines.attribute3,
        lines.attribute4,
        lines.attribute5,
        lines.creation_date,
        lines.created_by,
        lines.last_update_date,
        lines.last_updated_by
    from cr_object_group_lines lines, cr_project_objects cpo, CR_OBJECT_GROUP_HDRS hdrs
    where lines.group_id = hdrs.group_id
    AND hdrs.project_id = cpo.project_id
    AND lines.object_id = cpo.object_id
$#$
	
CREATE OR REPLACE VIEW CR_PROCESS_REQUESTS_V AS
    SELECT
        cprj.request_id,
        cprj.cld_template_id,
        cld_hdrs.cld_template_name,
        cprj.request_type,
        cprj.status,
        cprj.total_records,
        cprj.completed_percentage,
        cprj.start_date,
        cprj.end_date,
        cprj.err_msg,
        cprj.user_id,
        cprj.cr_batch_name,
        cprj.success_rec,
        cprj.fail_rec,
        cprj.percentage,
        cpo.object_name parent_object_code,
	cpo.module_name
    FROM
        (
            SELECT
                req.request_id,
                req.cld_template_id,
                req.request_type,
                req.status,
                req.total_records,
                req.completed_percentage,
                req.start_date,
                req.end_date,
                req.err_msg,
                req.user_id,
                req.cr_batch_name,
                SUM(j.success_records) success_rec,
                SUM(j.failure_records) fail_rec,
                CASE
                    WHEN ( req.total_records = 0
                           OR SUM(j.success_records) IS NULL ) THEN
                        0
                    ELSE
                        round(((SUM(j.success_records) / req.total_records)) * 100)
                END                    AS percentage
            FROM
                cr_process_requests req,
                cr_process_jobs     j
            WHERE
                req.request_id = j.request_id
            GROUP BY
                req.request_id,
                req.cld_template_id,
                req.request_type,
                req.status,
                req.total_records,
                req.completed_percentage,
                req.start_date,
                req.end_date,
                req.err_msg,
                req.user_id,
                req.cr_batch_name
            ORDER BY
                req.request_id DESC
        )                    cprj,
        cr_cld_template_hdrs cld_hdrs,
        cr_project_objects   cpo
    WHERE
            cld_hdrs.cld_template_id = cprj.cld_template_id
        AND cpo.object_id = cld_hdrs.parent_object_id
        AND cpo.project_id = cld_hdrs.project_id
$#$

CREATE OR REPLACE VIEW CR_CLD_TRANSFORM_STATS_V AS
	SELECT
	    cloud_template_id,
	    cloud_template_name,
	    project_id,
	    project,
	    parent_object_id,
	    parent_object_code,
	    object_id,
	    object,
	    src_stg_table_name,
	    cld_stg_table_name,
	    total_source_records,
	    total_cloud_records,
	    validation_failed,
	    validation_passed,
	    source_unverfied,
	    vs_trans_rec,
	    vs_untrans_rec,
	    vf_trans_rec,
	    vf_untrans_rec,
	    cloud_unkown_records,
	    total_untrans_rec,
        cloud_int_rej_rec,
        cloud_success_rec,
		cr_batch_name,
		load_request_id
FROM
    TABLE ( cr_fetch_transform_stats_func )
$#$

CREATE OR REPLACE VIEW CR_TEMPLATE_STATISTICS_V AS
    SELECT
        cloud_template_id                                                 criteria_id,
        cloud_template_name                                               criteria_name,
        'TEMPLATE'                                                        criteria_type,
        total_cloud_records                                               success,
        ( total_source_records - source_unverfied ) - total_cloud_records failed,
        source_unverfied                                                  unverified
    FROM
        cr_cld_transform_stats_v
    UNION ALL
    SELECT
        project_id,
        project,
        'PROJECT',
        SUM(total_cloud_records)                                             success,
        SUM((total_source_records - source_unverfied) - total_cloud_records) failed,
        SUM(source_unverfied)                                                new
    FROM
        cr_cld_transform_stats_v
    GROUP BY
        project_id,
        project
    UNION ALL
    SELECT
        parent_object_id,
        parent_object_code,
        'PARENT_OBJECT_CODE',
        SUM(total_cloud_records)                                             success,
        SUM((total_source_records - source_unverfied) - total_cloud_records) failed,
        SUM(source_unverfied)                                                new
    FROM
        cr_cld_transform_stats_v
    GROUP BY
        parent_object_id,
        parent_object_code
    UNION ALL
    SELECT
        object_id,
        object,
        'OBJECT',
        SUM(total_cloud_records)                                             success,
        SUM((total_source_records - source_unverfied) - total_cloud_records) failed,
        SUM(source_unverfied)                                                new
    FROM
        cr_cld_transform_stats_v
    GROUP BY
        object_id,
        object
$#$

CREATE OR REPLACE VIEW CR_TEMPLATE_STATE_V
AS
SELECT
    cld.cld_template_id,
    cld.cld_template_name,
    cld_hdrs_v.project_id,
    cld_hdrs_v.project_name,
    cld_hdrs_v.parent_object_id,
    cld_hdrs_v.parent_object_name,
    cld_hdrs_v.object_id,
    cld_hdrs_v.object_name,
	cld_hdrs_v.module_name,
    cld_hdrs_v.metadata_table_id,
    cld_hdrs_v.metadata_table_name,
    cld_hdrs_v.src_template_id,
    cld_hdrs_v.source_template_name,
    cld_hdrs_v.staging_table_name,
    CASE
        WHEN MIN(cld.src_template_id) IS NULL THEN
            'N'
        ELSE
            'Y'
    END validation,
    CASE
        WHEN MIN(req.request_type) IN ( 'VALIDATION', 'CONVERSION' ) THEN
            'Y'
        ELSE
            'N'
    END reprocess,
    CASE
        WHEN MIN(req.request_type) IN ( 'VALIDATION', 'CONVERSION' ) THEN
            'Y'
        ELSE
            'N'
    END conversion,
    CASE
        WHEN MIN(req.request_type) = 'VALIDATION' THEN
            'Y'
        ELSE
            'N'
    END file_gen
FROM
    cr_cld_template_hdrs   cld,
    cr_process_requests    req,
    cr_cld_template_hdrs_v cld_hdrs_v
WHERE
        cld.cld_template_id = req.cld_template_id (+)
    AND cld_hdrs_v.cld_template_id = cld.cld_template_id
GROUP BY
    cld.cld_template_name,
    cld.cld_template_id,
    cld_hdrs_v.project_id,
    cld_hdrs_v.project_name,
    cld_hdrs_v.parent_object_id,
    cld_hdrs_v.parent_object_name,
    cld_hdrs_v.object_id,
    cld_hdrs_v.object_name,
    cld_hdrs_v.metadata_table_id,
    cld_hdrs_v.metadata_table_name,
    cld_hdrs_v.src_template_id,
    cld_hdrs_v.source_template_name,
    cld_hdrs_v.staging_table_name,
    cld_hdrs_v.module_name
$#$

