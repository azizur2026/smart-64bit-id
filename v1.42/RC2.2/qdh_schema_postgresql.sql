-- ============================================================================
-- SMART 64-Bit ID v1.42 (Version 0, Revision 0010)
-- QDH Reference Relational Schema — PostgreSQL 13+
-- STATUS: RC2.2 (final) — aligned to SPECIFICATION.md, ERROR-CODES.md,
--         QDH-SPECIFICATION.md, QDH-ERROR-CODES.md, QDH-LOGGING-AND-LIFECYCLE.md
-- LICENSE: AGPL3   CONTACT: contact@samara.com.bd
-- ----------------------------------------------------------------------------
-- Single-pass file. Objects are created in dependency order; no ALTER is
-- required afterwards and there is no circular foreign key.
-- BIT LAYOUT (core §2): 63 Version=0 | 62..59 Revision=0010 | 58 Role
--   57..54 Reserved=0000 | 53..50 Class | 49..29 Engine | 28..0 Local
-- IDENTITY KEY: (Class, Engine, Local)      VIRTUAL ENGINE KEY: (Class, Engine)
-- ----------------------------------------------------------------------------
-- ROLES: s64_controller_role, s64_allocator_role, qdh_policy_engine_role,
--        s64_auditor_role. Cross-role writes go through SECURITY DEFINER
--        functions only.
-- ERROR SURFACE: RAISE ... USING ERRCODE, DETAIL = json{build of 8 fields},
--        MESSAGE = 'qdh|s64|op|class|engine|local|epoch'. A '-' in the qdh
--        position means no QDH subsystem code applies.
-- AUDIT PROOF: linkage, event_hash = sha256(payload_canonical), and semantic
--        correspondence of the jsonb projection. The schema cannot prove that
--        payload_canonical is the RFC 8785 form; the golden vectors cover that.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------------
-- 1. Trust roots
-- ---------------------------------------------------------------------------
CREATE TABLE trust_roots (
    trust_root_id       char(64)    PRIMARY KEY,
    platform            varchar(128) NOT NULL,
    measurement_digest  char(64)    NOT NULL,
    valid_from_utc      timestamptz NOT NULL,
    valid_to_utc        timestamptz NOT NULL,
    revoked_at_utc      timestamptz NULL,
    created_at_utc      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_tr_window CHECK (valid_to_utc > valid_from_utc)
);

-- ---------------------------------------------------------------------------
-- 2. Physical nodes
-- ---------------------------------------------------------------------------
CREATE TABLE physical_nodes (
    node_id            varchar(128) PRIMARY KEY,
    node_state         varchar(32)  NOT NULL,
    network_address    varchar(64)  NOT NULL,
    hardware_address   varchar(32)  NOT NULL,
    substrate_attested boolean      NOT NULL DEFAULT false,
    quarantined_at_utc timestamptz  NULL,
    unfit_at_utc       timestamptz  NULL,
    created_at_utc     timestamptz  NOT NULL DEFAULT now(),
    updated_at_utc     timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT uq_node_hw UNIQUE (hardware_address),
    CONSTRAINT chk_node_state CHECK (node_state IN
        ('NODE_ACTIVE','NODE_QUARANTINED','NODE_UNFIT','NODE_RETIRED')),
    CONSTRAINT chk_node_qts CHECK (
        (node_state <> 'NODE_QUARANTINED' AND quarantined_at_utc IS NULL)
     OR (node_state =  'NODE_QUARANTINED' AND quarantined_at_utc IS NOT NULL)),
    CONSTRAINT chk_node_uts CHECK (
        (node_state <> 'NODE_UNFIT' AND unfit_at_utc IS NULL)
     OR (node_state =  'NODE_UNFIT' AND unfit_at_utc IS NOT NULL))
);

-- ---------------------------------------------------------------------------
-- 3. Nonce registry
-- ---------------------------------------------------------------------------
CREATE TABLE nonce_registry (
    nonce            char(64)    PRIMARY KEY,
    class_id         smallint    NOT NULL,
    engine_id        integer     NOT NULL,
    generation_epoch bigint      NOT NULL,
    incident_id      varchar(64) NOT NULL,
    issued_at_utc    timestamptz NOT NULL DEFAULT now(),
    consumed_at_utc  timestamptz NULL,
    CONSTRAINT chk_nr_epoch CHECK (generation_epoch >= 1)
);

