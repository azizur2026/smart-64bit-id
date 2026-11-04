USE s64_test;
START TRANSACTION;

INSERT INTO physical_engine(engine_id,class_id,status)
VALUES (__PHYS_MATCH__,1,'ACTIVE'),(__PHYS_MISMATCH__,2,'ACTIVE');
INSERT INTO virtual_engine(virtual_engine_id,class_id,status)
VALUES (__VIRT_MATCH__,1,'ACTIVE'),(__VIRT_MISMATCH__,1,'ACTIVE');

-- Matching Class: attachment succeeds.
INSERT INTO engine_attachment(engine_id,virtual_engine_id,class_id)
SELECT p.engine_id,v.virtual_engine_id,p.class_id
FROM physical_engine p JOIN virtual_engine v ON p.class_id=v.class_id
WHERE p.engine_id=__PHYS_MATCH__ AND v.virtual_engine_id=__VIRT_MATCH__;

-- Mismatching Class: record request, then compare actual Class values.
INSERT INTO attachment_request(engine_id,virtual_engine_id,requested_by)
VALUES (__PHYS_MISMATCH__,__VIRT_MISMATCH__,'CT-06-test');

UPDATE virtual_engine v
JOIN physical_engine p
  ON p.engine_id=__PHYS_MISMATCH__
SET v.status='INACTIVE'
WHERE v.virtual_engine_id=__VIRT_MISMATCH__
  AND p.class_id <> v.class_id;

UPDATE physical_engine p
JOIN virtual_engine v
  ON v.virtual_engine_id=__VIRT_MISMATCH__
SET p.status='QUARANTINED'
WHERE p.engine_id=__PHYS_MISMATCH__
  AND p.class_id <> v.class_id
  AND v.status='INACTIVE';

UPDATE attachment_request
SET request_status='REJECTED'
WHERE engine_id=__PHYS_MISMATCH__
  AND virtual_engine_id=__VIRT_MISMATCH__
  AND EXISTS (
      SELECT 1 FROM physical_engine p
      JOIN virtual_engine v ON v.virtual_engine_id=__VIRT_MISMATCH__
      WHERE p.engine_id=__PHYS_MISMATCH__
        AND p.class_id <> v.class_id
        AND v.status='INACTIVE'
  );

SELECT 'matching_attachment' AS check_name,
       COUNT(*)=1 AS passed
FROM engine_attachment
WHERE engine_id=__PHYS_MATCH__ AND virtual_engine_id=__VIRT_MATCH__;

SELECT 'mismatch_virtual_inactive' AS check_name,
       status='INACTIVE' AS passed
FROM virtual_engine WHERE virtual_engine_id=__VIRT_MISMATCH__;

SELECT 'mismatch_engine_quarantined' AS check_name,
       status='QUARANTINED' AS passed
FROM physical_engine WHERE engine_id=__PHYS_MISMATCH__;

SELECT 'mismatch_request_rejected' AS check_name,
       request_status='REJECTED' AS passed
FROM attachment_request
WHERE engine_id=__PHYS_MISMATCH__ AND virtual_engine_id=__VIRT_MISMATCH__;

ROLLBACK;
