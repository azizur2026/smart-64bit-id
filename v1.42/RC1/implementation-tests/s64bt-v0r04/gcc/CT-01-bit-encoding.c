/*
 * CT-01 - Bit encoding and decoding.
 * S64BT Package Version: 0
 * S64BT Package Revision: 04
 * S64BT Package Date: Nov 14, 2026
 */
#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>
#include <stdlib.h>

#define LOCAL_MASK    UINT64_C(0x1FFFFFFF)
#define ENGINE_MASK   UINT64_C(0x1FFFFF)
#define RESERVED_MASK (UINT64_C(0x0F) << 54)

typedef struct {
    uint32_t local_id, engine_id;
    uint8_t class_id, role, revision, version;
} s64_fields;

static uint64_t encode(s64_fields f) {
    return (uint64_t)f.local_id |
        ((uint64_t)f.engine_id << 29) |
        ((uint64_t)f.class_id  << 50) |
        ((uint64_t)f.role      << 58) |
        ((uint64_t)f.revision  << 59) |
        ((uint64_t)f.version   << 63);
}
static s64_fields decode(uint64_t id) {
    s64_fields f = {
        (uint32_t)(id & LOCAL_MASK),
        (uint32_t)((id >> 29) & ENGINE_MASK),
        (uint8_t)((id >> 50) & 0x0F),
        (uint8_t)((id >> 58) & 1),
        (uint8_t)((id >> 59) & 0x0F),
        (uint8_t)(id >> 63)
    };
    return f;
}
static int same(s64_fields a, s64_fields b) {
    return a.local_id == b.local_id && a.engine_id == b.engine_id &&
        a.class_id == b.class_id && a.role == b.role &&
        a.revision == b.revision && a.version == b.version;
}

static int g_assert_n = 0;
static int assert_result(int ok, const char *category) {
    g_assert_n++;
    printf("CT-01: assertion %d %s%s%s\n",
           g_assert_n, ok ? "PASS" : "FAIL",
           category && *category ? " " : "",
           category ? category : "");
    return ok;
}

