-- 01_reports_setup_local.sql
-- Setup lokalny do PROJEKTU RAPORTY (Zad 4 i 5)
-- Tabele: REGIONY, PRACOWNICY, SPRZEDAZ + dane przykładowe.
-- Dane przykładowe do PROJEKTU RAPORTY (Zadania 4 i 5).
--  - 3 regiony
--  - 5 pracowników
--  - kilka transakcji w różnych miesiącach, w tym luty 2024 (ważny dla Zad 5).

-- Bezpieczne dropy
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE sprzedaz';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE pracownicy';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE regiony';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

----------------------------------------------------------------------
-- Tabele zgodnie z treścią zadania
----------------------------------------------------------------------

CREATE TABLE regiony (
    id     NUMBER PRIMARY KEY,
    nazwa  VARCHAR2(100)
);

CREATE TABLE pracownicy (
    id       NUMBER PRIMARY KEY,
    imie     VARCHAR2(50),
    nazwisko VARCHAR2(50),
    reg_id   NUMBER REFERENCES regiony(id)
);

CREATE TABLE sprzedaz (
    id      NUMBER PRIMARY KEY,
    dt      DATE,        -- data transakcji (indeksowana w realnym systemie)
    prac_id NUMBER REFERENCES pracownicy(id),
    wartosc NUMBER       -- wartość sprzedaży
);

----------------------------------------------------------------------
-- Dane przykładowe (3 regiony, 5 pracowników, transakcje w różnych miesiącach)
----------------------------------------------------------------------

INSERT INTO regiony (id, nazwa) VALUES (1, 'Polska Północ');
INSERT INTO regiony (id, nazwa) VALUES (2, 'Polska Południe');
INSERT INTO regiony (id, nazwa) VALUES (3, 'Polska Zachód');

INSERT INTO pracownicy (id, imie, nazwisko, reg_id)
VALUES (1, 'Jan', 'Kowalski', 1);

INSERT INTO pracownicy (id, imie, nazwisko, reg_id)
VALUES (2, 'Anna', 'Nowak', 1);

INSERT INTO pracownicy (id, imie, nazwisko, reg_id)
VALUES (3, 'Piotr', 'Wiśniewski', 2);

INSERT INTO pracownicy (id, imie, nazwisko, reg_id)
VALUES (4, 'Kasia', 'Zielińska', 2);

INSERT INTO pracownicy (id, imie, nazwisko, reg_id)
VALUES (5, 'Tomek', 'Lewandowski', 3);

-- Czyścimy sprzedaż (na wypadek poprzednich testów)
DELETE FROM sprzedaz;

-- Kilka transakcji poza zakresem 12m do testów "cięcia"
INSERT INTO sprzedaz (id, dt, prac_id, wartosc)
VALUES (1, DATE '2023-01-15', 1, 100);

INSERT INTO sprzedaz (id, dt, prac_id, wartosc)
VALUES (2, DATE '2023-06-10', 2, 200);

-- Transakcje w lutym 2024 (ważne dla Zad 5)
INSERT INTO sprzedaz (id, dt, prac_id, wartosc)
VALUES (3, DATE '2024-02-05', 1, 500);

INSERT INTO sprzedaz (id, dt, prac_id, wartosc)
VALUES (4, DATE '2024-02-10', 1, 700);

INSERT INTO sprzedaz (id, dt, prac_id, wartosc)
VALUES (5, DATE '2024-02-12', 2, 300);

INSERT INTO sprzedaz (id, dt, prac_id, wartosc)
VALUES (6, DATE '2024-02-20', 3, 900);

INSERT INTO sprzedaz (id, dt, prac_id, wartosc)
VALUES (7, DATE '2024-02-25', 3, 400);

INSERT INTO sprzedaz (id, dt, prac_id, wartosc)
VALUES (8, DATE '2024-02-28', 4, 1000);

-- Kilka transakcji w innych miesiącach roku 2024
INSERT INTO sprzedaz (id, dt, prac_id, wartosc)
VALUES (9, DATE '2024-03-05', 1, 150);

INSERT INTO sprzedaz (id, dt, prac_id, wartosc)
VALUES (10, DATE '2024-11-15', 2, 250);

INSERT INTO sprzedaz (id, dt, prac_id, wartosc)
VALUES (11, DATE '2025-01-10', 3, 300);

INSERT INTO sprzedaz (id, dt, prac_id, wartosc)
VALUES (12, DATE '2025-04-18', 4, 450);

INSERT INTO sprzedaz (id, dt, prac_id, wartosc)
VALUES (13, DATE '2025-08-22', 5, 800);

COMMIT;

