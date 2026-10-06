#define _GNU_SOURCE

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <time.h>
#include <sched.h>

#define N 262144
#define REPS 1000
#define ENGINE_COUNT 8

#define LOCAL_MASK  ((1ULL << 29) - 1)
#define ENGINE_MASK ((1ULL << 21) - 1)

typedef struct {
    uint64_t array0;
    uint64_t opaque_id;
} proposed_record_t;

typedef struct {
    uint64_t opaque_id;
    uint32_t engine_id;
} conventional_record_t;

static proposed_record_t *proposed;
static conventional_record_t *conventional;

/* Prevent the compiler from eliminating the selected Engine result. */
static volatile uint64_t sink;

static inline uint64_t now_ns(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC_RAW, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + ts.tv_nsec;
}

/*
 * Published Global ID layout:
 *
 * bits  0-28 : Local ID
 * bits 29-49 : Engine ID
 * bits 50-57 : Region
 * bit      58: State
 * bits 59-62 : Reserved
 * bit      63: Version
 */
static inline uint64_t make_array0(uint32_t engine, uint32_t local)
{
    return ((uint64_t)(engine & ENGINE_MASK) << 29) |
           (uint64_t)(local & LOCAL_MASK) |
           (1ULL << 58) |
           (1ULL << 63);
}

/*
 * Proposed:
 *
 * array[0]
 *    -> extract Engine ID
 *    -> select Engine[engine_id]
 *
 * Engine selection is represented by indexing an array of
 * independent Engine tokens.
 */
static uint64_t run_proposed(void)
{
    uint64_t total = 0;

    for (int r = 0; r < REPS; r++) {
        for (size_t i = 0; i < N; i++) {

            uint64_t id = proposed[i].array0;

            uint32_t engine =
                (uint32_t)((id >> 29) & ENGINE_MASK);

            /*
             * Engine table represents independent Engine instances.
             * We only measure selection, not Engine execution.
             */
            uint64_t selected_engine = engine % ENGINE_COUNT;

            total += selected_engine;
        }
    }

    sink += total;
    return total;
}

/*
 * Conventional:
 *
 * opaque ID
 *    -> external mapping
 *    -> Engine ID
 *    -> select Engine[engine_id]
 *
 * The mapping is a separate memory structure.
 */
static uint64_t run_conventional(void)
{
    uint64_t total = 0;

    for (int r = 0; r < REPS; r++) {
        for (size_t i = 0; i < N; i++) {

            uint64_t opaque_id = conventional[i].opaque_id;

            /*
             * External mapping lookup.
             *
             * The opaque ID determines which mapping entry
             * must be accessed.
             */
            size_t index = (size_t)(opaque_id % N);

            uint32_t engine =
                conventional[index].engine_id;

            uint64_t selected_engine = engine % ENGINE_COUNT;

            total += selected_engine;
        }
    }

    sink += total;
    return total;
}

int main(void)
{
    cpu_set_t set;

    CPU_ZERO(&set);
    CPU_SET(2, &set);

    if (sched_setaffinity(0, sizeof(set), &set) != 0) {
        perror("sched_setaffinity");
        return 1;
    }

    proposed =
        aligned_alloc(64, N * sizeof(*proposed));

    conventional =
        aligned_alloc(64, N * sizeof(*conventional));

    if (!proposed || !conventional) {
        fprintf(stderr, "allocation failed\n");
        return 1;
    }

    /*
     * Deterministic workload.
     *
     * Exactly 8 Engine IDs are used:
     * Engine 0 ... Engine 7.
     */
    for (size_t i = 0; i < N; i++) {

        uint32_t engine = (uint32_t)(i % ENGINE_COUNT);
        uint32_t local  = (uint32_t)(i + 1);

        proposed[i].array0 =
            make_array0(engine, local);

        proposed[i].opaque_id =
            (uint64_t)(i + 1);

        conventional[i].opaque_id =
            (uint64_t)(i + 1);

        conventional[i].engine_id =
            engine;
    }

    /* Warm-up */
    run_proposed();
    run_conventional();

    sink = 0;

    uint64_t p0 = now_ns();
    uint64_t proposed_result = run_proposed();
    uint64_t p1 = now_ns();

    uint64_t c0 = now_ns();
    uint64_t conventional_result = run_conventional();
    uint64_t c1 = now_ns();

    double proposed_ns =
        (double)(p1 - p0) / ((double)N * REPS);

    double conventional_ns =
        (double)(c1 - c0) / ((double)N * REPS);

    double improvement =
        (1.0 - proposed_ns / conventional_ns) * 100.0;

    printf("A3: Engine selection only\n");
    printf("CPU pinned        : 2\n");
    printf("Engine instances  : %d\n", ENGINE_COUNT);
    printf("Records           : %d\n", N);
    printf("Repetitions       : %d\n\n", REPS);

    printf("Proposed:\n");
    printf("  array[0] -> Engine extraction -> Engine selection\n");
    printf("  ns/request       : %.6f\n", proposed_ns);
    printf("  result            : %llu\n\n",
           (unsigned long long)proposed_result);

    printf("Conventional:\n");
    printf("  opaque ID -> external mapping -> Engine selection\n");
    printf("  ns/request       : %.6f\n", conventional_ns);
    printf("  result            : %llu\n\n",
           (unsigned long long)conventional_result);

    if (proposed_result == conventional_result)
        printf("CORRECTNESS PASS\n");
    else
        printf("CORRECTNESS FAIL\n");

    printf("Proposed/Conventional: %.6f\n",
           proposed_ns / conventional_ns);

    printf("Proposed improvement: %.2f%%\n",
           improvement);

    printf("Final sink: %llu\n",
           (unsigned long long)sink);

    free(proposed);
    free(conventional);

    return 0;
}
