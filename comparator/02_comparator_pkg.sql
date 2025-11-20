-- 02_comparator_pkg.sql
-- PROJEKT COMPARATOR: Zadanie 1 + Zadanie 2
--
-- Założenia:
--  - istnieje tabela FACT_HISTORY (PK: ID_PACK, ID_FACT + kolumny danych),
--  - istnieją tabele tymczasowe:
--      TMP_FACT_HISTORY_COMPARE_STATUS (ID_FACT, STATUS)
--      TMP_FACT_HISTORY_COMPARE_DIFF   (ID_FACT, COL_NAME, COL_TYPE, COL_OLD_VALUE, COL_NEW_VALUE)
--
-- W tej implementacji, do celów przykładowych, zakładam istnienie 3 kolumn danych:
--    COL_V1 (VARCHAR2), COL_N1 (NUMBER), COL_D1 (DATE).
-- W środowisku docelowym listę kolumn w sekcjach porównania i BUILD_DIFF
-- należy dopasować do faktycznej struktury FACT_HISTORY (np. rozszerzyć
-- do pełnego zestawu kolumn biznesowych).
--
-- Pakiet COMPARATOR_PKG
-- Zadania 1 i 2:
--  - porównanie dwóch "paczek" danych faktów (ID_PACK_OLD, ID_PACK_NEW)
--  - zapis wyników:
--      * TMP_FACT_HISTORY_COMPARE_STATUS: status rekordu (1=MODIFIED, 2=NEW, 3=DELETED)
--      * TMP_FACT_HISTORY_COMPARE_DIFF: szczegóły różnic na poziomie kolumn


CREATE OR REPLACE PACKAGE comparator_pkg AS
    -- Stały format dla DATE -> VARCHAR2 (Zad 2)
    c_date_fmt CONSTANT VARCHAR2(30) := 'YYYY-MM-DD HH24:MI:SS';

    ----------------------------------------------------------------------
    -- ZADANIE 1:
    --  COMPARE_FACT (ID_PACK_OLD, ID_PACK_NEW)
    --  -> uzupełnia TMP_FACT_HISTORY_COMPARE_STATUS
    ----------------------------------------------------------------------
    PROCEDURE compare_fact (
        id_pack_old IN NUMBER,
        id_pack_new IN NUMBER
    );

    ----------------------------------------------------------------------
    -- ZADANIE 2:
    --  COMPARE_FACT (ID_PACK_OLD, ID_PACK_NEW, BUILD_DIFF DEFAULT FALSE)
    --  -> oprócz statusów opcjonalnie uzupełnia TMP_FACT_HISTORY_COMPARE_DIFF
    ----------------------------------------------------------------------
    PROCEDURE compare_fact (
        id_pack_old IN NUMBER,
        id_pack_new IN NUMBER,
        build_diff  IN BOOLEAN DEFAULT FALSE   -- FALSE = tylko statusy, TRUE = statusy + diff
    );
END comparator_pkg;
/
SHOW ERRORS PACKAGE comparator_pkg;
/

