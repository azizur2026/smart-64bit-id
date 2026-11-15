/*
 * CT-07 - Concurrent allocation. Tier 3.
 * S64BT Package Version: 0
 * S64BT Package Revision: 04
 * S64BT Package Date: Nov 14, 2026
 * Scope: test-inline encoding; production allocator NOT exercised.
 * Parameters (workers, ops, class) read from s64bt.config via S64BT_CONFIG env.
 */
#define _POSIX_C_SOURCE 200809L
#include <mysql.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <time.h>

#define LOCAL_MAX UINT32_C(0x1FFFFFFF)
#define ENGINE_MAX UINT32_C(0x1FFFFF)
#define MAX_RETRIES 10U
#define REQUIRED_DB "s64_ct07_disposable"
#define ENGINE_LOCK_NAME "s64_ct07_engine_provision_v1"

static uint32_t g_engine_id = 0;
static unsigned g_workers = 1000;
static unsigned g_ops_per_worker = 100;
static unsigned g_class_id = 1;
static char g_evidence_dir[512] = "gcc/evidence/CT-07";

typedef struct {
    unsigned id, operations, successes, failures, retries, duplicates;
    unsigned connection_failures;
} Worker;

static pthread_mutex_t totals_lock = PTHREAD_MUTEX_INITIALIZER;
static unsigned total_success, total_fail, total_retry, total_dup, total_connfail;

static const char *env_or(const char *k, const char *d) {
    const char *v = getenv(k); return (v && *v) ? v : d;
}

/* Parse s64bt.config for CT07_WORKERS, CT07_OPS_PER_WORKER, CT07_CLASS_ID */
static int load_config(void) {
    const char *cfg_path = env_or("S64BT_CONFIG", "s64bt.config");
    FILE *fp = fopen(cfg_path, "r");
    if (!fp) {
        fprintf(stderr, "CT-07 config open failed: %s\n", cfg_path);
        return 0;
    }
    char line[512];
    while (fgets(line, sizeof(line), fp)) {
        char *p = line;
        while (*p == ' ' || *p == '\t') p++;
        if (*p == '#' || *p == '\n' || *p == '\0') continue;
        if (strncmp(p, "CT07_WORKERS=", 13) == 0) g_workers = (unsigned)strtoul(p+13, NULL, 10);
        else if (strncmp(p, "CT07_OPS_PER_WORKER=", 20) == 0) g_ops_per_worker = (unsigned)strtoul(p+20, NULL, 10);
        else if (strncmp(p, "CT07_CLASS_ID=", 14) == 0) g_class_id = (unsigned)strtoul(p+14, NULL, 10);
        else if (strncmp(p, "EVIDENCE_DIR=", 13) == 0) {
            char *v = p + 13;
            size_t n = strlen(v);
            while (n > 0 && (v[n-1] == '\n' || v[n-1] == '\r')) v[--n] = '\0';
            snprintf(g_evidence_dir, sizeof(g_evidence_dir), "%s/CT-07", v);
        }
    }
    fclose(fp);
    /* M6: allow env override for evidence dir */
    const char *env_ev = getenv("S64_EVIDENCE_DIR");
    if (env_ev && *env_ev) {
        snprintf(g_evidence_dir, sizeof(g_evidence_dir), "%s/CT-07", env_ev);
    }
    if (g_workers == 0 || g_ops_per_worker == 0) {
        fprintf(stderr, "CT-07 invalid config: workers=%u ops=%u\n", g_workers, g_ops_per_worker);
        return 0;
    }
    return 1;
}

static int connect_db(MYSQL *db) {
    unsigned t = 30;
    if (!mysql_init(db)) return 0;
    mysql_options(db, MYSQL_OPT_CONNECT_TIMEOUT, &t);
    return mysql_real_connect(db,
        env_or("S64_DB_HOST", "localhost"), env_or("S64_DB_USER", "root"),
        env_or("S64_DB_PASS", ""), REQUIRED_DB, 0,
        env_or("S64_DB_SOCKET", "/opt/lampp/var/mysql/mysql.sock"), 0) != NULL;
}
static int query(MYSQL *db, const char *sql) { return mysql_query(db, sql) == 0; }

