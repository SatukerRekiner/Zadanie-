-- 02_zad4_miesieczny_raport.sql
-- Raport miesięczny sprzedaży za 12 miesięcy wstecz bez miesiąca bieżącego
-- dla wszystkich pracowników, w podziale na miesiące.
-- Zakres:
--  - od pierwszego dnia miesiąca sprzed 12 miesięcy
--  - do pierwszego dnia bieżącego miesiąca
--  - 12 pełnych miesięcy "historycznych", bez miesiąca bieżącego.



CREATE OR REPLACE VIEW v_raport_miesieczny_sprzedaz AS
WITH months (month_start) AS (
    -- pierwszy miesiąc: 12 miesięcy wstecz od początku bieżącego miesiąca
    SELECT ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -12) AS month_start
    FROM dual
    UNION ALL
    -- kolejne miesiące, aż do miesiąca poprzedzającego bieżący
    SELECT ADD_MONTHS(month_start, 1)
    FROM   months
    WHERE  ADD_MONTHS(month_start, 1) < TRUNC(SYSDATE, 'MM')
)
SELECT
    p.id      AS pracownik_id,
    p.imie,
    p.nazwisko,
    TO_CHAR(m.month_start, 'YYYY-MM') AS rok_miesiac,
    -- liczba transakcji tylko z tabeli SPRZEDAZ (nie liczymy "pustego" wiersza)
    COUNT(s.id)                                   AS liczba_transakcji,
    NVL(SUM(s.wartosc), 0)                        AS wartosc_miesieczna,
    CASE
        WHEN COUNT(s.id) > 0 THEN AVG(s.wartosc)
        ELSE 0
    END                                           AS srednia_wartosc_transakcji,
    NVL(MAX(s.wartosc), 0)                        AS max_wartosc_transakcji
FROM
    months m
    CROSS JOIN pracownicy p
    LEFT JOIN sprzedaz s
        ON s.prac_id = p.id
       AND s.dt >= m.month_start
       AND s.dt <  ADD_MONTHS(m.month_start, 1)
GROUP BY
    p.id, p.imie, p.nazwisko, m.month_start;

