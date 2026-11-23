#!/usr/bin/env bash
set -u
ENGINE="${1:?usage: run.sh mysql|pg}"
case "$ENGINE" in
  mysql) DB=qdh_schema ;;   # grants in the schema are database-qualified
  pg)    DB=qdh_t ;;
esac
PASS=0; FAIL=0

my() { sudo mysql "$@" 2>&1; }
pgq() { psql -qAt -d "$DB" -c "$1" 2>&1; }

reset_mysql() {
  sudo mysql -e "DROP DATABASE IF EXISTS $DB; CREATE DATABASE $DB;" || return 1
  sudo mysql "$DB" < qdh_schema_mysql.sql >/dev/null 2>&1 || return 1
  sudo mysql "$DB" -e "
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
     WHERE class_id=1 AND engine_id=0;" >/dev/null 2>&1
}

reset_pg() {
  dropdb --if-exists "$DB" >/dev/null 2>&1
  createdb "$DB" >/dev/null 2>&1 || return 1
  psql -q -d "$DB" -v ON_ERROR_STOP=1 -f qdh_schema_postgresql.sql >/dev/null 2>&1 || return 1
  psql -q -d "$DB" -v ON_ERROR_STOP=1 >/dev/null 2>&1 <<'SQL'
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
}

record() { if [ "$2" = PASS ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
           printf '%-4s %-52s %s\n' "$1" "$3" "$2"; }

root_mysql() { sudo mysql "$DB" -N -e "SELECT LPAD(HEX(fn_expected_smart_id_v142(1,0,0,1)),64,'0');" | tr -d '\n'; }
root_pg()    { psql -qAt -d "$DB" -c "SELECT lpad(to_hex(fn_expected_smart_id_v142(1,0,0,1)),64,'0');" | tr -d '\n'; }

call_alloc() {  # $1 = local
  if [ "$ENGINE" = mysql ]; then
    sudo mysql "$DB" -e "CALL s64_allocate(1,0,$1,1,'v1.42',1,'$(root_mysql)',NULL,@a);" 2>&1 | grep -v Warning
  else
    psql -qAt -d "$DB" -c "SELECT s64_allocate(1,0,$1,1,'v1.42',1,'$(root_pg)',NULL);" 2>&1
  fi
}

case_C01() {
  reset_$ENGINE >/dev/null 2>&1 || { record C01 FAIL "fixture"; return; }
  call_alloc 0 >/dev/null
  OUT=$(call_alloc 0)
  N=$([ "$ENGINE" = mysql ] && sudo mysql "$DB" -N -e "SELECT COUNT(*) FROM identity_records;" || psql -qAt -d "$DB" -c "SELECT count(*) FROM identity_records;")
  if echo "$OUT" | grep -q "S64-E014\|S64-E018" && [ "$N" = 1 ]; then record C01 PASS "one identity, second refused"
  else record C01 FAIL "rows=$N :: $(echo "$OUT" | head -2 | tr '\n' ' ')"; fi
}

case_C02() {
  reset_$ENGINE >/dev/null 2>&1 || { record C02 FAIL "fixture"; return; }
  if [ "$ENGINE" = mysql ]; then
    sudo mysql "$DB" -e "UPDATE allocator_leases SET revoked_at_utc=UTC_TIMESTAMP() WHERE class_id=1 AND engine_id=0;" >/dev/null
  else
    psql -qAt -d "$DB" -c "UPDATE allocator_leases SET revoked_at_utc=now() WHERE class_id=1 AND engine_id=0;" >/dev/null
  fi
  OUT=$(call_alloc 0)
  echo "$OUT" | grep -q "QDH-E003" && record C02 PASS "revoked lease refused" || record C02 FAIL "$(echo "$OUT" | head -1)"
}

case_C03() {
  reset_$ENGINE >/dev/null 2>&1 || { record C03 FAIL "fixture"; return; }
  if [ "$ENGINE" = mysql ]; then
    sudo mysql "$DB" -e "UPDATE physical_nodes SET node_state='NODE_QUARANTINED', quarantined_at_utc=UTC_TIMESTAMP() WHERE node_id='n1';" >/dev/null
    ST=$(sudo mysql "$DB" -N -e "SELECT lifecycle_state FROM virtual_engines WHERE class_id=1 AND engine_id=0;")
  else
    psql -qAt -d "$DB" -c "UPDATE physical_nodes SET node_state='NODE_QUARANTINED', quarantined_at_utc=now() WHERE node_id='n1';" >/dev/null
    ST=$(psql -qAt -d "$DB" -c "SELECT lifecycle_state FROM virtual_engines WHERE class_id=1 AND engine_id=0;")
  fi
  OUT=$(call_alloc 0)
  if echo "$OUT" | grep -q "QDH-E003\|QDH-E007\|QDH-E018" && [ "$ST" = STATE_QUARANTINED ]; then
    record C03 PASS "quarantined (E003 at lease gate), refused"
  else record C03 FAIL "state=$ST :: $(echo "$OUT" | head -1)"; fi
}

case_C04() {
  reset_$ENGINE >/dev/null 2>&1 || { record C04 FAIL "fixture"; return; }
  call_alloc 0 >/dev/null
  if [ "$ENGINE" = mysql ]; then
    sudo mysql "$DB" -e "CALL s64_retire(1,0,0);" >/dev/null 2>&1
  else
    psql -qAt -d "$DB" -c "SELECT s64_retire(1,0,0);" >/dev/null 2>&1
  fi
  OUT=$(call_alloc 0)
  echo "$OUT" | grep -q "S64-E014\|S64-E016\|S64-E018" && record C04 PASS "reissue refused" || record C04 FAIL "$(echo "$OUT" | head -1)"
}

case_C05() {
  reset_$ENGINE >/dev/null 2>&1 || { record C05 FAIL "fixture"; return; }
  SQL="INSERT INTO identity_records (class_id,engine_id,local_id,full_smart_id,role_bit,allocated_profile,allocated_epoch,history_chain_root_id) VALUES (1,0,0,999,1,'v1.42',1,REPEAT('b',64));"
  if [ "$ENGINE" = mysql ]; then
    OUT=$(sudo mysql -u s64_alloc -pallocpw "$DB" -e "$SQL" 2>&1 | grep -v Warning)
    echo "$OUT" | grep -q 1142 && record C05 PASS "INSERT denied at privilege layer" || record C05 FAIL "$(echo "$OUT" | head -2 | tr '\n' ' ')"
  else
    OUT=$(env PGPASSWORD=x psql -h localhost -U s64_alloc_pg -d "$DB" -c "$SQL" 2>&1)
    echo "$OUT" | grep -q "permission denied for table" && record C05 PASS "INSERT denied at privilege layer" || record C05 FAIL "$(echo "$OUT" | head -2 | tr '\n' ' ')"
  fi
}


case_C06() {   # concurrent allocation and quarantine: atomicity, not ordering
  reset_$ENGINE >/dev/null 2>&1 || { record C06 FAIL "fixture"; return; }
  ( call_alloc 0 >/dev/null 2>&1 ) & P1=$!
  if [ "$ENGINE" = mysql ]; then
    ( sudo mysql "$DB" -e "UPDATE physical_nodes SET node_state='NODE_QUARANTINED', quarantined_at_utc=UTC_TIMESTAMP() WHERE node_id='n1';" >/dev/null 2>&1 ) & P2=$!
  else
    ( psql -qAt -d "$DB" -c "UPDATE physical_nodes SET node_state='NODE_QUARANTINED', quarantined_at_utc=now() WHERE node_id='n1';" >/dev/null 2>&1 ) & P2=$!
  fi
  wait $P1 $P2
  if [ "$ENGINE" = mysql ]; then
    C=$(sudo mysql "$DB" -N -e "SELECT (SELECT COUNT(*) FROM identity_records),(SELECT local_watermark FROM virtual_engines WHERE class_id=1 AND engine_id=0),(SELECT COUNT(*) FROM durable_allocation_log),(SELECT COUNT(*) FROM coordinate_tombstones);")
  else
    C=$(psql -qAt -F' ' -d "$DB" -c "SELECT (SELECT count(*) FROM identity_records),(SELECT local_watermark FROM virtual_engines WHERE class_id=1 AND engine_id=0),(SELECT count(*) FROM durable_allocation_log),(SELECT count(*) FROM coordinate_tombstones);")
  fi
  case "$(echo "$C" | tr -d '\t')" in
    "0000"|"0 0 0 0") record C06 PASS "no allocation committed" ;;
    "1111"|"1 1 1 1") record C06 PASS "allocation atomic: id/log/tombstone/watermark agree" ;;
    *) record C06 FAIL "inconsistent state: $C" ;;
  esac
}