static void add_totals(const Worker *w) {
    pthread_mutex_lock(&totals_lock);
    total_success += w->successes; total_fail += w->failures;
    total_retry += w->retries; total_dup += w->duplicates;
    total_connfail += w->connection_failures;
    pthread_mutex_unlock(&totals_lock);
}
static void backoff(unsigned n) {
    struct timespec ts = {0, (long)((n < 19 ? (n + 1) * 5 : 100) * 1000000)};
    nanosleep(&ts, NULL);
}

static int prepare_test_engine(void) {
    MYSQL db; MYSQL_RES *res = NULL; MYSQL_ROW row;
    char sql[256]; int lock_held = 0; int ok = 0;
    if (!connect_db(&db)) {
        fprintf(stderr, "CT-07 setup connection failed: %s\n", mysql_error(&db));
        return 0;
    }
    if (!query(&db, "SELECT GET_LOCK('" ENGINE_LOCK_NAME "',30)")) {
        fprintf(stderr, "CT-07 lock failed: %s\n", mysql_error(&db));
        mysql_close(&db); return 0;
    }
    res = mysql_store_result(&db); row = res ? mysql_fetch_row(res) : NULL;
    if (!row || !row[0] || strcmp(row[0], "1") != 0) {
        fprintf(stderr, "CT-07 lock timeout\n");
        if (res) mysql_free_result(res);
        mysql_close(&db); return 0;
    }
    mysql_free_result(res); lock_held = 1;

    if (!query(&db, "START TRANSACTION")) goto cleanup;
    if (!query(&db, "SELECT COALESCE(MAX(engine_id),0)+1 FROM physical_engine")) {
        (void)query(&db, "ROLLBACK"); goto cleanup;
    }
    res = mysql_store_result(&db); row = res ? mysql_fetch_row(res) : NULL;
    if (!row || !row[0]) {
        if (res) mysql_free_result(res);
        (void)query(&db, "ROLLBACK"); goto cleanup;
    }
    {
        unsigned long candidate = strtoul(row[0], NULL, 10);
        mysql_free_result(res); res = NULL;
        if (candidate == 0 || candidate > ENGINE_MAX) {
            (void)query(&db, "ROLLBACK"); goto cleanup;
        }
        g_engine_id = (uint32_t)candidate;
    }
    snprintf(sql, sizeof(sql),
        "INSERT INTO physical_engine(engine_id,class_id,status) VALUES(%" PRIu32 ",%u,'ACTIVE')",
        g_engine_id, g_class_id);
    if (!query(&db, sql)) { (void)query(&db, "ROLLBACK"); goto cleanup; }
    snprintf(sql, sizeof(sql),
        "INSERT INTO engine_counter(engine_id,next_local_id) VALUES(%" PRIu32 ",1)", g_engine_id);
    if (!query(&db, sql) || !query(&db, "COMMIT")) {
        (void)query(&db, "ROLLBACK"); goto cleanup;
    }
    ok = 1;

cleanup:
    if (res) mysql_free_result(res);
    if (lock_held) (void)query(&db, "SELECT RELEASE_LOCK('" ENGINE_LOCK_NAME "')");
    mysql_close(&db);
    if (ok) {
        /* H1: evidence write must be fatal if it fails */
        char path[600];
        snprintf(path, sizeof(path), "%s/engine-id.txt", g_evidence_dir);
        FILE *fp = fopen(path, "w");
        if (!fp) {
            perror(path);
            fprintf(stderr, "CT-07 FAIL: engine committed (id=%u) but evidence file could not be opened\n",
                    g_engine_id);
            return 0;
        }
        int w = fprintf(fp, "database=%s\nengine_id=%" PRIu32 "\ninitial_next_local_id=1\n",
                        REQUIRED_DB, g_engine_id);
        int c = fclose(fp);
        if (w < 0 || c != 0) {
            fprintf(stderr, "CT-07 FAIL: engine committed (id=%u) but evidence write failed\n",
                    g_engine_id);
            return 0;
        }
        printf("Provisioned isolated test Engine ID: %" PRIu32 " in database %s\n",
               g_engine_id, REQUIRED_DB);
    }
    return ok;
}

