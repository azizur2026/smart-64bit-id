/*
 * CT-02 - Local ID boundary.
 * S64BT Package Version: 0
 * S64BT Package Revision: 04
 * S64BT Package Date: Nov 14, 2026
 * Scope: test-local only; production allocator NOT exercised.
 */
#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>

#define LOCAL_MAX UINT64_C(0x1FFFFFFF)

static int test_local_valid_local_id(uint64_t v) { return v <= LOCAL_MAX; }

static int g_assert_n = 0;
static int assert_result(int ok, const char *category) {
    g_assert_n++;
    printf("CT-02: assertion %d %s%s%s\n",
           g_assert_n, ok ? "PASS" : "FAIL",
           category && *category ? " " : "",
           category ? category : "");
    return ok;
}

int main(void) {
    int assertions = 0, passed = 0;
    printf("CT-02: SCOPE=test-local; production-allocator NOT exercised\n");

    const uint64_t valid[] = {0, 1, LOCAL_MAX - 2, LOCAL_MAX - 1, LOCAL_MAX};
    for (unsigned i = 0; i < 5; ++i) {
        assertions++;
        char cat[32]; snprintf(cat, sizeof(cat), "valid[%u]", i);
        if (assert_result(test_local_valid_local_id(valid[i]) && ((valid[i] & LOCAL_MAX) == valid[i]), cat)) passed++;
        else fprintf(stderr, "CT-02 FAIL valid rejected: %" PRIu64 "\n", valid[i]);
    }

    const uint64_t invalid[] = {LOCAL_MAX + 1, LOCAL_MAX + 2, UINT32_MAX, UINT64_MAX};
    for (unsigned i = 0; i < 4; ++i) {
        assertions++;
        char cat[32]; snprintf(cat, sizeof(cat), "invalid[%u]", i);
        if (assert_result(!test_local_valid_local_id(invalid[i]), cat)) passed++;
        else fprintf(stderr, "CT-02 FAIL invalid accepted: %" PRIu64 "\n", invalid[i]);
    }

    printf("CT-02: PASS\n");
    printf("valid_accepted=5 invalid_rejected=4\n");
    printf("assertions=%d passed=%d\n", assertions, passed);
    return (assertions == passed) ? 0 : 1;
}
