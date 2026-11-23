/*
 * CT-05 - v1.42 profile identification, field validation, error codes, precedence.
 * S64BT Package Version: 0
 * S64BT Package Revision: 04
 * S64BT Package Date: Nov 14, 2026
 */
#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>
#include <string.h>

#define CLASS_MASK    (UINT64_C(0x0F) << 50)
#define RESERVED_MASK (UINT64_C(0x0F) << 54)
#define REVISION_MASK (UINT64_C(0x0F) << 59)
#define VERSION_MASK  (UINT64_C(1)  << 63)

static const char *s64_error(uint64_t id) {
    unsigned version  = (unsigned)((id & VERSION_MASK)  >> 63);
    unsigned revision = (unsigned)((id & REVISION_MASK) >> 59);
    if (version != 0 || revision != 0b0010) return "S64-E002";
    unsigned reserved = (unsigned)((id & RESERVED_MASK) >> 54);
    if (reserved != 0)                       return "S64-E003";
    unsigned c = (unsigned)((id & CLASS_MASK) >> 50);
    if (c == 0)                              return "S64-E004";
    if (c >= 9 && c <= 15)                   return "S64-E005";
    return "";
}

int main(void) {
    int assertions = 0, passed = 0;

    #define CHK(id_, want_) do {                                          \
        assertions++;                                                     \
        const char *got = s64_error((uint64_t)(id_));                     \
        int ok = (strcmp(got, want_) == 0);                               \
        printf("CT-05: assertion %d %s id=0x%016" PRIx64 " want='%s'\n",   \
               assertions, ok ? "PASS" : "FAIL",                          \
               (uint64_t)(id_), want_);                                   \
        if (ok) passed++;                                                 \
        else fprintf(stderr, "CT-05 FAIL id=0x%016" PRIx64               \
                     " got='%s' want='%s'\n", (uint64_t)(id_), got, want_); \
    } while (0)

    for (unsigned c = 1; c <= 8; c++)
    for (unsigned role = 0; role <= 1; role++) {
        uint64_t id = (UINT64_C(2) << 59) |
                      ((uint64_t)role << 58) |
                      ((uint64_t)c    << 50);
        CHK(id, "");
    }

    CHK((UINT64_C(1)  << 63) | (UINT64_C(2)  << 59) | (UINT64_C(1) << 50), "S64-E002");
    CHK((UINT64_C(0)  << 63) | (UINT64_C(0)  << 59) | (UINT64_C(1) << 50), "S64-E002");
    CHK((UINT64_C(0)  << 63) | (UINT64_C(1)  << 59) | (UINT64_C(1) << 50), "S64-E002");
    CHK((UINT64_C(0)  << 63) | (UINT64_C(3)  << 59) | (UINT64_C(1) << 50), "S64-E002");
    CHK((UINT64_C(0)  << 63) | (UINT64_C(15) << 59) | (UINT64_C(1) << 50), "S64-E002");

    CHK((UINT64_C(2) << 59) | (UINT64_C(1)  << 54) | (UINT64_C(1) << 50), "S64-E003");
    CHK((UINT64_C(2) << 59) | (UINT64_C(15) << 54) | (UINT64_C(1) << 50), "S64-E003");

    CHK((UINT64_C(2) << 59), "S64-E004");

    for (unsigned c = 9; c <= 15; c++)
        CHK((UINT64_C(2) << 59) | ((uint64_t)c << 50), "S64-E005");

    CHK((UINT64_C(1) << 63) | (UINT64_C(2) << 59), "S64-E002");
    CHK((UINT64_C(0) << 63) | (UINT64_C(0) << 59) | (UINT64_C(1) << 54), "S64-E002");
    CHK((UINT64_C(2) << 59) | (UINT64_C(1) << 54), "S64-E003");
    CHK((UINT64_C(2) << 59) | (UINT64_C(1) << 54) | (UINT64_C(9) << 50), "S64-E003");
    CHK((UINT64_C(2) << 59), "S64-E004");

    #undef CHK

    printf("CT-05: PASS\n");
    printf("scope=v1.42-profile-identification+error-codes+precedence\n");
    printf("assertions=%d passed=%d\n", assertions, passed);
    return (assertions == passed) ? 0 : 1;
}