static int allocate_one(MYSQL *db, Worker *w, unsigned *error_code) {
    MYSQL_RES *res = NULL; MYSQL_ROW row;
    char sql[512]; uint32_t local; uint64_t id;
    *error_code = 0;
    if (!query(db, "START TRANSACTION")) { *error_code = mysql_errno(db); return 0; }
    snprintf(sql, sizeof(sql),
        "SELECT next_local_id FROM engine_counter WHERE engine_id=%" PRIu32 " FOR UPDATE", g_engine_id);
    if (!query(db, sql)) { *error_code = mysql_errno(db); (void)query(db, "ROLLBACK"); return 0; }
    res = mysql_store_result(db);
    if (!res) { *error_code = mysql_errno(db); (void)query(db, "ROLLBACK"); return 0; }
    row = mysql_fetch_row(res);
    if (!row || !row[0]) { mysql_free_result(res); (void)query(db, "ROLLBACK"); return 0; }
    {
        unsigned long parsed = strtoul(row[0], NULL, 10);
        mysql_free_result(res);
        if (parsed == 0 || parsed > LOCAL_MAX) { (void)query(db, "ROLLBACK"); return 0; }
        local = (uint32_t)parsed;
    }
    id = (uint64_t)local | ((uint64_t)g_engine_id << 29) |
         ((uint64_t)g_class_id << 50) | (UINT64_C(2) << 59);
    snprintf(sql, sizeof(sql),
        "UPDATE engine_counter SET next_local_id=next_local_id+1 WHERE engine_id=%" PRIu32, g_engine_id);
    if (!query(db, sql)) { *error_code = mysql_errno(db); (void)query(db, "ROLLBACK"); return 0; }
    snprintf(sql, sizeof(sql),
        "INSERT INTO allocation(engine_id,local_id,s64_id) VALUES(%" PRIu32 ",%" PRIu32 ",%" PRIu64 ")",
        g_engine_id, local, id);
    if (!query(db, sql)) {
        *error_code = mysql_errno(db);
        if (*error_code == 1062) w->duplicates++;
        (void)query(db, "ROLLBACK"); return 0;
    }
    if (!query(db, "COMMIT")) { *error_code = mysql_errno(db); (void)query(db, "ROLLBACK"); return 0; }
    return 1;
}

static void *worker(void *arg) {
    Worker *w = (Worker *)arg;
    MYSQL db;
    if (!connect_db(&db)) {
        fprintf(stderr, "Worker %u connection failed\n", w->id);
        w->connection_failures = 1; w->failures = w->operations;
        add_totals(w); return NULL;
    }
    for (unsigned i = 0; i < w->operations; i++) {
        int ok = 0;
        for (unsigned attempt = 0; attempt <= MAX_RETRIES; attempt++) {
            unsigned err = 0;
            if (allocate_one(&db, w, &err)) { ok = 1; break; }
            if (err == 1205 || err == 1213) { w->retries++; backoff(attempt); continue; }
            break;
        }
        if (ok) w->successes++; else w->failures++;
    }
    mysql_close(&db);
    add_totals(w);
    return NULL;
}