-- ---------------------------------------------------------------------------
-- 4. Event type and incident class registries
-- ---------------------------------------------------------------------------
CREATE TABLE event_type_registry (
    event_type        varchar(64) PRIMARY KEY,
    is_core           boolean     NOT NULL DEFAULT false,
    description       varchar(255) NOT NULL,
    registered_at_utc timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE incident_trigger_class (
    trigger_class     varchar(64) PRIMARY KEY,
    is_core           boolean     NOT NULL DEFAULT false,
    description       varchar(255) NOT NULL,
    registered_at_utc timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- 5. Allocator leases  (engine existence validated by trigger, no cycle)
-- ---------------------------------------------------------------------------
CREATE TABLE allocator_leases (
    lease_id              uuid        PRIMARY KEY,
    class_id              smallint    NOT NULL,
    engine_id             integer     NOT NULL,
    generation_epoch      bigint      NOT NULL,
    issued_at_utc         timestamptz NOT NULL DEFAULT now(),
    expires_at_utc        timestamptz NOT NULL,
    revoked_at_utc        timestamptz NULL,
    lease_signature       text        NOT NULL,
    signing_trust_root_id char(64)    NOT NULL REFERENCES trust_roots(trust_root_id),
    CONSTRAINT chk_al_epoch CHECK (generation_epoch >= 1)
);
CREATE UNIQUE INDEX uq_al_active ON allocator_leases (class_id, engine_id)
    WHERE revoked_at_utc IS NULL;

-- ---------------------------------------------------------------------------
-- 6. Virtual engines
-- ---------------------------------------------------------------------------
CREATE TABLE virtual_engines (
    class_id           smallint    NOT NULL,
    engine_id          integer     NOT NULL,
    active_profile     varchar(32) NOT NULL,
    generation_epoch   bigint      NOT NULL DEFAULT 1,
    lifecycle_state    varchar(32) NOT NULL,
    local_watermark    bigint      NOT NULL DEFAULT 0,
    physical_node_id   varchar(128) NOT NULL REFERENCES physical_nodes(node_id),
    allocator_lease_id uuid        NULL REFERENCES allocator_leases(lease_id),
    lineage            jsonb       NOT NULL,
    created_at_utc     timestamptz NOT NULL DEFAULT now(),
    updated_at_utc     timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (class_id, engine_id),
    CONSTRAINT chk_ve_class  CHECK (class_id BETWEEN 1 AND 8),
    CONSTRAINT chk_ve_engine CHECK (engine_id BETWEEN 0 AND 2097151),
    CONSTRAINT chk_ve_prof   CHECK (active_profile IN ('v1.41','v1.42')),
    CONSTRAINT chk_ve_epoch  CHECK (generation_epoch >= 1),
    CONSTRAINT chk_ve_state  CHECK (lifecycle_state IN (
        'STATE_UNALLOCATED','STATE_ACTIVE','STATE_QUARANTINED',
        'STATE_DE_VERIFYING','STATE_HE_SANITIZING','STATE_RECLAIM_COMMIT',
        'STATE_EXHAUSTED','STATE_RETIRED_PERMANENT')),
    CONSTRAINT chk_ve_wm     CHECK (local_watermark BETWEEN 0 AND 536870912),
    CONSTRAINT chk_ve_exh    CHECK (local_watermark < 536870912
                                    OR lifecycle_state IN ('STATE_EXHAUSTED','STATE_RETIRED_PERMANENT')),
    CONSTRAINT chk_ve_lease  CHECK (lifecycle_state <> 'STATE_ACTIVE'
                                    OR allocator_lease_id IS NOT NULL),
    CONSTRAINT chk_ve_lineage CHECK (jsonb_typeof(lineage) = 'array')
);
CREATE INDEX idx_ve_rollover ON virtual_engines
    (class_id, lifecycle_state, engine_id, local_watermark);
CREATE INDEX idx_ve_node ON virtual_engines (physical_node_id, lifecycle_state);

-- ---------------------------------------------------------------------------
-- 7. Identity records
-- ---------------------------------------------------------------------------
CREATE TABLE identity_records (
    class_id              smallint    NOT NULL,
    engine_id             integer     NOT NULL,
    local_id              integer     NOT NULL,
    full_smart_id         numeric(20) NOT NULL,
    role_bit              smallint    NOT NULL,
    allocated_profile     varchar(32) NOT NULL,
    allocated_epoch       bigint      NOT NULL,
    history_chain_root_id char(64)    NOT NULL,
    predecessor_smart_id  numeric(20) NULL,
    is_active             boolean     NOT NULL DEFAULT false,
    is_retired            boolean     NOT NULL DEFAULT false,
    allocated_at_utc      timestamptz NOT NULL DEFAULT now(),
    activated_at_utc      timestamptz NULL,
    retired_at_utc        timestamptz NULL,
    PRIMARY KEY (class_id, engine_id, local_id),
    CONSTRAINT fk_ir_ve FOREIGN KEY (class_id, engine_id)
        REFERENCES virtual_engines(class_id, engine_id),
    CONSTRAINT uq_ir_full UNIQUE (full_smart_id),
    CONSTRAINT uq_ir_pred UNIQUE (predecessor_smart_id),
    CONSTRAINT chk_ir_class   CHECK (class_id BETWEEN 1 AND 8),
    CONSTRAINT chk_ir_engine  CHECK (engine_id BETWEEN 0 AND 2097151),
    CONSTRAINT chk_ir_local   CHECK (local_id BETWEEN 0 AND 536870911),
    CONSTRAINT chk_ir_role    CHECK (role_bit IN (0,1)),
    CONSTRAINT chk_ir_profile CHECK (allocated_profile IN ('v1.41','v1.42')),
    CONSTRAINT chk_ir_not_both CHECK (NOT (is_active AND is_retired)),
    CONSTRAINT chk_ir_act_ts  CHECK (
        (is_active AND activated_at_utc IS NOT NULL)
     OR (NOT is_active AND activated_at_utc IS NULL)),
    CONSTRAINT chk_ir_ret_ts  CHECK (
        (NOT is_retired AND retired_at_utc IS NULL)
     OR (is_retired AND retired_at_utc IS NOT NULL))
);
CREATE UNIQUE INDEX uq_ir_active_chain ON identity_records (history_chain_root_id)
    WHERE is_active;
CREATE INDEX idx_ir_chain ON identity_records (history_chain_root_id);

-- ---------------------------------------------------------------------------
-- 8. Coordinate tombstones
-- ---------------------------------------------------------------------------
CREATE TABLE coordinate_tombstones (
    class_id          smallint    NOT NULL,
    engine_id         integer     NOT NULL,
    local_id          integer     NOT NULL,
    allocated_profile varchar(32) NOT NULL,
    allocated_epoch   bigint      NOT NULL,
    status            varchar(16) NOT NULL,
    recorded_at_utc   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (class_id, engine_id, local_id),
    CONSTRAINT fk_ct_ve FOREIGN KEY (class_id, engine_id)
        REFERENCES virtual_engines(class_id, engine_id),
    CONSTRAINT chk_ct_status CHECK (status IN ('CONSUMED','RETIRED')),
    CONSTRAINT chk_ct_epoch  CHECK (allocated_epoch >= 1),
    CONSTRAINT chk_ct_local  CHECK (local_id BETWEEN 0 AND 536870911)
);

-- ---------------------------------------------------------------------------
-- 9. Durable allocation log
-- ---------------------------------------------------------------------------
CREATE TABLE durable_allocation_log (
    class_id      smallint    NOT NULL,
    engine_id     integer     NOT NULL,
    local_id      integer     NOT NULL,
    epoch         bigint      NOT NULL,
    profile       varchar(32) NOT NULL,
    role_bit      smallint    NOT NULL,
    full_smart_id numeric(20) NOT NULL,
    recorded_at_utc timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (class_id, engine_id, local_id),
    CONSTRAINT fk_dal_ve FOREIGN KEY (class_id, engine_id)
        REFERENCES virtual_engines(class_id, engine_id),
    CONSTRAINT chk_dal_local CHECK (local_id BETWEEN 0 AND 536870911)
);

-- ---------------------------------------------------------------------------
-- 10. Lease watermarks
-- ---------------------------------------------------------------------------
CREATE TABLE lease_watermarks (
    lease_id      uuid        PRIMARY KEY,
    class_id      smallint    NOT NULL,
    engine_id     integer     NOT NULL,
    lease_floor   bigint      NOT NULL,
    lease_ceiling bigint      NOT NULL,
    release_state varchar(16) NOT NULL DEFAULT 'ACTIVE',
    recorded_at_utc timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_lw_ve FOREIGN KEY (class_id, engine_id)
        REFERENCES virtual_engines(class_id, engine_id),
    CONSTRAINT uq_lw_range UNIQUE (class_id, engine_id, lease_floor),
    CONSTRAINT chk_lw_order CHECK (lease_floor >= 0 AND lease_ceiling <= 536870912
                                   AND lease_floor < lease_ceiling),
    CONSTRAINT chk_lw_state CHECK (release_state IN ('ACTIVE','CONSUMED','RELEASED'))
);

-- ---------------------------------------------------------------------------
-- 11. Hardware attestations
-- ---------------------------------------------------------------------------
CREATE TABLE hardware_attestations (
    attestation_id           bigserial   PRIMARY KEY,
    class_id                 smallint    NOT NULL,
    engine_id                integer     NOT NULL,
    bound_generation_epoch   bigint      NOT NULL,
    bound_incident_id        varchar(64) NOT NULL,
    challenge_nonce          char(64)    NOT NULL UNIQUE REFERENCES nonce_registry(nonce),
    attestation_digest       char(64)    NOT NULL,
    signing_trust_root_id    char(64)    NOT NULL REFERENCES trust_roots(trust_root_id),
    sanitization_method      varchar(16) NOT NULL,
    verification_result      varchar(16) NOT NULL,
    cert_not_before_utc      timestamptz NOT NULL,
    cert_not_after_utc       timestamptz NOT NULL,
    revocation_checked_at_utc timestamptz NOT NULL,
    verified_at_utc          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_ha_method CHECK (sanitization_method IN ('CLEAR','PURGE','DESTROY')),
    CONSTRAINT chk_ha_result CHECK (verification_result IN ('PASS','FAIL')),
    CONSTRAINT chk_ha_window CHECK (cert_not_after_utc > cert_not_before_utc)
);

-- ---------------------------------------------------------------------------
-- 12. QDH audit events
-- ---------------------------------------------------------------------------
CREATE TABLE qdh_audit_events (
    event_id          uuid        PRIMARY KEY,
    class_id          smallint    NOT NULL,
    engine_id         integer     NOT NULL,
    stream_seq        bigint      NOT NULL,
    event_type        varchar(64) NOT NULL REFERENCES event_type_registry(event_type),
    generation_epoch  bigint      NOT NULL,
    timestamp_utc     timestamptz NOT NULL,
    previous_state    varchar(32) NOT NULL,
    new_state         varchar(32) NOT NULL,
    epoch_before      bigint      NOT NULL,
    epoch_after       bigint      NOT NULL,
    profile_before    varchar(32) NOT NULL,
    profile_after     varchar(32) NOT NULL,
    watermark_verified bigint     NULL,
    qdh_error_code    varchar(16) NULL,
    s64_error_code    varchar(16) NULL,
    prev_event_hash   char(64)    NOT NULL,
    event_hash        char(64)    NOT NULL,
    payload_canonical bytea       NOT NULL,
    payload           jsonb       NOT NULL,
    CONSTRAINT fk_qae_ve FOREIGN KEY (class_id, engine_id)
        REFERENCES virtual_engines(class_id, engine_id),
    CONSTRAINT uq_qae_stream UNIQUE (class_id, engine_id, stream_seq),
    CONSTRAINT uq_qae_hash UNIQUE (event_hash),
    CONSTRAINT chk_qae_seq   CHECK (stream_seq >= 1),
    CONSTRAINT chk_qae_epoch CHECK (generation_epoch >= 1
                                    AND epoch_before >= 1 AND epoch_after >= 1),
    CONSTRAINT chk_qae_hash_fmt CHECK (event_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT chk_qae_prev_fmt CHECK (prev_event_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT chk_qae_payload  CHECK (jsonb_typeof(payload) = 'object')
);

-- ---------------------------------------------------------------------------
-- 13. Audit anchors
-- ---------------------------------------------------------------------------
CREATE TABLE audit_anchors (
    anchor_id       bigserial   PRIMARY KEY,
    root_hash       char(64)    NOT NULL UNIQUE,
    anchor_uri      varchar(512) NOT NULL,
    covers_from_utc timestamptz NOT NULL,
    covers_to_utc   timestamptz NOT NULL,
    anchored_at_utc timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_anchor_window CHECK (covers_to_utc > covers_from_utc)
);

-- ===========================================================================
-- 14. Helper functions
-- ===========================================================================
CREATE OR REPLACE FUNCTION qdh_raise(
    p_state text, p_qdh text, p_s64 text, p_op text,
    p_class integer, p_engine integer, p_local integer,
    p_epoch bigint, p_human text
) RETURNS void AS $$
BEGIN
    RAISE EXCEPTION USING
        ERRCODE = p_state,
        MESSAGE = p_qdh || '|' || p_s64 || '|' || p_op || '|'
                  || coalesce(p_class::text,'') || '|'
                  || coalesce(p_engine::text,'') || '|'
                  || coalesce(p_local::text,'') || '|'
                  || coalesce(p_epoch::text,'') || '|' || p_human,
        DETAIL  = json_build_object(
                      'qdh_code',         p_qdh,
                      's64_code',         p_s64,
                      'operation_class',  p_op,
                      'class_id',         p_class,
                      'engine_id',        p_engine,
                      'local_id',         p_local,
                      'generation_epoch', p_epoch,
                      'human_message',    p_human)::text;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_expected_smart_id_v142(
    p_class integer, p_engine integer, p_local integer, p_role integer
) RETURNS bigint AS $$
BEGIN
    RETURN ( (2::bigint << 59) | (p_role::bigint << 58) | (p_class::bigint << 50)
           | (p_engine::bigint << 29) | p_local::bigint );
END $$ LANGUAGE plpgsql IMMUTABLE;

-- Golden-vector verifier (QDH-LOGGING §1.2)
CREATE OR REPLACE FUNCTION verify_audit_vector(
    p_canonical text, p_expected char(64)
) RETURNS integer AS $$
BEGIN
    RETURN CASE WHEN encode(sha256(convert_to(p_canonical,'UTF8')),'hex')
                     = lower(p_expected) THEN 1 ELSE 0 END;
END $$ LANGUAGE plpgsql IMMUTABLE;

-- ===========================================================================
-- 15. Allocation, retirement, quarantine, generation commit
-- ===========================================================================

CREATE OR REPLACE FUNCTION s64_allocate(
    p_class integer, p_engine integer, p_local integer, p_role integer,
    p_profile text, p_epoch bigint, p_chain_root text, p_pred numeric,
    OUT p_full_id numeric
) AS $$
DECLARE
    v_state   varchar(32);
    v_epoch   bigint;
    v_wm      bigint;
    v_node    varchar(128);
    v_lease   uuid;
    v_revoked timestamptz;
    v_expires timestamptz;
    v_node_st varchar(32);
BEGIN
    IF p_local IS NULL OR p_local < 0 OR p_local > 536870911 THEN
        PERFORM qdh_raise('45001','QDH-E020','S64-E023','COMMIT',
                          p_class, p_engine, p_local, p_epoch,
                          'Local coordinate out of range');
    END IF;

    SELECT lifecycle_state, generation_epoch, local_watermark, physical_node_id,
           allocator_lease_id
      INTO v_state, v_epoch, v_wm, v_node, v_lease
      FROM virtual_engines
     WHERE class_id = p_class AND engine_id = p_engine
       FOR UPDATE;

    IF NOT FOUND THEN
        PERFORM qdh_raise('45001','QDH-E019','S64-E013','COMMIT',
                          p_class, p_engine, p_local, p_epoch,
                          '(Class,Engine) does not resolve to a control-table row');
    END IF;

    IF v_lease IS NULL THEN
        PERFORM qdh_raise('45003','QDH-E003','S64-E019','COMMIT',
                          p_class, p_engine, p_local, v_epoch,
                          'No allocator authority attached to engine');
    END IF;

    SELECT revoked_at_utc, expires_at_utc, generation_epoch
      INTO v_revoked, v_expires, v_epoch
      FROM allocator_leases WHERE lease_id = v_lease;

    IF v_revoked IS NOT NULL OR v_expires <= now() THEN
        PERFORM qdh_raise('45003','QDH-E003','S64-E019','COMMIT',
                          p_class, p_engine, p_local, v_epoch,
                          'Allocator lease revoked or expired');
    END IF;

    IF p_epoch <> v_epoch THEN
        PERFORM qdh_raise('45003','QDH-E003','S64-E019','COMMIT',
                          p_class, p_engine, p_local, v_epoch,
                          'Generation epoch does not match current epoch');
    END IF;

    IF v_state <> 'STATE_ACTIVE' THEN
        PERFORM qdh_raise('45001','QDH-E018','S64-E031','COMMIT',
                          p_class, p_engine, p_local, v_epoch,
                          'Engine state does not admit allocation');
    END IF;

    SELECT node_state INTO v_node_st FROM physical_nodes WHERE node_id = v_node;
    IF v_node_st IS DISTINCT FROM 'NODE_ACTIVE' THEN
        PERFORM qdh_raise('45001','QDH-E007','S64-E021','COMMIT',
                          p_class, p_engine, p_local, v_epoch,
                          'Hosting node is not NODE_ACTIVE');
    END IF;

    IF p_local < v_wm THEN
        PERFORM qdh_raise('45001','QDH-E014','S64-E018','COMMIT',
                          p_class, p_engine, p_local, v_epoch,
                          'Local coordinate below the non-reuse floor');
    END IF;

    IF p_local > v_wm THEN
        PERFORM qdh_raise('45001','QDH-E020','S64-E023','COMMIT',
                          p_class, p_engine, p_local, v_epoch,
                          'Unrecorded forward gap; allocation must resume at next_safe_local');
    END IF;

    p_full_id := fn_expected_smart_id_v142(p_class, p_engine, p_local, p_role);

    INSERT INTO identity_records
        (class_id, engine_id, local_id, full_smart_id, role_bit,
         allocated_profile, allocated_epoch, history_chain_root_id, predecessor_smart_id)
    VALUES
        (p_class, p_engine, p_local, p_full_id::numeric, p_role,
         p_profile, p_epoch, p_chain_root, p_pred);

    INSERT INTO durable_allocation_log
        (class_id, engine_id, local_id, epoch, profile, role_bit, full_smart_id)
    VALUES
        (p_class, p_engine, p_local, p_epoch, p_profile, p_role, p_full_id::numeric);

    UPDATE virtual_engines
       SET local_watermark = p_local + 1, updated_at_utc = now()
     WHERE class_id = p_class AND engine_id = p_engine
       AND generation_epoch = p_epoch;

    IF NOT FOUND THEN
        PERFORM qdh_raise('45003','QDH-E003','S64-E019','COMMIT',
                          p_class, p_engine, p_local, p_epoch,
                          'Epoch-fenced update affected no row');
    END IF;

END $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION s64_allocate_range(
    p_class integer, p_engine integer, p_from integer, p_count integer,
    p_role integer, p_profile text, p_epoch bigint, p_chain_root text
) RETURNS integer AS $$
DECLARE
    i integer := 0;
    v_id numeric;
BEGIN
    WHILE i < p_count LOOP
        SELECT s64_allocate(p_class, p_engine, p_from + i, p_role, p_profile,
                            p_epoch, p_chain_root, NULL) INTO v_id;
        i := i + 1;
    END LOOP;
    RETURN i;
END $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION s64_retire(
    p_class integer, p_engine integer, p_local integer
) RETURNS void AS $$
DECLARE
    v_active  boolean;
    v_retired boolean;
BEGIN
    SELECT is_active, is_retired INTO v_active, v_retired
      FROM identity_records
     WHERE class_id = p_class AND engine_id = p_engine AND local_id = p_local
       FOR UPDATE;

    IF NOT FOUND THEN
        PERFORM qdh_raise('45001','QDH-E019','S64-E013','RETIREMENT',
                          p_class, p_engine, p_local, 0,
                          'Identity record not found');
    END IF;

    IF v_retired THEN
        PERFORM qdh_raise('45001','QDH-E018','S64-E031','RETIREMENT',
                          p_class, p_engine, p_local, 0,
                          'Record already retired');
    END IF;

    UPDATE identity_records
       SET is_active = false, activated_at_utc = NULL,
           is_retired = true, retired_at_utc = now()
     WHERE class_id = p_class AND engine_id = p_engine AND local_id = p_local;


END $$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fencing primitive only. The calling control plane MUST, in the same
-- transaction, insert one NODE_QUARANTINE_TRIGGERED event per affected engine
-- and record the incident. Gaps are reported by qdh_audit_gap.
CREATE OR REPLACE FUNCTION qdh_begin_quarantine(
    p_node_id text
) RETURNS void AS $$
BEGIN
    UPDATE physical_nodes
       SET node_state = 'NODE_QUARANTINED', quarantined_at_utc = now(),
           updated_at_utc = now()
     WHERE node_id = p_node_id AND node_state = 'NODE_ACTIVE';
END $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION qdh_commit_generation(
    p_class integer, p_engine integer, p_safe_local bigint,
    p_node text, p_reason text, p_closing_event uuid
) RETURNS void AS $$
DECLARE
    v_epoch   bigint;
    v_profile varchar(32);
    v_wm      bigint;
    v_opened  timestamptz;
    v_state   varchar(32);
BEGIN
    IF p_reason NOT IN ('FAIL_HARD_RECLAIMED','NODE_REFURBISHMENT','EXHAUSTED') THEN
        PERFORM qdh_raise('45001','QDH-E018','S64-E031','CONTROL',
                          p_class, p_engine, 0, 0,
                          'Reclamation may record only reclaim, refurbish, or exhaust');
    END IF;

    IF p_safe_local < 0 OR p_safe_local > 536870912 THEN
        PERFORM qdh_raise('45001','QDH-E020','S64-E023','CONTROL',
                          p_class, p_engine, p_safe_local::integer, 0,
                          'next_safe_local out of range');
    END IF;

    SELECT generation_epoch, active_profile, local_watermark, created_at_utc, lifecycle_state
      INTO v_epoch, v_profile, v_wm, v_opened, v_state
      FROM virtual_engines
     WHERE class_id = p_class AND engine_id = p_engine
       FOR UPDATE;

    IF NOT FOUND THEN
        PERFORM qdh_raise('45001','QDH-E019','S64-E013','CONTROL',
                          p_class, p_engine, 0, 0,
                          '(Class,Engine) does not resolve');
    END IF;

    IF p_safe_local < v_wm THEN
        PERFORM qdh_raise('45001','QDH-E014','S64-E018','CONTROL',
                          p_class, p_engine, p_safe_local::integer, v_epoch,
                          'Watermark regression');
    END IF;

    UPDATE virtual_engines
       SET lifecycle_state = CASE WHEN p_safe_local >= 536870912
                                  THEN 'STATE_EXHAUSTED' ELSE 'STATE_RECLAIM_COMMIT' END,
           local_watermark = p_safe_local,
           generation_epoch = generation_epoch + 1,
           lineage = lineage || jsonb_build_array(jsonb_build_object(
                         'generation_epoch',        v_epoch,
                         'profile_version_revision', v_profile,
                         'local_start',             v_wm,
                         'local_end_watermark',     p_safe_local,
                         'physical_node_id',        p_node,
                         'opened_at_utc',           v_opened,
                         'closed_at_utc',           now(),
                         'closure_reason',          p_reason,
                         'closing_audit_event_id',  p_closing_event)),
           updated_at_utc = now()
     WHERE class_id = p_class AND engine_id = p_engine
       AND generation_epoch = v_epoch;

    IF NOT FOUND THEN
        PERFORM qdh_raise('45003','QDH-E003','S64-E019','CONTROL',
                          p_class, p_engine, p_safe_local::integer, v_epoch,
                          'Commit did not affect one row');
    END IF;
END $$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PART 2 — Trigger functions, triggers, views, roles, grants, seed data
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 16. Blast radius
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION tf_pn_after_update() RETURNS trigger AS $$
BEGIN
    IF NEW.node_state = 'NODE_QUARANTINED' AND OLD.node_state <> 'NODE_QUARANTINED' THEN
        UPDATE allocator_leases al
           SET revoked_at_utc = now()
          FROM virtual_engines ve
         WHERE ve.class_id = al.class_id AND ve.engine_id = al.engine_id
           AND ve.physical_node_id = NEW.node_id
           AND al.revoked_at_utc IS NULL;

        UPDATE virtual_engines
           SET lifecycle_state = 'STATE_QUARANTINED',
               allocator_lease_id = NULL,
               updated_at_utc = now()
         WHERE physical_node_id = NEW.node_id
           AND lifecycle_state NOT IN ('STATE_RETIRED_PERMANENT','STATE_QUARANTINED');
    END IF;
    RETURN NULL;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pn_after_update AFTER UPDATE ON physical_nodes
    FOR EACH ROW EXECUTE FUNCTION tf_pn_after_update();

-- ---------------------------------------------------------------------------
-- 17. Virtual engines
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION tf_ve_before_insert() RETURNS trigger AS $$
DECLARE
    v_node_state varchar(32);
    v_att        boolean;
BEGIN
    IF NEW.lifecycle_state <> 'STATE_UNALLOCATED' THEN
        PERFORM qdh_raise('45001','QDH-E018','S64-E031','CONTROL',
                          NEW.class_id, NEW.engine_id, 0, NEW.generation_epoch,
                          'Initial insert must be STATE_UNALLOCATED');
    END IF;

    IF NEW.generation_epoch <> 1 OR NEW.local_watermark <> 0
       OR jsonb_array_length(NEW.lineage) <> 0 THEN
        PERFORM qdh_raise('45001','QDH-E018','S64-E031','CONTROL',
                          NEW.class_id, NEW.engine_id, 0, 1,
                          'Initial generation must be epoch 1, watermark 0, empty lineage');
    END IF;

    SELECT node_state, substrate_attested INTO v_node_state, v_att
      FROM physical_nodes WHERE node_id = NEW.physical_node_id;

    IF NOT FOUND THEN
        PERFORM qdh_raise('45001','QDH-E019','S64-E013','CONTROL',
                          NEW.class_id, NEW.engine_id, 0, 1,
                          'Hosting node not found');
    END IF;

    IF v_node_state <> 'NODE_ACTIVE' OR NOT v_att THEN
        PERFORM qdh_raise('45001','QDH-E007','S64-E021','CONTROL',
                          NEW.class_id, NEW.engine_id, 0, 1,
                          'Binding requires a NODE_ACTIVE, attested host');
    END IF;

    RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ve_before_insert BEFORE INSERT ON virtual_engines
    FOR EACH ROW EXECUTE FUNCTION tf_ve_before_insert();

CREATE OR REPLACE FUNCTION tf_ve_before_update() RETURNS trigger AS $$
DECLARE
    v_len_o    integer;
    v_len_n    integer;
    v_last     jsonb;
    v_le_epoch bigint;
    v_le_start bigint;
    v_le_end   bigint;
    v_reason   varchar(32);
    v_event    uuid;
    v_cnt      integer;
    v_node_st  varchar(32);
    v_tr_rev   timestamptz;
    v_tr_exp   timestamptz;
    v_tr_epoch bigint;
    v_tr_cls   smallint;
    v_tr_eng   integer;
BEGIN
    IF NEW.class_id <> OLD.class_id OR NEW.engine_id <> OLD.engine_id THEN
        PERFORM qdh_raise('45001','QDH-E018','S64-E031','CONTROL',
                          OLD.class_id, OLD.engine_id, 0, OLD.generation_epoch,
                          'Control-table key is immutable');
    END IF;

    IF NEW.local_watermark < OLD.local_watermark THEN
        PERFORM qdh_raise('45001','QDH-E014','S64-E018','CONTROL',
                          OLD.class_id, OLD.engine_id, NEW.local_watermark::integer,
                          OLD.generation_epoch, 'Local watermark regression');
    END IF;

    IF NEW.active_profile <> OLD.active_profile THEN
        IF NEW.lifecycle_state <> OLD.lifecycle_state
           OR OLD.lifecycle_state <> 'STATE_ACTIVE' THEN
            PERFORM qdh_raise('45001','QDH-E018','S64-E031','CONTROL',
                              OLD.class_id, OLD.engine_id, 0, OLD.generation_epoch,
                              'Profile change outside the explicit upgrade procedure');
        END IF;
        IF NEW.generation_epoch <> OLD.generation_epoch + 1 THEN
            PERFORM qdh_raise('45001','QDH-E018','S64-E031','CONTROL',
                              OLD.class_id, OLD.engine_id, 0, OLD.generation_epoch,
                              'Profile change must open a new generation');
        END IF;
    END IF;

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
            PERFORM qdh_raise('45001','QDH-E018','S64-E031','CONTROL',
                              OLD.class_id, OLD.engine_id, 0, OLD.generation_epoch,
                              'Lifecycle transition not permitted: '
                              || OLD.lifecycle_state || ' -> ' || NEW.lifecycle_state);
        END IF;
    END IF;

    v_len_o := jsonb_array_length(OLD.lineage);
    v_len_n := jsonb_array_length(NEW.lineage);

    IF NEW.generation_epoch = OLD.generation_epoch THEN
        IF NEW.lineage IS DISTINCT FROM OLD.lineage THEN
            PERFORM qdh_raise('45002','QDH-E005','S64-E021','CONTROL',
                              OLD.class_id, OLD.engine_id, 0, OLD.generation_epoch,
                              'Lineage is append-only and unchanged without an epoch advance');
        END IF;
    ELSIF NEW.generation_epoch = OLD.generation_epoch + 1 THEN
        IF v_len_n <> v_len_o + 1 THEN
            PERFORM qdh_raise('45002','QDH-E005','S64-E021','CONTROL',
                              OLD.class_id, OLD.engine_id, 0, OLD.generation_epoch,
                              'Epoch advance requires exactly one appended lineage entry');
        END IF;

        v_last     := NEW.lineage -> (v_len_n - 1);
        v_le_epoch := (v_last ->> 'generation_epoch')::bigint;
        v_le_start := (v_last ->> 'local_start')::bigint;
        v_le_end   := (v_last ->> 'local_end_watermark')::bigint;
        v_reason   := v_last ->> 'closure_reason';
        v_event    := (v_last ->> 'closing_audit_event_id')::uuid;

        IF v_le_epoch <> OLD.generation_epoch
           OR v_le_start <> OLD.local_watermark
           OR v_le_end > NEW.local_watermark THEN
            PERFORM qdh_raise('45002','QDH-E005','S64-E021','CONTROL',
                              OLD.class_id, OLD.engine_id, 0, OLD.generation_epoch,
                              'Lineage entry does not describe the closed generation');
        END IF;

        IF v_reason NOT IN ('FAIL_HARD_RECLAIMED','NODE_REFURBISHMENT',
                            'EXHAUSTED','PROFILE_UPGRADE') THEN
            PERFORM qdh_raise('45002','QDH-E005','S64-E021','CONTROL',
                              OLD.class_id, OLD.engine_id, 0, OLD.generation_epoch,
                              'Unrecognised closure_reason: ' || coalesce(v_reason,'NULL'));
        END IF;

        SELECT count(*) INTO v_cnt FROM qdh_audit_events
         WHERE event_id = v_event
           AND class_id = OLD.class_id AND engine_id = OLD.engine_id
           AND generation_epoch = v_le_epoch
           AND event_type IN ('RECLAMATION_COMMITTED','ENGINE_EXHAUSTED_ROLLOVER',
                              'ENGINE_EXHAUSTED_TERMINAL','ENGINE_RETIRED_PERMANENT',
                              'PROFILE_UPGRADED');
        IF v_cnt <> 1 THEN
            PERFORM qdh_raise('45002','QDH-E005','S64-E021','CONTROL',
                              OLD.class_id, OLD.engine_id, 0, OLD.generation_epoch,
                              'closing_audit_event_id does not resolve to a matching closing event');
        END IF;
    ELSE
        PERFORM qdh_raise('45001','QDH-E018','S64-E031','CONTROL',
                          OLD.class_id, OLD.engine_id, 0, OLD.generation_epoch,
                          'Generation epoch may advance by exactly one');
    END IF;

    IF NEW.lifecycle_state = 'STATE_HE_SANITIZING'
       AND OLD.lifecycle_state <> 'STATE_HE_SANITIZING' THEN
        SELECT count(*) INTO v_cnt FROM qdh_audit_events
         WHERE class_id = OLD.class_id AND engine_id = OLD.engine_id
           AND generation_epoch = OLD.generation_epoch
           AND event_type = 'DE_WATERMARK_VERIFIED';
        IF v_cnt = 0 THEN
            PERFORM qdh_raise('45006','QDH-E016','S64-E021','CONTROL',
                              OLD.class_id, OLD.engine_id, 0, OLD.generation_epoch,
                              'DE_WATERMARK_VERIFIED missing for current generation');
        END IF;
    END IF;

    IF NEW.lifecycle_state = 'STATE_RECLAIM_COMMIT'
       AND OLD.lifecycle_state <> 'STATE_RECLAIM_COMMIT' THEN
        SELECT count(*) INTO v_cnt FROM qdh_audit_events
         WHERE class_id = OLD.class_id AND engine_id = OLD.engine_id
           AND generation_epoch = OLD.generation_epoch
           AND event_type = 'HE_SANITIZATION_ATTESTED';
        IF v_cnt = 0 THEN
            PERFORM qdh_raise('45006','QDH-E016','S64-E021','CONTROL',
                              OLD.class_id, OLD.engine_id, 0, OLD.generation_epoch,
                              'HE_SANITIZATION_ATTESTED missing for current generation');
        END IF;
    END IF;

    IF OLD.lifecycle_state = 'STATE_RECLAIM_COMMIT'
       AND NEW.lifecycle_state = 'STATE_ACTIVE' THEN
        SELECT count(*) INTO v_cnt FROM qdh_audit_events
         WHERE class_id = OLD.class_id AND engine_id = OLD.engine_id
           AND generation_epoch = NEW.generation_epoch
           AND event_type = 'ALLOCATOR_LEASE_ISSUED';
        IF v_cnt = 0 THEN
            PERFORM qdh_raise('45006','QDH-E017','S64-E021','CONTROL',
                              OLD.class_id, OLD.engine_id, 0, NEW.generation_epoch,
                              'ALLOCATOR_LEASE_ISSUED must precede ENGINE_REACTIVATED');
        END IF;
    END IF;

    IF NEW.lifecycle_state <> 'STATE_ACTIVE' AND NEW.allocator_lease_id IS NOT NULL THEN
        PERFORM qdh_raise('45001','QDH-E018','S64-E031','CONTROL',
                          OLD.class_id, OLD.engine_id, 0, NEW.generation_epoch,
                          'allocator_lease_id must be NULL outside STATE_ACTIVE');
    END IF;

    IF NEW.lifecycle_state = 'STATE_ACTIVE'
       AND OLD.lifecycle_state <> 'STATE_ACTIVE' THEN
        SELECT node_state INTO v_node_st
          FROM physical_nodes WHERE node_id = NEW.physical_node_id;
        IF v_node_st IS DISTINCT FROM 'NODE_ACTIVE' THEN
            PERFORM qdh_raise('45001','QDH-E007','S64-E021','CONTROL',
                              OLD.class_id, OLD.engine_id, 0, NEW.generation_epoch,
                              'Reactivation requires a NODE_ACTIVE host');
        END IF;

        IF NEW.allocator_lease_id IS NULL THEN
            PERFORM qdh_raise('45001','QDH-E018','S64-E031','CONTROL',
                              OLD.class_id, OLD.engine_id, 0, NEW.generation_epoch,
                              'STATE_ACTIVE requires an allocator lease');
        END IF;

        SELECT revoked_at_utc, expires_at_utc, generation_epoch, class_id, engine_id
          INTO v_tr_rev, v_tr_exp, v_tr_epoch, v_tr_cls, v_tr_eng
          FROM allocator_leases WHERE lease_id = NEW.allocator_lease_id;

        IF NOT FOUND
           OR v_tr_cls <> NEW.class_id OR v_tr_eng <> NEW.engine_id
           OR v_tr_epoch <> NEW.generation_epoch
           OR v_tr_rev IS NOT NULL
           OR v_tr_exp <= now() THEN
            PERFORM qdh_raise('45003','QDH-E003','S64-E019','CONTROL',
                              OLD.class_id, OLD.engine_id, 0, NEW.generation_epoch,
                              'Lease is absent, revoked, expired, or bound to a different epoch');
        END IF;
    END IF;

    IF NEW.physical_node_id IS DISTINCT FROM OLD.physical_node_id THEN
        IF OLD.lifecycle_state IN ('STATE_ACTIVE','STATE_RETIRED_PERMANENT') THEN
            PERFORM qdh_raise('45001','QDH-E018','S64-E031','CONTROL',
                              OLD.class_id, OLD.engine_id, 0, OLD.generation_epoch,
                              'Placement change not permitted in the current state');
        END IF;
        SELECT node_state INTO v_node_st
          FROM physical_nodes WHERE node_id = NEW.physical_node_id;
        IF v_node_st IS DISTINCT FROM 'NODE_ACTIVE' THEN
            PERFORM qdh_raise('45001','QDH-E007','S64-E021','CONTROL',
                              OLD.class_id, OLD.engine_id, 0, OLD.generation_epoch,
                              'Placement target is not NODE_ACTIVE');
        END IF;
    END IF;

    RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ve_before_update BEFORE UPDATE ON virtual_engines
    FOR EACH ROW EXECUTE FUNCTION tf_ve_before_update();

-- ---------------------------------------------------------------------------
-- 18. Identity records
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION tf_ir_before_insert() RETURNS trigger AS $$
DECLARE
    v_epoch    bigint;
    v_profile  varchar(32);
    v_pred_root char(64);
    v_found    boolean;
BEGIN
    IF NEW.full_smart_id <> fn_expected_smart_id_v142(
           NEW.class_id, NEW.engine_id, NEW.local_id, NEW.role_bit)::numeric THEN
        PERFORM qdh_raise('45001','-','S64-E027','COMMIT',
                          NEW.class_id, NEW.engine_id, NEW.local_id,
                          NEW.allocated_epoch,
                          'full_smart_id does not match the bit-packed coordinate');
    END IF;

    IF NEW.is_active OR NEW.is_retired THEN
        PERFORM qdh_raise('45001','QDH-E018','S64-E031','COMMIT',
                          NEW.class_id, NEW.engine_id, NEW.local_id,
                          NEW.allocated_epoch,
                          'A newly allocated identity is created inactive and unretired');
    END IF;

    SELECT generation_epoch, active_profile INTO v_epoch, v_profile
      FROM virtual_engines
     WHERE class_id = NEW.class_id AND engine_id = NEW.engine_id;

    IF NEW.allocated_epoch <> v_epoch THEN
        PERFORM qdh_raise('45003','QDH-E003','S64-E019','COMMIT',
                          NEW.class_id, NEW.engine_id, NEW.local_id,
                          NEW.allocated_epoch,
                          'Allocation epoch does not match the current generation');
    END IF;

    IF NEW.allocated_profile <> v_profile THEN
        PERFORM qdh_raise('45001','QDH-E015','S64-E030','COMMIT',
                          NEW.class_id, NEW.engine_id, NEW.local_id,
                          NEW.allocated_epoch,
                          'Recorded profile does not match the generation profile');
    END IF;

    IF NEW.predecessor_smart_id IS NULL THEN
        IF NEW.history_chain_root_id <> lpad(to_hex(NEW.full_smart_id::bigint), 64, '0') THEN
            PERFORM qdh_raise('45001','-','S64-E031','COMMIT',
                              NEW.class_id, NEW.engine_id, NEW.local_id,
                              NEW.allocated_epoch,
                              'First allocation must self-root its history chain');
        END IF;
    ELSE
        SELECT history_chain_root_id INTO v_pred_root
          FROM identity_records WHERE full_smart_id = NEW.predecessor_smart_id;
        v_found := FOUND;
        IF NOT v_found THEN
            PERFORM qdh_raise('45001','QDH-E019','S64-E013','COMMIT',
                              NEW.class_id, NEW.engine_id, NEW.local_id,
                              NEW.allocated_epoch, 'Predecessor does not exist');
        END IF;
        IF NEW.history_chain_root_id <> v_pred_root THEN
            PERFORM qdh_raise('45001','QDH-E018','S64-E031','COMMIT',
                              NEW.class_id, NEW.engine_id, NEW.local_id,
                              NEW.allocated_epoch,
                              'Successor must inherit the predecessor chain root');
        END IF;
    END IF;

    RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ir_before_insert BEFORE INSERT ON identity_records
    FOR EACH ROW EXECUTE FUNCTION tf_ir_before_insert();

CREATE OR REPLACE FUNCTION tf_ir_before_update() RETURNS trigger AS $$
DECLARE
    v_epoch bigint;
BEGIN
    IF OLD.is_retired THEN
        PERFORM qdh_raise('45001','QDH-E018','S64-E025','RETIREMENT',
                          OLD.class_id, OLD.engine_id, OLD.local_id,
                          OLD.allocated_epoch,
                          'A retired record MUST NOT be modified or reactivated');
    END IF;

    IF NEW.class_id <> OLD.class_id
       OR NEW.engine_id <> OLD.engine_id
       OR NEW.local_id <> OLD.local_id
       OR NEW.full_smart_id <> OLD.full_smart_id
       OR NEW.role_bit <> OLD.role_bit
       OR NEW.allocated_profile <> OLD.allocated_profile
       OR NEW.allocated_epoch <> OLD.allocated_epoch
       OR NEW.history_chain_root_id <> OLD.history_chain_root_id
       OR NEW.predecessor_smart_id IS DISTINCT FROM OLD.predecessor_smart_id
       OR NEW.allocated_at_utc <> OLD.allocated_at_utc THEN
        PERFORM qdh_raise('45002','QDH-E005','S64-E024','RETIREMENT',
                          OLD.class_id, OLD.engine_id, OLD.local_id,
                          OLD.allocated_epoch, 'Immutable identity field mutation');
    END IF;

    IF NEW.is_active AND NOT OLD.is_active THEN
        SELECT generation_epoch INTO v_epoch FROM virtual_engines
         WHERE class_id = OLD.class_id AND engine_id = OLD.engine_id;
        IF OLD.allocated_epoch <> v_epoch THEN
            PERFORM qdh_raise('45003','QDH-E003','S64-E019','COMMIT',
                              OLD.class_id, OLD.engine_id, OLD.local_id,
                              OLD.allocated_epoch,
                              'Activation of a prior-generation record');
        END IF;
    END IF;

    RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ir_before_update BEFORE UPDATE ON identity_records
    FOR EACH ROW EXECUTE FUNCTION tf_ir_before_update();

CREATE OR REPLACE FUNCTION tf_ir_after_insert() RETURNS trigger AS $$
BEGIN
    INSERT INTO coordinate_tombstones
        (class_id, engine_id, local_id, allocated_profile, allocated_epoch, status)
    VALUES
        (NEW.class_id, NEW.engine_id, NEW.local_id,
         NEW.allocated_profile, NEW.allocated_epoch, 'CONSUMED');
    RETURN NULL;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ir_after_insert AFTER INSERT ON identity_records
    FOR EACH ROW EXECUTE FUNCTION tf_ir_after_insert();

CREATE OR REPLACE FUNCTION tf_ir_after_update() RETURNS trigger AS $$
BEGIN
    IF NEW.is_retired AND NOT OLD.is_retired THEN
        UPDATE coordinate_tombstones SET status = 'RETIRED'
         WHERE class_id = NEW.class_id AND engine_id = NEW.engine_id
           AND local_id = NEW.local_id;
    END IF;
    RETURN NULL;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ir_after_update AFTER UPDATE ON identity_records
    FOR EACH ROW EXECUTE FUNCTION tf_ir_after_update();

-- ---------------------------------------------------------------------------
-- 19. Tombstones, durable log, watermarks, leases, attestations, registries
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION tf_ct_before_insert() RETURNS trigger AS $$
DECLARE
    v_cnt   integer;
    v_epoch bigint;
BEGIN
    SELECT count(*) INTO v_cnt FROM identity_records
     WHERE class_id = NEW.class_id AND engine_id = NEW.engine_id
       AND local_id = NEW.local_id;
    IF v_cnt <> 1 THEN
        PERFORM qdh_raise('45001','QDH-E019','S64-E013','TOMBSTONE_WRITE',
                          NEW.class_id, NEW.engine_id, NEW.local_id,
                          NEW.allocated_epoch,
                          'Tombstone requires an existing identity record');
    END IF;

    SELECT generation_epoch INTO v_epoch FROM virtual_engines
     WHERE class_id = NEW.class_id AND engine_id = NEW.engine_id;
    IF NEW.allocated_epoch > v_epoch THEN
        PERFORM qdh_raise('45003','QDH-E003','S64-E021','TOMBSTONE_WRITE',
                          NEW.class_id, NEW.engine_id, NEW.local_id,
                          NEW.allocated_epoch,
                          'Tombstone epoch is ahead of the current generation');
    END IF;
    RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ct_before_insert BEFORE INSERT ON coordinate_tombstones
    FOR EACH ROW EXECUTE FUNCTION tf_ct_before_insert();

CREATE OR REPLACE FUNCTION tf_ct_before_update() RETURNS trigger AS $$
BEGIN
    IF NEW.class_id <> OLD.class_id OR NEW.engine_id <> OLD.engine_id
       OR NEW.local_id <> OLD.local_id
       OR NEW.allocated_profile <> OLD.allocated_profile
       OR NEW.allocated_epoch <> OLD.allocated_epoch
       OR NEW.recorded_at_utc <> OLD.recorded_at_utc
       OR NOT (OLD.status = 'CONSUMED' AND NEW.status = 'RETIRED') THEN
        PERFORM qdh_raise('45002','QDH-E005','S64-E021','CONTROL',
                          OLD.class_id, OLD.engine_id, OLD.local_id,
                          OLD.allocated_epoch,
                          'Tombstones are append-only; only CONSUMED -> RETIRED is permitted');
    END IF;
    RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ct_before_update BEFORE UPDATE ON coordinate_tombstones
    FOR EACH ROW EXECUTE FUNCTION tf_ct_before_update();

CREATE OR REPLACE FUNCTION tf_dal_before_insert() RETURNS trigger AS $$
DECLARE
    v_cnt integer;
BEGIN
    SELECT count(*) INTO v_cnt FROM identity_records
     WHERE class_id = NEW.class_id AND engine_id = NEW.engine_id
       AND local_id = NEW.local_id;
    IF v_cnt <> 1 THEN
        PERFORM qdh_raise('45001','QDH-E019','S64-E013','COMMIT',
                          NEW.class_id, NEW.engine_id, NEW.local_id, NEW.epoch,
                          'Durable log entry requires an identity record');
    END IF;
    RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_dal_before_insert BEFORE INSERT ON durable_allocation_log
    FOR EACH ROW EXECUTE FUNCTION tf_dal_before_insert();

CREATE OR REPLACE FUNCTION tf_lw_before_update() RETURNS trigger AS $$
BEGIN
    IF NEW.lease_id <> OLD.lease_id
       OR NEW.class_id <> OLD.class_id OR NEW.engine_id <> OLD.engine_id
       OR NEW.lease_floor <> OLD.lease_floor OR NEW.lease_ceiling <> OLD.lease_ceiling
       OR NOT (OLD.release_state = 'ACTIVE'
               AND NEW.release_state IN ('CONSUMED','RELEASED')) THEN
        PERFORM qdh_raise('45002','QDH-E005','S64-E021','CONTROL',
                          OLD.class_id, OLD.engine_id, OLD.lease_floor::integer, 0,
                          'Only ACTIVE -> CONSUMED|RELEASED is permitted on a watermark');
    END IF;
    RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_lw_before_update BEFORE UPDATE ON lease_watermarks
    FOR EACH ROW EXECUTE FUNCTION tf_lw_before_update();

CREATE OR REPLACE FUNCTION tf_al_before_insert() RETURNS trigger AS $$
DECLARE
    v_epoch bigint;
BEGIN
    SELECT generation_epoch INTO v_epoch FROM virtual_engines
     WHERE class_id = NEW.class_id AND engine_id = NEW.engine_id;
    IF NOT FOUND THEN
        PERFORM qdh_raise('45001','QDH-E019','S64-E013','CONTROL',
                          NEW.class_id, NEW.engine_id, 0, NEW.generation_epoch,
                          'Lease references an engine that does not exist');
    END IF;
    IF NEW.generation_epoch <> v_epoch THEN
        PERFORM qdh_raise('45003','QDH-E003','S64-E019','CONTROL',
                          NEW.class_id, NEW.engine_id, 0, NEW.generation_epoch,
                          'Lease must be bound to the current generation');
    END IF;
    IF NEW.lease_signature = '' THEN
        PERFORM qdh_raise('45004','QDH-E004','S64-E021','CONTROL',
                          NEW.class_id, NEW.engine_id, 0, NEW.generation_epoch,
                          'Unsigned lease');
    END IF;
    RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_al_before_insert BEFORE INSERT ON allocator_leases
    FOR EACH ROW EXECUTE FUNCTION tf_al_before_insert();

CREATE OR REPLACE FUNCTION tf_al_before_update() RETURNS trigger AS $$
BEGIN
    IF NEW.lease_id <> OLD.lease_id
       OR NEW.class_id <> OLD.class_id OR NEW.engine_id <> OLD.engine_id
       OR NEW.generation_epoch <> OLD.generation_epoch
       OR NEW.expires_at_utc <> OLD.expires_at_utc
       OR NEW.lease_signature <> OLD.lease_signature
       OR NEW.signing_trust_root_id <> OLD.signing_trust_root_id
       OR NOT (OLD.revoked_at_utc IS NULL AND NEW.revoked_at_utc IS NOT NULL) THEN
        PERFORM qdh_raise('45002','QDH-E005','S64-E021','CONTROL',
                          OLD.class_id, OLD.engine_id, 0, OLD.generation_epoch,
                          'A lease may only transition from unrevoked to revoked');
    END IF;
    RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_al_before_update BEFORE UPDATE ON allocator_leases
    FOR EACH ROW EXECUTE FUNCTION tf_al_before_update();

CREATE OR REPLACE FUNCTION tf_ha_before_insert() RETURNS trigger AS $$
DECLARE
    v_n_class smallint; v_n_engine integer; v_n_epoch bigint;
    v_n_incident varchar(64); v_n_consumed timestamptz;
    v_measurement char(64); v_tr_from timestamptz; v_tr_to timestamptz;
    v_tr_revoked timestamptz;
BEGIN
    SELECT class_id, engine_id, generation_epoch, incident_id, consumed_at_utc
      INTO v_n_class, v_n_engine, v_n_epoch, v_n_incident, v_n_consumed
      FROM nonce_registry WHERE nonce = NEW.challenge_nonce;

    IF NOT FOUND OR v_n_consumed IS NOT NULL THEN
        PERFORM qdh_raise('45004','QDH-E004','S64-E021','CONTROL',
                          NEW.class_id, NEW.engine_id, 0, NEW.bound_generation_epoch,
                          'Nonce is unknown or already consumed');
    END IF;

    IF v_n_class <> NEW.class_id OR v_n_engine <> NEW.engine_id
       OR v_n_epoch <> NEW.bound_generation_epoch
       OR v_n_incident <> NEW.bound_incident_id THEN
        PERFORM qdh_raise('45004','QDH-E004','S64-E021','CONTROL',
                          NEW.class_id, NEW.engine_id, 0, NEW.bound_generation_epoch,
                          'Nonce binding does not match the engine context');
    END IF;

    SELECT measurement_digest, valid_from_utc, valid_to_utc, revoked_at_utc
      INTO v_measurement, v_tr_from, v_tr_to, v_tr_revoked
      FROM trust_roots WHERE trust_root_id = NEW.signing_trust_root_id;

    IF NOT FOUND
       OR v_measurement <> NEW.attestation_digest
       OR v_tr_revoked IS NOT NULL
       OR NEW.verified_at_utc < v_tr_from
       OR NEW.verified_at_utc >= v_tr_to THEN
        PERFORM qdh_raise('45004','QDH-E004','S64-E021','CONTROL',
                          NEW.class_id, NEW.engine_id, 0, NEW.bound_generation_epoch,
                          'Attestation digest is not allowlisted, or the trust root is revoked or out of window');
    END IF;

    IF NEW.cert_not_before_utc > NEW.verified_at_utc
       OR NEW.cert_not_after_utc <= NEW.verified_at_utc THEN
        PERFORM qdh_raise('45004','QDH-E004','S64-E021','CONTROL',
                          NEW.class_id, NEW.engine_id, 0, NEW.bound_generation_epoch,
                          'Certificate was not valid at verification time');
    END IF;

    IF NEW.revocation_checked_at_utc < now() - interval '24 hours' THEN
        PERFORM qdh_raise('45004','QDH-E004','S64-E021','CONTROL',
                          NEW.class_id, NEW.engine_id, 0, NEW.bound_generation_epoch,
                          'Revocation check is stale');
    END IF;

    UPDATE nonce_registry SET consumed_at_utc = now()
     WHERE nonce = NEW.challenge_nonce;
    RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ha_before_insert BEFORE INSERT ON hardware_attestations
    FOR EACH ROW EXECUTE FUNCTION tf_ha_before_insert();

CREATE OR REPLACE FUNCTION tf_nr_before_update() RETURNS trigger AS $$
BEGIN
    IF NOT (OLD.consumed_at_utc IS NULL AND NEW.consumed_at_utc IS NOT NULL)
       OR NEW.nonce <> OLD.nonce OR NEW.class_id <> OLD.class_id
       OR NEW.engine_id <> OLD.engine_id
       OR NEW.generation_epoch <> OLD.generation_epoch
       OR NEW.incident_id <> OLD.incident_id THEN
        PERFORM qdh_raise('45004','QDH-E004','S64-E021','CONTROL',
                          OLD.class_id, OLD.engine_id, 0, OLD.generation_epoch,
                          'A nonce may only be consumed once and is otherwise immutable');
    END IF;
    RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_nr_before_update BEFORE UPDATE ON nonce_registry
    FOR EACH ROW EXECUTE FUNCTION tf_nr_before_update();

CREATE OR REPLACE FUNCTION tf_tr_before_update() RETURNS trigger AS $$
BEGIN
    IF NEW.trust_root_id <> OLD.trust_root_id
       OR NEW.platform <> OLD.platform
       OR NEW.measurement_digest <> OLD.measurement_digest
       OR NEW.valid_from_utc <> OLD.valid_from_utc
       OR NEW.valid_to_utc <> OLD.valid_to_utc THEN
        PERFORM qdh_raise('45004','QDH-E004','S64-E021','CONTROL',
                          0, 0, 0, 0,
                          'Trust-root identity and measurement are immutable; only revocation is permitted');
    END IF;
    RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tr_before_update BEFORE UPDATE ON trust_roots
    FOR EACH ROW EXECUTE FUNCTION tf_tr_before_update();

-- Generic append-only guard
CREATE OR REPLACE FUNCTION tf_forbid_change() RETURNS trigger AS $$
BEGIN
    PERFORM qdh_raise('45002','QDH-E005','S64-E021','CONTROL',
                      coalesce((to_jsonb(OLD) ->> 'class_id')::integer, 0),
                      coalesce((to_jsonb(OLD) ->> 'engine_id')::integer, 0),
                      coalesce((to_jsonb(OLD) ->> 'local_id')::integer, 0),
                      coalesce((to_jsonb(OLD) ->> 'epoch')::bigint,
                               (to_jsonb(OLD) ->> 'generation_epoch')::bigint, 0),
                      TG_TABLE_NAME || ' is append-only; ' || TG_OP || ' is forbidden');
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ct_before_delete BEFORE DELETE ON coordinate_tombstones
    FOR EACH ROW EXECUTE FUNCTION tf_forbid_change();
CREATE TRIGGER trg_dal_before_update BEFORE UPDATE ON durable_allocation_log
    FOR EACH ROW EXECUTE FUNCTION tf_forbid_change();
CREATE TRIGGER trg_dal_before_delete BEFORE DELETE ON durable_allocation_log
    FOR EACH ROW EXECUTE FUNCTION tf_forbid_change();
CREATE TRIGGER trg_lw_before_delete BEFORE DELETE ON lease_watermarks
    FOR EACH ROW EXECUTE FUNCTION tf_forbid_change();
CREATE TRIGGER trg_qae_before_update BEFORE UPDATE ON qdh_audit_events
    FOR EACH ROW EXECUTE FUNCTION tf_forbid_change();
CREATE TRIGGER trg_qae_before_delete BEFORE DELETE ON qdh_audit_events
    FOR EACH ROW EXECUTE FUNCTION tf_forbid_change();
CREATE TRIGGER trg_aa_before_update BEFORE UPDATE ON audit_anchors
    FOR EACH ROW EXECUTE FUNCTION tf_forbid_change();
CREATE TRIGGER trg_aa_before_delete BEFORE DELETE ON audit_anchors
    FOR EACH ROW EXECUTE FUNCTION tf_forbid_change();

-- Core registry protection
CREATE OR REPLACE FUNCTION tf_core_registry_guard() RETURNS trigger AS $$
BEGIN
    IF OLD.is_core THEN
        PERFORM qdh_raise('45002','QDH-E005','S64-E021','CONTROL',
                          0, 0, 0, 0,
                          'Core ' || TG_TABLE_NAME || ' entries cannot be '
                          || lower(TG_OP) || 'd');
    END IF;
    IF TG_OP = 'UPDATE' THEN
        RETURN NEW;
    END IF;
    RETURN OLD;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_etr_guard BEFORE UPDATE OR DELETE ON event_type_registry
    FOR EACH ROW EXECUTE FUNCTION tf_core_registry_guard();
CREATE TRIGGER trg_itc_guard BEFORE UPDATE OR DELETE ON incident_trigger_class
    FOR EACH ROW EXECUTE FUNCTION tf_core_registry_guard();

-- ---------------------------------------------------------------------------
-- 20. Audit events: chain, hash, correspondence, ordering
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION tf_qae_before_insert() RETURNS trigger AS $$
DECLARE
    v_last_seq  bigint;
    v_last_hash char(64);
    v_cnt       integer;
    v_zero      char(64) := repeat('0', 64);
    v_tc        varchar(64);
    v_canon     jsonb;
BEGIN
    v_tc := NEW.payload #>> '{incident,trigger_class}';
    IF v_tc IS NOT NULL THEN
        SELECT count(*) INTO v_cnt FROM incident_trigger_class
         WHERE trigger_class = v_tc;
        IF v_cnt = 0 THEN
            PERFORM qdh_raise('45005','QDH-E011','S64-E012','CONTROL',
                              NEW.class_id, NEW.engine_id, 0, NEW.generation_epoch,
                              'Unregistered incident trigger_class: ' || v_tc);
        END IF;
    END IF;

    IF NEW.payload ? 'event_hash' THEN
        PERFORM qdh_raise('45005','QDH-E011','S64-E012','CONTROL',
                          NEW.class_id, NEW.engine_id, 0, NEW.generation_epoch,
                          'payload must not contain event_hash');
    END IF;

    BEGIN
        v_canon := convert_from(NEW.payload_canonical, 'UTF8')::jsonb;
    EXCEPTION WHEN others THEN
        PERFORM qdh_raise('45005','QDH-E011','S64-E012','CONTROL',
                          NEW.class_id, NEW.engine_id, 0, NEW.generation_epoch,
                          'payload_canonical is not valid UTF-8 JSON');
    END;

    IF v_canon IS DISTINCT FROM NEW.payload THEN
        PERFORM qdh_raise('45005','QDH-E011','S64-E012','CONTROL',
                          NEW.class_id, NEW.engine_id, 0, NEW.generation_epoch,
                          'payload projection does not correspond to payload_canonical');
    END IF;

    IF NEW.event_hash <> encode(sha256(NEW.payload_canonical), 'hex') THEN
        PERFORM qdh_raise('45005','QDH-E011','S64-E012','CONTROL',
                          NEW.class_id, NEW.engine_id, 0, NEW.generation_epoch,
                          'event_hash is not the digest of payload_canonical');
    END IF;

    SELECT stream_seq, event_hash INTO v_last_seq, v_last_hash
      FROM qdh_audit_events
     WHERE class_id = NEW.class_id AND engine_id = NEW.engine_id
     ORDER BY stream_seq DESC LIMIT 1
       FOR UPDATE;

    IF v_last_seq IS NULL THEN
        IF NEW.stream_seq <> 1 OR NEW.prev_event_hash <> v_zero THEN
            PERFORM qdh_raise('45005','QDH-E011','S64-E012','CONTROL',
                              NEW.class_id, NEW.engine_id, 0, NEW.generation_epoch,
                              'Genesis record must be stream_seq 1 with the all-zero sentinel');
        END IF;
    ELSE
        IF NEW.stream_seq <> v_last_seq + 1 OR NEW.prev_event_hash <> v_last_hash THEN
            PERFORM qdh_raise('45005','QDH-E011','S64-E012','CONTROL',
                              NEW.class_id, NEW.engine_id, 0, NEW.generation_epoch,
                              'Stream is not contiguous or prev_event_hash does not match');
        END IF;
    END IF;

    IF (NEW.payload #>> '{event_id}')::uuid IS DISTINCT FROM NEW.event_id
    OR (NEW.payload #>> '{virtual_engine,class_id}')::integer IS DISTINCT FROM NEW.class_id
    OR (NEW.payload #>> '{virtual_engine,engine_id}')::integer IS DISTINCT FROM NEW.engine_id
    OR (NEW.payload #>> '{stream_seq}')::bigint IS DISTINCT FROM NEW.stream_seq
    OR (NEW.payload #>> '{event_type}') IS DISTINCT FROM NEW.event_type
    OR (NEW.payload #>> '{generation_epoch}')::bigint IS DISTINCT FROM NEW.generation_epoch
    OR (NEW.payload #>> '{timestamp_utc}')::timestamptz IS DISTINCT FROM NEW.timestamp_utc
    OR (NEW.payload #>> '{lifecycle,previous_state}') IS DISTINCT FROM NEW.previous_state
    OR (NEW.payload #>> '{lifecycle,new_state}') IS DISTINCT FROM NEW.new_state
    OR (NEW.payload #>> '{lifecycle,epoch_before}')::bigint IS DISTINCT FROM NEW.epoch_before
    OR (NEW.payload #>> '{lifecycle,epoch_after}')::bigint IS DISTINCT FROM NEW.epoch_after
    OR (NEW.payload #>> '{lifecycle,profile_before}') IS DISTINCT FROM NEW.profile_before
    OR (NEW.payload #>> '{lifecycle,profile_after}') IS DISTINCT FROM NEW.profile_after
    OR (NEW.payload #>> '{watermark_audit,verified_first_never_consumed_local}')::bigint
           IS DISTINCT FROM NEW.watermark_verified
    OR (NEW.payload #>> '{diagnostic,qdh_code}') IS DISTINCT FROM NEW.qdh_error_code
    OR (NEW.payload #>> '{diagnostic,s64_code}') IS DISTINCT FROM NEW.s64_error_code
    OR (NEW.payload #>> '{prev_event_hash}') IS DISTINCT FROM NEW.prev_event_hash THEN
        PERFORM qdh_raise('45005','QDH-E011','S64-E012','CONTROL',
                          NEW.class_id, NEW.engine_id, 0, NEW.generation_epoch,
                          'Column and payload disagree');
    END IF;

    IF NEW.event_type = 'ENGINE_REACTIVATED' THEN
        SELECT count(*) INTO v_cnt FROM qdh_audit_events
         WHERE class_id = NEW.class_id AND engine_id = NEW.engine_id
           AND generation_epoch = NEW.generation_epoch
           AND event_type = 'ALLOCATOR_LEASE_ISSUED';
        IF v_cnt = 0 THEN
            PERFORM qdh_raise('45006','QDH-E017','S64-E021','CONTROL',
                              NEW.class_id, NEW.engine_id, 0, NEW.generation_epoch,
                              'ENGINE_REACTIVATED before ALLOCATOR_LEASE_ISSUED');
        END IF;
    END IF;

    IF NEW.event_type = 'PROFILE_UPGRADED'
       AND NEW.profile_before = NEW.profile_after THEN
        PERFORM qdh_raise('45002','QDH-E005','S64-E021','CONTROL',
                          NEW.class_id, NEW.engine_id, 0, NEW.generation_epoch,
                          'PROFILE_UPGRADED without a profile change');
    END IF;

    IF NEW.event_type = 'RECLAMATION_COMMITTED'
       AND (NEW.payload #>> '{lifecycle,closure_reason}') = 'PROFILE_UPGRADE' THEN
        PERFORM qdh_raise('45002','QDH-E005','S64-E021','CONTROL',
                          NEW.class_id, NEW.engine_id, 0, NEW.generation_epoch,
                          'Reclamation may not record the PROFILE_UPGRADE closure reason');
    END IF;

    RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_qae_before_insert BEFORE INSERT ON qdh_audit_events
    FOR EACH ROW EXECUTE FUNCTION tf_qae_before_insert();

-- ---------------------------------------------------------------------------
-- 21. Views
-- ---------------------------------------------------------------------------
CREATE VIEW qdh_transition_evidence AS
SELECT ve.class_id, ve.engine_id, ve.generation_epoch, ve.lifecycle_state,
       (SELECT count(*) FROM qdh_audit_events e
         WHERE e.class_id = ve.class_id AND e.engine_id = ve.engine_id
           AND e.generation_epoch = ve.generation_epoch
           AND e.event_type = 'DE_WATERMARK_VERIFIED')        AS de_evidence,
       (SELECT count(*) FROM qdh_audit_events e
         WHERE e.class_id = ve.class_id AND e.engine_id = ve.engine_id
           AND e.generation_epoch = ve.generation_epoch
           AND e.event_type = 'HE_SANITIZATION_ATTESTED')     AS he_evidence,
       (SELECT count(*) FROM qdh_audit_events e
         WHERE e.class_id = ve.class_id AND e.engine_id = ve.engine_id
           AND e.generation_epoch = ve.generation_epoch
           AND e.event_type = 'ALLOCATOR_LEASE_ISSUED')       AS lease_evidence
  FROM virtual_engines ve;

CREATE VIEW v_next_forward_engine AS
SELECT ve.class_id, min(ve.engine_id) AS next_engine_id
  FROM virtual_engines ve
 WHERE ve.lifecycle_state = 'STATE_UNALLOCATED'
    OR (ve.lifecycle_state = 'STATE_ACTIVE'
        AND ve.local_watermark < 536870912
        AND EXISTS (SELECT 1 FROM allocator_leases al
                     WHERE al.class_id = ve.class_id AND al.engine_id = ve.engine_id
                       AND al.revoked_at_utc IS NOT NULL))
 GROUP BY ve.class_id;

-- ---------------------------------------------------------------------------
-- 22. Roles and grants
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 's64_controller_role') THEN
        CREATE ROLE s64_controller_role NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 's64_allocator_role') THEN
        CREATE ROLE s64_allocator_role NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'qdh_policy_engine_role') THEN
        CREATE ROLE qdh_policy_engine_role NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 's64_auditor_role') THEN
        CREATE ROLE s64_auditor_role NOLOGIN;
    END IF;
END $$;

GRANT USAGE ON SCHEMA public TO s64_controller_role, s64_allocator_role,
                               qdh_policy_engine_role, s64_auditor_role;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO s64_controller_role, s64_allocator_role,
                                               qdh_policy_engine_role, s64_auditor_role;

GRANT INSERT, UPDATE ON virtual_engines, physical_nodes TO s64_controller_role;
GRANT INSERT ON allocator_leases, lease_watermarks, trust_roots,
                event_type_registry, incident_trigger_class, audit_anchors,
                qdh_audit_events TO s64_controller_role;
GRANT UPDATE (revoked_at_utc) ON allocator_leases TO s64_controller_role;
GRANT UPDATE (release_state)  ON lease_watermarks TO s64_controller_role;
GRANT UPDATE (revoked_at_utc) ON trust_roots         TO s64_controller_role;
GRANT EXECUTE ON FUNCTION qdh_commit_generation(integer, integer, bigint, text, text, uuid),
                          qdh_begin_quarantine(text)
                TO s64_controller_role;

-- Allocator role holds EXECUTE only. INSERT on the three tables is denied by
-- design: identity creation must pass through the definer functions so that
-- identity, tombstone, durable log and watermark advance in one transaction.
GRANT EXECUTE ON FUNCTION s64_allocate(integer, integer, integer, integer, text, bigint, text, numeric),
                          s64_allocate_range(integer, integer, integer, integer, integer, text, bigint, text),
                          s64_retire(integer, integer, integer)
                TO s64_allocator_role;

GRANT INSERT ON qdh_audit_events, hardware_attestations, nonce_registry, audit_anchors
                TO qdh_policy_engine_role;

GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO s64_controller_role,
                                                  qdh_policy_engine_role;

-- ---------------------------------------------------------------------------
-- 23. Seed data
-- ---------------------------------------------------------------------------
INSERT INTO event_type_registry (event_type, is_core, description) VALUES
 ('ENGINE_INITIAL_BOUND',      true, 'Genesis binding of a (Class,Engine) at epoch 1, watermark 0'),
 ('NODE_QUARANTINE_TRIGGERED', true, 'Node-wide blast-radius quarantine, one event per affected engine'),
 ('DE_WATERMARK_VERIFIED',     true, 'Durable lease and tombstone audit completed'),
 ('HE_SANITIZATION_ATTESTED',  true, 'Sanitization, zeroization, and attestation verified'),
 ('RECLAMATION_COMMITTED',     true, 'Atomic generation commit and lineage append'),
 ('ALLOCATOR_LEASE_ISSUED',    true, 'New epoch-bound allocator lease granted'),
 ('ENGINE_REACTIVATED',        true, 'Engine returned to STATE_ACTIVE'),
 ('FENCING_VIOLATION_BLOCKED', true, 'Stale allocator write rejected'),
 ('ENGINE_EXHAUSTED_ROLLOVER', true, 'Namespace exhausted, forward engine reserved'),
 ('ENGINE_EXHAUSTED_TERMINAL', true, 'Namespace exhausted, no eligible forward engine'),
 ('ENGINE_RETIRED_PERMANENT',  true, 'Terminal engine retirement'),
 ('PROFILE_UPGRADED',          true, 'Explicit profile upgrade under core 13.1');

INSERT INTO incident_trigger_class (trigger_class, is_core, description) VALUES
 ('FAIL_HARD_POWER_LOSS',         true, 'Power cut or power-loss event'),
 ('FAIL_HARD_HARDWARE_FAULT',     true, 'Hardware fault or failure'),
 ('FAIL_HARD_STORAGE_STALL',      true, 'Storage stall affecting authoritative state'),
 ('FAIL_HARD_SPLIT_BRAIN',        true, 'Heartbeat loss indicative of split brain'),
 ('DE_EVIDENCE_INSUFFICIENT',     true, 'DE could not establish a safe watermark'),
 ('DE_TOMBSTONE_GAP',             true, 'DE detected a missing or out-of-range tombstone'),
 ('DE_PROFILE_MISMATCH',          true, 'DE detected conflicting profile evidence'),
 ('HE_SANITIZATION_FAILED',       true, 'HE failed verification or attestation'),
 ('HE_ATTESTATION_REPLAYED',      true, 'HE rejected a replayed nonce, expired certificate, or digest mismatch'),
 ('FENCING_VIOLATION',            true, 'Stale allocator write or lease renewal blocked'),
 ('MANUAL_OVERRIDE_ATTEMPT',      true, 'Unauthorized manual override attempted'),
 ('AUDIT_CHAIN_BREAK',            true, 'Audit hash-chain integrity failure'),
 ('EVIDENCE_BINDING_MISSING',     true, 'Transition attempted without required prior evidence'),
 ('PHASE5_ORDERING_VIOLATION',    true, 'Phase 5 events emitted out of order'),
 ('LIFECYCLE_TRANSITION_REJECTED',true, 'Transition not permitted by the state machine'),
 ('ENGINE_NOT_FOUND',             true, '(Class,Engine) did not resolve during a QDH operation'),
 ('RANGE_INVALID',                true, 'Coordinate out of range, or below the watermark floor'),
 ('HOST_UNFIT',                   true, 'Binding, allocation, or reactivation on a non-active node'),
 ('PROFILE_UPGRADE',              true, 'Explicit profile upgrade under core 13.1');

-- ---------------------------------------------------------------------------
-- 24. Privilege and search_path hardening (review F1/F2)
-- ---------------------------------------------------------------------------
-- Trigger functions that write other tables must run as the owner, otherwise
-- the allocator's lack of INSERT on the tombstones would break allocation.
ALTER FUNCTION tf_pn_after_update()     SECURITY DEFINER;
ALTER FUNCTION tf_ir_after_insert()     SECURITY DEFINER;
ALTER FUNCTION tf_ir_after_update()     SECURITY DEFINER;
ALTER FUNCTION tf_ha_before_insert()    SECURITY DEFINER;

ALTER FUNCTION s64_allocate(integer,integer,integer,integer,text,bigint,text,numeric)
    SET search_path = pg_catalog, public, pg_temp;
ALTER FUNCTION s64_allocate_range(integer,integer,integer,integer,integer,text,bigint,text)
    SET search_path = pg_catalog, public, pg_temp;
ALTER FUNCTION s64_retire(integer,integer,integer)
    SET search_path = pg_catalog, public, pg_temp;
ALTER FUNCTION qdh_begin_quarantine(text)
    SET search_path = pg_catalog, public, pg_temp;
ALTER FUNCTION qdh_commit_generation(integer,integer,bigint,text,text,uuid)
    SET search_path = pg_catalog, public, pg_temp;
ALTER FUNCTION tf_pn_after_update()  SET search_path = pg_catalog, public, pg_temp;
ALTER FUNCTION tf_ir_after_insert()  SET search_path = pg_catalog, public, pg_temp;
ALTER FUNCTION tf_ir_after_update()  SET search_path = pg_catalog, public, pg_temp;
ALTER FUNCTION tf_ha_before_insert() SET search_path = pg_catalog, public, pg_temp;

REVOKE ALL ON FUNCTION qdh_raise(text,text,text,text,integer,integer,integer,bigint,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_expected_smart_id_v142(integer,integer,integer,integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION verify_audit_vector(text,char) FROM PUBLIC;
REVOKE ALL ON FUNCTION s64_allocate(integer,integer,integer,integer,text,bigint,text,numeric) FROM PUBLIC;
REVOKE ALL ON FUNCTION s64_allocate_range(integer,integer,integer,integer,integer,text,bigint,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION s64_retire(integer,integer,integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION qdh_begin_quarantine(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION qdh_commit_generation(integer,integer,bigint,text,text,uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION fn_expected_smart_id_v142(integer,integer,integer,integer),
                          verify_audit_vector(text,char)
      TO s64_controller_role, s64_allocator_role, qdh_policy_engine_role, s64_auditor_role;

-- ---------------------------------------------------------------------------
-- 25. Audit-gap view
-- ---------------------------------------------------------------------------
CREATE VIEW qdh_audit_gap AS
SELECT ve.class_id, ve.engine_id, ve.generation_epoch
  FROM virtual_engines ve
 WHERE ve.lifecycle_state = 'STATE_QUARANTINED'
   AND NOT EXISTS (SELECT 1 FROM qdh_audit_events e
                    WHERE e.class_id = ve.class_id
                      AND e.engine_id = ve.engine_id
                      AND e.generation_epoch = ve.generation_epoch
                      AND e.event_type = 'NODE_QUARANTINE_TRIGGERED');

-- This view is created after the bulk GRANT ... ON ALL TABLES above,
-- so it needs an explicit read grant of its own.
GRANT SELECT ON qdh_audit_gap TO s64_auditor_role, s64_allocator_role, s64_controller_role;

-- END OF FILE

-- ---------------------------------------------------------------------------
-- 26. Identifier validation (core §16.1 order)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION s64_validate(p_id numeric) RETURNS text AS $$
DECLARE
    v_ver int; v_rev int; v_res int; v_cls int; v_eng int; v_loc int;
    v_ap text; v_ae bigint; v_cp text; v_ce bigint; v_gp text := NULL;
    v_lin jsonb;
BEGIN
    v_ver := ((p_id::bigint >> 63) & 1);
    v_rev := ((p_id::bigint >> 59) & 15);
    IF v_ver <> 0 OR v_rev <> 2 THEN RETURN 'S64-E002'; END IF;

    v_res := ((p_id::bigint >> 54) & 15);
    IF v_res <> 0 THEN RETURN 'S64-E003'; END IF;

    v_cls := ((p_id::bigint >> 50) & 15);
    IF v_cls = 0 THEN RETURN 'S64-E004'; END IF;
    IF v_cls > 8  THEN RETURN 'S64-E005'; END IF;

    v_eng := ((p_id::bigint >> 29) & 2097151);
    v_loc := (p_id::bigint & 536870911);

    SELECT allocated_profile, allocated_epoch INTO v_ap, v_ae
      FROM identity_records
     WHERE class_id = v_cls AND engine_id = v_eng AND local_id = v_loc;
    IF NOT FOUND THEN RETURN 'S64-E008'; END IF;

    SELECT active_profile, generation_epoch, lineage INTO v_cp, v_ce, v_lin
      FROM virtual_engines WHERE class_id = v_cls AND engine_id = v_eng;
    IF NOT FOUND THEN RETURN 'S64-E013'; END IF;

    IF v_ae = v_ce THEN
        v_gp := v_cp;
    ELSE
        SELECT e->>'profile_version_revision' INTO v_gp
          FROM jsonb_array_elements(v_lin) e
         WHERE (e->>'generation_epoch')::bigint = v_ae LIMIT 1;
    END IF;
    IF v_gp IS NULL OR v_gp <> v_ap THEN RETURN 'S64-E030'; END IF;

    RETURN 'VALID';
END $$ LANGUAGE plpgsql STABLE
   SET search_path = pg_catalog, public, pg_temp;

REVOKE ALL ON FUNCTION s64_validate(numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION s64_validate(numeric)
      TO s64_controller_role, s64_allocator_role, qdh_policy_engine_role, s64_auditor_role;

-- ---------------------------------------------------------------------------
-- 27. Schema trust boundary (review finding A)
-- ---------------------------------------------------------------------------
-- Objects live in `public`, so `public` must not be writable by untrusted roles;
-- otherwise a definer function could resolve a shadowed object. Verify with:
--   SELECT has_schema_privilege('public','CREATE');   -- must be false for callers
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
ALTER SCHEMA public OWNER TO CURRENT_USER;
