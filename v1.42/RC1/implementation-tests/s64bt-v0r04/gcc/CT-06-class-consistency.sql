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
VALUES (__PHYS_MATCH__,1,'ACTIVE'),(__PHYS_MISMATCH__,2,'ACTIVE');
INSERT INTO virtual_engine(virtual_engine_id,class_id,status)
VALUES (__VIRT_MATCH__,1,'ACTIVE'),(__VIRT_MISMATCH__,1,'ACTIVE');

INSERT INTO engine_attachment(engine_id,virtual_engine_id,class_id)
SELECT p.engine_id,v.virtual_engine_id,p.class_id
FROM physical_engine p JOIN virtual_engine v ON p.class_id=v.class_id
WHERE p.engine_id=__PHYS_MATCH__ AND v.virtual_engine_id=__VIRT_MATCH__;

INSERT INTO attachment_request(engine_id,virtual_engine_id,requested_by)
VALUES (__PHYS_MISMATCH__,__VIRT_MISMATCH__,'CT-06-test');

UPDATE virtual_engine v
JOIN physical_engine p ON p.engine_id=__PHYS_MISMATCH__
SET v.status='INACTIVE'
WHERE v.virtual_engine_id=__VIRT_MISMATCH__ AND p.class_id <> v.class_id;

UPDATE physical_engine p
JOIN virtual_engine v ON v.virtual_engine_id=__VIRT_MISMATCH__
SET p.status='QUARANTINED'
WHERE p.engine_id=__PHYS_MISMATCH__ AND p.class_id <> v.class_id
  AND v.status='INACTIVE';

UPDATE attachment_request
SET request_status='REJECTED'
WHERE engine_id=__PHYS_MISMATCH__ AND virtual_engine_id=__VIRT_MISMATCH__
  AND EXISTS (
      SELECT 1 FROM physical_engine p
      JOIN virtual_engine v ON v.virtual_engine_id=__VIRT_MISMATCH__
      WHERE p.engine_id=__PHYS_MISMATCH__
        AND p.class_id <> v.class_id
        AND v.status='INACTIVE'
  );

-- t1: matching attachment exists
SET @total = @total + 1;
SET @ok = IF((SELECT COUNT(*) FROM engine_attachment WHERE engine_id=__PHYS_MATCH__ AND virtual_engine_id=__VIRT_MATCH__) = 1, 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t1_match;

-- t2: mismatched virtual inactive
SET @total = @total + 1;
SET @ok = IF((SELECT status FROM virtual_engine WHERE virtual_engine_id=__VIRT_MISMATCH__) = 'INACTIVE', 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t2_virt_inactive;

-- t3: mismatched physical quarantined
SET @total = @total + 1;
SET @ok = IF((SELECT status FROM physical_engine WHERE engine_id=__PHYS_MISMATCH__) = 'QUARANTINED', 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t3_phys_quarantined;

-- t4: request rejected
SET @total = @total + 1;
SET @ok = IF((SELECT request_status FROM attachment_request WHERE engine_id=__PHYS_MISMATCH__ AND virtual_engine_id=__VIRT_MISMATCH__) = 'REJECTED', 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t4_request_rejected;

ROLLBACK;

-- t5: engine_attachment rolled back
SET @total = @total + 1;
SET @ok = IF((SELECT COUNT(*) FROM engine_attachment WHERE engine_id=__PHYS_MATCH__) = 0, 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t5_rollback_attach;

-- t6: attachment_request rolled back
SET @total = @total + 1;
SET @ok = IF((SELECT COUNT(*) FROM attachment_request WHERE engine_id=__PHYS_MISMATCH__) = 0, 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t6_rollback_request;

-- t7: physical_engine rolled back
SET @total = @total + 1;
SET @ok = IF((SELECT COUNT(*) FROM physical_engine WHERE engine_id IN (__PHYS_MATCH__,__PHYS_MISMATCH__)) = 0, 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t7_rollback_phys;

-- t8: virtual_engine rolled back
SET @total = @total + 1;
SET @ok = IF((SELECT COUNT(*) FROM virtual_engine WHERE virtual_engine_id IN (__VIRT_MATCH__,__VIRT_MISMATCH__)) = 0, 1, 0);
SET @pass = @pass + @ok;
SET @fail = @fail + (1 - @ok);
SELECT @ok AS t8_rollback_virt;

SELECT CONCAT('assertions=', @total, ' passed=', @pass) AS assertion_counts;
