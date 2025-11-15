-- 03_reservation_tests.sql
-- Testy lokalne procedur reservation_pkg (rezerwacja + anulowanie)

SET SERVEROUTPUT ON;

PROMPT *** RESET LICZNIKÓW ***
UPDATE res_config
   SET current_reservations = 0
 WHERE id_cfg = 1;

DELETE FROM res_reservation;
DELETE FROM res_attempt;
COMMIT;

DECLARE
    v_status NUMBER;
    v_idr    VARCHAR2(32);
BEGIN
    DBMS_OUTPUT.put_line('*** TEST A: Poprawna rezerwacja dla PESEL 11111111111 ***');

    reservation_pkg.reserve_ticket(
        p_pesel  => '11111111111',
        p_status => v_status,
        p_idr    => v_idr
    );
    COMMIT;

    DBMS_OUTPUT.put_line('Status = ' || v_status || ', IDR = ' || NVL(v_idr, 'NULL'));

    DBMS_OUTPUT.put_line('*** TEST B: Druga próba tego samego PESEL (powinien mieć status=3) ***');

    reservation_pkg.reserve_ticket(
        p_pesel  => '11111111111',
        p_status => v_status,
        p_idr    => v_idr
    );
    COMMIT;

    DBMS_OUTPUT.put_line('Status = ' || v_status || ', IDR = ' || NVL(v_idr, 'NULL'));

    DBMS_OUTPUT.put_line('*** TEST C: Próba z błędnym PESEL (np. za krótki) ***');

    reservation_pkg.reserve_ticket(
        p_pesel  => '123',
        p_status => v_status,
        p_idr    => v_idr
    );
    COMMIT;

    DBMS_OUTPUT.put_line('Status = ' || v_status || ' (powinno być 2), IDR = ' || NVL(v_idr, 'NULL'));

    DBMS_OUTPUT.put_line('*** TEST D: Wyczerpanie limitu (limit z RES_CONFIG = 5) ***');

    -- Mamy już 1 poprawną rezerwację (PESEL 11111111111).
    -- Teraz spróbujemy dodać kolejne 10 różnych PESELi
    FOR i IN 1 .. 10 LOOP
        reservation_pkg.reserve_ticket(
            p_pesel  => LPAD(TO_CHAR(i), 11, '0'),  -- '00000000001', '00000000002', ...
            p_status => v_status,
            p_idr    => v_idr
        );
        COMMIT;

        DBMS_OUTPUT.put_line(
            'Proba ' || i || ': PESEL=' || LPAD(TO_CHAR(i), 11, '0') ||
            ', status=' || v_status ||
            ', idr=' || NVL(v_idr, 'NULL')
        );
    END LOOP;
END;
/
-------------------------------------------------------------------------------
-- TESTY ANULOWANIA
-------------------------------------------------------------------------------
DECLARE
    v_status NUMBER;
    v_idr    VARCHAR2(32);
BEGIN
    DBMS_OUTPUT.put_line('*** TEST E: Anulowanie rezerwacji dla PESEL 11111111111 ***');

    -- Szukamy IDR z tabeli rezerwacji
    SELECT idr
      INTO v_idr
      FROM res_reservation
     WHERE pesel = '11111111111';

    reservation_pkg.cancel_ticket(
        p_pesel  => '11111111111',
        p_idr    => v_idr,
        p_status => v_status
    );
    COMMIT;

    DBMS_OUTPUT.put_line('Status anulowania = ' || v_status || ' (0 = OK), IDR = ' || v_idr);

    DBMS_OUTPUT.put_line('*** TEST F: Ponowne anulowanie tej samej rezerwacji (powinno się nie udać) ***');

    reservation_pkg.cancel_ticket(
        p_pesel  => '11111111111',
        p_idr    => v_idr,
        p_status => v_status
    );
    COMMIT;

    DBMS_OUTPUT.put_line('Status anulowania (druga próba) = ' || v_status || ' (powinno być 4)');
END;
/
PROMPT *** ZAWARTOŚĆ RES_RESERVATION ***
SELECT * FROM res_reservation ORDER BY created_at;

PROMPT *** ZAWARTOŚĆ RES_CONFIG ***
SELECT * FROM res_config;

PROMPT *** ZAWARTOŚĆ RES_ATTEMPT (ostatnie 30 prób) ***
SELECT *
FROM   (
    SELECT *
    FROM   res_attempt
    ORDER BY attempt_id DESC
)
WHERE ROWNUM <= 30
ORDER BY attempt_id;
