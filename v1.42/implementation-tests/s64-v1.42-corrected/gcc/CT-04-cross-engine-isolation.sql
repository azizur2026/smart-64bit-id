USE s64_test;

-- Expression-level encoding separation check; this is not a persistent
-- allocation-isolation test.
SET @local_id = 1;
SET @class_id = 1;
SET @role = 1;
SET @revision = 0;
SET @version = 1;
SET @engine_a = 1001;
SET @engine_b = 1002;

SET @id_a =
    (CAST(@version AS UNSIGNED) << 63) |
    (CAST(@revision AS UNSIGNED) << 59) |
    (CAST(@role AS UNSIGNED) << 58) |
    (CAST(@class_id AS UNSIGNED) << 50) |
    (CAST(@engine_a AS UNSIGNED) << 29) |
    @local_id;
SET @id_b =
    (CAST(@version AS UNSIGNED) << 63) |
    (CAST(@revision AS UNSIGNED) << 59) |
    (CAST(@role AS UNSIGNED) << 58) |
    (CAST(@class_id AS UNSIGNED) << 50) |
    (CAST(@engine_b AS UNSIGNED) << 29) |
    @local_id;

SELECT
    @id_a <> @id_b AS distinct_ids,
    ((@id_a >> 29) & 2097151) = @engine_a AS engine_a_decodes,
    ((@id_b >> 29) & 2097151) = @engine_b AS engine_b_decodes,
    (@id_a & 536870911) = @local_id AS local_a_decodes,
    (@id_b & 536870911) = @local_id AS local_b_decodes,
    ((@id_a >> 54) & 15) = 0 AS reserved_a_zero,
    ((@id_b >> 54) & 15) = 0 AS reserved_b_zero;
