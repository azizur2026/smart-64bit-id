-- ============================================================================
-- SMART 64-Bit ID v1.42 (Version 0, Revision 0010)
-- QDH Reference Relational Schema — MySQL 8.0.16+
-- STATUS: RC2.2 (final) — aligned to SPECIFICATION.md, ERROR-CODES.md,
--         QDH-SPECIFICATION.md, QDH-ERROR-CODES.md, QDH-LOGGING-AND-LIFECYCLE.md
-- LICENSE: AGPL3   CONTACT: contact@samara.com.bd
-- ============================================================================
-- BIT LAYOUT (frozen core §2): 63 Version=0 | 62..59 Revision=0010 | 58 Role
--   57..54 Reserved=0000 | 53..50 Class | 49..29 Engine | 28..0 Local
-- IDENTITY KEY: (Class, Engine, Local)   VIRTUAL ENGINE KEY: (Class, Engine)
-- ============================================================================
-- ROLE MAPPING (core §6.3.2, four separated roles)
--   s64_controller_role   : control table, nodes, leases, watermark ranges
--   s64_allocator_role    : EXECUTE only; writes occur inside definer routines
--   qdh_policy_engine_role: audit events, attestations, nonces, transitions
--   s64_auditor_role      : read-only
-- Cross-role writes are performed by SQL SECURITY DEFINER procedures only.
-- ============================================================================
-- STRUCTURED ERROR SURFACE (8 fields, QDH-ERROR-CODES.md §1)
--   'QDH-Exxx|S64-Exxx|<operation_class>|<class_id>|<engine_id>|<local_id>|<epoch>|<human>'
-- SQLSTATE classes: 45001 allocation/identity | 45002 lineage/immutability
--                   45003 epoch fencing        | 45004 attestation
--                   45005 audit chain          | 45006 evidence/ordering
-- ============================================================================
-- WHAT THIS SCHEMA PROVES FOR AUDIT EVENTS
--   1. stream linkage (prev_event_hash = prior event_hash, seq contiguous)
--   2. event_hash = SHA2(payload_canonical, 256)
--   3. semantic correspondence between the JSON projection and the canonical bytes
-- It cannot prove that payload_canonical is the RFC 8785 serialization of the
-- projection; that is the application's obligation, checked by the golden vectors.
-- ============================================================================