case_C07() {   # HE phase entered without the required DE evidence
  reset_$ENGINE >/dev/null 2>&1 || { record C07 FAIL "fixture"; return; }
  if [ "$ENGINE" = mysql ]; then
    sudo mysql "$DB" -e "UPDATE virtual_engines SET lifecycle_state='STATE_QUARANTINED', allocator_lease_id=NULL WHERE class_id=1 AND engine_id=0;" >/dev/null
    sudo mysql "$DB" -e "UPDATE virtual_engines SET lifecycle_state='STATE_DE_VERIFYING' WHERE class_id=1 AND engine_id=0;" >/dev/null
    OUT=$(sudo mysql "$DB" -e "UPDATE virtual_engines SET lifecycle_state='STATE_HE_SANITIZING' WHERE class_id=1 AND engine_id=0;" 2>&1)
  else
    psql -qAt -d "$DB" -c "UPDATE virtual_engines SET lifecycle_state='STATE_QUARANTINED', allocator_lease_id=NULL WHERE class_id=1 AND engine_id=0;" >/dev/null
    psql -qAt -d "$DB" -c "UPDATE virtual_engines SET lifecycle_state='STATE_DE_VERIFYING' WHERE class_id=1 AND engine_id=0;" >/dev/null
    OUT=$(psql -qAt -d "$DB" -c "UPDATE virtual_engines SET lifecycle_state='STATE_HE_SANITIZING' WHERE class_id=1 AND engine_id=0;" 2>&1)
  fi
  echo "$OUT" | grep -q "QDH-E016" && record C07 PASS "HE refused without DE evidence" || record C07 FAIL "$(echo "$OUT" | head -1)"
}

