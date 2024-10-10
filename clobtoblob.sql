DECLARE
    v_blob     BLOB;
    v_raw      RAW(16000); -- Smaller chunk size to avoid buffer overflow
    v_start    PLS_INTEGER := 1;
    v_chunk    PLS_INTEGER := 16000; -- Adjusted chunk size
    v_length   PLS_INTEGER;
    v_hex      VARCHAR2(32767); -- Double the chunk size to hold the hex representation
    start_pos  PLS_INTEGER;
    end_pos    PLS_INTEGER;
    v_strt number := 0;
    VPDF VARCHAR2(32767);
    vfullhex clob;
    VCBLOB BLOB;
    l_dest_offset PLS_INTEGER    := 1;
    l_src_offset PLS_INTEGER     := 1;
    l_lang_context PLS_INTEGER   := DBMS_LOB.default_lang_ctx;
    l_warning PLS_INTEGER        := DBMS_LOB.warn_inconvertible_char;
    
BEGIN
dbms_lob.createtemporary(vfullhex, true);
dbms_lob.createtemporary(VCBLOB, true);

    -- Retrieve the BLOB
    SELECT APPRV_LETTER INTO v_blob FROM DRUG_INCLU_APP_DOCLONG2LOB WHERE SLNO = '2008120097';
    v_length := DBMS_LOB.GETLENGTH(v_blob);
    
    -- Loop through the BLOB and convert to RAW in chunks
    WHILE v_start <= v_length LOOP
        v_raw := DBMS_LOB.SUBSTR(v_blob, v_chunk, v_start);
        
        -- Convert RAW to hexadecimal
        v_hex := v_raw;
         
        start_pos := INSTR(v_hex, '25504446');
        
        -- Output the hexadecimal representation
        IF v_strt = 0 and start_pos > 0 THEN
            VPDF := SUBSTR(v_hex,start_pos);
            v_strt := 1;
        ELSIF v_strt = 1 then  VPDF := v_hex;
        END IF;  
         
         
        end_pos := INSTR(VPDF, '25454F46') + 7;
        
        IF v_strt = 1 and end_pos > 7 THEN
            VPDF := SUBSTR(VPDF,0,end_pos);
            v_strt := 2;
        ELSIF v_strt = 2 then EXIT;
        END IF;  

        vfullhex := vfullhex ||vpdf;
--        DBMS_OUTPUT.PUT_LINE(length(vfullhex));
-- DBMS_OUTPUT.PUT_LINE(vpdf);
        v_start := v_start + v_chunk;
    END LOOP;

--DBMS_OUTPUT.PUT_LINE(length(vfullhex));

--vfullhex := utl_raw.cast_to_varchar2(hextoraw(vfullhex)));

update DRUG_INCLU_APP_DOCLONG2LOB set APPRV_LETTER_clob = vfullhex WHERE SLNO = '2008120097';

 DBMS_LOB.converttoblob (dest_lob       => VCblob,
                            src_clob       => vfullhex,
                            amount         => DBMS_LOB.lobmaxsize,
                            dest_offset    => l_dest_offset,
                            src_offset     => l_src_offset,
                            blob_csid      => DBMS_LOB.default_csid,
                            lang_context   => l_lang_context,
                            warning        => l_warning);
            DBMS_OUTPUT.PUT_LINE(length(vfullhex) ||' - ' || length(VCBLOB));

update DRUG_INCLU_APP_DOCLONG2LOB set APPRV_LETTER_Blob = VCBLOB WHERE SLNO = '2008120097';

        dbms_lob.freetemporary(vfullhex);
        dbms_lob.freetemporary(VCBLOB);

END;
/

------------------------------------------------------------------------------------------------------------

DECLARE
    v_blob       BLOB;
    v_raw        RAW(16000); -- Chunk size to read from BLOB
    v_start      PLS_INTEGER := 1;
    v_chunk      PLS_INTEGER := 16000; -- Adjusted chunk size
    v_length     PLS_INTEGER;
    v_hex        VARCHAR2(32767); -- Double the chunk size to hold the hex representation
    start_pos    PLS_INTEGER;
    end_pos      PLS_INTEGER;
    v_strt       NUMBER := 0;
    VPDF         RAW(32767);
    vfullhex     CLOB;
    VCBLOB       BLOB;
    pdf_start_pos PLS_INTEGER := 0;
    pdf_end_pos  PLS_INTEGER := 0;
BEGIN
    dbms_lob.createtemporary(vfullhex, true);
    dbms_lob.createtemporary(VCBLOB, true);

    -- Retrieve the BLOB
    SELECT APPRV_LETTER INTO v_blob FROM DRUG_INCLU_APP_DOCLONG2LOB WHERE SLNO = '2008120097';
    v_length := DBMS_LOB.GETLENGTH(v_blob);
    
    -- Loop through the BLOB and convert to RAW in chunks
    WHILE v_start <= v_length LOOP
        v_raw := DBMS_LOB.SUBSTR(v_blob, v_chunk, v_start);
        
        -- Convert RAW to hexadecimal for searching
        v_hex := RAWTOHEX(v_raw);
         
        IF v_strt = 0 THEN
            start_pos := INSTR(v_hex, '25504446'); -- '%PDF' in hex
            IF start_pos > 0 THEN
                pdf_start_pos := (start_pos + 1) / 2; -- Convert hex position to byte position
                v_strt := 1;
            END IF;
        END IF;
        
        IF v_strt = 1 THEN
            end_pos := INSTR(v_hex, '25454F46'); -- '%%EOF' in hex
            IF end_pos > 0 THEN
                pdf_end_pos := (end_pos + 8) / 2; -- Convert hex position to byte position and add length of '%%EOF'
                v_strt := 2;
            END IF;
        END IF;

        IF v_strt = 1 THEN
            IF pdf_start_pos > 0 THEN
                DBMS_LOB.APPEND(VCBLOB, DBMS_LOB.SUBSTR(v_blob, v_chunk - pdf_start_pos + 1, v_start + pdf_start_pos - 1));
                pdf_start_pos := 0; -- Reset after use
            ELSE
                DBMS_LOB.APPEND(VCBLOB, v_raw);
            END IF;
        ELSIF v_strt = 2 THEN
            IF pdf_end_pos > 0 THEN
                DBMS_LOB.APPEND(VCBLOB, DBMS_LOB.SUBSTR(v_blob, pdf_end_pos - pdf_start_pos + 1, v_start));
                EXIT;
            ELSE
                DBMS_LOB.APPEND(VCBLOB, v_raw);
            END IF;
        END IF;

        v_start := v_start + v_chunk;
    END LOOP;

    -- Use VCBLOB as needed (e.g., insert/update into another table)
update DRUG_INCLU_APP_DOCLONG2LOB set APPRV_LETTER_Blob = VCBLOB WHERE SLNO = '2008120097';
    -- Free temporary BLOBs
    DBMS_LOB.FREETEMPORARY(vfullhex);
    DBMS_LOB.FREETEMPORARY(VCBLOB);

    DBMS_OUTPUT.PUT_LINE('Extraction and conversion successful.');
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

