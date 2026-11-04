USE s64_test;
START TRANSACTION;

INSERT INTO physical_engine(engine_id, class_id)
VALUES (1803612, 1);

INSERT INTO allocation(engine_id, local_id, s64_id)
VALUES (1803612, 1, 9225466243580952577);

INSERT IGNORE INTO allocation(engine_id, local_id, s64_id)
VALUES (1803612, 1, 9225466243580952578);

SELECT IF(ROW_COUNT() = 0, 'CT-03: PASS', 'CT-03: FAIL') AS result;

ROLLBACK;
