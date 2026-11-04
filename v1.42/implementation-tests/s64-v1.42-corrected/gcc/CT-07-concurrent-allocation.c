#define _POSIX_C_SOURCE 200809L
#include <mysql.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <time.h>

#define CLASS_ID 1U
#define LOCAL_MAX UINT32_C(0x1FFFFFFF)
#define ENGINE_MAX UINT32_C(0x1FFFFF)
#define OPS_PER_WORKER 100U
#define MAX_WORKERS 1000U
#define MAX_RETRIES 10U
#define REQUIRED_DB "s64_ct07_disposable"
#define ENGINE_LOCK_NAME "s64_ct07_engine_provision_v1"

static uint32_t g_engine_id = 0;

typedef struct {
    unsigned id, operations, successes, failures, retries, duplicates;
    unsigned connection_failures;
} Worker;

static pthread_mutex_t totals_lock = PTHREAD_MUTEX_INITIALIZER;
static unsigned total_success, total_fail, total_retry, total_dup, total_connfail;

static const char *env_or(const char *key, const char *fallback) {
    const char *v = getenv(key);
    return (v && *v) ? v : fallback;
}

static int connect_db(MYSQL *db) {
    unsigned timeout = 30;
    if (!mysql_init(db)) return 0;
    mysql_options(db, MYSQL_OPT_CONNECT_TIMEOUT, &timeout);
    return mysql_real_connect(db, env_or("S64_DB_HOST", "localhost"),
        env_or("S64_DB_USER", "root"), env_or("S64_DB_PASS", ""),
        REQUIRED_DB, 0, env_or("S64_DB_SOCKET", "/opt/lampp/var/mysql/mysql.sock"), 0) != NULL;
}

static int query(MYSQL *db, const char *sql) {
    return mysql_query(db, sql) == 0;
}

static void add_totals(const Worker *w) {
    pthread_mutex_lock(&totals_lock);
    total_success += w->successes;
    total_fail += w->failures;
    total_retry += w->retries;
    total_dup += w->duplicates;
    total_connfail += w->connection_failures;
    pthread_mutex_unlock(&totals_lock);
}

static void backoff(unsigned n) {
    struct timespec ts = {0, (long)((n < 19 ? (n + 1) * 5 : 100) * 1000000)};
    nanosleep(&ts, NULL);
}

/*
 * Provision a new Engine ID in the dedicated disposable database.
 * Existing Engine rows and allocations are never deleted or reset.
 * GET_LOCK serializes concurrent test-run provisioning.
 */
