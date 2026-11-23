#!/usr/bin/env bash
# Finding A evidence: PUBLIC must not be able to create objects in schema public.
set -eu
DB=${1:-qdh_t}
psql -qAt -d "$DB" -c "SELECT 'public_can_create=' || has_schema_privilege('public','public','CREATE');"
psql -qAt -d "$DB" -c "SELECT 'test_role_can_create=' || has_schema_privilege('s64_alloc_pg','public','CREATE');"
psql -qAt -d "$DB" -c "SELECT 'public_schema_owner=' || pg_get_userbyid(nspowner) FROM pg_namespace WHERE nspname='public';"
