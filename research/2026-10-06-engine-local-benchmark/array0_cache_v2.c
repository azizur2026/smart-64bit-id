#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <time.h>

#define ENGINE_BITS 21
#define LOCAL_BITS  29

#define ENGINE_MASK ((1ULL << ENGINE_BITS) - 1)
#define LOCAL_MASK  ((1ULL << LOCAL_BITS) - 1)

typedef struct {
    uint64_t opaque_id;
    uint64_t external_engine_local;
} conventional_record;

static inline uint64_t make_id(uint32_t engine, uint32_t local)
{
    return ((uint64_t)(engine & ENGINE_MASK) << LOCAL_BITS)
           | (uint64_t)(local & LOCAL_MASK);
}

static inline uint32_t extract_engine(uint64_t id)
{
    return (uint32_t)((id >> LOCAL_BITS) & ENGINE_MASK);
}

static inline uint32_t extract_local(uint64_t id)
{
    return (uint32_t)(id & LOCAL_MASK);
}

static uint64_t now_ns(void)
{
    struct timespec ts;

    clock_gettime(CLOCK_MONOTONIC_RAW, &ts);

    return (uint64_t)ts.tv_sec * 1000000000ULL
         + (uint64_t)ts.tv_nsec;
}

static volatile uint64_t sink = 0;

static void fill_data(uint64_t *encoded,
                      conventional_record *conventional,
                      size_t n)
{
    for (size_t i = 0; i < n; i++) {

        uint32_t engine =
            (uint32_t)((i * 17 + 13) & ENGINE_MASK);

        uint32_t local =
            (uint32_t)((i * 31 + 7) & LOCAL_MASK);

        uint64_t packed =
            make_id(engine, local);

        encoded[i] = packed;

        /*
         * Conventional representation:
         *
         * opaque identity is unrelated to Engine+Local.
         * Engine+Local is stored externally.
         */
        conventional[i].opaque_id =
            0x9e3779b97f4a7c15ULL ^ (uint64_t)i;

        conventional[i].external_engine_local =
            packed;
    }
}

static double test_encoded(const uint64_t *encoded,
                           size_t n)
{
    uint64_t s = 0;

    uint64_t start = now_ns();

    for (size_t i = 0; i < n; i++) {

        uint64_t id = encoded[i];

        uint32_t engine =
            extract_engine(id);

        uint32_t local =
            extract_local(id);

        s += (uint64_t)engine +
             (uint64_t)local;
    }

    uint64_t end = now_ns();

    sink += s;

    return (double)(end - start) /
           (double)n;
}

static double test_conventional(
    const conventional_record *records,
    size_t n)
{
    uint64_t s = 0;

    uint64_t start = now_ns();

    for (size_t i = 0; i < n; i++) {

        /*
         * First load the opaque identity.
         */
        uint64_t opaque =
            records[i].opaque_id;

        /*
         * Then load the externally stored
         * Engine+Local information.
         */
        uint64_t metadata =
            records[i].external_engine_local;

        uint32_t engine =
            extract_engine(metadata);

        uint32_t local =
            extract_local(metadata);

        /*
         * Keep both pieces live.
         */
        s += opaque ^
             ((uint64_t)engine +
              (uint64_t)local);
    }

    uint64_t end = now_ns();

    sink += s;

    return (double)(end - start) /
           (double)n;
}

int main(void)
{
    const size_t sizes[] = {
        512,
        4096,
        8192,
        65536,
        262144,
        786432,
        2097152,
        8388608
    };

    const size_t count =
        sizeof(sizes) / sizeof(sizes[0]);

    printf("A0 cache sweep v2\n");
    printf("Intel i5-1035G1\n");
    printf("Scalar benchmark: vectorization disabled\n");
    printf("Encoded record: 8 bytes\n");
    printf("Conventional record: 16 bytes\n\n");

    printf("%12s %14s %14s %14s\n",
           "Records",
           "Encoded",
           "Conventional",
           "Encoded/Conv");

    printf("%12s %14s %14s %14s\n",
           "-------",
           "--------",
           "------------",
           "------------");

    for (size_t x = 0; x < count; x++) {

        size_t n = sizes[x];

        uint64_t *encoded =
            aligned_alloc(64,
                          n * sizeof(uint64_t));

        conventional_record *conventional =
            aligned_alloc(64,
                          n * sizeof(conventional_record));

        if (!encoded || !conventional) {
            fprintf(stderr,
                    "Allocation failed at %zu records\n",
                    n);
            return 1;
        }

        fill_data(encoded,
                  conventional,
                  n);

        /*
         * Warm-up.
         */
        test_encoded(encoded, n);
        test_conventional(conventional, n);

        double encoded_ns = 0.0;
        double conventional_ns = 0.0;

        const int reps = 9;

        for (int r = 0; r < reps; r++) {

            encoded_ns +=
                test_encoded(encoded, n);

            conventional_ns +=
                test_conventional(conventional, n);
        }

        encoded_ns /= reps;
        conventional_ns /= reps;

        double ratio =
            encoded_ns / conventional_ns;

        printf("%12zu %14.4f %14.4f %14.4f\n",
               n,
               encoded_ns,
               conventional_ns,
               ratio);

        free(encoded);
        free(conventional);
    }

    printf("\nFinal sink: %llu\n",
           (unsigned long long)sink);

    return 0;
}