CREATE OR REPLACE PACKAGE BODY comparator_pkg AS

    ------------------------------------------------------------------
    -- Wersja 2-parametrowa (Zadanie 1)
    -- Deleguje do wersji 3-parametrowej z build_diff = FALSE
    ------------------------------------------------------------------
    PROCEDURE compare_fact (
        id_pack_old IN NUMBER,
        id_pack_new IN NUMBER
    ) AS
    BEGIN
        compare_fact(
            id_pack_old => id_pack_old,
            id_pack_new => id_pack_new,
            build_diff  => FALSE
        );
    END compare_fact;

    ------------------------------------------------------------------
    -- Wersja 3-parametrowa (Zadanie 1 + Zadanie 2)
    ------------------------------------------------------------------
    PROCEDURE compare_fact (
        id_pack_old IN NUMBER,
        id_pack_new IN NUMBER,
        build_diff  IN BOOLEAN DEFAULT FALSE
    ) AS
    BEGIN
        ----------------------------------------------------------------------
        -- ZADANIE 1: wyliczenie STATUSÓW w TMP_FACT_HISTORY_COMPARE_STATUS
        ----------------------------------------------------------------------

        -- Czyścimy poprzednie wyniki statusów
        DELETE FROM tmp_fact_history_compare_status;

        ----------------------------------------------------------------------
        -- 1) MODIFIED (1) - rekord jest w obu paczkach, ale dane się różnią
        ----------------------------------------------------------------------
        INSERT INTO tmp_fact_history_compare_status (id_fact, status)
        SELECT
            f_old.id_fact,
            1 AS status
        FROM fact_history f_old
        JOIN fact_history f_new
          ON f_new.id_fact = f_old.id_fact
         AND f_new.id_pack = id_pack_new
        WHERE f_old.id_pack = id_pack_old
          AND (
                NVL(f_old.col_v1, '#NULL#')           <> NVL(f_new.col_v1, '#NULL#')
             OR NVL(f_old.col_n1, -999999999999)      <> NVL(f_new.col_n1, -999999999999)
             OR NVL(f_old.col_d1, DATE '1900-01-01')  <> NVL(f_new.col_d1, DATE '1900-01-01')
          );

        ----------------------------------------------------------------------
        -- 2) NEW (2) - rekord jest tylko w nowej paczce
        ----------------------------------------------------------------------
        INSERT INTO tmp_fact_history_compare_status (id_fact, status)
        SELECT
            f_new.id_fact,
            2 AS status
        FROM fact_history f_new
        LEFT JOIN fact_history f_old
          ON f_old.id_fact = f_new.id_fact
         AND f_old.id_pack = id_pack_old
        WHERE f_new.id_pack = id_pack_new
          AND f_old.id_fact IS NULL;

        ----------------------------------------------------------------------
        -- 3) DELETED (3) - rekord był w starej paczce, brak go w nowej
        ----------------------------------------------------------------------
        INSERT INTO tmp_fact_history_compare_status (id_fact, status)
        SELECT
            f_old.id_fact,
            3 AS status
        FROM fact_history f_old
        LEFT JOIN fact_history f_new
          ON f_new.id_fact = f_old.id_fact
         AND f_new.id_pack = id_pack_new
        WHERE f_old.id_pack = id_pack_old
          AND f_new.id_fact IS NULL;

        ----------------------------------------------------------------------
        -- ZADANIE 2: szczegóły różnic w TMP_FACT_HISTORY_COMPARE_DIFF
        -- tylko dla STATUS = 1 (MODIFIED) oraz gdy build_diff = TRUE
        ----------------------------------------------------------------------
        IF build_diff THEN

            -- Czyścimy poprzednie różnice
            DELETE FROM tmp_fact_history_compare_diff;

            -- Dla uproszczenia zakładamy konkretne kolumny:
            --   COL_V1 (VARCHAR2), COL_N1 (NUMBER), COL_D1 (DATE)
            -- W środowisku docelowym listę kolumn należy dopasować
            -- do pełnej struktury FACT_HISTORY.
            FOR r IN (
                SELECT
                    f_old.id_fact,
                    f_old.col_v1  AS old_col_v1,
                    f_new.col_v1  AS new_col_v1,
                    f_old.col_n1  AS old_col_n1,
                    f_new.col_n1  AS new_col_n1,
                    f_old.col_d1  AS old_col_d1,
                    f_new.col_d1  AS new_col_d1
                FROM fact_history f_old
                JOIN fact_history f_new
                  ON f_new.id_fact = f_old.id_fact
                 AND f_new.id_pack = id_pack_new
                WHERE f_old.id_pack = id_pack_old
                  AND (
                        NVL(f_old.col_v1, '#NULL#')           <> NVL(f_new.col_v1, '#NULL#')
                     OR NVL(f_old.col_n1, -999999999999)      <> NVL(f_new.col_n1, -999999999999)
                     OR NVL(f_old.col_d1, DATE '1900-01-01')  <> NVL(f_new.col_d1, DATE '1900-01-01')
                  )
            ) LOOP
                -- COL_V1 różne?
                IF NVL(r.old_col_v1, '#NULL#') <> NVL(r.new_col_v1, '#NULL#') THEN
                    INSERT INTO tmp_fact_history_compare_diff (
                        id_fact, col_name, col_type, col_old_value, col_new_value
                    )
                    VALUES (
                        r.id_fact,
                        'COL_V1',
                        'VARCHAR2',
                        r.old_col_v1,
                        r.new_col_v1
                    );
                END IF;

                -- COL_N1 różne?
                IF NVL(r.old_col_n1, -999999999999) <> NVL(r.new_col_n1, -999999999999) THEN
                    INSERT INTO tmp_fact_history_compare_diff (
                        id_fact, col_name, col_type, col_old_value, col_new_value
                    )
                    VALUES (
                        r.id_fact,
                        'COL_N1',
                        'NUMBER',
                        CASE WHEN r.old_col_n1 IS NULL THEN NULL ELSE TO_CHAR(r.old_col_n1) END,
                        CASE WHEN r.new_col_n1 IS NULL THEN NULL ELSE TO_CHAR(r.new_col_n1) END
                    );
                END IF;

                -- COL_D1 różne?
                IF NVL(r.old_col_d1, DATE '1900-01-01') <> NVL(r.new_col_d1, DATE '1900-01-01') THEN
                    INSERT INTO tmp_fact_history_compare_diff (
                        id_fact, col_name, col_type, col_old_value, col_new_value
                    )
                    VALUES (
                        r.id_fact,
                        'COL_D1',
                        'DATE',
                        CASE WHEN r.old_col_d1 IS NULL THEN NULL ELSE TO_CHAR(r.old_col_d1, c_date_fmt) END,
                        CASE WHEN r.new_col_d1 IS NULL THEN NULL ELSE TO_CHAR(r.new_col_d1, c_date_fmt) END
                    );
                END IF;
            END LOOP;
        END IF;

        -- Brak COMMIT – decyzja o zatwierdzeniu transakcji po stronie wywołującego.
        -- COMMIT;

    END compare_fact;

END comparator_pkg;
/
SHOW ERRORS PACKAGE BODY comparator_pkg;
