#!/usr/bin/env bash
# F3 evidence. qdh_begin_quarantine() is a fencing primitive: it quarantines the
# node and writes no audit event. The control plane must propagate the fence to
# the engine and insert one NODE_QUARANTINE_TRIGGERED event per engine.
# qdh_audit_gap must report the missing event until it is inserted.
set -eu
DB=${1:-qdh_f3}
ROLE=s64_auditor_role

dropdb --if-exists "$DB"; createdb "$DB"
echo "\$ psql -d $DB -f qdh_schema_postgresql.sql"
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f qdh_schema_postgresql.sql >/dev/null

psql -q -v ON_ERROR_STOP=1 -d "$DB" >/dev/null <<'SQL'
INSERT INTO trust_roots (trust_root_id,platform,measurement_digest,valid_from_utc,valid_to_utc)
  VALUES (repeat('a',64),'t','m1',now(),now()+interval '1 day');
INSERT INTO physical_nodes (node_id,node_state,network_address,hardware_address,substrate_attested)
  VALUES ('n1','NODE_ACTIVE','10.0.0.1','02:00:00:00:00:01',true);
INSERT INTO virtual_engines (class_id,engine_id,active_profile,lifecycle_state,physical_node_id,lineage)
  VALUES (1,0,'v1.42','STATE_UNALLOCATED','n1','[]');
INSERT INTO allocator_leases (lease_id,class_id,engine_id,generation_epoch,expires_at_utc,lease_signature,signing_trust_root_id)
  VALUES (gen_random_uuid(),1,0,1,now()+interval '1 day','sig',repeat('a',64));
UPDATE virtual_engines SET lifecycle_state='STATE_ACTIVE',
  allocator_lease_id=(SELECT lease_id FROM allocator_leases WHERE class_id=1 AND engine_id=0)
 WHERE class_id=1 AND engine_id=0;
SQL

echo "\$ SELECT qdh_begin_quarantine('n1');"
psql -qAt -v ON_ERROR_STOP=1 -d "$DB" -c "SELECT qdh_begin_quarantine('n1');"
echo "\$ SELECT node_id, node_state FROM physical_nodes;"
psql -qAt -v ON_ERROR_STOP=1 -d "$DB" -c "SELECT node_id || ' ' || node_state FROM physical_nodes;"

echo "\$ -- control-plane step: propagate the node fence to the engine"
psql -qAt -v ON_ERROR_STOP=1 -d "$DB" -c "UPDATE virtual_engines SET lifecycle_state='STATE_QUARANTINED', allocator_lease_id=NULL WHERE class_id=1 AND engine_id=0;"

echo "\$ -- gap before any quarantine event exists (SET ROLE $ROLE)"
psql -qAt -v ON_ERROR_STOP=1 -d "$DB" -c "SET ROLE $ROLE; SELECT 'gap_rows=' || count(*) FROM qdh_audit_gap;"

echo "\$ python3 tests/sql/gen_event.py pg quarantine-epoch1 | psql -d $DB"
python3 tests/sql/gen_event.py pg quarantine-epoch1 | psql -q -v ON_ERROR_STOP=1 -d "$DB" >/dev/null

echo "\$ -- gap after the epoch-1 event exists (SET ROLE $ROLE)"
psql -qAt -v ON_ERROR_STOP=1 -d "$DB" -c "SET ROLE $ROLE; SELECT 'gap_rows=' || count(*) FROM qdh_audit_gap;"
