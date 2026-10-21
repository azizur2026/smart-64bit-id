#define _GNU_SOURCE
#include <errno.h>
#include <inttypes.h>
#include <sched.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define N          524288U
#define ENGINE_MAX 131072U
#define HT_CAP     (1U << 20)
#define SAMPLES    7U
#define EMPTY_KEY  UINT64_MAX

typedef struct {
    uint64_t key;
    uint32_t engine;
    uint32_t pad;
} HashEntry;

static uint64_t ids[N];
static HashEntry hash_table[HT_CAP];
static volatile uint64_t final_sink;

static void fail(const char *msg) {
    fprintf(stderr, "ERROR: %s\n", msg);
    exit(EXIT_FAILURE);
}

static uint64_t now_ns(void) {
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC_RAW, &ts) != 0) {
        perror("clock_gettime");
        exit(EXIT_FAILURE);
    }
    return (uint64_t)ts.tv_sec * 1000000000ULL +
           (uint64_t)ts.tv_nsec;
}

static void pin_cpu2(void) {
#ifdef __linux__
    cpu_set_t set;
    CPU_ZERO(&set);
    CPU_SET(2, &set);
    if (sched_setaffinity(0, sizeof(set), &set) != 0)
        fprintf(stderr, "# warning=CPU2 affinity failed: %s\n",
                strerror(errno));
#endif
}

static uint64_t hash64(uint64_t x) {
    x ^= x >> 30;
    x *= UINT64_C(0xbf58476d1ce4e5b9);
    x ^= x >> 27;
    x *= UINT64_C(0x94d049bb133111eb);
    x ^= x >> 31;
    return x;
}

/* SMART v1.41 field layout. Reserved bits are zero.
   Version=0, Revision=1, Class=1..8. */
static uint64_t make_id(uint32_t engine, uint32_t local,
                        uint32_t cls, uint32_t role) {
    return (UINT64_C(1) << 59)
         | ((uint64_t)(role & 1U) << 58)
         | ((uint64_t)(cls & 0xFU) << 50)
         | ((uint64_t)(engine & 0x1FFFFFU) << 29)
         | (uint64_t)(local & 0x1FFFFFFFU);
}

static uint32_t extract_engine(uint64_t id) {
    return (uint32_t)((id >> 29) & UINT64_C(0x1FFFFF));
}

/* Deterministic permutation of all indices 0..N-1.
   N is a power of two; the multiplier is odd. */
static void initialize_ids(void) {
    const uint32_t multiplier = 265443U;
    const uint32_t increment = 101390U;

    for (uint32_t i = 0; i < N; ++i) {
        uint32_t p = (uint32_t)(
            ((uint64_t)multiplier * i + increment) & (N - 1U));

        uint32_t engine = p % ENGINE_MAX;
        uint32_t local = p / ENGINE_MAX;
        uint32_t cls = (p % 8U) + 1U;
        uint32_t role = p & 1U;

        ids[i] = make_id(engine, local, cls, role);
    }
}

static uint32_t lookup_engine(uint64_t id) {
    uint32_t slot =
        (uint32_t)(hash64(id) & (HT_CAP - 1U));

    for (uint32_t probes = 0; probes < HT_CAP; ++probes) {
        if (hash_table[slot].key == id)
            return hash_table[slot].engine;

        if (hash_table[slot].key == EMPTY_KEY)
            fail("hash-table lookup miss");

        slot = (slot + 1U) & (HT_CAP - 1U);
    }

    fail("hash-table probe limit exceeded");
    return 0;
}

static void build_hash_table(void) {
    for (uint32_t i = 0; i < HT_CAP; ++i)
        hash_table[i].key = EMPTY_KEY;

    for (uint32_t i = 0; i < N; ++i) {
        uint64_t id = ids[i];
        uint32_t engine = extract_engine(id);
        uint32_t slot =
            (uint32_t)(hash64(id) & (HT_CAP - 1U));

        for (uint32_t probes = 0; probes < HT_CAP; ++probes) {
            if (hash_table[slot].key == EMPTY_KEY) {
                hash_table[slot].key = id;
                hash_table[slot].engine = engine;
                break;
            }

            if (hash_table[slot].key == id)
                fail("duplicate ID");

            slot = (slot + 1U) & (HT_CAP - 1U);

            if (probes == HT_CAP - 1U)
                fail("hash-table insertion probe limit exceeded");
        }
    }
}

typedef uint64_t (*Runner)(uint32_t, uint64_t *);

static uint64_t run_smart(uint32_t shards, uint64_t *checksum) {
    uint64_t sum = 0;

    for (uint32_t i = 0; i < N; ++i) {
        uint32_t engine = extract_engine(ids[i]);
        sum += engine % shards;
    }

    *checksum = sum;
    return sum;
}

/* Alternative routing rule, not semantically equivalent to Engine % shards. */
static uint64_t run_id_modulo(uint32_t shards, uint64_t *checksum) {
    uint64_t sum = 0;

    for (uint32_t i = 0; i < N; ++i)
        sum += ids[i] % shards;

    *checksum = sum;
    return sum;
}