static int prepare_test_engine(void) {
    MYSQL db;
    MYSQL_RES *res = NULL;
    MYSQL_ROW row;
    char sql[256];
    int lock_held = 0;
    int ok = 0;

    if (!connect_db(&db)) {
        fprintf(stderr, "CT-07 setup connection failed: %s\n", mysql_error(&db));
        return 0;
    }

    if (!query(&db, "SELECT GET_LOCK('" ENGINE_LOCK_NAME "',30)")) {
        fprintf(stderr, "CT-07 could not acquire provisioning lock: %s\n", mysql_error(&db));
        mysql_close(&db);
        return 0;
    }
    res = mysql_store_result(&db);
    row = res ? mysql_fetch_row(res) : NULL;
    if (!row || !row[0] || strcmp(row[0], "1") != 0) {
        fprintf(stderr, "CT-07 could not acquire provisioning lock within 30 seconds.\n");
        if (res) mysql_free_result(res);
        mysql_close(&db);
        return 0;
    }
    mysql_free_result(res);
    lock_held = 1;

    if (!query(&db, "START TRANSACTION")) {
        fprintf(stderr, "CT-07 setup transaction failed: %s\n", mysql_error(&db));
        goto cleanup;
    }
    if (!query(&db, "SELECT COALESCE(MAX(engine_id),0)+1 FROM physical_engine")) {
        fprintf(stderr, "CT-07 Engine ID selection failed: %s\n", mysql_error(&db));
        (void)query(&db, "ROLLBACK");
        goto cleanup;
    }
    res = mysql_store_result(&db);
    row = res ? mysql_fetch_row(res) : NULL;
    if (!row || !row[0]) {
        fprintf(stderr, "CT-07 could not determine an unused Engine ID.\n");
        if (res) mysql_free_result(res);
        (void)query(&db, "ROLLBACK");
        goto cleanup;
    }
    unsigned long candidate = strtoul(row[0], NULL, 10);
    mysql_free_result(res);
    res = NULL;
    if (candidate == 0 || candidate > ENGINE_MAX) {
        fprintf(stderr, "CT-07 disposable database has no available Engine ID.\n");
        (void)query(&db, "ROLLBACK");
        goto cleanup;
    }
    g_engine_id = (uint32_t)candidate;

    snprintf(sql, sizeof(sql),
        "INSERT INTO physical_engine(engine_id,class_id,status) VALUES(%" PRIu32 ",%u,'ACTIVE')",
        g_engine_id, CLASS_ID);
    if (!query(&db, sql)) {
        fprintf(stderr, "CT-07 test Engine insert failed: %s\n", mysql_error(&db));
        (void)query(&db, "ROLLBACK");
        goto cleanup;
    }
    snprintf(sql, sizeof(sql),
        "INSERT INTO engine_counter(engine_id,next_local_id) VALUES(%" PRIu32 ",1)",
        g_engine_id);
    if (!query(&db, sql) || !query(&db, "COMMIT")) {
        fprintf(stderr, "CT-07 test counter/commit failed: %s\n", mysql_error(&db));
        (void)query(&db, "ROLLBACK");
        goto cleanup;
    }
    ok = 1;

cleanup:
    if (res) mysql_free_result(res);
    if (lock_held) (void)query(&db, "SELECT RELEASE_LOCK('" ENGINE_LOCK_NAME "')");
    mysql_close(&db);
    if (ok) {
        FILE *fp = fopen("evidence/CT-07/engine-id.txt", "w");
        if (!fp) {
            perror("evidence/CT-07/engine-id.txt");
            return 0;
        }
        fprintf(fp, "database=%s\nengine_id=%" PRIu32 "\ninitial_next_local_id=1\n",
                REQUIRED_DB, g_engine_id);
        if (fclose(fp) != 0) return 0;
        printf("Provisioned isolated test Engine ID: %" PRIu32 " in database %s\n",
               g_engine_id, REQUIRED_DB);
    }
    return ok;
}

static int allocate_one(MYSQL *db, Worker *w, unsigned *error_code) {
    MYSQL_RES *res = NULL;
    MYSQL_ROW row;
    char sql[512];
    uint32_t local;
    uint64_t id;
    *error_code = 0;

    if (!query(db, "START TRANSACTION")) { *error_code = mysql_errno(db); return 0; }
    snprintf(sql, sizeof(sql),
        "SELECT next_local_id FROM engine_counter WHERE engine_id=%" PRIu32 " FOR UPDATE", g_engine_id);
    if (!query(db, sql)) { *error_code = mysql_errno(db); (void)query(db, "ROLLBACK"); return 0; }
    res = mysql_store_result(db);
    if (!res) { *error_code = mysql_errno(db); (void)query(db, "ROLLBACK"); return 0; }
    row = mysql_fetch_row(res);
    if (!row || !row[0]) { mysql_free_result(res); (void)query(db, "ROLLBACK"); return 0; }
    unsigned long parsed = strtoul(row[0], NULL, 10);
    mysql_free_result(res);
    if (parsed == 0 || parsed > LOCAL_MAX) { (void)query(db, "ROLLBACK"); return 0; }

    local = (uint32_t)parsed;
    id = (uint64_t)local | ((uint64_t)g_engine_id << 29) |
         ((uint64_t)CLASS_ID << 50) | (UINT64_C(1) << 63);
    snprintf(sql, sizeof(sql),
        "UPDATE engine_counter SET next_local_id=next_local_id+1 WHERE engine_id=%" PRIu32,
        g_engine_id);
    if (!query(db, sql)) { *error_code = mysql_errno(db); (void)query(db, "ROLLBACK"); return 0; }
    snprintf(sql, sizeof(sql),
        "INSERT INTO allocation(engine_id,local_id,s64_id) VALUES(%" PRIu32 ",%" PRIu32 ",%" PRIu64 ")",
        g_engine_id, local, id);
    if (!query(db, sql)) {
        *error_code = mysql_errno(db);
        if (*error_code == 1062) w->duplicates++;
        (void)query(db, "ROLLBACK");
        return 0;
    }
    if (!query(db, "COMMIT")) { *error_code = mysql_errno(db); (void)query(db, "ROLLBACK"); return 0; }
    return 1;
}

