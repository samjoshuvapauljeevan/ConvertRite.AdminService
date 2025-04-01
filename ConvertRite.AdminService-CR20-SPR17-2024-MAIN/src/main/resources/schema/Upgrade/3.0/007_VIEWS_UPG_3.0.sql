--views
CREATE OR REPLACE VIEW cr_cld_transform_stats_v  AS
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
        load_request_id,
        comments
    FROM
        cr_transform_stats
    WHERE
        LATEST_FLAG = 'Y'
$#$
create or replace view CR_PROCESS_REQUESTS_V as 
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
        cpo.object_name,
        cpo.parent_object_code,
        cpo.module_name,
        cjs.load_request_id,
        cjs.job_status,
        cjs.parameter_list,
        cjs.object_id,
        cjs.document_author,
        cjs.document_title,
        cjs.document_security_group,
        cjs.document_account,
        cjs.content_id,
        cjs.job_name,
        cjs.interface_id,
        cjs.job_status cloud_job_status,
        cjs.JOB_ERROR_MESSAGE Cloud_job_error_message,
        cjs.ADDITIONAL_INFO ADDITIONAL_INFO,
        cprj.cld_record_count cloud_record_count
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
                req.cld_record_count,
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
                req.cr_batch_name,
                req.cld_record_count
            ORDER BY
                req.request_id DESC
        )                    cprj,
        cr_cld_template_hdrs cld_hdrs,
        cr_project_objects   cpo,
        cr_cloud_job_status  cjs
    WHERE
            cld_hdrs.cld_template_id = cprj.cld_template_id
        AND cpo.object_id = cld_hdrs.parent_object_id
        AND cpo.project_id = cld_hdrs.project_id
        AND cprj.cld_template_id = cjs.cld_template_id (+)
        AND cprj.cr_batch_name = cjs.batch_name (+)
    ORDER BY
        cprj.request_id DESC
$#$

  CREATE OR REPLACE  VIEW CR_TEMPLATE_STATISTICS_V AS 
  SELECT
        cloud_template_id                                                 criteria_id,
        cloud_template_name                                               criteria_name,
        'TEMPLATE'                                                        criteria_type,
        total_cloud_records                                               success,
        ( total_source_records - source_unverfied ) - total_cloud_records failed,
      TO_NUMBER (source_unverfied)                                                  unverified
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
