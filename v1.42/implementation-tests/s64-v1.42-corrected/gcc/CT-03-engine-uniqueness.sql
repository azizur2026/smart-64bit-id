USE s64_test;
START TRANSACTION;

INSERT INTO physical_engine(engine_id, class_id)
VALUES (__ENGINE_ID__, 1);

INSERT INTO allocation(engine_id, local_id, s64_id)
VALUES (__ENGINE_ID__, 1, __S64_A__);

INSERT IGNORE INTO allocation(engine_id, local_id, s64_id)
VALUES (__ENGINE_ID__, 1, __S64_B__);

SELECT IF(ROW_COUNT() = 0, 'CT-03: PASS', 'CT-03: FAIL') AS result;

ROLLBACK;
