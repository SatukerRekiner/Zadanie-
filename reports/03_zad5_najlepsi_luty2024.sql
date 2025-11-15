-- 03_zad5_najlepsi_luty2024.sql
-- Najlepsi sprzedawcy w każdym regionie za luty 2024.


CREATE OR REPLACE VIEW v_najlepsi_sprzedawcy_luty2024 AS
WITH sales_agg AS (
    SELECT
        r.id          AS reg_id,
        r.nazwa       AS region_nazwa,
        p.id          AS pracownik_id,
        p.imie,
        p.nazwisko,
        SUM(s.wartosc) AS suma_sprzedazy
    FROM
        sprzedaz s
        JOIN pracownicy p ON p.id = s.prac_id
        JOIN regiony r     ON r.id = p.reg_id
    WHERE
        s.dt >= DATE '2024-02-01'
        AND s.dt < DATE '2024-03-01'
    GROUP BY
        r.id, r.nazwa,
        p.id, p.imie, p.nazwisko
),
ranked AS (
    SELECT
        sa.*,
        ROW_NUMBER() OVER (
            PARTITION BY sa.reg_id
            ORDER BY sa.suma_sprzedazy DESC
        ) AS rn
    FROM sales_agg sa
)
SELECT
    reg_id,
    region_nazwa,
    pracownik_id,
    imie,
    nazwisko,
    suma_sprzedazy
FROM ranked
WHERE rn = 1;

-- Przykładowe użycie:
-- SELECT * FROM v_najlepsi_sprzedawcy_luty2024
-- ORDER BY reg_id, pracownik_id;
