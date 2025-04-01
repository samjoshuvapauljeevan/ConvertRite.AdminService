
create or replace PACKAGE "CR_TRANSFORM_UTILS_PKG" AS
    TYPE varchartab IS
        TABLE OF VARCHAR2(2000);
    TYPE numtab IS
        TABLE OF NUMBER;
    FUNCTION raise_exception RETURN VARCHAR2;

    FUNCTION raise_exception (
        p_cloud_column IN VARCHAR2
    ) RETURN VARCHAR2;
    end;
	$#$

create or replace PACKAGE BODY "CR_TRANSFORM_UTILS_PKG" AS
      FUNCTION raise_exception RETURN VARCHAR2 IS
    BEGIN
        RAISE case_not_found;
    END raise_exception;

    FUNCTION raise_exception (
        p_cloud_column IN VARCHAR2
    ) RETURN VARCHAR2 IS
    BEGIN
        raise_application_error(-20001, ' Error :' || p_cloud_column,TRUE);
      -- return  ('No valid Mapping for ' || p_cloud_column);
    END raise_exception;
    END;
		$#$