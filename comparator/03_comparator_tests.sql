-- 03_comparator_tests.sql
-- Testy lokalne pakietu comparator_pkg

SET SERVEROUTPUT ON;

PROMPT *** CZYSZCZENIE TMP TABEL ***
DELETE FROM tmp_fact_history_compare_status;
DELETE FROM tmp_fact_history_compare_diff;
COMMIT;

PROMPT *** TEST 1: Tylko statusy (Zadanie 1) ***
BEGIN
    comparator_pkg.compare_fact(
        id_pack_old => 1,
        id_pack_new => 2,
        build_diff  => FALSE
    );
END;
/

PROMPT *** WYNIKI: TMP_FACT_HISTORY_COMPARE_STATUS ***
SELECT * FROM tmp_fact_history_compare_status
ORDER BY id_fact;

PROMPT *** TEST 2: Statusy + szczegóły (Zadanie 2) ***
DELETE FROM tmp_fact_history_compare_status;
DELETE FROM tmp_fact_history_compare_diff;
COMMIT;

BEGIN
    comparator_pkg.compare_fact(
        id_pack_old => 1,
        id_pack_new => 2,
        build_diff  => TRUE
    );
END;
/

PROMPT *** WYNIKI: TMP_FACT_HISTORY_COMPARE_STATUS ***
SELECT * FROM tmp_fact_history_compare_status
ORDER BY id_fact;

PROMPT *** WYNIKI: TMP_FACT_HISTORY_COMPARE_DIFF ***
SELECT * FROM tmp_fact_history_compare_diff
ORDER BY id_fact, col_name;