case_C08() {   # reclamation with a stale watermark
  reset_$ENGINE >/dev/null 2>&1 || { record C08 FAIL "fixture"; return; }
  call_alloc 0 >/dev/null
  if [ "$ENGINE" = mysql ]; then
    OUT=$(sudo mysql "$DB" -e "CALL qdh_commit_generation(1,0,0,'n1','FAIL_HARD_RECLAIMED',UUID());" 2>&1)
  else
    OUT=$(psql -qAt -d "$DB" -c "SELECT qdh_commit_generation(1,0,0,'n1','FAIL_HARD_RECLAIMED',gen_random_uuid());" 2>&1)
  fi
  echo "$OUT" | grep -q "QDH-E014\|S64-E018" && record C08 PASS "watermark regression refused" || record C08 FAIL "$(echo "$OUT" | head -1)"
}

case_C09() {   # lease bound to a non-current epoch
  reset_$ENGINE >/dev/null 2>&1 || { record C09 FAIL "fixture"; return; }
  if [ "$ENGINE" = mysql ]; then
    OUT=$(sudo mysql "$DB" -e "INSERT INTO allocator_leases (lease_id,class_id,engine_id,generation_epoch,expires_at_utc,lease_signature,signing_trust_root_id) VALUES (UUID(),1,0,2,UTC_TIMESTAMP()+INTERVAL 1 DAY,'sig',REPEAT('a',64));" 2>&1)
  else
    OUT=$(psql -qAt -d "$DB" -c "INSERT INTO allocator_leases (lease_id,class_id,engine_id,generation_epoch,expires_at_utc,lease_signature,signing_trust_root_id) VALUES (gen_random_uuid(),1,0,2,now()+interval '1 day','sig',repeat('a',64));" 2>&1)
  fi
  echo "$OUT" | grep -q "QDH-E003" && record C09 PASS "old-epoch lease refused" || record C09 FAIL "$(echo "$OUT" | head -1)"
}