static void *worker(void *arg) {
    Worker *w = (Worker *)arg;
    MYSQL db;
    if (!connect_db(&db)) {
        fprintf(stderr, "Worker %u connection failed\n", w->id);
        w->connection_failures = 1;
        w->failures = w->operations;
        add_totals(w);
        return NULL;
    }
    for (unsigned i = 0; i < w->operations; i++) {
        int ok = 0;
        for (unsigned attempt = 0; attempt <= MAX_RETRIES; attempt++) {
            unsigned err = 0;
            if (allocate_one(&db, w, &err)) { ok = 1; break; }
            if (err == 1205 || err == 1213) { w->retries++; backoff(attempt); continue; }
            break;
        }
        if (ok) w->successes++;
        else w->failures++;
    }
    mysql_close(&db);
    add_totals(w);
    return NULL;
}

static int verify(unsigned expected) {
    MYSQL db;
    MYSQL_RES *res;
    MYSQL_ROW row;
    char sql[512];
    if (!connect_db(&db)) { fprintf(stderr, "CT-07 verification connection failed\n"); return 0; }
    snprintf(sql, sizeof(sql),
        "SELECT COUNT(*),COUNT(DISTINCT s64_id),COALESCE(MIN(local_id),0),COALESCE(MAX(local_id),0) "
        "FROM allocation WHERE engine_id=%" PRIu32, g_engine_id);
    if (!query(&db, sql)) { mysql_close(&db); return 0; }
    res = mysql_store_result(&db); row = res ? mysql_fetch_row(res) : NULL;
    if (!row) { if (res) mysql_free_result(res); mysql_close(&db); return 0; }
    unsigned long long count = strtoull(row[0], NULL, 10);
    unsigned long long unique = strtoull(row[1], NULL, 10);
    unsigned long long min = strtoull(row[2], NULL, 10);
    unsigned long long max = strtoull(row[3], NULL, 10);
    mysql_free_result(res);
    snprintf(sql, sizeof(sql), "SELECT next_local_id FROM engine_counter WHERE engine_id=%" PRIu32, g_engine_id);
    if (!query(&db, sql)) { mysql_close(&db); return 0; }
    res = mysql_store_result(&db); row = res ? mysql_fetch_row(res) : NULL;
    if (!row) { if (res) mysql_free_result(res); mysql_close(&db); return 0; }
    unsigned long long next = strtoull(row[0], NULL, 10);
    mysql_free_result(res);
    mysql_close(&db);
    printf("Database: %s\nTest Engine ID: %" PRIu32 "\nDatabase allocation rows: %llu\n"
           "Distinct S64 IDs: %llu\nMin Local ID: %llu\nMax Local ID: %llu\nNext Local ID: %llu\n",
           REQUIRED_DB, g_engine_id, count, unique, min, max, next);
    return count == expected && unique == count && min == 1 && max == expected &&
           next == (unsigned long long)expected + 1;
}

int main(int argc, char **argv) {
    if (argc != 2 || strcmp(argv[1], "--i-understand-disposable-db") != 0) {
        fprintf(stderr, "Usage: %s --i-understand-disposable-db\n", argv[0]);
        fprintf(stderr, "This provisions a NEW Engine ID in the dedicated database %s.\n", REQUIRED_DB);
        fprintf(stderr, "It never resets/deletes an existing Engine, counter, or allocation.\n");
        return 2;
    }
    if (!prepare_test_engine()) return 1;

    const unsigned workers = MAX_WORKERS;
    const unsigned expected = workers * OPS_PER_WORKER;
    pthread_t *threads = calloc(workers, sizeof(*threads));
    Worker *data = calloc(workers, sizeof(*data));
    if (!threads || !data) { fprintf(stderr, "Allocation failure\n"); free(threads); free(data); return 1; }

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);
    unsigned created = 0;
    for (unsigned i = 0; i < workers; i++) {
        data[i].id = i;
        data[i].operations = OPS_PER_WORKER;
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
    free(threads);
    free(data);
    return pass ? 0 : 1;
}
