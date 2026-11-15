-- CT-04 - Cross-engine bit separation (expression-level). Tier 3.
-- S64BT Package Version: 0
-- S64BT Package Revision: 04
-- S64BT Package Date: Nov 14, 2026
-- No USE statement. Scope: expression-level only.
-- Byte-roundtrip assertions not included (not viable in MariaDB at full 64-bit).
-- Each assertion emits a single 0 or 1 column.
SET @pass = 0;
SET @fail = 0;
SET @total = 0;

SET @local_id = 1;
SET @class_id = 1;
SET @role     = 1;
SET @revision = 2;
SET @version  = 0;
SET @engine_a = 1001;
SET @engine_b = 1002;

SET @id_a =
    (CAST(@version  AS UNSIGNED) << 63) |
    (CAST(@revision AS UNSIGNED) << 59) |
    (CAST(@role     AS UNSIGNED) << 58) |
    (CAST(@class_id AS UNSIGNED) << 50) |
    (CAST(@engine_a AS UNSIGNED) << 29) |
    @local_id;
SET @id_b =
    (CAST(@version  AS UNSIGNED) << 63) |
    (CAST(@revision AS UNSIGNED) << 59) |
    (CAST(@role     AS UNSIGNED) << 58) |
    (CAST(@class_id AS UNSIGNED) << 50) |
    (CAST(@engine_b AS UNSIGNED) << 29) |
    @local_id;

-- t1: distinct IDs
SET @total = @total + 1;
SET @ok = IF(@id_a <> @id_b, 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t1_distinct;

-- t2: engine_a decodes
SET @total = @total + 1;
SET @ok = IF(((@id_a >> 29) & 2097151) = @engine_a, 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t2_engine_a;

-- t3: engine_b decodes
SET @total = @total + 1;
SET @ok = IF(((@id_b >> 29) & 2097151) = @engine_b, 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t3_engine_b;

-- t4: local_a decodes
SET @total = @total + 1;
SET @ok = IF((@id_a & 536870911) = @local_id, 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t4_local_a;

-- t5: local_b decodes
SET @total = @total + 1;
SET @ok = IF((@id_b & 536870911) = @local_id, 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t5_local_b;

-- t6: reserved_a zero
SET @total = @total + 1;
SET @ok = IF(((@id_a >> 54) & 15) = 0, 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t6_reserved_a;

-- t7: reserved_b zero
SET @total = @total + 1;
SET @ok = IF(((@id_b >> 54) & 15) = 0, 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t7_reserved_b;

-- t8: both IDs are distinct and non-zero
SET @total = @total + 1;
SET @ok = IF(@id_a <> @id_b AND @id_a <> 0 AND @id_b <> 0, 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t8_distinct_nonzero;

SELECT CONCAT('assertions=', @total, ' passed=', @pass) AS assertion_counts;
SELECT 'CT-04: SCOPE=expression-level' AS scope;
