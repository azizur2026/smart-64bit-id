#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>
#include <stdlib.h>

#define LOCAL_MASK UINT64_C(0x1FFFFFFF)
#define ENGINE_MASK UINT64_C(0x1FFFFF)
#define RESERVED_MASK (UINT64_C(0x0F) << 54)

typedef struct {
    uint32_t local_id, engine_id;
    uint8_t class_id, role, revision, version;
} s64_fields;

static uint64_t encode(s64_fields f) {
    return (uint64_t)f.local_id |
        ((uint64_t)f.engine_id << 29) |
        ((uint64_t)f.class_id << 50) |
        ((uint64_t)f.role << 58) |
        ((uint64_t)f.revision << 59) |
        ((uint64_t)f.version << 63);
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
static int verify(s64_fields f) {
    uint64_t id = encode(f);
    return !(id & RESERVED_MASK) && same(f, decode(id));
}
int main(void) {
    /* Independent constants: these are not computed by encode(). */
    static const struct { s64_fields fields; uint64_t expected; } vectors[] = {
        {{1, 1, 1, 0, 0, 1}, UINT64_C(0x8004000020000001)},
        {{0, 0, 1, 0, 0, 1}, UINT64_C(0x8004000000000000)},
        {{1, 1, 1, 1, 0, 1}, UINT64_C(0x8404000020000001)},
        {{1, 1, 1, 0, 1, 1}, UINT64_C(0x8804000020000001)}
    };
    unsigned vector_count = sizeof(vectors) / sizeof(vectors[0]);
    for (unsigned i = 0; i < vector_count; ++i) {
        uint64_t actual = encode(vectors[i].fields);
        if (actual != vectors[i].expected ||
            !same(decode(vectors[i].expected), vectors[i].fields)) {
            fprintf(stderr, "CT-01 FAIL: canonical vector %u\n", i);
            return EXIT_FAILURE;
        }
    }
    uint64_t boundaries = 0;
    for (uint32_t c=1;c<=8;c++)
    for (uint32_t r=0;r<=1;r++)
    for (uint32_t v=0;v<=15;v++)
    for (uint32_t e=0;e<=1;e++)
    for (uint32_t l=0;l<=1;l++) {
        s64_fields f = {l ? (uint32_t)LOCAL_MASK : 0,
                        e ? (uint32_t)ENGINE_MASK : 0,
                        (uint8_t)c,(uint8_t)r,(uint8_t)v,1};
        if (!verify(f)) { fprintf(stderr,"CT-01 FAIL: boundary\n"); return 1; }
        boundaries++;
    }
    uint64_t state=UINT64_C(0x9E3779B97F4A7C15), random_count=0;
    for (uint64_t i=0;i<UINT64_C(1000000);i++) {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17;
        s64_fields f = {(uint32_t)(state & LOCAL_MASK),
            (uint32_t)((state >> 8) & ENGINE_MASK),
            (uint8_t)((i % 8)+1),(uint8_t)((state >> 16)&1),
            (uint8_t)((state >> 20)&15),1};
        if (!verify(f)) { fprintf(stderr,"CT-01 FAIL: random case %" PRIu64 "\n",i); return 1; }
        random_count++;
    }
    printf("CT-01: PASS\nCanonical vectors: %u\nBoundary cases: %" PRIu64
           "\nRandom cases: %" PRIu64 "\nTotal round-trip cases: %" PRIu64 "\n",
           vector_count,boundaries,random_count,boundaries+random_count);
    return 0;
}