case_C13() {   # terminal exhaustion, no wraparound
  reset_$ENGINE >/dev/null 2>&1 || { record C13 FAIL "fixture"; return; }
  if [ "$ENGINE" = mysql ]; then
    sudo mysql "$DB" -e "UPDATE virtual_engines SET local_watermark=536870912, lifecycle_state='STATE_EXHAUSTED', allocator_lease_id=NULL WHERE class_id=1 AND engine_id=0;" >/dev/null
    N=$(sudo mysql "$DB" -N -e "SELECT COUNT(*) FROM v_next_forward_engine WHERE class_id=1;")
    OUT=$(sudo mysql "$DB" -e "CALL s64_allocate(1,0,536870911,1,'v1.42',1,REPEAT('0',64),NULL,@a);" 2>&1)
  else
    psql -qAt -d "$DB" -c "UPDATE virtual_engines SET local_watermark=536870912, lifecycle_state='STATE_EXHAUSTED', allocator_lease_id=NULL WHERE class_id=1 AND engine_id=0;" >/dev/null
    N=$(psql -qAt -d "$DB" -c "SELECT count(*) FROM v_next_forward_engine WHERE class_id=1;")
    OUT=$(psql -qAt -d "$DB" -c "SELECT s64_allocate(1,0,536870911,1,'v1.42',1,repeat('0',64),NULL);" 2>&1)
  fi
  if [ "$N" = 0 ] && echo "$OUT" | grep -q "QDH-E018\|QDH-E003\|S64-E031\|S64-E019"; then
    record C13 PASS "no forward candidate, allocation refused"
  else record C13 FAIL "candidates=$N :: $(echo "$OUT" | head -1)"; fi
}


case_C12() {   # identifier validation implements the 16.1 order
  reset_$ENGINE >/dev/null 2>&1 || { record C12 FAIL "fixture"; return; }
  call_alloc 0 >/dev/null
  if [ "$ENGINE" = mysql ]; then
    ID=$(sudo mysql "$DB" -N -e "SELECT full_smart_id FROM identity_records WHERE local_id=0;" | tr -d '\n')
    V1=$(sudo mysql "$DB" -N -e "SELECT s64_validate($ID);")
    R0=$(sudo mysql "$DB" -N -e "SELECT s64_validate($ID & ~(15 << 59));")
    C0=$(sudo mysql "$DB" -N -e "SELECT s64_validate($ID & ~(15 << 50));")
    NF=$(sudo mysql "$DB" -N -e "SELECT s64_validate(fn_expected_smart_id_v142(1,0,99,1));")
  else
    ID=$(psql -qAt -d "$DB" -c "SELECT full_smart_id FROM identity_records WHERE local_id=0;" | tr -d '\n')
    V1=$(psql -qAt -d "$DB" -c "SELECT s64_validate($ID);")
    R0=$(psql -qAt -d "$DB" -c "SELECT s64_validate($ID & ~(15::bigint << 59));")
    C0=$(psql -qAt -d "$DB" -c "SELECT s64_validate($ID & ~(15::bigint << 50));")
    NF=$(psql -qAt -d "$DB" -c "SELECT s64_validate(fn_expected_smart_id_v142(1,0,99,1));")
  fi
  if [ "$V1" = VALID ] && [ "$R0" = S64-E002 ] && [ "$C0" = S64-E004 ] && [ "$NF" = S64-E008 ]; then
    record C12 PASS "order: VALID / E002 / E004 / E008"
  else record C12 FAIL "got $V1 / $R0 / $C0 / $NF"; fi
}

case_C10() {   # audit event whose stored hash is not the digest of its canonical bytes
  reset_$ENGINE >/dev/null 2>&1 || { record C10 FAIL "fixture"; return; }
  if [ "$ENGINE" = mysql ]; then
    OUT=$(python3 tests/sql/gen_event.py mysql bad-hash | sudo mysql "$DB" 2>&1 | grep -v Warning)
  else
    OUT=$(python3 tests/sql/gen_event.py pg bad-hash | psql -qAt -d "$DB" 2>&1)
  fi
  echo "$OUT" | grep -q "event_hash is not the digest" && record C10 PASS "hash check fired" || record C10 FAIL "$(echo "$OUT" | head -2 | tr '\n' ' ')"
}

