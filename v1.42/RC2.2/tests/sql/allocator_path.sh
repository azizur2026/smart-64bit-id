#!/usr/bin/env bash
# Evidence: the restricted allocator performs a legitimate allocation and the same
# role is denied a direct INSERT. Every invariant is asserted; any mismatch exits 1.
set -u
ENGINE=${1:?usage: allocator_path.sh mysql|pg}
case "$ENGINE" in
  mysql) DB=qdh_schema; USER_=s64_alloc; PASS_=allocpw ;;
  pg)    DB=qdh_t;      USER_=s64_alloc_pg; PASS_=x ;;
  *) echo "usage: allocator_path.sh mysql|pg" >&2; exit 2 ;;
esac
FAILED=0
check() { if [ "$2" = "$3" ]; then echo "PASS $1=$2"; else echo "FAIL $1=$2 (want $3)"; FAILED=1; fi; }

if [ "$ENGINE" = mysql ]; then
  sudo mysql -e "DROP DATABASE IF EXISTS $DB; CREATE DATABASE $DB;" >/dev/null
  sudo mysql "$DB" < qdh_schema_mysql.sql
  sudo mysql "$DB" <<'SQL'
INSERT INTO trust_roots (trust_root_id,platform,measurement_digest,valid_from_utc,valid_to_utc)
  VALUES (REPEAT('a',64),'t','m1',UTC_TIMESTAMP(),UTC_TIMESTAMP()+INTERVAL 1 DAY);
INSERT INTO physical_nodes (node_id,node_state,network_address,hardware_address,substrate_attested)
  VALUES ('n1','NODE_ACTIVE','10.0.0.1','02:00:00:00:00:01',1);
INSERT INTO virtual_engines (class_id,engine_id,active_profile,lifecycle_state,physical_node_id,lineage)
  VALUES (1,0,'v1.42','STATE_UNALLOCATED','n1','[]');
INSERT INTO allocator_leases (lease_id,class_id,engine_id,generation_epoch,expires_at_utc,lease_signature,signing_trust_root_id)
  VALUES (UUID(),1,0,1,UTC_TIMESTAMP()+INTERVAL 1 DAY,'sig',REPEAT('a',64));
UPDATE virtual_engines SET lifecycle_state='STATE_ACTIVE',
  allocator_lease_id=(SELECT lease_id FROM allocator_leases WHERE class_id=1 AND engine_id=0)
 WHERE class_id=1 AND engine_id=0;
SQL
  sudo mysql -e "ALTER USER 's64_alloc'@'localhost' IDENTIFIED BY 'allocpw';" >/dev/null
  ROOT=$(sudo mysql "$DB" -N -e "SELECT LPAD(HEX(fn_expected_smart_id_v142(1,0,0,1)),64,'0');")
  if mysql -u "$USER_" -p"$PASS_" "$DB" -e "CALL s64_allocate(1,0,0,1,'v1.42',1,'$ROOT',NULL,@a);" >/dev/null 2>&1
  then echo "PASS allocation call succeeded as $USER_"; else echo "FAIL allocation call as $USER_"; FAILED=1; fi
  check "smart_id" "$(sudo mysql "$DB" -N -e 'SELECT full_smart_id FROM identity_records;')" "1442277780665401344"
  check "counts" "$(sudo mysql "$DB" -N -e "SELECT CONCAT((SELECT COUNT(*) FROM identity_records),' ',(SELECT local_watermark FROM virtual_engines WHERE class_id=1 AND engine_id=0),' ',(SELECT COUNT(*) FROM durable_allocation_log),' ',(SELECT COUNT(*) FROM coordinate_tombstones));")" "1 1 1 1"
  check "tombstone" "$(sudo mysql "$DB" -N -e "SELECT CONCAT(class_id,':',engine_id,':',local_id,' ',status) FROM coordinate_tombstones;")" "1:0:0 CONSUMED"
  if mysql -u "$USER_" -p"$PASS_" "$DB" -e "INSERT INTO identity_records (class_id,engine_id,local_id,full_smart_id,role_bit,allocated_profile,allocated_epoch,history_chain_root_id) VALUES (1,0,9,999,1,'v1.42',1,'x');" >/dev/null 2>&1
  then echo "FAIL direct insert succeeded"; FAILED=1; else echo "PASS direct insert denied"; fi
else
  dropdb --if-exists "$DB"; createdb "$DB"
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
  psql -qAt -d postgres -c "ALTER ROLE s64_alloc_pg PASSWORD 'x';" >/dev/null
  ROOT=$(psql -qAt -d "$DB" -c "SELECT lpad(to_hex(fn_expected_smart_id_v142(1,0,0,1)),64,'0');")
  ID=$(PGPASSWORD="$PASS_" psql -qAt -h 127.0.0.1 -U "$USER_" -d "$DB" -c "SELECT s64_allocate(1,0,0,1,'v1.42',1,'$ROOT',NULL);" 2>/dev/null)
  if [ -n "$ID" ]; then echo "PASS allocation call succeeded as $USER_"; else echo "FAIL allocation call as $USER_"; FAILED=1; fi
  check "smart_id" "$ID" "1442277780665401344"
  check "counts" "$(psql -qAt -F' ' -d "$DB" -c "SELECT (SELECT count(*) FROM identity_records),(SELECT local_watermark FROM virtual_engines WHERE class_id=1 AND engine_id=0),(SELECT count(*) FROM durable_allocation_log),(SELECT count(*) FROM coordinate_tombstones);")" "1 1 1 1"
  check "tombstone" "$(psql -qAt -d "$DB" -c "SELECT class_id||':'||engine_id||':'||local_id||' '||status FROM coordinate_tombstones;")" "1:0:0 CONSUMED"
  if PGPASSWORD="$PASS_" psql -qAt -h 127.0.0.1 -U "$USER_" -d "$DB" -c "INSERT INTO identity_records (class_id,engine_id,local_id,full_smart_id,role_bit,allocated_profile,allocated_epoch,history_chain_root_id) VALUES (1,0,9,999,1,'v1.42',1,gen_random_uuid());" >/dev/null 2>&1
  then echo "FAIL direct insert succeeded"; FAILED=1; else echo "PASS direct insert denied"; fi
fi
if [ "$FAILED" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "CHECKS FAILED"; exit 1; fi
