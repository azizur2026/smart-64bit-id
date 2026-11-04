USE s64_test;
START TRANSACTION;

INSERT INTO physical_engine(engine_id,class_id,status)
VALUES (1622747,1,'ACTIVE'),(1622748,2,'ACTIVE');
INSERT INTO virtual_engine(virtual_engine_id,class_id,status)
VALUES (9472051,1,'ACTIVE'),(9472052,1,'ACTIVE');

-- Matching Class: attachment succeeds.
INSERT INTO engine_attachment(engine_id,virtual_engine_id,class_id)
SELECT p.engine_id,v.virtual_engine_id,p.class_id
FROM physical_engine p JOIN virtual_engine v ON p.class_id=v.class_id
WHERE p.engine_id=1622747 AND v.virtual_engine_id=9472051;

-- Mismatching Class: record request, then compare actual Class values.
INSERT INTO attachment_request(engine_id,virtual_engine_id,requested_by)
VALUES (1622748,9472052,'CT-06-test');

UPDATE virtual_engine v
JOIN physical_engine p
  ON p.engine_id=1622748
SET v.status='INACTIVE'
WHERE v.virtual_engine_id=9472052
  AND p.class_id <> v.class_id;

UPDATE physical_engine p
JOIN virtual_engine v
  ON v.virtual_engine_id=9472052
SET p.status='QUARANTINED'
WHERE p.engine_id=1622748
  AND p.class_id <> v.class_id
  AND v.status='INACTIVE';

UPDATE attachment_request
SET request_status='REJECTED'
WHERE engine_id=1622748
  AND virtual_engine_id=9472052
  AND EXISTS (
      SELECT 1 FROM physical_engine p
      JOIN virtual_engine v ON v.virtual_engine_id=9472052
      WHERE p.engine_id=1622748
        AND p.class_id <> v.class_id
        AND v.status='INACTIVE'
  );

SELECT 'matching_attachment' AS check_name,
       COUNT(*)=1 AS passed
FROM engine_attachment
WHERE engine_id=1622747 AND virtual_engine_id=9472051;

SELECT 'mismatch_virtual_inactive' AS check_name,
       status='INACTIVE' AS passed
FROM virtual_engine WHERE virtual_engine_id=9472052;

SELECT 'mismatch_engine_quarantined' AS check_name,
       status='QUARANTINED' AS passed
FROM physical_engine WHERE engine_id=1622748;

SELECT 'mismatch_request_rejected' AS check_name,
       request_status='REJECTED' AS passed
FROM attachment_request
WHERE engine_id=1622748 AND virtual_engine_id=9472052;

ROLLBACK;
