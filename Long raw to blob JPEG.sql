CREATE TABLE PMIS_OPL.PMIS_EMP_OTHERS_TMP
(
  EMP_CODE               VARCHAR2(10 BYTE)      NOT NULL,
  EMP_PIC_BLOB                blob,
  SLNO                   number
);

alter table PMIS_OPL.PMIS_EMP_OTHERS
add slno number;


DECLARE
    CURSOR c1 IS SELECT emp_code, slno FROM PMIS_OPL.PMIS_EMP_OTHERS;
sln number := 0;
BEGIN
    FOR i IN c1
    LOOP
        --update a serial number for curosr query
        sln := sln + 1;
        update PMIS_OPL.PMIS_EMP_OTHERS
        set slno = sln
        where emp_code = i.emp_code;
        commit;
    end loop;
end;


-- Convert Long RAW into blob by inserting into temp table
DECLARE
    CURSOR c1 IS SELECT emp_code, slno FROM PMIS_OPL.PMIS_EMP_OTHERS where slno between 20001 and 25000;
    
BEGIN
    FOR i IN c1
    LOOP

        INSERT INTO PMIS_OPL.PMIS_EMP_OTHERS_TMP (EMP_CODE,EMP_PIC_BLOB,SLNO)
            SELECT EMP_CODE,
                   TO_LOB(EMP_PIC),
                   SLNO
              FROM PMIS_OPL.PMIS_EMP_OTHERS
             WHERE emp_code = i.emp_code;

        COMMIT;
    END LOOP;
END;



--Copy converted blob into blob column of main table
DECLARE
    CURSOR c2 IS
        SELECT emp_code, EMP_PIC_BLOB
          FROM PMIS_OPL.PMIS_EMP_OTHERS_tmp
         WHERE slno BETWEEN 1 AND 1000;
BEGIN
    FOR j IN c2
    LOOP
        UPDATE PMIS_OPL.PMIS_EMP_OTHERS
           SET EMP_PIC_BLOB = j.EMP_PIC_BLOB
         WHERE emp_code = j.emp_code AND pic_ver = j.pic_ver;

        COMMIT;
        DBMS_OUTPUT.put_line (j.emp_code);
    END LOOP;
END;



--SELECT COUNT(1) FROM PMIS_EMP_OTHERS_TMP WHERE EMP_PIC IS NULL    2540