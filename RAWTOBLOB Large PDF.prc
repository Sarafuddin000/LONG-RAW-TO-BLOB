CREATE OR REPLACE PROCEDURE RAWTOBLOB(p_slno VARCHAR2) IS
--    declare    
--    p_slno varchar2(20) := '2008110088';
--    p_main_table varchar2(200) := 'DRUG_INCLU_APP_DOC'  ----REPLACE WITH TABLE THAT CONTAIN LONGRAW AND CREATE COLUMNNAMEBLOB BLOB Column if not exists
--    p_temp_table varchar2(200) := 'DRUG_INCLU_APP_DOCLONG2LOBTMP'
    v_blob       BLOB := NULL;
    v_raw        RAW(16000) := NULL; -- Chunk size to read from BLOB
    v_start      PLS_INTEGER := 1;
    v_chunk      PLS_INTEGER := 16000; -- Adjusted chunk size
    v_length     PLS_INTEGER := 0;
    v_hex        VARCHAR2(32767) := NULL; -- Double the chunk size to hold the hex representation
    start_pos    PLS_INTEGER := 0;
    end_pos      PLS_INTEGER := 0;
    v_strt       NUMBER := 0;
    vfullhex     CLOB := NULL;
    VCBLOB       BLOB := NULL;
    pdf_start_pos PLS_INTEGER := 0;
    pdf_end_pos  PLS_INTEGER := 0;
    ERR_SL VARCHAR2(500) := NULL;
BEGIN
    dbms_lob.createtemporary(vfullhex, true);
    dbms_lob.createtemporary(VCBLOB, true);

    -- Retrieve the BLOB
    SELECT APPRV_LETTER INTO v_blob FROM DRUG_INCLU_APP_DOCLONG2LOBTMP WHERE SLNO = p_slno;
    v_length := DBMS_LOB.GETLENGTH(v_blob);

    -- Loop through the BLOB to find the positions
    WHILE v_start <= v_length LOOP
        v_raw := DBMS_LOB.SUBSTR(v_blob, v_chunk, v_start);
        v_hex := RAWTOHEX(v_raw);
        
        IF v_strt = 0 THEN
            start_pos := INSTR(v_hex, '25504446'); -- '%PDF' in hex
            IF start_pos > 0 THEN
                pdf_start_pos := (v_start - 1) * 2 + start_pos; -- Absolute position in hex
                v_strt := 1;
            END IF;
        END IF;
        
        IF v_strt = 1 THEN
            end_pos := INSTR(v_hex, '25454F46', -1); -- Last '%%EOF' in hex
            IF end_pos > 0 THEN
                pdf_end_pos := (v_start - 1) * 2 + end_pos + 6; -- Absolute position in hex, include length of '%%EOF'
            END IF;
        END IF;

        v_start := v_start + v_chunk;
    END LOOP;
    
    
    -----Position 0 means the file might not be a PDF or there are error in file
    IF pdf_start_pos = 0 OR pdf_end_pos = 0 THEN
        ERR_SL := ERR_SL ||', ' || p_slno;
    END IF;

    pdf_start_pos := (pdf_start_pos + 1) / 2; -- Convert to byte position
    pdf_end_pos := (pdf_end_pos + 1) / 2;     -- Convert to byte position

    -- Extract the BLOB content from pdf_start_pos to pdf_end_pos
    v_start := pdf_start_pos;
    WHILE v_start <= pdf_end_pos LOOP
        v_chunk := LEAST(16000, pdf_end_pos - v_start + 1);
        v_raw := DBMS_LOB.SUBSTR(v_blob, v_chunk, v_start);
        DBMS_LOB.APPEND(VCBLOB, v_raw);
        v_start := v_start + v_chunk;
    END LOOP;

    -- Use VCBLOB as needed (e.g., insert/update into another table)
    UPDATE DRUG_INCLU_APP_DOC SET APPRV_LETTER_Blob = VCBLOB WHERE SLNO = p_slno;
COMMIT;
    -- Free temporary BLOBs
    DBMS_LOB.FREETEMPORARY(vfullhex);
    DBMS_LOB.FREETEMPORARY(VCBLOB);

--    DBMS_OUTPUT.PUT_LINE('Extraction and conversion successful.');
    
    
    IF LENGTH(ERR_SL) > 1  THEN  ----IF there are unsucclessfull conversion
        DBMS_OUTPUT.PUT_LINE('Error on: '||ERR_SL);
    ELSE NULL; END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        IF DBMS_LOB.ISOPEN(vfullhex) = 1 THEN
            DBMS_LOB.CLOSE(vfullhex);
        END IF;
        IF DBMS_LOB.ISOPEN(VCBLOB) = 1 THEN
            DBMS_LOB.CLOSE(VCBLOB);
        END IF;
        RAISE;
END;
/




CREATE OR REPLACE PROCEDURE LOADLONGRAW
AS
BEGIN

   delete from  DRUG_INCLU_APP_DOCLONG2LOBtmp; 
commit;

    insert into DRUG_INCLU_APP_DOCLONG2LOBtmp (SLNO, APPRV_LETTER, APPRV_LETTER_BLOB)
    SELECT 
      SLNO, to_lob(APPRV_LETTER), APPRV_LETTER_BLOB
    FROM DRUG_INCLU_APP_DOC where APPRV_LETTER is not null;
commit;

 
  for i in ( SELECT SLNO FROM DRUG_INCLU_APP_DOCLONG2LOBtmp)
  LOOP
    RAWTOBLOB(i.SLNO);
  END LOOP;

  commit;

end;

exec LOADLONGRAW(); ---Execute for bulk in a table
--exec  RAWTOBLOB(p_SLNO); ---Execute for a sinlge slno


SELECT SLNO, LENGTH(APPRV_LETTER_BLOB) FROM DRUG_INCLU_APP_DOC WHERE to_number(LENGTH(nvl(APPRV_LETTER_BLOB,'30'))) < 500 ---30 in HEX equivalent to 0 in number

create table DRUG_INCLU_APP_DOC_260624 as select * from DRUG_INCLU_APP_DOC 
