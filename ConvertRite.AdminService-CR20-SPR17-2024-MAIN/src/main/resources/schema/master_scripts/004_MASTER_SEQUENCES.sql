DECLARE
    l_copy_seq_count NUMBER;
BEGIN
    -- Check if the sequence exists
    SELECT
        COUNT(*)
    INTO l_copy_seq_count
    FROM
        all_objects
    WHERE
        object_name = 'CR_COPY_ID_SEQ'
        And Object_type='SEQUENCE';
       -- and owner = 'MASTER';
        dbms_output.put_line('l_copy_seq_count: '||l_copy_seq_count);
        
    IF l_copy_seq_count = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE SEQUENCE CR_COPY_ID_SEQ START WITH 1 INCREMENT BY 1 MINVALUE 1 ';
            dbms_output.put_line('DOne: ');
    END IF;
END;
$#$