static int verify(unsigned expected) {
    MYSQL db; MYSQL_RES *res; MYSQL_ROW row; char sql[512];
    if (!connect_db(&db)) {
        fprintf(stderr, "CT-07 verification connection failed\n"); return 0;
    }
    snprintf(sql, sizeof(sql),
        "SELECT COUNT(*),COUNT(DISTINCT s64_id),COALESCE(MIN(local_id),0),COALESCE(MAX(local_id),0) "
        "FROM allocation WHERE engine_id=%" PRIu32, g_engine_id);
    if (!query(&db, sql)) { mysql_close(&db); return 0; }
    res = mysql_store_result(&db); row = res ? mysql_fetch_row(res) : NULL;
    if (!row) { if (res) mysql_free_result(res); mysql_close(&db); return 0; }
    {
        unsigned long long count    = strtoull(row[0], NULL, 10);
        unsigned long long unique   = strtoull(row[1], NULL, 10);
        unsigned long long min_local = strtoull(row[2], NULL, 10);
        unsigned long long max_local = strtoull(row[3], NULL, 10);
        mysql_free_result(res);
        snprintf(sql, sizeof(sql),
            "SELECT next_local_id FROM engine_counter WHERE engine_id=%" PRIu32, g_engine_id);
        if (!query(&db, sql)) { mysql_close(&db); return 0; }
        res = mysql_store_result(&db); row = res ? mysql_fetch_row(res) : NULL;
        if (!row) { if (res) mysql_free_result(res); mysql_close(&db); return 0; }
        {
            unsigned long long next = strtoull(row[0], NULL, 10);
            mysql_free_result(res);
            snprintf(sql, sizeof(sql),
                "SELECT COUNT(*) FROM allocation WHERE engine_id=%" PRIu32
                " AND s64_id <> ((%" PRIu64 " << 59) | (%u << 50) | (engine_id << 29) | local_id)",
                g_engine_id, (uint64_t)2, g_class_id);
            if (!query(&db, sql)) { mysql_close(&db); return 0; }
            res = mysql_store_result(&db); row = res ? mysql_fetch_row(res) : NULL;
            unsigned long long bad_encoding = row ? strtoull(row[0], NULL, 10) : 1;
            if (res) mysql_free_result(res);
            mysql_close(&db);
            printf("Database: %s\nTest Engine ID: %" PRIu32 "\nDatabase allocation rows: %llu\n"
                   "Distinct S64 IDs: %llu\nMin Local ID: %llu\nMax Local ID: %llu\nNext Local ID: %llu\n"
                   "Rows with wrong encoding: %llu\n",
                   REQUIRED_DB, g_engine_id, count, unique, min_local, max_local, next, bad_encoding);
            return count == expected && unique == count && min_local == 1 &&
                   max_local == expected && next == (unsigned long long)expected + 1 &&
                   bad_encoding == 0;
        }
    }
}

int main(int argc, char **argv) {
    if (argc != 2 || strcmp(argv[1], "--i-understand-disposable-db") != 0) {
        fprintf(stderr, "Usage: %s --i-understand-disposable-db\n", argv[0]);
        fprintf(stderr, "This provisions a NEW Engine ID in the dedicated database %s.\n", REQUIRED_DB);
        return 2;
    }
    if (!load_config()) return 1;
    if (!prepare_test_engine()) return 1;

    const unsigned workers = g_workers;
    const unsigned expected = workers * g_ops_per_worker;
    pthread_t *threads = calloc(workers, sizeof(*threads));
    Worker *data = calloc(workers, sizeof(*data));
    if (!threads || !data) { fprintf(stderr, "Allocation failure\n"); free(threads); free(data); return 1; }

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);
    unsigned created = 0;
    for (unsigned i = 0; i < workers; i++) {
        data[i].id = i;
        data[i].operations = g_ops_per_worker;
        if (pthread_create(&threads[i], NULL, worker, &data[i]) != 0) {
            fprintf(stderr, "Thread creation failed at %u\n", i);
            break;
        }
        created++;
    }
    for (unsigned i = 0; i < created; i++) pthread_join(threads[i], NULL);
    clock_gettime(CLOCK_MONOTONIC, &end);
    double elapsed = (double)(end.tv_sec - start.tv_sec) +
                     (double)(end.tv_nsec - start.tv_nsec) / 1e9;
    int dbok = verify(total_success);
    int pass = created == workers && total_success == expected && total_fail == 0 &&
               total_dup == 0 && total_connfail == 0 && dbok;
    printf("CT-07 workers: %u\nWorkers created: %u\nExpected allocations: %u\n"
           "Successful allocations: %u\nFailed allocations: %u\nDeadlock/timeout retries: %u\n"
           "Duplicate-key errors: %u\nConnection failures: %u\nElapsed seconds: %.3f\n"
           "Throughput: %.2f allocations/sec\nDatabase integrity: %s\nCT-07: %s\n",
           workers, created, expected, total_success, total_fail, total_retry, total_dup,
           total_connfail, elapsed, elapsed > 0 ? total_success / elapsed : 0.0,
           dbok ? "PASS" : "FAIL", pass ? "PASS" : "FAIL");
    printf("assertions=6 passed=%d\n", pass ? 6 : 0);
    free(threads);
    free(data);
    return pass ? 0 : 1;
}
