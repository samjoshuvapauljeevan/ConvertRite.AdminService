---------functions
create or replace FUNCTION convert_to_yyyy_mm_dd (
    input_date IN VARCHAR2
) RETURN VARCHAR2 IS

    output_date VARCHAR2(10);
    invalid_date EXCEPTION;

    FUNCTION try_parse_date (
        date_string IN VARCHAR2,
        date_format IN VARCHAR2
    ) RETURN DATE IS
        parsed_date DATE;
    BEGIN
        BEGIN
            parsed_date := TO_DATE ( date_string,
                                     date_format );
            RETURN parsed_date;
        EXCEPTION
            WHEN OTHERS THEN
                RETURN NULL;
        END;
    END;

BEGIN
    IF input_date IS NULL THEN
        RETURN NULL;
    END IF;
    
    IF try_parse_date(input_date, 'YYYY-MM-DD') IS NOT NULL THEN
        output_date := to_char(
            try_parse_date(input_date, 'YYYY-MM-DD'),
            'YYYY/MM/DD'
        );
    ELSIF try_parse_date(input_date, 'DD-MON-YYYY') IS NOT NULL THEN
        output_date := to_char(
            try_parse_date(input_date, 'DD-MON-YYYY'),
            'YYYY/MM/DD'
        );
    ELSIF try_parse_date(input_date, 'MM/DD/YYYY') IS NOT NULL THEN
        output_date := to_char(
            try_parse_date(input_date, 'MM/DD/YYYY'),
            'YYYY/MM/DD'
        );
    ELSIF try_parse_date(input_date, 'DD/MM/YYYY') IS NOT NULL THEN
        output_date := to_char(
            try_parse_date(input_date, 'DD/MM/YYYY'),
            'YYYY/MM/DD'
        );
    ELSIF try_parse_date(input_date, 'DD-MM-YY') IS NOT NULL THEN
        output_date := to_char(
            try_parse_date(input_date, 'DD-MM-YY'),
            'YYYY/MM/DD'
        );
    ELSIF try_parse_date(input_date, 'DD-MM-YYYY HH24:MI:SS') IS NOT NULL THEN
        output_date := to_char(
            try_parse_date(input_date, 'DD-MM-YYYY HH24:MI:SS'),
            'YYYY/MM/DD'
        );
    ELSIF try_parse_date(input_date, 'DD-MM-YYYY HH24:MI') IS NOT NULL THEN
        output_date := to_char(
            try_parse_date(input_date, 'DD-MM-YYYY HH24:MI'),
            'YYYY/MM/DD'
        );
    ELSE
        RAISE invalid_date;
    END IF;

    RETURN output_date;
EXCEPTION
    WHEN invalid_date THEN
        RETURN 'Invalid Date Format';
    WHEN OTHERS THEN
        RETURN 'Error';
END convert_to_yyyy_mm_dd;

$#$
