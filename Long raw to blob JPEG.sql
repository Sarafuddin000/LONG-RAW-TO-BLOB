
--Create a table to store converted raw as blob
CREATE TABLE PMIS_OHNL.PMIS_EMP_OTHERS_TMP
(
  EMP_CODE               VARCHAR2(10 BYTE)      NOT NULL,
  EMP_PIC_BLOB                BLOB,
  SLNO                   NUMBER
);


--Use an SLNO to limit and faster chunk by chunk process management
ALTER TABLE PMIS_OHNL.PMIS_EMP_OTHERS
ADD (SLNO NUMBER,
EMP_PIC_BLOB blob);


--Update SLNO increment by 1 to work like primary key
DECLARE
    CURSOR C1 IS SELECT EMP_CODE, SLNO FROM PMIS_OHNL.PMIS_EMP_OTHERS;
SLN NUMBER := 0;
BEGIN
    FOR I IN C1
    LOOP
        --update a serial number for curosr query
        SLN := SLN + 1;
        UPDATE PMIS_OHNL.PMIS_EMP_OTHERS
        SET SLNO = SLN
        WHERE EMP_CODE = I.EMP_CODE;
        COMMIT;
    END LOOP;
END;

--Make sure you have enough space in tablespace
select round(sum(dbms_lob.getlength(emp_pic_blob))/1024/1024) as MB
from PMIS_OHNL.PMIS_EMP_OTHERS_TMP;

-- Convert Long RAW into blob by inserting into temp table
DECLARE
    CURSOR C1 IS SELECT EMP_CODE, SLNO FROM PMIS_OHNL.PMIS_EMP_OTHERS WHERE SLNO BETWEEN 251 AND 500;
    
BEGIN
    FOR I IN C1
    LOOP

        INSERT INTO PMIS_OHNL.PMIS_EMP_OTHERS_TMP (EMP_CODE,EMP_PIC_BLOB,SLNO)
            SELECT EMP_CODE,
                   TO_LOB(EMP_PIC),
                   SLNO
              FROM PMIS_OHNL.PMIS_EMP_OTHERS
             WHERE EMP_CODE = I.EMP_CODE;

        COMMIT;
    END LOOP;
END;





--Copy converted blob into blob column of main table
DECLARE
    CURSOR C2 IS
        SELECT EMP_CODE, EMP_PIC_BLOB, SLNO
          FROM PMIS_OHNL.PMIS_EMP_OTHERS_TMP
         WHERE SLNO BETWEEN 1 AND 1000;
BEGIN
    FOR J IN C2
    LOOP
        UPDATE PMIS_OHNL.PMIS_EMP_OTHERS
           SET EMP_PIC_BLOB = J.EMP_PIC_BLOB
         WHERE EMP_CODE = J.EMP_CODE
         AND SLNO = J.SLNO;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE (J.EMP_CODE);
    END LOOP;
END;


--Run Count to cross check if there is any blob / raw misses by the process
--SELECT COUNT(1) FROM PMIS_EMP_OTHERS_TMP WHERE EMP_PIC IS NULL   	 2540
-- SELECT COUNT(1) FROM PMIS_EMP_OTHERS WHERE EMP_PIC IS NULL	   2540
