import json, hashlib, sys

engine, mode = sys.argv[1], sys.argv[2]
Z = "0" * 64

def canon(o): return json.dumps(o, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
def body(seq, prev):
    return {
        "event_id": "550e8400-e29b-41d4-a716-44665544000%d" % (seq - 1),
        "stream_seq": seq,
        "timestamp_utc": "2026-11-23T10:0%d:00.000000Z" % (seq - 1),
        "event_type": "ENGINE_INITIAL_BOUND",
        "generation_epoch": 1,
        "virtual_engine": {"class_id": 1, "engine_id": 0},
        "lifecycle": {"previous_state": "STATE_UNALLOCATED", "new_state": "STATE_ACTIVE",
                      "epoch_before": 1, "epoch_after": 1,
                      "profile_before": "v1.42", "profile_after": "v1.42"},
        "watermark_audit": {"prior_consumed_max": 0, "durable_lease_ceiling": 0,
                            "verified_first_never_consumed_local": 0},
        "incident": {"incident_id": "INC-1", "trigger_class": "FAIL_HARD_POWER_LOSS",
                     "physical_node_before": "n1", "physical_node_after": "n1",
                     "he_attestation_digest": None},
        "diagnostic": {"qdh_code": None, "s64_code": None, "orchestrator_node": "qdh-controller-01"},
        "prev_event_hash": prev,
    }

def insert(b, h):
    c = canon(b)
    if engine == "mysql":
        return ("INSERT INTO qdh_audit_events (event_id,class_id,engine_id,stream_seq,event_type,"
                "generation_epoch,timestamp_utc,previous_state,new_state,epoch_before,epoch_after,"
                "profile_before,profile_after,watermark_verified,qdh_error_code,s64_error_code,"
                "prev_event_hash,event_hash,payload_canonical,payload) VALUES "
                "('%s',1,0,%d,'%s',%d,'%s','%s','%s',%d,%d,'%s','%s',%d,NULL,NULL,'%s','%s','%s','%s');\n"
                % (b["event_id"], b["stream_seq"], b["event_type"], b["generation_epoch"],
                   b["timestamp_utc"].replace("T", " ").replace("Z", ""),
                   b["lifecycle"]["previous_state"], b["lifecycle"]["new_state"],
                   b["lifecycle"]["epoch_before"], b["lifecycle"]["epoch_after"],
                   b["lifecycle"]["profile_before"], b["lifecycle"]["profile_after"],
                   b["watermark_audit"]["verified_first_never_consumed_local"],
                   b["prev_event_hash"], h, c, c))
    else:
        return ("INSERT INTO qdh_audit_events (event_id,class_id,engine_id,stream_seq,event_type,"
                "generation_epoch,timestamp_utc,previous_state,new_state,epoch_before,epoch_after,"
                "profile_before,profile_after,watermark_verified,qdh_error_code,s64_error_code,"
                "prev_event_hash,event_hash,payload_canonical,payload) VALUES "
                "('%s',1,0,%d,'%s',%d,'%s','%s','%s',%d,%d,'%s','%s',%d,NULL,NULL,'%s','%s',"
                "convert_to('%s','UTF8'),'%s'::jsonb);\n"
                % (b["event_id"], b["stream_seq"], b["event_type"], b["generation_epoch"],
                   b["timestamp_utc"], b["lifecycle"]["previous_state"], b["lifecycle"]["new_state"],
                   b["lifecycle"]["epoch_before"], b["lifecycle"]["epoch_after"],
                   b["lifecycle"]["profile_before"], b["lifecycle"]["profile_after"],
                   b["watermark_audit"]["verified_first_never_consumed_local"],
                   b["prev_event_hash"], h, c, c))

if mode == "good":
    b = body(1, Z); sys.stdout.write(insert(b, hashlib.sha256(canon(b).encode()).hexdigest()))
elif mode == "bad-hash":
    b = body(1, Z); sys.stdout.write(insert(b, Z))
elif mode == "quarantine-epoch1":
    q = body(1, Z)
    q["event_type"] = "NODE_QUARANTINE_TRIGGERED"
    q["generation_epoch"] = 1
    q["lifecycle"] = {"previous_state": "STATE_QUARANTINED", "new_state": "STATE_QUARANTINED",
                      "epoch_before": 1, "epoch_after": 1,
                      "profile_before": "v1.42", "profile_after": "v1.42"}
    sys.stdout.write(insert(q, hashlib.sha256(canon(q).encode()).hexdigest()))
elif mode == "reclaim-epoch1":
    b1 = body(1, Z); b1["event_type"] = "NODE_QUARANTINE_TRIGGERED"
    b1["lifecycle"] = {"previous_state": "STATE_ACTIVE", "new_state": "STATE_QUARANTINED",
                       "epoch_before": 1, "epoch_after": 1,
                       "profile_before": "v1.42", "profile_after": "v1.42"}
    h1 = hashlib.sha256(canon(b1).encode()).hexdigest()
    b2 = body(2, h1); b2["event_type"] = "RECLAMATION_COMMITTED"
    b2["lifecycle"] = {"previous_state": "STATE_RECLAIM_COMMIT", "new_state": "STATE_RECLAIM_COMMIT",
                       "epoch_before": 1, "epoch_after": 1,
                       "profile_before": "v1.42", "profile_after": "v1.42"}
    sys.stdout.write(insert(b1, h1) + insert(b2, hashlib.sha256(canon(b2).encode()).hexdigest()))
elif mode == "quarantine-epoch2-after-reclaim":
    b1 = body(1, Z); b1["event_type"] = "NODE_QUARANTINE_TRIGGERED"
    b1["lifecycle"] = {"previous_state": "STATE_ACTIVE", "new_state": "STATE_QUARANTINED",
                       "epoch_before": 1, "epoch_after": 1,
                       "profile_before": "v1.42", "profile_after": "v1.42"}
    h1 = hashlib.sha256(canon(b1).encode()).hexdigest()
    b2 = body(2, h1); b2["event_type"] = "RECLAMATION_COMMITTED"
    b2["lifecycle"] = {"previous_state": "STATE_RECLAIM_COMMIT", "new_state": "STATE_RECLAIM_COMMIT",
                       "epoch_before": 1, "epoch_after": 1,
                       "profile_before": "v1.42", "profile_after": "v1.42"}
    h2 = hashlib.sha256(canon(b2).encode()).hexdigest()
    b3 = body(3, h2); b3["event_type"] = "NODE_QUARANTINE_TRIGGERED"; b3["generation_epoch"] = 2
    b3["lifecycle"] = {"previous_state": "STATE_QUARANTINED", "new_state": "STATE_QUARANTINED",
                       "epoch_before": 2, "epoch_after": 2,
                       "profile_before": "v1.42", "profile_after": "v1.42"}
    sys.stdout.write(insert(b3, hashlib.sha256(canon(b3).encode()).hexdigest()))
elif mode == "quarantine-epoch2":
    q = body(1, Z)
    q["event_type"] = "NODE_QUARANTINE_TRIGGERED"
    q["generation_epoch"] = 2
    q["lifecycle"] = {"previous_state": "STATE_QUARANTINED", "new_state": "STATE_QUARANTINED",
                      "epoch_before": 2, "epoch_after": 2,
                      "profile_before": "v1.42", "profile_after": "v1.42"}
    sys.stdout.write(insert(q, hashlib.sha256(canon(q).encode()).hexdigest()))
else:  # bad-chain: correct genesis, then a second event with the sentinel as prev
    b1 = body(1, Z); sys.stdout.write(insert(b1, hashlib.sha256(canon(b1).encode()).hexdigest()))
    b2 = body(2, Z); sys.stdout.write(insert(b2, hashlib.sha256(canon(b2).encode()).hexdigest()))