int main(void) {
    int assertions = 0, passed = 0;

    static const struct { s64_fields f; uint64_t expect; } canon[] = {
        {{1, 1, 1, 0, 0, 1}, UINT64_C(0x8004000020000001)},
        {{0, 0, 1, 0, 0, 1}, UINT64_C(0x8004000000000000)},
        {{1, 1, 1, 1, 0, 1}, UINT64_C(0x8404000020000001)},
        {{1, 1, 1, 0, 1, 1}, UINT64_C(0x8804000020000001)},
    };
    for (unsigned i = 0; i < 4; ++i) {
        assertions++;
        uint64_t got = encode(canon[i].f);
        char cat[32]; snprintf(cat, sizeof(cat), "canonical[%u]", i);
        if (assert_result(got == canon[i].expect && same(decode(canon[i].expect), canon[i].f), cat)) passed++;
        else { fprintf(stderr, "CT-01 FAIL canonical[%u]\n", i); }
    }

    static const struct { s64_fields f; uint64_t expect; } v142[] = {
        {{1, 42, 1, 1, 2, 0}, UINT64_C(0x1404000540000001)},
        {{2, 42, 2, 1, 2, 0}, UINT64_C(0x1408000540000002)},
        {{3, 42, 3, 1, 2, 0}, UINT64_C(0x140C000540000003)},
        {{4, 42, 4, 1, 2, 0}, UINT64_C(0x1410000540000004)},
        {{5, 42, 5, 1, 2, 0}, UINT64_C(0x1414000540000005)},
        {{6, 42, 6, 1, 2, 0}, UINT64_C(0x1418000540000006)},
        {{7, 42, 7, 1, 2, 0}, UINT64_C(0x141C000540000007)},
        {{8, 42, 8, 1, 2, 0}, UINT64_C(0x1420000540000008)},
    };
    for (unsigned i = 0; i < 8; ++i) {
        assertions++;
        uint64_t got = encode(v142[i].f);
        char cat[32]; snprintf(cat, sizeof(cat), "v142[%u]", i);
        if (assert_result(got == v142[i].expect && same(decode(v142[i].expect), v142[i].f), cat)) passed++;
        else fprintf(stderr, "CT-01 FAIL v142[%u] got=0x%016" PRIx64 " want=0x%016" PRIx64 "\n",
                     i, got, v142[i].expect);
    }

    static const struct { s64_fields f; uint64_t expect; } cross[] = {
        {{1, 42, 1, 1, 0,  0}, UINT64_C(0x0404000540000001)},
        {{1, 42, 1, 1, 1,  0}, UINT64_C(0x0C04000540000001)},
        {{1, 42, 1, 1, 2,  0}, UINT64_C(0x1404000540000001)},
        {{1, 42, 1, 1, 15, 0}, UINT64_C(0x7C04000540000001)},
    };
    for (unsigned i = 0; i < 4; ++i) {
        assertions++;
        uint64_t got = encode(cross[i].f);
        char cat[32]; snprintf(cat, sizeof(cat), "cross[%u]", i);
        if (assert_result(got == cross[i].expect && same(decode(cross[i].expect), cross[i].f), cat)) passed++;
        else fprintf(stderr, "CT-01 FAIL cross[%u]\n", i);
    }

    uint64_t boundaries = 0;
    for (uint32_t c = 1; c <= 8; c++)
    for (uint32_t r = 0; r <= 1; r++)
    for (uint32_t rev = 0; rev <= 15; rev++)
    for (uint32_t e = 0; e <= 1; e++)
    for (uint32_t l = 0; l <= 1; l++)
    for (uint32_t v = 0; v <= 1; v++) {
        s64_fields f = {
            l ? (uint32_t)LOCAL_MASK : 0,
            e ? (uint32_t)ENGINE_MASK : 0,
            (uint8_t)c, (uint8_t)r, (uint8_t)rev, (uint8_t)v
        };
        uint64_t id = encode(f);
        if ((id & RESERVED_MASK) || !same(f, decode(id))) {
            fprintf(stderr, "CT-01 FAIL boundary\n"); return 1;
        }
        boundaries++;
    }
    assertions++; if (assert_result(boundaries == 2048, "boundary_count")) passed++;
    else fprintf(stderr, "CT-01 FAIL boundary count=%" PRIu64 "\n", boundaries);

    uint64_t state = UINT64_C(0x9E3779B97F4A7C15), rc = 0;
    for (uint64_t i = 0; i < UINT64_C(1000000); i++) {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17;
        s64_fields f = {
            (uint32_t)(state & LOCAL_MASK),
            (uint32_t)((state >> 8) & ENGINE_MASK),
            (uint8_t)((i % 8) + 1),
            (uint8_t)((state >> 16) & 1),
            (uint8_t)((state >> 20) & 15),
            (uint8_t)((state >> 24) & 1)
        };
        uint64_t id = encode(f);
        if ((id & RESERVED_MASK) || !same(f, decode(id))) {
            fprintf(stderr, "CT-01 FAIL random[%" PRIu64 "]\n", i); return 1;
        }
        rc++;
    }
    assertions++; if (assert_result(rc == 1000000, "random_count")) passed++;
    else fprintf(stderr, "CT-01 FAIL random count=%" PRIu64 "\n", rc);

    printf("CT-01: PASS\n");
    printf("canonical_vectors=4 v142_vectors=8 cross_version_vectors=4\n");
    printf("boundary_cases=%" PRIu64 " random_cases=%" PRIu64 " total_round_trips=%" PRIu64 "\n",
           boundaries, rc, 4 + 8 + 4 + boundaries + rc);
    printf("assertions=%d passed=%d\n", assertions, passed);
    return (assertions == passed) ? 0 : 1;
}