SET NAMES utf8mb4;
SET time_zone = '+00:00';
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------------
-- 1. Physical nodes  (core §6.3.2: node is its own entity)
-- ---------------------------------------------------------------------------
CREATE TABLE physical_nodes (
    node_id             VARCHAR(128) NOT NULL,
    node_state          VARCHAR(32)  NOT NULL,
    network_address     VARCHAR(64)  NOT NULL,
    hardware_address    VARCHAR(32)  NOT NULL,
    substrate_attested  TINYINT      NOT NULL DEFAULT 0,
    quarantined_at_utc  DATETIME(6)  NULL,
    unfit_at_utc        DATETIME(6)  NULL,
    created_at_utc      DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at_utc      DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                                     ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (node_id),
    UNIQUE KEY uq_node_hw (hardware_address),
    CONSTRAINT chk_node_state CHECK (node_state IN
        ('NODE_ACTIVE','NODE_QUARANTINED','NODE_UNFIT','NODE_RETIRED')),
    CONSTRAINT chk_node_qts CHECK (
        (node_state <> 'NODE_QUARANTINED' AND quarantined_at_utc IS NULL)
     OR (node_state =  'NODE_QUARANTINED' AND quarantined_at_utc IS NOT NULL)),
    CONSTRAINT chk_node_uts CHECK (
        (node_state <> 'NODE_UNFIT' AND unfit_at_utc IS NULL)
     OR (node_state =  'NODE_UNFIT' AND unfit_at_utc IS NOT NULL))
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 2. Virtual engines  (core §6.3.1 / §6.3.2)
-- ---------------------------------------------------------------------------
CREATE TABLE virtual_engines (
    class_id             SMALLINT     NOT NULL,
    engine_id            INT          NOT NULL,
    active_profile       VARCHAR(32)  NOT NULL,
    generation_epoch     BIGINT       NOT NULL DEFAULT 1,
    lifecycle_state      VARCHAR(32)  NOT NULL,
    local_watermark      BIGINT       NOT NULL DEFAULT 0,
    physical_node_id     VARCHAR(128) NOT NULL,
    allocator_lease_id   CHAR(36)     NULL,
    lineage              JSON         NOT NULL,
    created_at_utc       DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at_utc       DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                                      ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (class_id, engine_id),
    KEY idx_ve_rollover_pool (class_id, lifecycle_state, engine_id, local_watermark),
    KEY idx_ve_node (physical_node_id, lifecycle_state),
    CONSTRAINT fk_ve_node FOREIGN KEY (physical_node_id)
        REFERENCES physical_nodes(node_id) ON DELETE RESTRICT,

    CONSTRAINT chk_ve_class   CHECK (class_id BETWEEN 1 AND 8),
    CONSTRAINT chk_ve_engine  CHECK (engine_id BETWEEN 0 AND 2097151),
    CONSTRAINT chk_ve_profile CHECK (active_profile IN ('v1.41','v1.42')),
    CONSTRAINT chk_ve_epoch   CHECK (generation_epoch >= 1),
    CONSTRAINT chk_ve_state   CHECK (lifecycle_state IN (
        'STATE_UNALLOCATED','STATE_ACTIVE','STATE_QUARANTINED',
        'STATE_DE_VERIFYING','STATE_HE_SANITIZING','STATE_RECLAIM_COMMIT',
        'STATE_EXHAUSTED','STATE_RETIRED_PERMANENT')),
    CONSTRAINT chk_ve_watermark CHECK (local_watermark BETWEEN 0 AND 536870912),
    CONSTRAINT chk_ve_exhausted_wm CHECK (
        local_watermark < 536870912
        OR lifecycle_state IN ('STATE_EXHAUSTED','STATE_RETIRED_PERMANENT')),
    CONSTRAINT chk_ve_active_lease CHECK (
        lifecycle_state <> 'STATE_ACTIVE' OR allocator_lease_id IS NOT NULL),
    CONSTRAINT chk_ve_lineage_json  CHECK (JSON_VALID(lineage) = 1),
    CONSTRAINT chk_ve_lineage_array CHECK (JSON_TYPE(lineage) = 'ARRAY')
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 3. Identity records  (core §5.3, §10.1, §10.6)
-- ---------------------------------------------------------------------------
CREATE TABLE identity_records (
    class_id              SMALLINT       NOT NULL,
    engine_id             INT            NOT NULL,
    local_id              INT            NOT NULL,
    full_smart_id         BIGINT UNSIGNED NOT NULL,
    role_bit              TINYINT        NOT NULL,
    allocated_profile     VARCHAR(32)    NOT NULL,
    allocated_epoch       BIGINT         NOT NULL,
    history_chain_root_id CHAR(64)       NOT NULL,
    predecessor_smart_id  BIGINT UNSIGNED NULL,
    is_active             TINYINT        NOT NULL DEFAULT 0,
    is_retired            TINYINT        NOT NULL DEFAULT 0,
    allocated_at_utc      DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    activated_at_utc      DATETIME(6)    NULL,
    retired_at_utc        DATETIME(6)    NULL,
    active_chain_marker   CHAR(64) GENERATED ALWAYS AS
                          (IF(is_active = 1, history_chain_root_id, NULL)) STORED,
    PRIMARY KEY (class_id, engine_id, local_id),
    UNIQUE KEY uq_ir_full_smart_id (full_smart_id),
    UNIQUE KEY uq_ir_active_chain (active_chain_marker),
    UNIQUE KEY uq_ir_predecessor (predecessor_smart_id),
    KEY idx_ir_chain (history_chain_root_id),
    CONSTRAINT fk_ir_ve FOREIGN KEY (class_id, engine_id)
        REFERENCES virtual_engines(class_id, engine_id) ON DELETE RESTRICT,
    CONSTRAINT chk_ir_class     CHECK (class_id BETWEEN 1 AND 8),
    CONSTRAINT chk_ir_engine    CHECK (engine_id BETWEEN 0 AND 2097151),
    CONSTRAINT chk_ir_local     CHECK (local_id BETWEEN 0 AND 536870911),
    CONSTRAINT chk_ir_role      CHECK (role_bit IN (0,1)),
    CONSTRAINT chk_ir_profile   CHECK (allocated_profile IN ('v1.41','v1.42')),
    CONSTRAINT chk_ir_flags     CHECK (is_active IN (0,1) AND is_retired IN (0,1)),
    CONSTRAINT chk_ir_not_both  CHECK (NOT (is_active = 1 AND is_retired = 1)),
    CONSTRAINT chk_ir_activated CHECK (
        (is_active = 1 AND activated_at_utc IS NOT NULL)
     OR (is_active = 0 AND activated_at_utc IS NULL)),
    CONSTRAINT chk_ir_retired_ts CHECK (
        (is_retired = 0 AND retired_at_utc IS NULL)
     OR (is_retired = 1 AND retired_at_utc IS NOT NULL))
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 4. Coordinate tombstones  (core §10.3)
-- ---------------------------------------------------------------------------
CREATE TABLE coordinate_tombstones (
    class_id        SMALLINT    NOT NULL,
    engine_id       INT         NOT NULL,
    local_id        INT         NOT NULL,
    allocated_profile VARCHAR(32) NOT NULL,
    allocated_epoch BIGINT      NOT NULL,
    status          VARCHAR(16) NOT NULL,
    recorded_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (class_id, engine_id, local_id),
    CONSTRAINT fk_ct_ve FOREIGN KEY (class_id, engine_id)
        REFERENCES virtual_engines(class_id, engine_id) ON DELETE RESTRICT,
    CONSTRAINT chk_ct_status CHECK (status IN ('CONSUMED','RETIRED')),
    CONSTRAINT chk_ct_epoch  CHECK (allocated_epoch >= 1),
    CONSTRAINT chk_ct_local  CHECK (local_id BETWEEN 0 AND 536870911)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 5. Durable allocation log  (core §7.3, append-only)
-- ---------------------------------------------------------------------------
CREATE TABLE durable_allocation_log (
    class_id    SMALLINT    NOT NULL,
    engine_id   INT         NOT NULL,
    local_id    INT         NOT NULL,
    epoch       BIGINT      NOT NULL,
    profile     VARCHAR(32) NOT NULL,
    role_bit    TINYINT     NOT NULL,
    full_smart_id BIGINT UNSIGNED NOT NULL,
    recorded_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (class_id, engine_id, local_id),
    CONSTRAINT fk_dal_ve FOREIGN KEY (class_id, engine_id)
        REFERENCES virtual_engines(class_id, engine_id) ON DELETE RESTRICT,
    CONSTRAINT chk_dal_epoch CHECK (epoch >= 1),
    CONSTRAINT chk_dal_local CHECK (local_id BETWEEN 0 AND 536870911)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 6. Lease watermarks  (core §7.3)
-- ---------------------------------------------------------------------------
CREATE TABLE lease_watermarks (
    lease_id      CHAR(36)    NOT NULL,
    class_id      SMALLINT    NOT NULL,
    engine_id     INT         NOT NULL,
    lease_floor   BIGINT      NOT NULL,
    lease_ceiling BIGINT      NOT NULL,
    release_state VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
    recorded_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (lease_id),
    UNIQUE KEY uq_lw_range (class_id, engine_id, lease_floor),
    CONSTRAINT fk_lw_ve FOREIGN KEY (class_id, engine_id)
        REFERENCES virtual_engines(class_id, engine_id) ON DELETE RESTRICT,
    CONSTRAINT chk_lw_order CHECK (lease_floor >= 0 AND lease_ceiling <= 536870912
                                   AND lease_floor < lease_ceiling),
    CONSTRAINT chk_lw_state CHECK (release_state IN ('ACTIVE','CONSUMED','RELEASED'))
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 7. Allocator leases  (core §7.4, §10.7.3; QDH §4.5)
-- ---------------------------------------------------------------------------
CREATE TABLE allocator_leases (
    lease_id          CHAR(36)    NOT NULL,
    class_id          SMALLINT    NOT NULL,
    engine_id         INT         NOT NULL,
    generation_epoch  BIGINT      NOT NULL,
    issued_at_utc     DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    expires_at_utc    DATETIME(6) NOT NULL,
    revoked_at_utc    DATETIME(6) NULL,
    lease_signature   TEXT        NOT NULL,
    signing_trust_root_id CHAR(64) NOT NULL,
    active_lease_key  CHAR(64) GENERATED ALWAYS AS
                      (IF(revoked_at_utc IS NULL,
                          CONCAT(class_id, ':', engine_id), NULL)) STORED,
    PRIMARY KEY (lease_id),
    UNIQUE KEY uq_al_active (active_lease_key),
    CONSTRAINT fk_al_ve FOREIGN KEY (class_id, engine_id)
        REFERENCES virtual_engines(class_id, engine_id) ON DELETE RESTRICT,
    CONSTRAINT chk_al_epoch CHECK (generation_epoch >= 1)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 8. Trust roots  (attestation allowlist)
-- ---------------------------------------------------------------------------
CREATE TABLE trust_roots (
    trust_root_id      CHAR(64)    NOT NULL,
    platform           VARCHAR(128) NOT NULL,
    measurement_digest CHAR(64)    NOT NULL,
    valid_from_utc     DATETIME(6) NOT NULL,
    valid_to_utc       DATETIME(6) NOT NULL,
    revoked_at_utc     DATETIME(6) NULL,
    created_at_utc     DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (trust_root_id),
    CONSTRAINT chk_tr_window CHECK (valid_to_utc > valid_from_utc)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 9. Nonce registry  (single-use challenges)
-- ---------------------------------------------------------------------------
CREATE TABLE nonce_registry (
    nonce               CHAR(64)    NOT NULL,
    class_id            SMALLINT    NOT NULL,
    engine_id           INT         NOT NULL,
    generation_epoch    BIGINT      NOT NULL,
    incident_id         VARCHAR(64) NOT NULL,
    issued_at_utc       DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    consumed_at_utc     DATETIME(6) NULL,
    PRIMARY KEY (nonce),
    CONSTRAINT chk_nr_epoch CHECK (generation_epoch >= 1)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 10. Hardware attestations  (QDH §4.3 step 4)
-- ---------------------------------------------------------------------------
CREATE TABLE hardware_attestations (
    attestation_id        BIGINT      NOT NULL AUTO_INCREMENT,
    class_id              SMALLINT    NOT NULL,
    engine_id             INT         NOT NULL,
    bound_generation_epoch BIGINT     NOT NULL,
    bound_incident_id     VARCHAR(64) NOT NULL,
    challenge_nonce       CHAR(64)    NOT NULL,
    attestation_digest    CHAR(64)    NOT NULL,
    signing_trust_root_id CHAR(64)    NOT NULL,
    sanitization_method   VARCHAR(16) NOT NULL,
    verification_result   VARCHAR(16) NOT NULL,
    cert_not_before_utc   DATETIME(6) NOT NULL,
    cert_not_after_utc    DATETIME(6) NOT NULL,
    revocation_checked_at_utc DATETIME(6) NOT NULL,
    verified_at_utc       DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (attestation_id),
    UNIQUE KEY uq_ha_nonce (challenge_nonce),
    CONSTRAINT fk_ha_root FOREIGN KEY (signing_trust_root_id)
        REFERENCES trust_roots(trust_root_id) ON DELETE RESTRICT,
    CONSTRAINT fk_ha_nonce FOREIGN KEY (challenge_nonce)
        REFERENCES nonce_registry(nonce) ON DELETE RESTRICT,
    CONSTRAINT chk_ha_method CHECK (sanitization_method IN ('CLEAR','PURGE','DESTROY')),
    CONSTRAINT chk_ha_result CHECK (verification_result IN ('PASS','FAIL')),
    CONSTRAINT chk_ha_window CHECK (cert_not_after_utc > cert_not_before_utc)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 11. Event-type registry  (QDH-LOGGING §3)
-- ---------------------------------------------------------------------------
CREATE TABLE event_type_registry (
    event_type          VARCHAR(64) NOT NULL,
    is_core             TINYINT     NOT NULL DEFAULT 0,
    description         VARCHAR(255) NOT NULL,
    registered_at_utc   DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (event_type),
    CONSTRAINT chk_et_core CHECK (is_core IN (0,1))
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 12. Incident trigger-class registry  (QDH-LOGGING §5)
-- ---------------------------------------------------------------------------
CREATE TABLE incident_trigger_class (
    trigger_class       VARCHAR(64) NOT NULL,
    is_core             TINYINT     NOT NULL DEFAULT 0,
    description         VARCHAR(255) NOT NULL,
    registered_at_utc   DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (trigger_class),
    CONSTRAINT chk_itc_core CHECK (is_core IN (0,1))
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 13. QDH audit events  (QDH-LOGGING §1, §2)
-- ---------------------------------------------------------------------------
CREATE TABLE qdh_audit_events (
    event_id          CHAR(36)    NOT NULL,
    class_id          SMALLINT    NOT NULL,
    engine_id         INT         NOT NULL,
    stream_seq        BIGINT      NOT NULL,
    event_type        VARCHAR(64) NOT NULL,
    generation_epoch  BIGINT      NOT NULL,
    timestamp_utc     DATETIME(6) NOT NULL,
    previous_state    VARCHAR(32) NOT NULL,
    new_state         VARCHAR(32) NOT NULL,
    epoch_before      BIGINT      NOT NULL,
    epoch_after       BIGINT      NOT NULL,
    profile_before    VARCHAR(32) NOT NULL,
    profile_after     VARCHAR(32) NOT NULL,
    watermark_verified BIGINT     NULL,
    qdh_error_code    VARCHAR(16) NULL,
    s64_error_code    VARCHAR(16) NULL,
    prev_event_hash   CHAR(64)    NOT NULL,
    event_hash        CHAR(64)    NOT NULL,
    payload_canonical LONGTEXT    NOT NULL,
    payload           JSON        NOT NULL,
    PRIMARY KEY (event_id),
    UNIQUE KEY uq_qae_stream (class_id, engine_id, stream_seq),
    UNIQUE KEY uq_qae_hash (event_hash),
    KEY idx_qae_type (event_type),
    CONSTRAINT fk_qae_ve FOREIGN KEY (class_id, engine_id)
        REFERENCES virtual_engines(class_id, engine_id) ON DELETE RESTRICT,
    CONSTRAINT fk_qae_type FOREIGN KEY (event_type)
        REFERENCES event_type_registry(event_type) ON DELETE RESTRICT,
    CONSTRAINT chk_qae_seq CHECK (stream_seq >= 1),
    CONSTRAINT chk_qae_epoch CHECK (generation_epoch >= 1
                                    AND epoch_before >= 1 AND epoch_after >= 1),
    CONSTRAINT chk_qae_hash CHECK (event_hash REGEXP '^[0-9a-f]{64}$'),
    CONSTRAINT chk_qae_prev CHECK (prev_event_hash REGEXP '^[0-9a-f]{64}$'),
    CONSTRAINT chk_qae_payload CHECK (JSON_VALID(payload) = 1)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- 14. Audit anchors  (QDH §7)
-- ---------------------------------------------------------------------------
CREATE TABLE audit_anchors (
    anchor_id      BIGINT      NOT NULL AUTO_INCREMENT,
    root_hash      CHAR(64)    NOT NULL,
    anchor_uri     VARCHAR(512) NOT NULL,
    covers_from_utc DATETIME(6) NOT NULL,
    covers_to_utc  DATETIME(6) NOT NULL,
    anchored_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (anchor_id),
    UNIQUE KEY uq_anchor_root (root_hash),
    CONSTRAINT chk_anchor_window CHECK (covers_to_utc > covers_from_utc)
) ENGINE=InnoDB;

-- ============================================================================
-- PART 2 — Functions, procedures, triggers, views, grants, seed data
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 15. Functions
-- ---------------------------------------------------------------------------
DELIMITER $$

CREATE FUNCTION fn_expected_smart_id_v142(
    p_class SMALLINT, p_engine INT, p_local INT, p_role TINYINT
) RETURNS BIGINT UNSIGNED
    DETERMINISTIC NO SQL
BEGIN
    RETURN ((2 << 59)                     -- Version 0, Revision 0010
          | (p_role    << 58)
          | (p_class   << 50)
          | (p_engine  << 29)
          |  p_local);
END$$

-- Golden-vector verifier (QDH-LOGGING §1.2): compares SHA-256 of the exact
-- canonical bytes against the expected digest.
CREATE FUNCTION verify_audit_vector(
    p_canonical LONGTEXT, p_expected CHAR(64)
) RETURNS TINYINT
    DETERMINISTIC NO SQL
BEGIN
    RETURN (SHA2(p_canonical, 256) <=> LOWER(p_expected));
END$$

-- ---------------------------------------------------------------------------
-- 16. Procedures
-- ---------------------------------------------------------------------------

-- Allocate exactly the next Local coordinate. Precedence per core §16.2:
-- authority/epoch -> lifecycle/host -> range -> watermark.
CREATE PROCEDURE s64_allocate(
    IN  p_class      SMALLINT,
    IN  p_engine     INT,
    IN  p_local      INT,
    IN  p_role       TINYINT,
    IN  p_profile    VARCHAR(32),
    IN  p_epoch      BIGINT,
    IN  p_chain_root CHAR(64),
    IN  p_pred       BIGINT UNSIGNED,
    OUT p_full_id    BIGINT UNSIGNED
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_state   VARCHAR(32);
    DECLARE v_epoch   BIGINT;
    DECLARE v_wm      BIGINT;
    DECLARE v_node    VARCHAR(128);
    DECLARE v_lease   CHAR(36);
    DECLARE v_msg     VARCHAR(512);
    DECLARE v_revoked DATETIME(6);
    DECLARE v_expires DATETIME(6);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_local IS NULL OR p_local < 0 OR p_local > 536870911 THEN
        SET v_msg = CONCAT('QDH-E020|S64-E023|COMMIT|', IFNULL(p_class,0), '|',
                           IFNULL(p_engine,0), '|', IFNULL(p_local,0), '|',
                           IFNULL(p_epoch,0), '|Local coordinate out of range');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;

    START TRANSACTION;

    SELECT lifecycle_state, generation_epoch, local_watermark, physical_node_id,
           allocator_lease_id
      INTO v_state, v_epoch, v_wm, v_node, v_lease
      FROM virtual_engines
     WHERE class_id = p_class AND engine_id = p_engine
     FOR UPDATE;

    IF v_state IS NULL THEN
        SET v_msg = CONCAT('QDH-E019|S64-E013|COMMIT|', p_class, '|', p_engine,
                           '|', p_local, '|', p_epoch,
                           '|(Class,Engine) does not resolve to a control-table row');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF v_lease IS NULL THEN
        SET v_msg = CONCAT('QDH-E003|S64-E019|COMMIT|', p_class, '|', p_engine,
                           '|', p_local, '|', v_epoch,
                           '|No allocator authority attached to engine');
        SIGNAL SQLSTATE '45003' SET MESSAGE_TEXT = v_msg;
    END IF;

    SELECT revoked_at_utc, expires_at_utc, generation_epoch
      INTO v_revoked, v_expires, v_epoch
      FROM allocator_leases WHERE lease_id = v_lease;

    IF v_revoked IS NOT NULL OR v_expires <= UTC_TIMESTAMP(6) THEN
        SET v_msg = CONCAT('QDH-E003|S64-E019|COMMIT|', p_class, '|', p_engine,
                           '|', p_local, '|', v_epoch,
                           '|Allocator lease revoked or expired');
        SIGNAL SQLSTATE '45003' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF p_epoch <> v_epoch THEN
        SET v_msg = CONCAT('QDH-E003|S64-E019|COMMIT|', p_class, '|', p_engine,
                           '|', p_local, '|', v_epoch,
                           '|Generation epoch does not match current epoch');
        SIGNAL SQLSTATE '45003' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF v_state <> 'STATE_ACTIVE' THEN
        SET v_msg = CONCAT('QDH-E018|S64-E031|COMMIT|', p_class, '|', p_engine,
                           '|', p_local, '|', v_epoch,
                           '|Engine state does not admit allocation');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF (SELECT node_state FROM physical_nodes WHERE node_id = v_node) <> 'NODE_ACTIVE' THEN
        SET v_msg = CONCAT('QDH-E007|S64-E021|COMMIT|', p_class, '|', p_engine,
                           '|', p_local, '|', v_epoch,
                           '|Hosting node is not NODE_ACTIVE');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF p_local < v_wm THEN
        SET v_msg = CONCAT('QDH-E014|S64-E018|COMMIT|', p_class, '|', p_engine,
                           '|', p_local, '|', v_epoch,
                           '|Local coordinate below the non-reuse floor');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF p_local > v_wm THEN
        SET v_msg = CONCAT('QDH-E020|S64-E023|COMMIT|', p_class, '|', p_engine,
                           '|', p_local, '|', v_epoch,
                           '|Unrecorded forward gap; allocation must resume at next_safe_local');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;

    SET p_full_id = fn_expected_smart_id_v142(p_class, p_engine, p_local, p_role);

    INSERT INTO identity_records
        (class_id, engine_id, local_id, full_smart_id, role_bit,
         allocated_profile, allocated_epoch, history_chain_root_id, predecessor_smart_id)
    VALUES
        (p_class, p_engine, p_local, p_full_id, p_role,
         p_profile, p_epoch, p_chain_root, p_pred);

    INSERT INTO durable_allocation_log
        (class_id, engine_id, local_id, epoch, profile, role_bit, full_smart_id)
    VALUES
        (p_class, p_engine, p_local, p_epoch, p_profile, p_role, p_full_id);

    UPDATE virtual_engines
       SET local_watermark = p_local + 1
     WHERE class_id = p_class AND engine_id = p_engine
       AND generation_epoch = p_epoch;

    IF ROW_COUNT() <> 1 THEN
        SET v_msg = CONCAT('QDH-E003|S64-E019|COMMIT|', p_class, '|', p_engine,
                           '|', p_local, '|', p_epoch,
                           '|Epoch-fenced update affected no row');
        SIGNAL SQLSTATE '45003' SET MESSAGE_TEXT = v_msg;
    END IF;

    COMMIT;
END$$

-- Contiguous batch allocation (core §7.2). Consumes [p_from, p_from + p_count).
CREATE PROCEDURE s64_allocate_range(
    IN p_class SMALLINT, IN p_engine INT, IN p_from INT, IN p_count INT,
    IN p_role TINYINT, IN p_profile VARCHAR(32), IN p_epoch BIGINT,
    IN p_chain_root CHAR(64)
)
    MODIFIES SQL DATA
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE v_id BIGINT UNSIGNED;
    WHILE i < p_count DO
        CALL s64_allocate(p_class, p_engine, p_from + i, p_role, p_profile,
                          p_epoch, p_chain_root, NULL, v_id);
        SET i = i + 1;
    END WHILE;
END$$

-- Retirement of a single identity record (core §10.1, §10.5, §10.7.2 exemption).
CREATE PROCEDURE s64_retire(
    IN p_class SMALLINT, IN p_engine INT, IN p_local INT
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_msg VARCHAR(512);
    DECLARE v_active TINYINT;
    DECLARE v_retired TINYINT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT is_active, is_retired INTO v_active, v_retired
      FROM identity_records
     WHERE class_id = p_class AND engine_id = p_engine AND local_id = p_local
     FOR UPDATE;

    IF v_active IS NULL THEN
        SET v_msg = CONCAT('QDH-E019|S64-E013|RETIREMENT|', p_class, '|', p_engine,
                           '|', p_local, '|0', '|Identity record not found');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF v_retired = 1 THEN
        SET v_msg = CONCAT('QDH-E018|S64-E031|RETIREMENT|', p_class, '|', p_engine,
                           '|', p_local, '|0', '|Record already retired');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;

    UPDATE identity_records
       SET is_active = 0, activated_at_utc = NULL,
           is_retired = 1, retired_at_utc = UTC_TIMESTAMP(6)
     WHERE class_id = p_class AND engine_id = p_engine AND local_id = p_local;


    COMMIT;
END$$

-- Authoritative quarantine entry point (QDH §4.1).
CREATE PROCEDURE qdh_begin_quarantine(
    IN p_node_id VARCHAR(128)
)
    MODIFIES SQL DATA
    COMMENT 'Fencing primitive only. The calling control plane MUST, in the same transaction, insert one NODE_QUARANTINE_TRIGGERED audit event per affected engine and record the incident. Gaps are reported by qdh_audit_gap.'
BEGIN
    UPDATE physical_nodes
       SET node_state = 'NODE_QUARANTINED', quarantined_at_utc = UTC_TIMESTAMP(6)
     WHERE node_id = p_node_id AND node_state = 'NODE_ACTIVE';
END$$

DELIMITER ;

-- ============================================================================
-- PART 3 — Triggers
-- Structured surface: 'QDH-Exxx|S64-Exxx|<operation_class>|<class>|<engine>|<local>|<epoch>|<human>'
-- A '-' in the QDH position means no QDH subsystem code applies: the condition
-- is a pure core boundary condition and the S64 code is authoritative.
-- ============================================================================
DELIMITER $$

-- ---------------------------------------------------------------------------
-- Physical node blast radius (QDH-D5, §4.1)
-- ---------------------------------------------------------------------------
CREATE TRIGGER trg_pn_after_update
AFTER UPDATE ON physical_nodes
FOR EACH ROW
BEGIN
    IF NEW.node_state = 'NODE_QUARANTINED'
       AND OLD.node_state <> 'NODE_QUARANTINED' THEN

        UPDATE allocator_leases al
          JOIN virtual_engines ve
            ON ve.class_id = al.class_id AND ve.engine_id = al.engine_id
           SET al.revoked_at_utc = UTC_TIMESTAMP(6)
         WHERE ve.physical_node_id = NEW.node_id
           AND al.revoked_at_utc IS NULL;

        UPDATE virtual_engines
           SET lifecycle_state = 'STATE_QUARANTINED',
               allocator_lease_id = NULL
         WHERE physical_node_id = NEW.node_id
           AND lifecycle_state NOT IN ('STATE_RETIRED_PERMANENT','STATE_QUARANTINED');
    END IF;
END$$

-- ---------------------------------------------------------------------------
-- Virtual engines: insert
-- ---------------------------------------------------------------------------
CREATE TRIGGER trg_ve_before_insert
BEFORE INSERT ON virtual_engines
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    DECLARE v_node_state VARCHAR(32);
    DECLARE v_att TINYINT;

    IF NEW.lifecycle_state <> 'STATE_UNALLOCATED' THEN
        SET v_msg = CONCAT('QDH-E018|S64-E031|CONTROL|', NEW.class_id, '|', NEW.engine_id,
                           '|0|', NEW.generation_epoch,
                           '|Initial insert must be STATE_UNALLOCATED');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF NEW.generation_epoch <> 1 OR NEW.local_watermark <> 0
       OR JSON_LENGTH(NEW.lineage) <> 0 THEN
        SET v_msg = CONCAT('QDH-E018|S64-E031|CONTROL|', NEW.class_id, '|', NEW.engine_id,
                           '|0|1|Initial generation must be epoch 1, watermark 0, empty lineage');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;

    SELECT node_state, substrate_attested
      INTO v_node_state, v_att
      FROM physical_nodes WHERE node_id = NEW.physical_node_id;

    IF v_node_state IS NULL THEN
        SET v_msg = CONCAT('QDH-E019|S64-E013|CONTROL|', NEW.class_id, '|', NEW.engine_id,
                           '|0|1|Hosting node not found');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF v_node_state <> 'NODE_ACTIVE' OR v_att <> 1 THEN
        SET v_msg = CONCAT('QDH-E007|S64-E021|CONTROL|', NEW.class_id, '|', NEW.engine_id,
                           '|0|1|Binding requires a NODE_ACTIVE, attested host');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;
END$$

-- ---------------------------------------------------------------------------
-- Virtual engines: update  (single consolidated trigger, fixed order)
-- ---------------------------------------------------------------------------
CREATE TRIGGER trg_ve_before_update
BEFORE UPDATE ON virtual_engines
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    DECLARE v_len_o INT;
    DECLARE v_len_n INT;
    DECLARE v_last JSON;
    DECLARE v_le_epoch BIGINT;
    DECLARE v_le_start BIGINT;
    DECLARE v_le_end BIGINT;
    DECLARE v_le_reason VARCHAR(32);
    DECLARE v_le_event CHAR(36);
    DECLARE v_cnt INT;
    DECLARE v_node_state VARCHAR(32);
    DECLARE v_lr_revoked DATETIME(6);
    DECLARE v_lr_expires DATETIME(6);
    DECLARE v_lr_epoch BIGINT;
    DECLARE v_lr_class SMALLINT;
    DECLARE v_lr_engine INT;

    -- 1. Key immutability
    IF NEW.class_id <> OLD.class_id OR NEW.engine_id <> OLD.engine_id THEN
        SET v_msg = CONCAT('QDH-E018|S64-E031|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                           '|0|', OLD.generation_epoch,
                           '|Control-table key is immutable');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- 2. Watermark monotonicity
    IF NEW.local_watermark < OLD.local_watermark THEN
        SET v_msg = CONCAT('QDH-E014|S64-E018|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                           '|', NEW.local_watermark, '|', OLD.generation_epoch,
                           '|Local watermark regression');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- 3. Profile change is only the §13.1 upgrade path
    IF NOT (NEW.active_profile <=> OLD.active_profile) THEN
        IF NEW.lifecycle_state <> OLD.lifecycle_state
           OR OLD.lifecycle_state <> 'STATE_ACTIVE' THEN
            SET v_msg = CONCAT('QDH-E018|S64-E031|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                               '|0|', OLD.generation_epoch,
                               '|Profile change outside the explicit upgrade procedure');
            SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
        END IF;
        IF NEW.generation_epoch <> OLD.generation_epoch + 1 THEN
            SET v_msg = CONCAT('QDH-E018|S64-E031|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                               '|0|', OLD.generation_epoch,
                               '|Profile change must open a new generation');
            SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
        END IF;
    END IF;

    -- 4. State transition whitelist, with universal quarantine entry
    IF NEW.lifecycle_state <> OLD.lifecycle_state THEN
        IF NOT (
               (OLD.lifecycle_state IN ('STATE_UNALLOCATED','STATE_ACTIVE',
                                        'STATE_DE_VERIFYING','STATE_HE_SANITIZING',
                                        'STATE_RECLAIM_COMMIT','STATE_EXHAUSTED')
                AND NEW.lifecycle_state = 'STATE_QUARANTINED')
            OR (OLD.lifecycle_state = 'STATE_UNALLOCATED' AND NEW.lifecycle_state = 'STATE_ACTIVE')
            OR (OLD.lifecycle_state = 'STATE_QUARANTINED'
                AND NEW.lifecycle_state IN ('STATE_DE_VERIFYING','STATE_RETIRED_PERMANENT'))
            OR (OLD.lifecycle_state = 'STATE_ACTIVE'
                AND NEW.lifecycle_state IN ('STATE_EXHAUSTED','STATE_RETIRED_PERMANENT'))
            OR (OLD.lifecycle_state = 'STATE_DE_VERIFYING'
                AND NEW.lifecycle_state IN ('STATE_HE_SANITIZING','STATE_EXHAUSTED',
                                            'STATE_RETIRED_PERMANENT'))
            OR (OLD.lifecycle_state = 'STATE_HE_SANITIZING'
                AND NEW.lifecycle_state IN ('STATE_RECLAIM_COMMIT','STATE_RETIRED_PERMANENT'))
            OR (OLD.lifecycle_state = 'STATE_RECLAIM_COMMIT' AND NEW.lifecycle_state = 'STATE_ACTIVE')
            OR (OLD.lifecycle_state = 'STATE_EXHAUSTED' AND NEW.lifecycle_state = 'STATE_RETIRED_PERMANENT')
        ) THEN
            SET v_msg = CONCAT('QDH-E018|S64-E031|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                               '|0|', OLD.generation_epoch,
                               '|Lifecycle transition not permitted: ',
                               OLD.lifecycle_state, ' -> ', NEW.lifecycle_state);
            SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
        END IF;
    END IF;

    -- 5. Epoch and lineage coupling
    SET v_len_o = JSON_LENGTH(OLD.lineage);
    SET v_len_n = JSON_LENGTH(NEW.lineage);

    IF NEW.generation_epoch = OLD.generation_epoch THEN
        IF CAST(NEW.lineage AS CHAR) <> CAST(OLD.lineage AS CHAR) THEN
            SET v_msg = CONCAT('QDH-E005|S64-E021|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                               '|0|', OLD.generation_epoch,
                               '|Lineage is append-only and must be unchanged without an epoch advance');
            SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = v_msg;
        END IF;
    ELSEIF NEW.generation_epoch = OLD.generation_epoch + 1 THEN
        IF v_len_n <> v_len_o + 1 THEN
            SET v_msg = CONCAT('QDH-E005|S64-E021|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                               '|0|', OLD.generation_epoch,
                               '|Epoch advance requires exactly one appended lineage entry');
            SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = v_msg;
        END IF;

        SET v_last = JSON_EXTRACT(NEW.lineage, CONCAT('$[', v_len_n - 1, ']'));
        SET v_le_epoch  = CAST(JSON_EXTRACT(v_last, '$.generation_epoch') AS SIGNED);
        SET v_le_start  = CAST(JSON_EXTRACT(v_last, '$.local_start') AS SIGNED);
        SET v_le_end    = CAST(JSON_EXTRACT(v_last, '$.local_end_watermark') AS SIGNED);
        SET v_le_reason = JSON_UNQUOTE(JSON_EXTRACT(v_last, '$.closure_reason'));
        SET v_le_event  = JSON_UNQUOTE(JSON_EXTRACT(v_last, '$.closing_audit_event_id'));

        IF v_le_epoch <> OLD.generation_epoch
           OR v_le_start <> OLD.local_watermark
           OR v_le_end > NEW.local_watermark
           OR NOT (v_le_reason <=> JSON_UNQUOTE(JSON_EXTRACT(v_last, '$.closure_reason'))) THEN
            SET v_msg = CONCAT('QDH-E005|S64-E021|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                               '|0|', OLD.generation_epoch,
                               '|Lineage entry does not describe the closed generation');
            SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = v_msg;
        END IF;

        IF v_le_reason NOT IN ('FAIL_HARD_RECLAIMED','NODE_REFURBISHMENT',
                               'EXHAUSTED','PROFILE_UPGRADE') THEN
            SET v_msg = CONCAT('QDH-E005|S64-E021|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                               '|0|', OLD.generation_epoch,
                               '|Unrecognised closure_reason: ', IFNULL(v_le_reason,'NULL'));
            SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = v_msg;
        END IF;

        SELECT COUNT(*) INTO v_cnt
          FROM qdh_audit_events
         WHERE event_id = v_le_event
           AND class_id = OLD.class_id AND engine_id = OLD.engine_id
           AND generation_epoch = v_le_epoch
           AND event_type IN ('RECLAMATION_COMMITTED','ENGINE_EXHAUSTED_ROLLOVER',
                              'ENGINE_EXHAUSTED_TERMINAL','ENGINE_RETIRED_PERMANENT',
                              'PROFILE_UPGRADED');
        IF v_cnt <> 1 THEN
            SET v_msg = CONCAT('QDH-E005|S64-E021|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                               '|0|', OLD.generation_epoch,
                               '|closing_audit_event_id does not resolve to a matching closing event');
            SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = v_msg;
        END IF;

        IF v_le_reason = 'PROFILE_UPGRADE'
           AND NOT (NEW.active_profile <=> OLD.active_profile) = 0 THEN
            SET v_msg = CONCAT('QDH-E005|S64-E021|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                               '|0|', OLD.generation_epoch,
                               '|PROFILE_UPGRADE without a profile change');
            SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = v_msg;
        END IF;
    ELSE
        SET v_msg = CONCAT('QDH-E018|S64-E031|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                           '|0|', OLD.generation_epoch,
                           '|Generation epoch may advance by exactly one');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- 6. Evidence binding into HE and RECLAIM_COMMIT
    IF NEW.lifecycle_state = 'STATE_HE_SANITIZING'
       AND OLD.lifecycle_state <> 'STATE_HE_SANITIZING' THEN
        SELECT COUNT(*) INTO v_cnt FROM qdh_audit_events
         WHERE class_id = OLD.class_id AND engine_id = OLD.engine_id
           AND generation_epoch = OLD.generation_epoch
           AND event_type = 'DE_WATERMARK_VERIFIED';
        IF v_cnt = 0 THEN
            SET v_msg = CONCAT('QDH-E016|S64-E021|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                               '|0|', OLD.generation_epoch,
                               '|DE_WATERMARK_VERIFIED missing for current generation');
            SIGNAL SQLSTATE '45006' SET MESSAGE_TEXT = v_msg;
        END IF;
    END IF;

    IF NEW.lifecycle_state = 'STATE_RECLAIM_COMMIT'
       AND OLD.lifecycle_state <> 'STATE_RECLAIM_COMMIT' THEN
        SELECT COUNT(*) INTO v_cnt FROM qdh_audit_events
         WHERE class_id = OLD.class_id AND engine_id = OLD.engine_id
           AND generation_epoch = OLD.generation_epoch
           AND event_type = 'HE_SANITIZATION_ATTESTED';
        IF v_cnt = 0 THEN
            SET v_msg = CONCAT('QDH-E016|S64-E021|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                               '|0|', OLD.generation_epoch,
                               '|HE_SANITIZATION_ATTESTED missing for current generation');
            SIGNAL SQLSTATE '45006' SET MESSAGE_TEXT = v_msg;
        END IF;
    END IF;

    -- 7. Phase 5 gate: a lease for the new epoch must already be issued
    IF OLD.lifecycle_state = 'STATE_RECLAIM_COMMIT'
       AND NEW.lifecycle_state = 'STATE_ACTIVE' THEN
        SELECT COUNT(*) INTO v_cnt FROM qdh_audit_events
         WHERE class_id = OLD.class_id AND engine_id = OLD.engine_id
           AND generation_epoch = NEW.generation_epoch
           AND event_type = 'ALLOCATOR_LEASE_ISSUED';
        IF v_cnt = 0 THEN
            SET v_msg = CONCAT('QDH-E017|S64-E021|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                               '|0|', NEW.generation_epoch,
                               '|ALLOCATOR_LEASE_ISSUED must precede ENGINE_REACTIVATED');
            SIGNAL SQLSTATE '45006' SET MESSAGE_TEXT = v_msg;
        END IF;
    END IF;

    -- 8. Lease lifetime rules
    IF NEW.lifecycle_state <> 'STATE_ACTIVE' AND NEW.allocator_lease_id IS NOT NULL THEN
        SET v_msg = CONCAT('QDH-E018|S64-E031|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                           '|0|', NEW.generation_epoch,
                           '|allocator_lease_id must be NULL outside STATE_ACTIVE');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- 9. Entering STATE_ACTIVE: host fitness and lease binding
    IF NEW.lifecycle_state = 'STATE_ACTIVE'
       AND OLD.lifecycle_state <> 'STATE_ACTIVE' THEN

        SELECT node_state INTO v_node_state
          FROM physical_nodes WHERE node_id = NEW.physical_node_id;
        IF v_node_state <> 'NODE_ACTIVE' THEN
            SET v_msg = CONCAT('QDH-E007|S64-E021|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                               '|0|', NEW.generation_epoch,
                               '|Reactivation requires a NODE_ACTIVE host');
            SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
        END IF;

        IF NEW.allocator_lease_id IS NULL THEN
            SET v_msg = CONCAT('QDH-E018|S64-E031|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                               '|0|', NEW.generation_epoch,
                               '|STATE_ACTIVE requires an allocator lease');
            SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
        END IF;

        SELECT revoked_at_utc, expires_at_utc, generation_epoch, class_id, engine_id
          INTO v_lr_revoked, v_lr_expires, v_lr_epoch, v_lr_class, v_lr_engine
          FROM allocator_leases WHERE lease_id = NEW.allocator_lease_id;

        IF v_lr_class IS NULL
           OR v_lr_class <> NEW.class_id OR v_lr_engine <> NEW.engine_id
           OR v_lr_epoch <> NEW.generation_epoch
           OR v_lr_revoked IS NOT NULL
           OR v_lr_expires <= UTC_TIMESTAMP(6) THEN
            SET v_msg = CONCAT('QDH-E003|S64-E019|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                               '|0|', NEW.generation_epoch,
                               '|Lease is absent, revoked, expired, or bound to a different epoch');
            SIGNAL SQLSTATE '45003' SET MESSAGE_TEXT = v_msg;
        END IF;
    END IF;

    -- 10. Placement change
    IF NOT (NEW.physical_node_id <=> OLD.physical_node_id) THEN
        IF OLD.lifecycle_state = 'STATE_ACTIVE'
           OR OLD.lifecycle_state = 'STATE_RETIRED_PERMANENT' THEN
            SET v_msg = CONCAT('QDH-E018|S64-E031|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                               '|0|', OLD.generation_epoch,
                               '|Placement change not permitted in the current state');
            SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
        END IF;
        SELECT node_state INTO v_node_state
          FROM physical_nodes WHERE node_id = NEW.physical_node_id;
        IF v_node_state <> 'NODE_ACTIVE' THEN
            SET v_msg = CONCAT('QDH-E007|S64-E021|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                               '|0|', OLD.generation_epoch,
                               '|Placement target is not NODE_ACTIVE');
            SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------------
-- Identity records: insert
-- ---------------------------------------------------------------------------
CREATE TRIGGER trg_ir_before_insert
BEFORE INSERT ON identity_records
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    DECLARE v_epoch BIGINT;
    DECLARE v_profile VARCHAR(32);
    DECLARE v_pred_root CHAR(64);
    DECLARE v_pred_retired TINYINT;

    IF NEW.full_smart_id <> fn_expected_smart_id_v142(
           NEW.class_id, NEW.engine_id, NEW.local_id, NEW.role_bit) THEN
        SET v_msg = CONCAT('-|S64-E027|COMMIT|', NEW.class_id, '|', NEW.engine_id,
                           '|', NEW.local_id, '|', NEW.allocated_epoch,
                           '|full_smart_id does not match the bit-packed coordinate');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF NEW.is_active <> 0 OR NEW.is_retired <> 0 THEN
        SET v_msg = CONCAT('QDH-E018|S64-E031|COMMIT|', NEW.class_id, '|', NEW.engine_id,
                           '|', NEW.local_id, '|', NEW.allocated_epoch,
                           '|A newly allocated identity is created inactive and unretired');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;

    SELECT generation_epoch, active_profile
      INTO v_epoch, v_profile
      FROM virtual_engines
     WHERE class_id = NEW.class_id AND engine_id = NEW.engine_id;

    IF NEW.allocated_epoch <> v_epoch THEN
        SET v_msg = CONCAT('QDH-E003|S64-E019|COMMIT|', NEW.class_id, '|', NEW.engine_id,
                           '|', NEW.local_id, '|', NEW.allocated_epoch,
                           '|Allocation epoch does not match the current generation');
        SIGNAL SQLSTATE '45003' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF NEW.allocated_profile <> v_profile THEN
        SET v_msg = CONCAT('QDH-E015|S64-E030|COMMIT|', NEW.class_id, '|', NEW.engine_id,
                           '|', NEW.local_id, '|', NEW.allocated_epoch,
                           '|Recorded profile does not match the generation profile');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- Chain root: self for a first allocation, inherited from the predecessor otherwise
    IF NEW.predecessor_smart_id IS NULL THEN
        IF NEW.history_chain_root_id <> LPAD(HEX(NEW.full_smart_id), 64, '0') THEN
            SET v_msg = CONCAT('-|S64-E031|COMMIT|', NEW.class_id, '|', NEW.engine_id,
                               '|', NEW.local_id, '|', NEW.allocated_epoch,
                               '|First allocation must self-root its history chain');
            SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
        END IF;
    ELSE
        SELECT history_chain_root_id, is_retired
          INTO v_pred_root, v_pred_retired
          FROM identity_records
         WHERE full_smart_id = NEW.predecessor_smart_id;

        IF v_pred_root IS NULL THEN
            SET v_msg = CONCAT('QDH-E019|S64-E013|COMMIT|', NEW.class_id, '|', NEW.engine_id,
                               '|', NEW.local_id, '|', NEW.allocated_epoch,
                               '|Predecessor does not exist');
            SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
        END IF;

        IF NEW.history_chain_root_id <> v_pred_root THEN
            SET v_msg = CONCAT('QDH-E018|S64-E031|COMMIT|', NEW.class_id, '|', NEW.engine_id,
                               '|', NEW.local_id, '|', NEW.allocated_epoch,
                               '|Successor must inherit the predecessor chain root');
            SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------------
-- Identity records: update
-- ---------------------------------------------------------------------------
CREATE TRIGGER trg_ir_before_update
BEFORE UPDATE ON identity_records
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    DECLARE v_epoch BIGINT;

    -- Retired records are fully immutable
    IF OLD.is_retired = 1 THEN
        SET v_msg = CONCAT('QDH-E018|S64-E025|RETIREMENT|', OLD.class_id, '|', OLD.engine_id,
                           '|', OLD.local_id, '|', OLD.allocated_epoch,
                           '|A retired record MUST NOT be modified or reactivated');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- Immutable identity fields (core §17)
    IF NEW.class_id <> OLD.class_id
       OR NEW.engine_id <> OLD.engine_id
       OR NEW.local_id <> OLD.local_id
       OR NEW.full_smart_id <> OLD.full_smart_id
       OR NEW.role_bit <> OLD.role_bit
       OR NOT (NEW.allocated_profile <=> OLD.allocated_profile)
       OR NEW.allocated_epoch <> OLD.allocated_epoch
       OR NOT (NEW.history_chain_root_id <=> OLD.history_chain_root_id)
       OR NOT (NEW.predecessor_smart_id <=> OLD.predecessor_smart_id)
       OR NOT (NEW.allocated_at_utc <=> OLD.allocated_at_utc) THEN
        SET v_msg = CONCAT('QDH-E005|S64-E024|RETIREMENT|', OLD.class_id, '|', OLD.engine_id,
                           '|', OLD.local_id, '|', OLD.allocated_epoch,
                           '|Immutable identity field mutation');
        SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- Activation is fenced to the current epoch
    IF NEW.is_active = 1 AND OLD.is_active = 0 THEN
        SELECT generation_epoch INTO v_epoch
          FROM virtual_engines
         WHERE class_id = OLD.class_id AND engine_id = OLD.engine_id;
        IF OLD.allocated_epoch <> v_epoch THEN
            SET v_msg = CONCAT('QDH-E003|S64-E019|COMMIT|', OLD.class_id, '|', OLD.engine_id,
                               '|', OLD.local_id, '|', OLD.allocated_epoch,
                               '|Activation of a prior-generation record');
            SIGNAL SQLSTATE '45003' SET MESSAGE_TEXT = v_msg;
        END IF;
    END IF;
    -- Retirement and prior-generation consumption writes are exempt (core §10.7.2)
END$$

CREATE TRIGGER trg_ir_after_insert
AFTER INSERT ON identity_records
FOR EACH ROW
BEGIN
    INSERT INTO coordinate_tombstones
        (class_id, engine_id, local_id, allocated_profile, allocated_epoch, status)
    VALUES
        (NEW.class_id, NEW.engine_id, NEW.local_id,
         NEW.allocated_profile, NEW.allocated_epoch, 'CONSUMED');
END$$

CREATE TRIGGER trg_ir_after_update
AFTER UPDATE ON identity_records
FOR EACH ROW
BEGIN
    IF NEW.is_retired = 1 AND OLD.is_retired = 0 THEN
        UPDATE coordinate_tombstones
           SET status = 'RETIRED'
         WHERE class_id = NEW.class_id AND engine_id = NEW.engine_id
           AND local_id = NEW.local_id;
    END IF;
END$$

-- ---------------------------------------------------------------------------
-- Coordinate tombstones
-- ---------------------------------------------------------------------------
CREATE TRIGGER trg_ct_before_insert
BEFORE INSERT ON coordinate_tombstones
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    DECLARE v_cnt INT;
    DECLARE v_epoch BIGINT;

    SELECT COUNT(*) INTO v_cnt FROM identity_records
     WHERE class_id = NEW.class_id AND engine_id = NEW.engine_id
       AND local_id = NEW.local_id;
    IF v_cnt <> 1 THEN
        SET v_msg = CONCAT('QDH-E019|S64-E013|TOMBSTONE_WRITE|', NEW.class_id, '|', NEW.engine_id,
                           '|', NEW.local_id, '|', NEW.allocated_epoch,
                           '|Tombstone requires an existing identity record');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;

    SELECT generation_epoch INTO v_epoch FROM virtual_engines
     WHERE class_id = NEW.class_id AND engine_id = NEW.engine_id;
    IF NEW.allocated_epoch > v_epoch THEN
        SET v_msg = CONCAT('QDH-E003|S64-E021|TOMBSTONE_WRITE|', NEW.class_id, '|', NEW.engine_id,
                           '|', NEW.local_id, '|', NEW.allocated_epoch,
                           '|Tombstone epoch is ahead of the current generation');
        SIGNAL SQLSTATE '45003' SET MESSAGE_TEXT = v_msg;
    END IF;
END$$

CREATE TRIGGER trg_ct_before_update
BEFORE UPDATE ON coordinate_tombstones
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);

    IF NEW.class_id <> OLD.class_id OR NEW.engine_id <> OLD.engine_id
       OR NEW.local_id <> OLD.local_id
       OR NOT (NEW.allocated_profile <=> OLD.allocated_profile)
       OR NEW.allocated_epoch <> OLD.allocated_epoch
       OR NOT (NEW.recorded_at_utc <=> OLD.recorded_at_utc)
       OR NOT (OLD.status = 'CONSUMED' AND NEW.status = 'RETIRED') THEN
        SET v_msg = CONCAT('QDH-E005|S64-E021|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                           '|', OLD.local_id, '|', OLD.allocated_epoch,
                           '|Tombstones are append-only; only CONSUMED -> RETIRED is permitted');
        SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = v_msg;
    END IF;
END$$

CREATE TRIGGER trg_ct_before_delete
BEFORE DELETE ON coordinate_tombstones
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    SET v_msg = CONCAT('QDH-E005|S64-E017|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                       '|', OLD.local_id, '|', OLD.allocated_epoch,
                       '|Permanent tombstones MUST NOT be deleted');
    SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = v_msg;
END$$

-- ---------------------------------------------------------------------------
-- Durable allocation log (append-only)
-- ---------------------------------------------------------------------------
CREATE TRIGGER trg_dal_before_insert
BEFORE INSERT ON durable_allocation_log
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    DECLARE v_cnt INT;
    SELECT COUNT(*) INTO v_cnt FROM identity_records
     WHERE class_id = NEW.class_id AND engine_id = NEW.engine_id AND local_id = NEW.local_id;
    IF v_cnt <> 1 THEN
        SET v_msg = CONCAT('QDH-E019|S64-E013|COMMIT|', NEW.class_id, '|', NEW.engine_id,
                           '|', NEW.local_id, '|', NEW.epoch,
                           '|Durable log entry requires an identity record');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;
END$$

CREATE TRIGGER trg_dal_before_update
BEFORE UPDATE ON durable_allocation_log
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    SET v_msg = CONCAT('QDH-E005|S64-E021|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                       '|', OLD.local_id, '|', OLD.epoch,
                       '|Durable allocation log is append-only');
    SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = v_msg;
END$$

CREATE TRIGGER trg_dal_before_delete
BEFORE DELETE ON durable_allocation_log
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    SET v_msg = CONCAT('QDH-E005|S64-E017|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                       '|', OLD.local_id, '|', OLD.epoch,
                       '|Durable allocation log MUST NOT be deleted');
    SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = v_msg;
END$$

-- ---------------------------------------------------------------------------
-- Lease watermarks
-- ---------------------------------------------------------------------------
CREATE TRIGGER trg_lw_before_update
BEFORE UPDATE ON lease_watermarks
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    IF NOT (NEW.lease_id <=> OLD.lease_id)
       OR NEW.class_id <> OLD.class_id OR NEW.engine_id <> OLD.engine_id
       OR NEW.lease_floor <> OLD.lease_floor OR NEW.lease_ceiling <> OLD.lease_ceiling
       OR NOT (NEW.release_state <=> OLD.release_state)
       OR NOT (OLD.release_state = 'ACTIVE'
               AND NEW.release_state IN ('CONSUMED','RELEASED')) THEN
        SET v_msg = CONCAT('QDH-E005|S64-E021|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                           '|', OLD.lease_floor, '|0',
                           '|Only ACTIVE -> CONSUMED|RELEASED is permitted on a watermark');
        SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = v_msg;
    END IF;
END$$

CREATE TRIGGER trg_lw_before_delete
BEFORE DELETE ON lease_watermarks
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    SET v_msg = CONCAT('QDH-E005|S64-E021|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                       '|', OLD.lease_floor, '|0',
                       '|Lease watermarks are append-only evidence');
    SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = v_msg;
END$$

-- ---------------------------------------------------------------------------
-- Allocator leases
-- ---------------------------------------------------------------------------
CREATE TRIGGER trg_al_before_insert
BEFORE INSERT ON allocator_leases
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    DECLARE v_epoch BIGINT;
    DECLARE v_tr_revoked DATETIME(6);

    SELECT generation_epoch INTO v_epoch FROM virtual_engines
     WHERE class_id = NEW.class_id AND engine_id = NEW.engine_id;

    IF NEW.generation_epoch <> v_epoch THEN
        SET v_msg = CONCAT('QDH-E003|S64-E019|CONTROL|', NEW.class_id, '|', NEW.engine_id,
                           '|0|', NEW.generation_epoch,
                           '|Lease must be bound to the current generation');
        SIGNAL SQLSTATE '45003' SET MESSAGE_TEXT = v_msg;
    END IF;

    SELECT revoked_at_utc INTO v_tr_revoked FROM trust_roots
     WHERE trust_root_id = NEW.signing_trust_root_id;
    IF v_tr_revoked IS NULL AND NEW.lease_signature = '' THEN
        SET v_msg = CONCAT('QDH-E004|S64-E021|CONTROL|', NEW.class_id, '|', NEW.engine_id,
                           '|0|', NEW.generation_epoch,
                           '|Unsigned or unresolvable lease');
        SIGNAL SQLSTATE '45004' SET MESSAGE_TEXT = v_msg;
    END IF;
END$$

CREATE TRIGGER trg_al_before_update
BEFORE UPDATE ON allocator_leases
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    IF NOT (NEW.lease_id <=> OLD.lease_id)
       OR NEW.class_id <> OLD.class_id OR NEW.engine_id <> OLD.engine_id
       OR NEW.generation_epoch <> OLD.generation_epoch
       OR NOT (NEW.expires_at_utc <=> OLD.expires_at_utc)
       OR NOT (NEW.lease_signature <=> OLD.lease_signature)
       OR NOT (NEW.signing_trust_root_id <=> OLD.signing_trust_root_id)
       OR NOT (OLD.revoked_at_utc IS NULL AND NEW.revoked_at_utc IS NOT NULL) THEN
        SET v_msg = CONCAT('QDH-E005|S64-E021|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                           '|0|', OLD.generation_epoch,
                           '|A lease may only transition from unrevoked to revoked');
        SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = v_msg;
    END IF;
END$$

-- ---------------------------------------------------------------------------
-- Hardware attestations
-- ---------------------------------------------------------------------------
CREATE TRIGGER trg_ha_before_insert
BEFORE INSERT ON hardware_attestations
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    DECLARE v_n_class SMALLINT;
    DECLARE v_n_engine INT;
    DECLARE v_n_epoch BIGINT;
    DECLARE v_n_incident VARCHAR(64);
    DECLARE v_n_consumed DATETIME(6);
    DECLARE v_measurement CHAR(64);
    DECLARE v_tr_from DATETIME(6);
    DECLARE v_tr_to DATETIME(6);
    DECLARE v_tr_revoked DATETIME(6);

    SELECT class_id, engine_id, generation_epoch, incident_id, consumed_at_utc
      INTO v_n_class, v_n_engine, v_n_epoch, v_n_incident, v_n_consumed
      FROM nonce_registry WHERE nonce = NEW.challenge_nonce;

    IF v_n_class IS NULL OR v_n_consumed IS NOT NULL THEN
        SET v_msg = CONCAT('QDH-E004|S64-E021|CONTROL|', NEW.class_id, '|', NEW.engine_id,
                           '|0|', NEW.bound_generation_epoch,
                           '|Nonce is unknown or already consumed');
        SIGNAL SQLSTATE '45004' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF v_n_class <> NEW.class_id OR v_n_engine <> NEW.engine_id
       OR v_n_epoch <> NEW.bound_generation_epoch OR v_n_incident <> NEW.bound_incident_id THEN
        SET v_msg = CONCAT('QDH-E004|S64-E021|CONTROL|', NEW.class_id, '|', NEW.engine_id,
                           '|0|', NEW.bound_generation_epoch,
                           '|Nonce binding does not match the engine context');
        SIGNAL SQLSTATE '45004' SET MESSAGE_TEXT = v_msg;
    END IF;

    SELECT measurement_digest, valid_from_utc, valid_to_utc, revoked_at_utc
      INTO v_measurement, v_tr_from, v_tr_to, v_tr_revoked
      FROM trust_roots WHERE trust_root_id = NEW.signing_trust_root_id;

    IF v_measurement IS NULL
       OR v_measurement <> NEW.attestation_digest
       OR v_tr_revoked IS NOT NULL
       OR NEW.verified_at_utc < v_tr_from
       OR NEW.verified_at_utc >= v_tr_to THEN
        SET v_msg = CONCAT('QDH-E004|S64-E021|CONTROL|', NEW.class_id, '|', NEW.engine_id,
                           '|0|', NEW.bound_generation_epoch,
                           '|Attestation digest is not allowlisted, or the trust root is revoked or out of window');
        SIGNAL SQLSTATE '45004' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF NEW.cert_not_before_utc > NEW.verified_at_utc
       OR NEW.cert_not_after_utc <= NEW.verified_at_utc THEN
        SET v_msg = CONCAT('QDH-E004|S64-E021|CONTROL|', NEW.class_id, '|', NEW.engine_id,
                           '|0|', NEW.bound_generation_epoch,
                           '|Certificate was not valid at verification time');
        SIGNAL SQLSTATE '45004' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF NEW.revocation_checked_at_utc < UTC_TIMESTAMP(6) - INTERVAL 24 HOUR THEN
        SET v_msg = CONCAT('QDH-E004|S64-E021|CONTROL|', NEW.class_id, '|', NEW.engine_id,
                           '|0|', NEW.bound_generation_epoch,
                           '|Revocation check is stale');
        SIGNAL SQLSTATE '45004' SET MESSAGE_TEXT = v_msg;
    END IF;

    UPDATE nonce_registry SET consumed_at_utc = UTC_TIMESTAMP(6)
     WHERE nonce = NEW.challenge_nonce;
END$$

-- ---------------------------------------------------------------------------
-- Nonces and trust roots
-- ---------------------------------------------------------------------------
CREATE TRIGGER trg_nr_before_update
BEFORE UPDATE ON nonce_registry
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    IF NOT (OLD.consumed_at_utc IS NULL AND NEW.consumed_at_utc IS NOT NULL)
       OR NOT (NEW.nonce <=> OLD.nonce) OR NEW.class_id <> OLD.class_id
       OR NEW.engine_id <> OLD.engine_id
       OR NEW.generation_epoch <> OLD.generation_epoch
       OR NOT (NEW.incident_id <=> OLD.incident_id) THEN
        SET v_msg = CONCAT('QDH-E004|S64-E021|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                           '|0|', OLD.generation_epoch,
                           '|A nonce may only be consumed once and is otherwise immutable');
        SIGNAL SQLSTATE '45004' SET MESSAGE_TEXT = v_msg;
    END IF;
END$$

CREATE TRIGGER trg_tr_before_update
BEFORE UPDATE ON trust_roots
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    IF NOT (NEW.trust_root_id <=> OLD.trust_root_id)
       OR NOT (NEW.platform <=> OLD.platform)
       OR NOT (NEW.measurement_digest <=> OLD.measurement_digest)
       OR NOT (NEW.valid_from_utc <=> OLD.valid_from_utc)
       OR NOT (NEW.valid_to_utc <=> OLD.valid_to_utc) THEN
        SET v_msg = CONCAT('QDH-E004|S64-E021|CONTROL|[0]|[0]|[0]|[0]',
                           '|Trust-root identity and measurement are immutable; only revocation is permitted');
        SIGNAL SQLSTATE '45004' SET MESSAGE_TEXT = v_msg;
    END IF;
END$$

-- ---------------------------------------------------------------------------
-- Audit events: chain, hash, correspondence, ordering
-- ---------------------------------------------------------------------------
CREATE TRIGGER trg_qae_before_insert
BEFORE INSERT ON qdh_audit_events
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    DECLARE v_last_seq BIGINT;
    DECLARE v_last_hash CHAR(64);
    DECLARE v_cnt INT;
    DECLARE v_zero CHAR(64) DEFAULT REPEAT('0', 64);
    DECLARE v_tc VARCHAR(64);

    -- Registry enforcement for incident tokens carried in the payload
    SET v_tc = JSON_UNQUOTE(JSON_EXTRACT(NEW.payload, '$.incident.trigger_class'));
    IF v_tc IS NOT NULL THEN
        SELECT COUNT(*) INTO v_cnt FROM incident_trigger_class
         WHERE trigger_class = v_tc;
        IF v_cnt = 0 THEN
            SET v_msg = CONCAT('QDH-E011|S64-E012|CONTROL|', NEW.class_id, '|', NEW.engine_id,
                               '|0|', NEW.generation_epoch,
                               '|Unregistered incident trigger_class: ', v_tc);
            SIGNAL SQLSTATE '45005' SET MESSAGE_TEXT = v_msg;
        END IF;
    END IF;

    -- Canonical bytes must be JSON, must not carry event_hash,
    -- and the projection must be semantically equal to them
    IF JSON_VALID(NEW.payload_canonical) = 0
       OR JSON_CONTAINS_PATH(NEW.payload, 'one', '$.event_hash') = 1
       OR NOT (NEW.payload <=> JSON_EXTRACT(NEW.payload_canonical, '$')) THEN
        SET v_msg = CONCAT('QDH-E011|S64-E012|CONTROL|', NEW.class_id, '|', NEW.engine_id,
                           '|0|', NEW.generation_epoch,
                           '|payload projection does not correspond to payload_canonical');
        SIGNAL SQLSTATE '45005' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- Stored hash must be the digest of the stored canonical bytes
    IF NEW.event_hash <> SHA2(NEW.payload_canonical, 256) THEN
        SET v_msg = CONCAT('QDH-E011|S64-E012|CONTROL|', NEW.class_id, '|', NEW.engine_id,
                           '|0|', NEW.generation_epoch,
                           '|event_hash is not the digest of payload_canonical');
        SIGNAL SQLSTATE '45005' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- Stream linkage
    SELECT stream_seq, event_hash
      INTO v_last_seq, v_last_hash
      FROM qdh_audit_events
     WHERE class_id = NEW.class_id AND engine_id = NEW.engine_id
     ORDER BY stream_seq DESC LIMIT 1;

    IF v_last_seq IS NULL THEN
        IF NEW.stream_seq <> 1 OR NEW.prev_event_hash <> v_zero THEN
            SET v_msg = CONCAT('QDH-E011|S64-E012|CONTROL|', NEW.class_id, '|', NEW.engine_id,
                               '|0|', NEW.generation_epoch,
                               '|Genesis record must be stream_seq 1 with the all-zero sentinel');
            SIGNAL SQLSTATE '45005' SET MESSAGE_TEXT = v_msg;
        END IF;
    ELSE
        IF NEW.stream_seq <> v_last_seq + 1 OR NEW.prev_event_hash <> v_last_hash THEN
            SET v_msg = CONCAT('QDH-E011|S64-E012|CONTROL|', NEW.class_id, '|', NEW.engine_id,
                               '|0|', NEW.generation_epoch,
                               '|Stream is not contiguous or prev_event_hash does not match');
            SIGNAL SQLSTATE '45005' SET MESSAGE_TEXT = v_msg;
        END IF;
    END IF;

    -- Column-to-payload correspondence, every column
    IF NOT (JSON_UNQUOTE(JSON_EXTRACT(NEW.payload,'$.event_id'))        <=> NEW.event_id)
    OR NOT (CAST(JSON_EXTRACT(NEW.payload,'$.virtual_engine.class_id')  AS SIGNED) <=> NEW.class_id)
    OR NOT (CAST(JSON_EXTRACT(NEW.payload,'$.virtual_engine.engine_id') AS SIGNED) <=> NEW.engine_id)
    OR NOT (CAST(JSON_EXTRACT(NEW.payload,'$.stream_seq')               AS SIGNED) <=> NEW.stream_seq)
    OR NOT (JSON_UNQUOTE(JSON_EXTRACT(NEW.payload,'$.event_type'))      <=> NEW.event_type)
    OR NOT (CAST(JSON_EXTRACT(NEW.payload,'$.generation_epoch')         AS SIGNED) <=> NEW.generation_epoch)
    OR NOT (STR_TO_DATE(JSON_UNQUOTE(JSON_EXTRACT(NEW.payload,'$.timestamp_utc')), '%Y-%m-%dT%H:%i:%s.%fZ') <=> NEW.timestamp_utc)
    OR NOT (JSON_UNQUOTE(JSON_EXTRACT(NEW.payload,'$.lifecycle.previous_state')) <=> NEW.previous_state)
    OR NOT (JSON_UNQUOTE(JSON_EXTRACT(NEW.payload,'$.lifecycle.new_state'))      <=> NEW.new_state)
    OR NOT (CAST(JSON_EXTRACT(NEW.payload,'$.lifecycle.epoch_before')  AS SIGNED) <=> NEW.epoch_before)
    OR NOT (CAST(JSON_EXTRACT(NEW.payload,'$.lifecycle.epoch_after')   AS SIGNED) <=> NEW.epoch_after)
    OR NOT (JSON_UNQUOTE(JSON_EXTRACT(NEW.payload,'$.lifecycle.profile_before')) <=> NEW.profile_before)
    OR NOT (JSON_UNQUOTE(JSON_EXTRACT(NEW.payload,'$.lifecycle.profile_after'))  <=> NEW.profile_after)
    OR NOT (CAST(JSON_EXTRACT(NEW.payload,'$.watermark_audit.verified_first_never_consumed_local') AS SIGNED) <=> NEW.watermark_verified)
    OR NOT (NULLIF(JSON_UNQUOTE(JSON_EXTRACT(NEW.payload,'$.diagnostic.qdh_code')), 'null') <=> NEW.qdh_error_code)
    OR NOT (NULLIF(JSON_UNQUOTE(JSON_EXTRACT(NEW.payload,'$.diagnostic.s64_code')), 'null') <=> NEW.s64_error_code)
    OR NOT (JSON_UNQUOTE(JSON_EXTRACT(NEW.payload,'$.prev_event_hash')) <=> NEW.prev_event_hash) THEN
        SET v_msg = CONCAT('QDH-E011|S64-E012|CONTROL|', NEW.class_id, '|', NEW.engine_id,
                           '|0|', NEW.generation_epoch,
                           '|Column and payload disagree');
        SIGNAL SQLSTATE '45005' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- Phase 5 ordering: reactivation requires a prior lease event for the same epoch
    IF NEW.event_type = 'ENGINE_REACTIVATED' THEN
        SELECT COUNT(*) INTO v_cnt FROM qdh_audit_events
         WHERE class_id = NEW.class_id AND engine_id = NEW.engine_id
           AND generation_epoch = NEW.generation_epoch
           AND event_type = 'ALLOCATOR_LEASE_ISSUED';
        IF v_cnt = 0 THEN
            SET v_msg = CONCAT('QDH-E017|S64-E021|CONTROL|', NEW.class_id, '|', NEW.engine_id,
                               '|0|', NEW.generation_epoch,
                               '|ENGINE_REACTIVATED before ALLOCATOR_LEASE_ISSUED');
            SIGNAL SQLSTATE '45006' SET MESSAGE_TEXT = v_msg;
        END IF;
    END IF;

    -- A profile upgrade event must describe an actual profile change
    IF NEW.event_type = 'PROFILE_UPGRADED' AND NEW.profile_before = NEW.profile_after THEN
        SET v_msg = CONCAT('QDH-E005|S64-E021|CONTROL|', NEW.class_id, '|', NEW.engine_id,
                           '|0|', NEW.generation_epoch,
                           '|PROFILE_UPGRADED without a profile change');
        SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- Reclamation events must not carry the upgrade closure reason
    IF NEW.event_type = 'RECLAMATION_COMMITTED'
       AND JSON_UNQUOTE(JSON_EXTRACT(NEW.payload,'$.lifecycle.closure_reason')) = 'PROFILE_UPGRADE' THEN
        SET v_msg = CONCAT('QDH-E005|S64-E021|CONTROL|', NEW.class_id, '|', NEW.engine_id,
                           '|0|', NEW.generation_epoch,
                           '|Reclamation may not record the PROFILE_UPGRADE closure reason');
        SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = v_msg;
    END IF;
END$$

CREATE TRIGGER trg_qae_before_update
BEFORE UPDATE ON qdh_audit_events
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    SET v_msg = CONCAT('QDH-E005|S64-E021|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                       '|0|', OLD.generation_epoch,
                       '|Audit events are immutable');
    SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = v_msg;
END$$

CREATE TRIGGER trg_qae_before_delete
BEFORE DELETE ON qdh_audit_events
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    SET v_msg = CONCAT('QDH-E005|S64-E021|CONTROL|', OLD.class_id, '|', OLD.engine_id,
                       '|0|', OLD.generation_epoch,
                       '|Audit events MUST NOT be deleted');
    SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = v_msg;
END$$

-- ---------------------------------------------------------------------------
-- Registry and anchor protections
-- ---------------------------------------------------------------------------
CREATE TRIGGER trg_etr_before_update
BEFORE UPDATE ON event_type_registry
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    IF OLD.is_core = 1
       OR NOT (NEW.event_type <=> OLD.event_type) OR NOT (NEW.is_core <=> OLD.is_core) THEN
        SET v_msg = CONCAT('QDH-E005|S64-E021|CONTROL|[0]|[0]|[0]|[0]',
                           '|Core event types are immutable and cannot be demoted');
        SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = v_msg;
    END IF;
END$$

CREATE TRIGGER trg_etr_before_delete
BEFORE DELETE ON event_type_registry
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    IF OLD.is_core = 1 THEN
        SET v_msg = CONCAT('QDH-E005|S64-E021|CONTROL|[0]|[0]|[0]|[0]',
                           '|Core event types cannot be removed');
        SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = v_msg;
    END IF;
END$$

CREATE TRIGGER trg_itc_before_update
BEFORE UPDATE ON incident_trigger_class
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    IF OLD.is_core = 1
       OR NOT (NEW.trigger_class <=> OLD.trigger_class)
       OR NOT (NEW.is_core <=> OLD.is_core) THEN
        SET v_msg = CONCAT('QDH-E005|S64-E021|CONTROL|[0]|[0]|[0]|[0]',
                           '|Reserved trigger classes are immutable');
        SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = v_msg;
    END IF;
END$$

CREATE TRIGGER trg_itc_before_delete
BEFORE DELETE ON incident_trigger_class
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    IF OLD.is_core = 1 THEN
        SET v_msg = CONCAT('QDH-E005|S64-E021|CONTROL|[0]|[0]|[0]|[0]',
                           '|Reserved trigger classes cannot be removed');
        SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = v_msg;
    END IF;
END$$

CREATE TRIGGER trg_aa_before_update
BEFORE UPDATE ON audit_anchors
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    SET v_msg = CONCAT('QDH-E005|S64-E021|CONTROL|[0]|[0]|[0]|[0]',
                       '|Audit anchors are immutable');
    SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = v_msg;
END$$

CREATE TRIGGER trg_aa_before_delete
BEFORE DELETE ON audit_anchors
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);
    SET v_msg = CONCAT('QDH-E005|S64-E021|CONTROL|[0]|[0]|[0]|[0]',
                       '|Audit anchors MUST NOT be deleted');
    SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = v_msg;
END$$

DELIMITER ;

-- ---------------------------------------------------------------------------
-- 17. Procedures (continued): atomic generation commit (QDH §4.4)
-- ---------------------------------------------------------------------------
DELIMITER $$

CREATE PROCEDURE qdh_commit_generation(
    IN p_class SMALLINT, IN p_engine INT, IN p_safe_local BIGINT,
    IN p_node VARCHAR(128), IN p_reason VARCHAR(32), IN p_closing_event CHAR(36)
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_msg VARCHAR(512);
    DECLARE v_epoch BIGINT;
    DECLARE v_profile VARCHAR(32);
    DECLARE v_wm BIGINT;
    DECLARE v_opened DATETIME(6);
    DECLARE v_state VARCHAR(32);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_reason NOT IN ('FAIL_HARD_RECLAIMED','NODE_REFURBISHMENT','EXHAUSTED') THEN
        SET v_msg = CONCAT('QDH-E018|S64-E031|CONTROL|', p_class, '|', p_engine,
                           '|0|0','|Reclamation may record only reclaim, refurbish, or exhaust');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF p_safe_local < 0 OR p_safe_local > 536870912 THEN
        SET v_msg = CONCAT('QDH-E020|S64-E023|CONTROL|', p_class, '|', p_engine,
                           '|', p_safe_local, '|0','|next_safe_local out of range');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;

    START TRANSACTION;

    SELECT generation_epoch, active_profile, local_watermark, created_at_utc, lifecycle_state
      INTO v_epoch, v_profile, v_wm, v_opened, v_state
      FROM virtual_engines
     WHERE class_id = p_class AND engine_id = p_engine
     FOR UPDATE;

    IF v_epoch IS NULL THEN
        SET v_msg = CONCAT('QDH-E019|S64-E013|CONTROL|', p_class, '|', p_engine,
                           '|0|0','|(Class,Engine) does not resolve');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF p_safe_local < v_wm THEN
        SET v_msg = CONCAT('QDH-E014|S64-E018|CONTROL|', p_class, '|', p_engine,
                           '|', p_safe_local, '|', v_epoch,'|Watermark regression');
        SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = v_msg;
    END IF;

    UPDATE virtual_engines
       SET lifecycle_state = IF(p_safe_local >= 536870912,
                                'STATE_EXHAUSTED', 'STATE_RECLAIM_COMMIT'),
           local_watermark = p_safe_local,
           generation_epoch = generation_epoch + 1,
           lineage = JSON_ARRAY_APPEND(
                       lineage, '$',
                       JSON_OBJECT(
                         'generation_epoch', v_epoch,
                         'profile_version_revision', v_profile,
                         'local_start', v_wm,
                         'local_end_watermark', p_safe_local,
                         'physical_node_id', p_node,
                         'opened_at_utc', v_opened,
                         'closed_at_utc', UTC_TIMESTAMP(6),
                         'closure_reason', p_reason,
                         'closing_audit_event_id', p_closing_event))
     WHERE class_id = p_class AND engine_id = p_engine
       AND generation_epoch = v_epoch;

    IF ROW_COUNT() <> 1 THEN
        SET v_msg = CONCAT('QDH-E003|S64-E019|CONTROL|', p_class, '|', p_engine,
                           '|', p_safe_local, '|', v_epoch,'|Commit did not affect one row');
        SIGNAL SQLSTATE '45003' SET MESSAGE_TEXT = v_msg;
    END IF;

    COMMIT;
END$$

DELIMITER ;

-- ---------------------------------------------------------------------------
-- 18. Views
-- ---------------------------------------------------------------------------
CREATE VIEW qdh_transition_evidence AS
SELECT ve.class_id,
       ve.engine_id,
       ve.generation_epoch,
       ve.lifecycle_state,
       (SELECT COUNT(*) FROM qdh_audit_events e
         WHERE e.class_id = ve.class_id AND e.engine_id = ve.engine_id
           AND e.generation_epoch = ve.generation_epoch
           AND e.event_type = 'DE_WATERMARK_VERIFIED')            AS de_evidence,
       (SELECT COUNT(*) FROM qdh_audit_events e
         WHERE e.class_id = ve.class_id AND e.engine_id = ve.engine_id
           AND e.generation_epoch = ve.generation_epoch
           AND e.event_type = 'HE_SANITIZATION_ATTESTED')         AS he_evidence,
       (SELECT COUNT(*) FROM qdh_audit_events e
         WHERE e.class_id = ve.class_id AND e.engine_id = ve.engine_id
           AND e.generation_epoch = ve.generation_epoch
           AND e.event_type = 'ALLOCATOR_LEASE_ISSUED')           AS lease_evidence
  FROM virtual_engines ve;

CREATE VIEW qdh_audit_gap AS
SELECT DISTINCT ve.class_id, ve.engine_id, ve.generation_epoch
  FROM virtual_engines ve
  LEFT JOIN qdh_audit_events e
         ON e.class_id         = ve.class_id
        AND e.engine_id        = ve.engine_id
        AND e.event_type       = 'NODE_QUARANTINE_TRIGGERED'
        AND e.generation_epoch = ve.generation_epoch
 WHERE ve.lifecycle_state = 'STATE_QUARANTINED'
   AND e.class_id IS NULL;

GRANT SELECT ON qdh_audit_gap TO s64_auditor_role, s64_allocator_role;


-- Rollover candidates: strictly ascending, never a live-leased engine
CREATE VIEW v_next_forward_engine AS
SELECT ve.class_id, MIN(ve.engine_id) AS next_engine_id
  FROM virtual_engines ve
 WHERE ve.lifecycle_state = 'STATE_UNALLOCATED'
    OR (ve.lifecycle_state = 'STATE_ACTIVE'
        AND ve.local_watermark < 536870912
        AND EXISTS (SELECT 1 FROM allocator_leases al
                     WHERE al.class_id = ve.class_id AND al.engine_id = ve.engine_id
                       AND al.revoked_at_utc IS NOT NULL))
 GROUP BY ve.class_id;

-- ---------------------------------------------------------------------------
-- 19. Grants (four separated roles)
-- ---------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS s64_controller_role;
CREATE ROLE IF NOT EXISTS s64_allocator_role;
CREATE ROLE IF NOT EXISTS qdh_policy_engine_role;
CREATE ROLE IF NOT EXISTS s64_auditor_role;

-- Roles persist across DROP DATABASE, so privileges are reset explicitly.
-- Without this, a reload re-grants but never removes stale privileges.
REVOKE ALL PRIVILEGES, GRANT OPTION FROM
    s64_controller_role, s64_allocator_role, qdh_policy_engine_role, s64_auditor_role;

GRANT SELECT ON qdh_schema.* TO s64_controller_role;
GRANT INSERT, UPDATE ON qdh_schema.virtual_engines      TO s64_controller_role;
GRANT INSERT, UPDATE ON qdh_schema.physical_nodes       TO s64_controller_role;
GRANT INSERT          ON qdh_schema.allocator_leases    TO s64_controller_role;
GRANT UPDATE (revoked_at_utc) ON qdh_schema.allocator_leases TO s64_controller_role;
GRANT INSERT          ON qdh_schema.lease_watermarks    TO s64_controller_role;
GRANT UPDATE (release_state) ON qdh_schema.lease_watermarks TO s64_controller_role;
GRANT INSERT          ON qdh_schema.trust_roots         TO s64_controller_role;
GRANT UPDATE (revoked_at_utc) ON qdh_schema.trust_roots TO s64_controller_role;
GRANT INSERT          ON qdh_schema.event_type_registry TO s64_controller_role;
GRANT INSERT          ON qdh_schema.incident_trigger_class TO s64_controller_role;
GRANT INSERT          ON qdh_schema.audit_anchors       TO s64_controller_role;
GRANT INSERT          ON qdh_schema.qdh_audit_events    TO s64_controller_role;
GRANT EXECUTE ON PROCEDURE qdh_schema.qdh_commit_generation TO s64_controller_role;
GRANT EXECUTE ON PROCEDURE qdh_schema.qdh_begin_quarantine  TO s64_controller_role;

GRANT SELECT ON qdh_schema.* TO s64_allocator_role;
GRANT EXECUTE ON PROCEDURE qdh_schema.s64_allocate       TO s64_allocator_role;
GRANT EXECUTE ON PROCEDURE qdh_schema.s64_allocate_range TO s64_allocator_role;
GRANT EXECUTE ON PROCEDURE qdh_schema.s64_retire         TO s64_allocator_role;

GRANT SELECT ON qdh_schema.* TO qdh_policy_engine_role;
GRANT INSERT ON qdh_schema.qdh_audit_events     TO qdh_policy_engine_role;
GRANT INSERT ON qdh_schema.hardware_attestations TO qdh_policy_engine_role;
GRANT INSERT ON qdh_schema.nonce_registry        TO qdh_policy_engine_role;
GRANT INSERT ON qdh_schema.audit_anchors         TO qdh_policy_engine_role;

GRANT SELECT ON qdh_schema.* TO s64_auditor_role;

-- ---------------------------------------------------------------------------
-- 20. Seed data
-- ---------------------------------------------------------------------------
INSERT INTO event_type_registry (event_type, is_core, description) VALUES
 ('ENGINE_INITIAL_BOUND',1,'Genesis binding of a (Class,Engine) at epoch 1, watermark 0'),
 ('NODE_QUARANTINE_TRIGGERED',1,'Node-wide blast-radius quarantine, one event per affected engine'),
 ('DE_WATERMARK_VERIFIED',1,'Durable lease and tombstone audit completed'),
 ('HE_SANITIZATION_ATTESTED',1,'Sanitization, zeroization, and attestation verified'),
 ('RECLAMATION_COMMITTED',1,'Atomic generation commit and lineage append'),
 ('ALLOCATOR_LEASE_ISSUED',1,'New epoch-bound allocator lease granted'),
 ('ENGINE_REACTIVATED',1,'Engine returned to STATE_ACTIVE'),
 ('FENCING_VIOLATION_BLOCKED',1,'Stale allocator write rejected'),
 ('ENGINE_EXHAUSTED_ROLLOVER',1,'Namespace exhausted, forward engine reserved'),
 ('ENGINE_EXHAUSTED_TERMINAL',1,'Namespace exhausted, no eligible forward engine'),
 ('ENGINE_RETIRED_PERMANENT',1,'Terminal engine retirement'),
 ('PROFILE_UPGRADED',1,'Explicit profile upgrade under core 13.1');

INSERT INTO incident_trigger_class (trigger_class, is_core, description) VALUES
 ('FAIL_HARD_POWER_LOSS',1,'Power cut or power-loss event'),
 ('FAIL_HARD_HARDWARE_FAULT',1,'Hardware fault or failure'),
 ('FAIL_HARD_STORAGE_STALL',1,'Storage stall affecting authoritative state'),
 ('FAIL_HARD_SPLIT_BRAIN',1,'Heartbeat loss indicative of split brain'),
 ('DE_EVIDENCE_INSUFFICIENT',1,'DE could not establish a safe watermark'),
 ('DE_TOMBSTONE_GAP',1,'DE detected a missing or out-of-range tombstone'),
 ('DE_PROFILE_MISMATCH',1,'DE detected conflicting profile evidence'),
 ('HE_SANITIZATION_FAILED',1,'HE failed verification or attestation'),
 ('HE_ATTESTATION_REPLAYED',1,'HE rejected a replayed nonce, expired certificate, or nonce/digest mismatch'),
 ('FENCING_VIOLATION',1,'Stale allocator write or lease renewal blocked'),
 ('MANUAL_OVERRIDE_ATTEMPT',1,'Unauthorized manual override attempted'),
 ('AUDIT_CHAIN_BREAK',1,'Audit hash-chain integrity failure'),
 ('EVIDENCE_BINDING_MISSING',1,'Transition attempted without required prior evidence'),
 ('PHASE5_ORDERING_VIOLATION',1,'Phase 5 events emitted out of order'),
 ('LIFECYCLE_TRANSITION_REJECTED',1,'Transition not permitted by the state machine'),
 ('ENGINE_NOT_FOUND',1,'(Class,Engine) did not resolve during a QDH operation'),
 ('RANGE_INVALID',1,'Engine or Local coordinate out of range, or below the watermark floor'),
 ('HOST_UNFIT',1,'Binding, allocation, or reactivation attempted on a non-active node'),
 ('PROFILE_UPGRADE',1,'Explicit profile upgrade under core 13.1');

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------

-- END OF FILE


-- ---------------------------------------------------------------------------
-- 26. Identifier validation (core §16.1 order)
-- ---------------------------------------------------------------------------
DELIMITER $$
CREATE FUNCTION s64_validate(p_id BIGINT UNSIGNED)
RETURNS VARCHAR(16)
    READS SQL DATA
BEGIN
    DECLARE v_ver TINYINT; DECLARE v_rev TINYINT; DECLARE v_res TINYINT;
    DECLARE v_cls TINYINT; DECLARE v_eng INT;     DECLARE v_loc INT;
    DECLARE v_ap VARCHAR(32); DECLARE v_ae BIGINT;
    DECLARE v_cp VARCHAR(32); DECLARE v_ce BIGINT;  DECLARE v_gp VARCHAR(32) DEFAULT NULL;
    DECLARE v_lin JSON;

    SET v_ver = (p_id >> 63) & 1;
    SET v_rev = (p_id >> 59) & 15;
    IF v_ver <> 0 OR v_rev <> 2 THEN RETURN 'S64-E002'; END IF;

    SET v_res = (p_id >> 54) & 15;
    IF v_res <> 0 THEN RETURN 'S64-E003'; END IF;

    SET v_cls = (p_id >> 50) & 15;
    IF v_cls = 0 THEN RETURN 'S64-E004'; END IF;
    IF v_cls > 8  THEN RETURN 'S64-E005'; END IF;

    SET v_eng = (p_id >> 29) & 2097151;
    SET v_loc = p_id & 536870911;

    SELECT allocated_profile, allocated_epoch INTO v_ap, v_ae
      FROM identity_records
     WHERE class_id = v_cls AND engine_id = v_eng AND local_id = v_loc;
    IF v_ap IS NULL THEN RETURN 'S64-E008'; END IF;

    SELECT active_profile, generation_epoch INTO v_cp, v_ce
      FROM virtual_engines WHERE class_id = v_cls AND engine_id = v_eng;
    IF v_cp IS NULL THEN RETURN 'S64-E013'; END IF;

    -- provenance is compared against the allocation generation, never the current profile
    IF v_ae = v_ce THEN
        SET v_gp = v_cp;
    ELSE
        SELECT lineage INTO v_lin FROM virtual_engines
         WHERE class_id = v_cls AND engine_id = v_eng;
        SELECT jt.pv INTO v_gp
          FROM JSON_TABLE(v_lin, '$[*]' COLUMNS (ge BIGINT PATH '$.generation_epoch',
                                                 pv VARCHAR(32) PATH '$.profile_version_revision')) jt
         WHERE jt.ge = v_ae LIMIT 1;
    END IF;
    IF v_gp IS NULL OR v_gp <> v_ap THEN RETURN 'S64-E030'; END IF;

    RETURN 'VALID';
END$$
DELIMITER ;

GRANT EXECUTE ON FUNCTION qdh_schema.s64_validate
      TO s64_controller_role, s64_allocator_role, qdh_policy_engine_role, s64_auditor_role;
