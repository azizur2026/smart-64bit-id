-- CT-06 - Authoritative Class consistency. Tier 3.
-- S64BT Package Version: 0
-- S64BT Package Revision: 04
-- S64BT Package Date: Nov 14, 2026
-- No USE statement. Scope: SQL workflow simulation.
SET @pass = 0;
SET @fail = 0;
SET @total = 0;

START TRANSACTION;

INSERT INTO physical_engine(engine_id,class_id,status)
VALUES (1629834,1,'ACTIVE'),(1629835,2,'ACTIVE');
INSERT INTO virtual_engine(virtual_engine_id,class_id,status)
VALUES (11243805,1,'ACTIVE'),(11243806,1,'ACTIVE');

INSERT INTO engine_attachment(engine_id,virtual_engine_id,class_id)
SELECT p.engine_id,v.virtual_engine_id,p.class_id
FROM physical_engine p JOIN virtual_engine v ON p.class_id=v.class_id
WHERE p.engine_id=1629834 AND v.virtual_engine_id=11243805;

INSERT INTO attachment_request(engine_id,virtual_engine_id,requested_by)
VALUES (1629835,11243806,'CT-06-test');

UPDATE virtual_engine v
JOIN physical_engine p ON p.engine_id=1629835
SET v.status='INACTIVE'
WHERE v.virtual_engine_id=11243806 AND p.class_id <> v.class_id;

UPDATE physical_engine p
JOIN virtual_engine v ON v.virtual_engine_id=11243806
SET p.status='QUARANTINED'
WHERE p.engine_id=1629835 AND p.class_id <> v.class_id
  AND v.status='INACTIVE';

UPDATE attachment_request
SET request_status='REJECTED'
WHERE engine_id=1629835 AND virtual_engine_id=11243806
  AND EXISTS (
      SELECT 1 FROM physical_engine p
      JOIN virtual_engine v ON v.virtual_engine_id=11243806
      WHERE p.engine_id=1629835
        AND p.class_id <> v.class_id
        AND v.status='INACTIVE'
  );

-- t1: matching attachment exists
SET @total = @total + 1;
SET @ok = IF((SELECT COUNT(*) FROM engine_attachment WHERE engine_id=1629834 AND virtual_engine_id=11243805) = 1, 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t1_match;

-- t2: mismatched virtual inactive
SET @total = @total + 1;
SET @ok = IF((SELECT status FROM virtual_engine WHERE virtual_engine_id=11243806) = 'INACTIVE', 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t2_virt_inactive;

-- t3: mismatched physical quarantined
SET @total = @total + 1;
SET @ok = IF((SELECT status FROM physical_engine WHERE engine_id=1629835) = 'QUARANTINED', 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t3_phys_quarantined;

-- t4: request rejected
SET @total = @total + 1;
SET @ok = IF((SELECT request_status FROM attachment_request WHERE engine_id=1629835 AND virtual_engine_id=11243806) = 'REJECTED', 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t4_request_rejected;

ROLLBACK;

-- t5: engine_attachment rolled back
SET @total = @total + 1;
SET @ok = IF((SELECT COUNT(*) FROM engine_attachment WHERE engine_id=1629834) = 0, 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t5_rollback_attach;

-- t6: attachment_request rolled back
SET @total = @total + 1;
SET @ok = IF((SELECT COUNT(*) FROM attachment_request WHERE engine_id=1629835) = 0, 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t6_rollback_request;

-- t7: physical_engine rolled back
SET @total = @total + 1;
SET @ok = IF((SELECT COUNT(*) FROM physical_engine WHERE engine_id IN (1629834,1629835)) = 0, 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t7_rollback_phys;

-- t8: virtual_engine rolled back
SET @total = @total + 1;
SET @ok = IF((SELECT COUNT(*) FROM virtual_engine WHERE virtual_engine_id IN (11243805,11243806)) = 0, 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t8_rollback_virt;

SELECT CONCAT('assertions=', @total, ' passed=', @pass) AS assertion_counts;
