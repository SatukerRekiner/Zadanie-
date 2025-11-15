-- 01_comparator_setup_local.sql
-- Setup lokalny do PROJEKTU COMPARATOR
-- Tabele + dane testowe, żeby móc odpalać pakiet.

-- Bezpieczne dropy (jak tabele nie istnieją, to ignorujemy błąd -942)
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE tmp_fact_history_compare_diff';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE tmp_fact_history_compare_status';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE fact_history';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

-- Tabela FACT_HISTORY (wersje danych FACT)
-- U siebie robimy prostą wersję: 3 kolumny danych:
--   COL_V1  - VARCHAR2
--   COL_N1  - NUMBER
--   COL_D1  - DATE
-- W ich środowisku można to rozszerzyć na więcej kolumn.

CREATE TABLE fact_history (
    id_pack INTEGER      NOT NULL,
    id_fact NUMBER       NOT NULL,
    col_v1  VARCHAR2(100),
    col_n1  NUMBER,
    col_d1  DATE,
    CONSTRAINT pk_fact_history PRIMARY KEY (id_pack, id_fact)
);

-- Tabela tymczasowa STATUSÓW (Zad 1)
CREATE TABLE tmp_fact_history_compare_status (
    id_fact NUMBER NOT NULL,
    status  NUMBER NOT NULL
);

-- Tabela tymczasowa SZCZEGÓŁÓW RÓŻNIC (Zad 2)
CREATE TABLE tmp_fact_history_compare_diff (
    id_fact       NUMBER        NOT NULL,
    col_name      VARCHAR2(30)  NOT NULL,
    col_type      VARCHAR2(30)  NOT NULL,
    col_old_value VARCHAR2(4000),
    col_new_value VARCHAR2(4000)
);

-- Dane testowe
-- Paczka 1 = stara wersja
-- Paczka 2 = nowa wersja

DELETE FROM fact_history;
COMMIT;

-- PACZKA STARA (1)
INSERT INTO fact_history (id_pack, id_fact, col_v1, col_n1, col_d1)
VALUES (1, 100, 'A', 10, DATE '2024-01-01');

INSERT INTO fact_history (id_pack, id_fact, col_v1, col_n1, col_d1)
VALUES (1, 101, 'B', 20, DATE '2024-01-01');

INSERT INTO fact_history (id_pack, id_fact, col_v1, col_n1, col_d1)
VALUES (1, 102, 'C', 30, DATE '2024-01-01');

-- PACZKA NOWA (2)
-- 100: zmieniamy dane (MODIFIED)
INSERT INTO fact_history (id_pack, id_fact, col_v1, col_n1, col_d1)
VALUES (2, 100, 'A', 99, DATE '2024-01-02');

-- 101: identyczny (brak w TMP_STATUS)
INSERT INTO fact_history (id_pack, id_fact, col_v1, col_n1, col_d1)
VALUES (2, 101, 'B', 20, DATE '2024-01-01');

-- 103: nowy rekord (NEW)
INSERT INTO fact_history (id_pack, id_fact, col_v1, col_n1, col_d1)
VALUES (2, 103, 'D', 40, DATE '2024-01-03');

COMMIT;
