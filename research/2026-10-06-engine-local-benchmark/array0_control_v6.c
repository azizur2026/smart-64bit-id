#define _GNU_SOURCE

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <sched.h>

#define DEFAULT_RECORDS 262144
#define DEFAULT_REPS    1000
#define CPU_CORE        2

typedef struct {
    uint64_t request_id;
    uint64_t padding;
} request_record_t;

static volatile uint64_t global_sink = 0;

static inline uint32_t extract_engine(uint64_t id)
{
    return (uint32_t)((id >> 29) & 0x1FFFFFULL);
}

static inline uint32_t extract_local(uint64_t id)
{
    return (uint32_t)(id & 0x1FFFFFFFULL);
}

static inline uint64_t make_id(uint32_t engine, uint32_t local)
{
    return ((uint64_t)(engine & 0x1FFFFF) << 29) |
           (uint64_t)(local & 0x1FFFFFFF);
}

static uint64_t now_ns(void)
{
    struct timespec ts;

    clock_gettime(CLOCK_MONOTONIC_RAW, &ts);

    return (uint64_t)ts.tv_sec * 1000000000ULL +
           (uint64_t)ts.tv_nsec;
}

/*
 * A0-6
 *
 * Encoded path:
 *   request -> one load -> extract
 *
 * Two-load control:
 *   request -> one load
 *   external value -> independent second load
 *   extract external value
 *
 * The second load is deliberately independent of request_id.
 * Therefore this is NOT an external lookup simulation.
 */

static uint64_t test_encoded(
        const request_record_t *records,
        size_t n,
        size_t reps)
{
    uint64_t sink = 0;

    for (size_t r = 0; r < reps; ++r) {

        const request_record_t *p = records;
        const request_record_t *end = records + n;

        while (p < end) {

            uint64_t id = p->request_id;

            uint32_t engine = extract_engine(id);
            uint32_t local  = extract_local(id);

            sink += (uint64_t)engine +
                    (uint64_t)local;

            ++p;
        }
    }

    return sink;
}

static uint64_t test_two_loads(
        const request_record_t *records,
        const uint64_t *external,
        size_t n,
        size_t reps)
{
    uint64_t sink = 0;

    for (size_t r = 0; r < reps; ++r) {

        const request_record_t *p = records;
        const uint64_t *e = external;
        const request_record_t *end = records + n;

        while (p < end) {

            /*
             * First load: request.
             */
            uint64_t request_id = p->request_id;

            /*
             * Second load:
             * predetermined sequential external address.
             *
             * IMPORTANT:
             * this address does NOT depend on request_id.
             */
            uint64_t engine_local = *e++;

            uint32_t engine =
                extract_engine(engine_local);

            uint32_t local =
                extract_local(engine_local);

            /*
             * Consume request_id so the first load remains
             * part of the measured work.
             */
            sink += (uint64_t)engine +
                    (uint64_t)local +
                    (request_id & 1ULL);

            ++p;
        }
    }

    return sink;
}

int main(int argc, char **argv)
{
    size_t records = DEFAULT_RECORDS;
    size_t reps = DEFAULT_REPS;

    if (argc > 1)
        records = strtoull(argv[1], NULL, 10);

    if (argc > 2)
        reps = strtoull(argv[2], NULL, 10);

    cpu_set_t cpuset;

    CPU_ZERO(&cpuset);
    CPU_SET(CPU_CORE, &cpuset);

    if (sched_setaffinity(
            0,
            sizeof(cpuset),
            &cpuset) != 0) {
        perror("sched_setaffinity");
        return 1;
    }

    /*
     * Both arrays are deliberately 16-byte/record for the
     * request side.
     */
    request_record_t *records_mem =
        aligned_alloc(
            64,
            records * sizeof(request_record_t));

    uint64_t *external =
        aligned_alloc(
            64,
            records * sizeof(uint64_t));

    if (!records_mem || !external) {
        fprintf(stderr, "allocation failed\n");
        return 1;
    }

    for (size_t i = 0; i < records; ++i) {

        uint32_t engine =
            (uint32_t)(i & 0x1FFFFF);

        uint32_t local =
            (uint32_t)(i & 0x1FFFFFFF);

        uint64_t id =
            make_id(engine, local);

        records_mem[i].request_id = id;
        records_mem[i].padding = 0;

        /*
         * Same logical Engine+Local information,
         * but stored separately.
         */
        external[i] = id;
    }

    /*
     * Warm-up.
     */
    uint64_t warm_encoded =
        test_encoded(records_mem, records, 2);

    uint64_t warm_two_loads =
        test_two_loads(
            records_mem,
            external,
            records,
            2);

    global_sink ^=
        warm_encoded ^ warm_two_loads;

    /*
     * Timed encoded path.
     */
    uint64_t start = now_ns();

    uint64_t sink_encoded =
        test_encoded(
            records_mem,
            records,
            reps);

    uint64_t end = now_ns();

    uint64_t elapsed_encoded =
        end - start;

    /*
     * Timed two-load control.
     */
    start = now_ns();

    uint64_t sink_two_loads =
        test_two_loads(
            records_mem,
            external,
            records,
            reps);

    end = now_ns();

    uint64_t elapsed_two_loads =
        end - start;

    global_sink ^=
        sink_encoded ^ sink_two_loads;

    double total_records =
        (double)records * (double)reps;

    double encoded_ns =
        (double)elapsed_encoded /
        total_records;

    double two_load_ns =
        (double)elapsed_two_loads /
        total_records;

    double ratio =
        encoded_ns / two_load_ns;

    double improvement =
        (1.0 - ratio) * 100.0;

    printf("A0-Control v6\n");
    printf("Intel i5-1035G1 target\n");
    printf("CPU pinned to core: %d\n", CPU_CORE);
    printf("Records: %zu\n", records);
    printf("Repetitions: %zu\n", reps);
    printf("Request record size: %zu bytes\n",
           sizeof(request_record_t));
    printf("External entry size: %zu bytes\n",
           sizeof(uint64_t));
    printf("External load dependency: NONE\n\n");

    printf("Results\n");
    printf("-------\n");

    printf("Encoded array[0]\n");
    printf("  elapsed:       %llu ns\n",
           (unsigned long long)elapsed_encoded);
    printf("  ns/record:     %.6f\n",
           encoded_ns);
    printf("  sink:          %llu\n\n",
           (unsigned long long)sink_encoded);

    printf("Two-load independent control\n");
    printf("  elapsed:       %llu ns\n",
           (unsigned long long)elapsed_two_loads);
    printf("  ns/record:     %.6f\n",
           two_load_ns);
    printf("  sink:          %llu\n\n",
           (unsigned long long)sink_two_loads);

    printf("Encoded / Two-load: %.6f\n",
           ratio);

    printf("Encoded path is %.2f%% faster.\n",
           improvement);

    printf("\nGlobal sink: %llu\n",
           (unsigned long long)global_sink);

    free(records_mem);
    free(external);

    return 0;
}
