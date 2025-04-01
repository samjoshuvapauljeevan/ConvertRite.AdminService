CREATE OR REPLACE TYPE CR_TRANSFORM_STATS_TYPE AS OBJECT (
    cloud_template_id    NUMBER,
    cloud_template_name  VARCHAR2(2000),
    project_id           NUMBER,
    project              VARCHAR2(2000),
    parent_object_id     NUMBER,
    parent_object_code   VARCHAR2(2000),
    object_id            NUMBER,
    object               VARCHAR2(2000),
    src_stg_table_name   VARCHAR2(2000),
    cld_stg_table_name   VARCHAR2(2000),
    total_source_records NUMBER,
    total_cloud_records  NUMBER,
    validation_failed    NUMBER,
    validation_passed    NUMBER,
    source_unverfied     NUMBER,
    vs_trans_rec         NUMBER,
    vs_untrans_rec       NUMBER,
    vf_trans_rec         NUMBER,
    vf_untrans_rec       NUMBER,
    cloud_unkown_records NUMBER,
    total_untrans_rec    NUMBER,
    cloud_int_rej_rec    NUMBER,
    cloud_success_rec    NUMBER,
    cr_batch_name        VARCHAR2(420),
    LOAD_REQUEST_ID      VARCHAR2(240)
)
$#$

CREATE OR REPLACE TYPE CR_TRANSFORM_STATS_TYPE_TAB
IS
  TABLE OF CR_TRANSFORM_STATS_TYPE
$#$