-- 01_reservation_setup_local.sql
-- Setup lokalny do PROJEKTU REZERWACJA MIEJSC (Zadanie 3)

-- Bezpieczne dropy

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE res_attempt';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE res_reservation';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE res_config';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE res_attempt_seq';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -2289 THEN RAISE; END IF;
END;
/

----------------------------------------------------------------------
-- Konfiguracja limitu rezerwacji (jedno wydarzenie, ID = 1)
----------------------------------------------------------------------

CREATE TABLE res_config (
    id_cfg              NUMBER PRIMARY KEY,
    max_reservations    NUMBER NOT NULL,
    current_reservations NUMBER DEFAULT 0 NOT NULL
);

COMMENT ON TABLE res_config IS 'Konfiguracja limitu rezerwacji dla jednego wydarzenia (id_cfg=1)';
COMMENT ON COLUMN res_config.max_reservations IS 'Maksymalna liczba rezerwacji (np. 50000 w realnym systemie)';
COMMENT ON COLUMN res_config.current_reservations IS 'Aktualna liczba aktywnych rezerwacji';

-- Dla testów ustawiamy mały limit, np. 5.
-- W realnym systemie można ustawić 50000 zgodnie z treścią zadania.
-- zmieniając wartość MAX_RESERVATIONS
INSERT INTO res_config (id_cfg, max_reservations, current_reservations)
VALUES (1, 5, 0);

----------------------------------------------------------------------
-- Tabela rezerwacji
-- 1 bilet na PESEL (unikalny), IDR = unikalny identyfikator rezerwacji
----------------------------------------------------------------------

CREATE TABLE res_reservation (
    idr        VARCHAR2(32) PRIMARY KEY,
    pesel      VARCHAR2(11) NOT NULL,
    created_at DATE DEFAULT SYSDATE NOT NULL,
    CONSTRAINT uq_res_reservation_pesel UNIQUE (pesel)
);

COMMENT ON TABLE res_reservation IS 'Aktywne rezerwacje biletów (po 1 bilecie na PESEL)';
COMMENT ON COLUMN res_reservation.idr IS 'Unikalny identyfikator rezerwacji (np. wysyłany w mailu do klienta)';

----------------------------------------------------------------------
-- Tabela prób rezerwacji (każda próba MUSI być zapisana)
----------------------------------------------------------------------

CREATE TABLE res_attempt (
    attempt_id NUMBER PRIMARY KEY,
    pesel      VARCHAR2(11),
    status     NUMBER,           -- 0=OK, 1=limit, 2=PESEL błędny, 3=już ma rezerwację, 9=błąd
    idr        VARCHAR2(32),
    attempt_at DATE DEFAULT SYSDATE,
    error_msg  VARCHAR2(4000)
);

COMMENT ON TABLE res_attempt IS 'Log wszystkich prób rezerwacji/anulowania (udanych i nieudanych)';
COMMENT ON COLUMN res_attempt.status IS 'Kod statusu zwrócony przez procedurę (0,1,2,3,4,9)';
COMMENT ON COLUMN res_attempt.error_msg IS 'Opis błędu lub informacja diagnostyczna';

CREATE SEQUENCE res_attempt_seq
    START WITH 1
    INCREMENT BY 1
    NOCACHE;

COMMIT;

