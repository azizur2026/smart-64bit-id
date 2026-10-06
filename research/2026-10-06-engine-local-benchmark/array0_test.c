#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define LOCAL_BITS  29
#define ENGINE_BITS 21

#define LOCAL_MASK  ((1ULL << LOCAL_BITS) - 1ULL)
#define ENGINE_MASK ((1ULL << ENGINE_BITS) - 1ULL)

static inline uint32_t extract_local(uint64_t id)
{
    return (uint32_t)(id & LOCAL_MASK);
}

static inline uint32_t extract_engine(uint64_t id)
{
    return (uint32_t)((id >> LOCAL_BITS) & ENGINE_MASK);
}

static uint64_t make_id(uint32_t engine, uint32_t local)
{
    return ((uint64_t)(engine & ENGINE_MASK) << LOCAL_BITS)
           | (uint64_t)(local & LOCAL_MASK);
}

int main(void)
{
    const size_t count = 10000000;

    uint64_t *ids = malloc(count * sizeof(uint64_t));

    if (ids == NULL) {
        perror("malloc");
        return 1;
    }

    /*
     * Runtime-generated IDs.
     * The compiler cannot know these values at compile time.
     */
    srand((unsigned)time(NULL));

    for (size_t i = 0; i < count; i++) {
        uint32_t engine = (uint32_t)(rand() & ENGINE_MASK);
        uint32_t local  = (uint32_t)(rand() & LOCAL_MASK);

        ids[i] = make_id(engine, local);
    }

    volatile uint64_t sink = 0;

    struct timespec start, end;

    clock_gettime(CLOCK_MONOTONIC_RAW, &start);

    for (size_t i = 0; i < count; i++) {
        uint32_t engine = extract_engine(ids[i]);
        uint32_t local  = extract_local(ids[i]);

        sink += engine;
        sink += local;
    }

    clock_gettime(CLOCK_MONOTONIC_RAW, &end);

    uint64_t elapsed_ns =
        (uint64_t)(end.tv_sec - start.tv_sec) * 1000000000ULL +
        (uint64_t)(end.tv_nsec - start.tv_nsec);

    printf("IDs               : %zu\n", count);
    printf("Elapsed           : %llu ns\n",
           (unsigned long long)elapsed_ns);
    printf("ns/ID             : %.4f\n",
           (double)elapsed_ns / (double)count);
    printf("Final sink        : %llu\n",
           (unsigned long long)sink);

    free(ids);

    return 0;
}