case_C11() {   # second event whose prev_event_hash does not match the head of the stream
  reset_$ENGINE >/dev/null 2>&1 || { record C11 FAIL "fixture"; return; }
  if [ "$ENGINE" = mysql ]; then
    python3 tests/sql/gen_event.py mysql good | sudo mysql "$DB" >/dev/null 2>&1
    OUT=$(python3 tests/sql/gen_event.py mysql bad-chain | sudo mysql "$DB" 2>&1 | grep -v Warning)
    N=$(sudo mysql "$DB" -N -e "SELECT COUNT(*) FROM qdh_audit_events;")
  else
    python3 tests/sql/gen_event.py pg good | psql -qAt -d "$DB" >/dev/null 2>&1
    OUT=$(python3 tests/sql/gen_event.py pg bad-chain | psql -qAt -d "$DB" 2>&1)
    N=$(psql -qAt -d "$DB" -c "SELECT count(*) FROM qdh_audit_events;")
  fi
  if echo "$OUT" | grep -q "Stream is not contiguous" && [ "$N" = 1 ]; then record C11 PASS "linkage check fired, first event intact"
  else record C11 FAIL "count=$N :: $(echo "$OUT" | head -2 | tr '\n' ' ')"; fi
}

case_C14() {   # stale prior-epoch quarantine event must not satisfy the current epoch
  reset_$ENGINE >/dev/null 2>&1 || { record C14 FAIL "fixture"; return; }
  if [ "$ENGINE" = mysql ]; then
    python3 tests/sql/gen_event.py mysql reclaim-epoch1 | sudo mysql "$DB" >/dev/null 2>&1
    sudo mysql "$DB" -e "UPDATE virtual_engines SET lineage=JSON_ARRAY_APPEND(lineage,'\$',JSON_OBJECT('generation_epoch',generation_epoch,'local_start',local_watermark,'local_end_watermark',local_watermark,'closure_reason','FAIL_HARD_RECLAIMED','closing_audit_event_id','550e8400-e29b-41d4-a716-446655440001')), generation_epoch=2, lifecycle_state='STATE_QUARANTINED', allocator_lease_id=NULL WHERE class_id=1 AND engine_id=0;"
    A=$(sudo mysql "$DB" -N -e "SELECT COUNT(*) FROM qdh_audit_gap;")
    python3 tests/sql/gen_event.py mysql quarantine-epoch2-after-reclaim | sudo mysql "$DB" >/dev/null 2>&1
    B=$(sudo mysql "$DB" -N -e "SELECT COUNT(*) FROM qdh_audit_gap;")
    E=$(sudo mysql "$DB" -N -e "SELECT CONCAT(generation_epoch,':',lifecycle_state) FROM virtual_engines WHERE class_id=1 AND engine_id=0;")
  else
    python3 tests/sql/gen_event.py pg reclaim-epoch1 | psql -qAt -d "$DB" >/dev/null 2>&1
    psql -qAt -d "$DB" -c "UPDATE virtual_engines SET generation_epoch=2, lifecycle_state='STATE_QUARANTINED', allocator_lease_id=NULL, lineage=lineage || jsonb_build_array(jsonb_build_object('generation_epoch',generation_epoch,'local_start',local_watermark,'local_end_watermark',local_watermark,'closure_reason','FAIL_HARD_RECLAIMED','closing_audit_event_id','550e8400-e29b-41d4-a716-446655440001')) WHERE class_id=1 AND engine_id=0;" >/dev/null
    A=$(psql -qAt -d "$DB" -c "SELECT count(*) FROM qdh_audit_gap;")
    python3 tests/sql/gen_event.py pg quarantine-epoch2-after-reclaim | psql -qAt -d "$DB" >/dev/null 2>&1
    B=$(psql -qAt -d "$DB" -c "SELECT count(*) FROM qdh_audit_gap;")
    E=$(psql -qAt -d "$DB" -c "SELECT generation_epoch || ':' || lifecycle_state FROM virtual_engines WHERE class_id=1 AND engine_id=0;")
  fi
  if [ "$A" = 1 ] && [ "$B" = 0 ] && [ "$E" = "2:STATE_QUARANTINED" ]; then
    record C14 PASS "stale epoch-1 event reported as gap; epoch-2 event clears it"
  else
    record C14 FAIL "epoch=$E gap_stale=$A gap_current=$B (want 2:STATE_QUARANTINED/1/0)"
  fi
}
echo "engine: $ENGINE  db: $DB"
case_C01; case_C02; case_C03; case_C04; case_C05; case_C06; case_C07; case_C08; case_C09; case_C10; case_C11; case_C12; case_C13; case_C14
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
