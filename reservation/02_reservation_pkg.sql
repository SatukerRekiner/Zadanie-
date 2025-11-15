-- 02_reservation_pkg.sql
-- PROJEKT REZERWACJA MIEJSC – Zadanie 3 (+ dla chętnych: anulowanie)
--
-- Statusy (stałe – zamiast "magicznych" liczb w kodzie):
--   c_status_ok             = 0  -- OK (rezerwacja/anulowanie wykonane)
--   c_status_limit          = 1  -- wykorzystany limit rezerwacji
--   c_status_bad_pesel      = 2  -- niepoprawny PESEL (format)
--   c_status_already_exists = 3  -- PESEL ma już rezerwację
--   c_status_not_found      = 4  -- brak takiej rezerwacji do anulowania
--   c_status_error          = 9  -- nieoczekiwany błąd serwera
--
-- Procedura główna:
--   reserve_ticket(
--       p_pesel   IN  VARCHAR2,
--       p_status  OUT NUMBER,
--       p_idr     OUT VARCHAR2
--   )
--
-- Procedura dodatkowa (dla chętnych):
--   cancel_ticket(
--       p_pesel   IN  VARCHAR2,
--       p_idr     IN  VARCHAR2,
--       p_status  OUT NUMBER
--   )

CREATE OR REPLACE PACKAGE reservation_pkg AS

    -- Stałe statusów
    c_status_ok             CONSTANT PLS_INTEGER := 0;
    c_status_limit          CONSTANT PLS_INTEGER := 1;
    c_status_bad_pesel      CONSTANT PLS_INTEGER := 2;
    c_status_already_exists CONSTANT PLS_INTEGER := 3;
    c_status_not_found      CONSTANT PLS_INTEGER := 4;
    c_status_error          CONSTANT PLS_INTEGER := 9;

    -- Główna procedura rezerwacji
    PROCEDURE reserve_ticket (
        p_pesel   IN  VARCHAR2,
        p_status  OUT NUMBER,
        p_idr     OUT VARCHAR2
    );

    -- Dla chętnych: procedura anulowania rezerwacji
    PROCEDURE cancel_ticket (
        p_pesel   IN  VARCHAR2,
        p_idr     IN  VARCHAR2,
        p_status  OUT NUMBER
    );

END reservation_pkg;
/
SHOW ERRORS PACKAGE reservation_pkg;
/

