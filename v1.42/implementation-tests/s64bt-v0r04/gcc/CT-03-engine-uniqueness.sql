-- CT-03 - Engine uniqueness. Tier 3.
-- S64BT Package Version: 0
-- S64BT Package Revision: 04
-- S64BT Package Date: Nov 14, 2026
-- No USE statement; caller selects database.
-- Each assertion emits a single 0 or 1 column.
SET @pass = 0;
SET @fail = 0;
SET @total = 0;

START TRANSACTION;

INSERT INTO physical_engine(engine_id, class_id) VALUES (__ENGINE_ID__, 1);
INSERT INTO allocation(engine_id, local_id, s64_id) VALUES (__ENGINE_ID__, 1, __S64_A__);

-- t1: composite PK rejects duplicate (engine_id, local_id)
INSERT IGNORE INTO allocation(engine_id, local_id, s64_id) VALUES (__ENGINE_ID__, 1, __S64_B__);
SET @total = @total + 1;
SET @ok = IF((SELECT COUNT(*) FROM allocation WHERE engine_id = __ENGINE_ID__ AND local_id = 1) = 1, 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t1_composite_pk;

-- t2: unique(s64_id) rejects same s64_id at different local_id
INSERT IGNORE INTO allocation(engine_id, local_id, s64_id) VALUES (__ENGINE_ID__, 2, __S64_A__);
SET @total = @total + 1;
SET @ok = IF((SELECT COUNT(*) FROM allocation WHERE s64_id = __S64_A__) = 1, 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t2_unique_s64;

-- t3: physical_engine PK rejects duplicate engine_id
INSERT IGNORE INTO physical_engine(engine_id, class_id) VALUES (__ENGINE_ID__, 1);
SET @total = @total + 1;
SET @ok = IF((SELECT COUNT(*) FROM physical_engine WHERE engine_id = __ENGINE_ID__) = 1, 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t3_unique_engine;

-- t4: surviving allocation row carries __S64_A__
SET @total = @total + 1;
SET @ok = IF((SELECT s64_id FROM allocation WHERE engine_id = __ENGINE_ID__ AND local_id = 1) = __S64_A__, 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t4_row_intact;

ROLLBACK;

-- t5: rollback removes allocation rows
SET @total = @total + 1;
SET @ok = IF((SELECT COUNT(*) FROM allocation WHERE engine_id = __ENGINE_ID__) = 0, 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t5_rollback_allocation;

-- t6: rollback removes physical_engine rows
SET @total = @total + 1;
SET @ok = IF((SELECT COUNT(*) FROM physical_engine WHERE engine_id = __ENGINE_ID__) = 0, 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t6_rollback_engine;

SELECT CONCAT('assertions=', @total, ' passed=', @pass) AS assertion_counts;