static uint64_t run_hash_lookup(uint32_t shards, uint64_t *checksum) {
    uint64_t sum = 0;

    for (uint32_t i = 0; i < N; ++i) {
        uint32_t engine = lookup_engine(ids[i]);
        sum += engine % shards;
    }

    *checksum = sum;
    return sum;
}

static double time_runner(Runner fn, uint32_t shards,
                          uint64_t *checksum) {
    uint64_t start = now_ns();
    uint64_t result = fn(shards, checksum);
    uint64_t end = now_ns();

    final_sink ^= result;
    return (double)(end - start) / (double)N;
}

static int parse_shards(const char *s, uint32_t *out) {
    if (!s || !*s)
        return 0;

    for (const unsigned char *p = (const unsigned char *)s; *p; ++p)
        if (*p < '0' || *p > '9')
            return 0;

    errno = 0;
    char *end = NULL;
    unsigned long value = strtoul(s, &end, 10);

    if (errno == ERANGE || end == s || *end != '\0' ||
        value < 1 || value > ENGINE_MAX)
        return 0;

    *out = (uint32_t)value;
    return 1;
}

static void validate(uint32_t shards) {
    uint64_t smart_sum = 0, modulo_sum = 0, lookup_sum = 0;

    for (uint32_t i = 0; i < N; ++i) {
        uint64_t id = ids[i];
        uint32_t engine = extract_engine(id);
        uint32_t looked_up = lookup_engine(id);

        if (engine >= ENGINE_MAX)
            fail("Engine out of range");

        if (engine != looked_up)
            fail("lookup Engine differs from extracted Engine");

        smart_sum += engine % shards;
        lookup_sum += looked_up % shards;
        modulo_sum += id % shards;
    }

    if (smart_sum != lookup_sum)
        fail("SMART and lookup routing checksums differ");

    printf("# validation_shards=%u smart_checksum=%" PRIu64
           " id_modulo_checksum=%" PRIu64
           " lookup_checksum=%" PRIu64 "\n",
           shards, smart_sum, modulo_sum, lookup_sum);
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s SHARDS [SHARDS ...]\n", argv[0]);
        return EXIT_FAILURE;
    }

    uint32_t *shards = calloc((size_t)(argc - 1), sizeof(*shards));
    if (!shards)
        fail("cannot allocate shard list");

    for (int i = 1; i < argc; ++i) {
        if (!parse_shards(argv[i], &shards[i - 1])) {
            fprintf(stderr, "ERROR: invalid shard count: %s\n", argv[i]);
            free(shards);
            return EXIT_FAILURE;
        }

        for (int j = 1; j < i; ++j) {
            if (shards[j - 1] == shards[i - 1]) {
                fprintf(stderr, "ERROR: duplicate shard count: %u\n",
                        shards[i - 1]);
                free(shards);
                return EXIT_FAILURE;
            }
        }
    }

    pin_cpu2();
    initialize_ids();
    build_hash_table();

    printf("# benchmark=SMART-v1.41-three-routing-methods-v6\n");
    printf("# ids=%u engine_max=%u samples=%u\n", N, ENGINE_MAX, SAMPLES);
    printf("# hash_table_entries=%u hash_table_bytes=%zu\n",
           HT_CAP, sizeof(hash_table));
    printf("# setup_and_validation_excluded_from_timing=YES\n");
    printf("# id_modulo_is_a_different_routing_rule=YES\n");
    printf("shards,sample,first,smart_ns_per_id,id_modulo_ns_per_id,"
           "hash_lookup_ns_per_id,smart_checksum,id_modulo_checksum,"
           "hash_lookup_checksum\n");

    Runner runners[3] = {
        run_smart, run_id_modulo, run_hash_lookup
    };

    const char *names[3] = {
        "smart", "id_modulo", "hash_lookup"
    };

    for (int s = 0; s < argc - 1; ++s) {
        uint32_t count = shards[s];
        validate(count);

        uint64_t warm_checksum;
        for (unsigned m = 0; m < 3; ++m)
            runners[m](count, &warm_checksum);

        for (uint32_t sample = 0; sample < SAMPLES; ++sample) {
            double times[3];
            uint64_t sums[3];
            unsigned first = sample % 3U;

            for (unsigned k = 0; k < 3; ++k) {
                unsigned method = (first + k) % 3U;
                times[method] =
                    time_runner(runners[method], count, &sums[method]);
            }

            if (sums[0] != sums[2])
                fail("SMART and hash-lookup checksums differ");

            printf("%u,%u,%s,%.4f,%.4f,%.4f,"
                   "%" PRIu64 ",%" PRIu64 ",%" PRIu64 "\n",
                   count, sample + 1U, names[first],
                   times[0], times[1], times[2],
                   sums[0], sums[1], sums[2]);
        }
    }

    fprintf(stderr, "# final_sink=%" PRIu64 "\n", final_sink);
    free(shards);
    return EXIT_SUCCESS;
}