CREATE OR REPLACE PACKAGE BODY reservation_pkg AS

    ------------------------------------------------------------------
    -- Procedura pomocnicza: logowanie próby (rezerwacji/anulowania)
    -- AUTONOMOUS_TRANSACTION => zapis loga niezależnie od transakcji głównej
    ------------------------------------------------------------------
    PROCEDURE log_attempt (
        p_pesel  IN VARCHAR2,
        p_status IN NUMBER,
        p_idr    IN VARCHAR2,
        p_error  IN VARCHAR2
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO res_attempt (
            attempt_id, pesel, status, idr, attempt_at, error_msg
        ) VALUES (
            res_attempt_seq.NEXTVAL,
            p_pesel,
            p_status,
            p_idr,
            SYSDATE,
            SUBSTR(p_error, 1, 4000)
        );
        COMMIT;
    END log_attempt;

    ------------------------------------------------------------------
    -- Główna procedura rezerwacji
    ------------------------------------------------------------------
    PROCEDURE reserve_ticket (
        p_pesel   IN  VARCHAR2,
        p_status  OUT NUMBER,
        p_idr     OUT VARCHAR2
    ) AS
        v_max     res_config.max_reservations%TYPE;
        v_curr    res_config.current_reservations%TYPE;
        v_idr     VARCHAR2(32);
    BEGIN
        p_idr    := NULL;
        p_status := NULL;

        ------------------------------------------------------------------
        -- 1. Walidacja PESEL (prosta: 11 cyfr)
        ------------------------------------------------------------------
        IF NOT REGEXP_LIKE(p_pesel, '^[0-9]{11}$') THEN
            p_status := c_status_bad_pesel;
            log_attempt(p_pesel, p_status, NULL, 'Invalid PESEL format');
            RETURN;
        END IF;

        ------------------------------------------------------------------
        -- 2. Pobranie i zablokowanie konfiguracji (limit globalny)
        ------------------------------------------------------------------
        BEGIN
            SELECT max_reservations, current_reservations
              INTO v_max, v_curr
              FROM res_config
             WHERE id_cfg = 1
             FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Brak konfiguracji – błąd serwera
                p_status := c_status_error;
                log_attempt(p_pesel, p_status, NULL, 'Config row not found (reserve)');
                RETURN;
        END;

        IF v_curr >= v_max THEN
            p_status := c_status_limit;
            log_attempt(p_pesel, p_status, NULL, 'Global reservation limit reached');
            RETURN;
        END IF;

        ------------------------------------------------------------------
        -- 3. Próba założenia nowej rezerwacji
        ------------------------------------------------------------------
        v_idr := RAWTOHEX(SYS_GUID());

        BEGIN
            INSERT INTO res_reservation (idr, pesel)
            VALUES (v_idr, p_pesel);

            UPDATE res_config
               SET current_reservations = v_curr + 1
             WHERE id_cfg = 1;

            p_status := c_status_ok;
            p_idr    := v_idr;

            log_attempt(p_pesel, p_status, p_idr, NULL);

        EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
                -- Ten PESEL ma już rezerwację
                p_status := c_status_already_exists;
                p_idr    := NULL;

                log_attempt(p_pesel, p_status, NULL, 'PESEL already has reservation');

            WHEN OTHERS THEN
                p_status := c_status_error;
                p_idr    := NULL;

                log_attempt(p_pesel, p_status, NULL, 'RESERVE ERROR: ' || SQLERRM);
                RAISE;
        END;

        -- Brak COMMIT – decyzja po stronie wywołującego.

    END reserve_ticket;

    ------------------------------------------------------------------
    -- Procedura anulowania rezerwacji (dla chętnych)
    -- p_pesel   - PESEL, dla którego chcemy anulować
    -- p_idr     - ID rezerwacji (np. przekazany w mailu)
    -- p_status:
    --    0 - anulowanie wykonane
    --    2 - błędny PESEL (format)
    --    4 - brak takiej rezerwacji (IDR/PESEL nie pasują)
    --    9 - nieoczekiwany błąd
    ------------------------------------------------------------------
    PROCEDURE cancel_ticket (
        p_pesel   IN  VARCHAR2,
        p_idr     IN  VARCHAR2,
        p_status  OUT NUMBER
    ) AS
        v_curr  res_config.current_reservations%TYPE;
        v_dummy VARCHAR2(1);
    BEGIN
        p_status := NULL;

        ------------------------------------------------------------------
        -- 1. Walidacja PESEL
        ------------------------------------------------------------------
        IF NOT REGEXP_LIKE(p_pesel, '^[0-9]{11}$') THEN
            p_status := c_status_bad_pesel;
            log_attempt(p_pesel, p_status, p_idr, 'Invalid PESEL format (cancel)');
            RETURN;
        END IF;

        ------------------------------------------------------------------
        -- 2. Pobranie konfiguracji (żeby spójnie zmniejszyć licznik)
        ------------------------------------------------------------------
        BEGIN
            SELECT current_reservations
              INTO v_curr
              FROM res_config
             WHERE id_cfg = 1
             FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                p_status := c_status_error;
                log_attempt(p_pesel, p_status, p_idr, 'Config row not found (cancel)');
                RETURN;
        END;

        ------------------------------------------------------------------
        -- 3. Szukamy rezerwacji dla danego PESEL + IDR
        ------------------------------------------------------------------
        BEGIN
            SELECT 'X'
              INTO v_dummy
              FROM res_reservation
             WHERE idr   = p_idr
               AND pesel = p_pesel
             FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- brak takiej rezerwacji -> nie zmieniamy licznika
                p_status := c_status_not_found;
                log_attempt(p_pesel, p_status, p_idr, 'No matching reservation to cancel');
                RETURN;
        END;

        ------------------------------------------------------------------
        -- 4. Usuwamy rezerwację i zmniejszamy licznik (nie schodzimy poniżej 0)
        ------------------------------------------------------------------
        DELETE FROM res_reservation
         WHERE idr   = p_idr
           AND pesel = p_pesel;

        UPDATE res_config
           SET current_reservations =
               CASE
                   WHEN current_reservations > 0
                   THEN current_reservations - 1
                   ELSE 0
               END
         WHERE id_cfg = 1;

        p_status := c_status_ok;
        log_attempt(p_pesel, p_status, p_idr, 'Reservation cancelled');

    EXCEPTION
        WHEN OTHERS THEN
            p_status := c_status_error;
            log_attempt(p_pesel, p_status, p_idr, 'CANCEL ERROR: ' || SQLERRM);
            RAISE;
    END cancel_ticket;

END reservation_pkg;
/
SHOW ERRORS PACKAGE BODY reservation_pkg;
