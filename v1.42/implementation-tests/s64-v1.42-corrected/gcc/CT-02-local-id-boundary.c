#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>
#include <limits.h>

#define LOCAL_MAX UINT64_C(0x1FFFFFFF)

static int valid_local_id(uint64_t value) {
    return value <= LOCAL_MAX;
}
int main(void) {
    const uint64_t valid[] = {0,1,LOCAL_MAX-1,LOCAL_MAX};
    const uint64_t invalid[] = {LOCAL_MAX+1,UINT32_MAX,UINT64_MAX};
    for (unsigned i=0;i<sizeof(valid)/sizeof(valid[0]);i++) {
        if (!valid_local_id(valid[i])) {
            fprintf(stderr,"CT-02 FAIL: valid value rejected: %" PRIu64 "\n",valid[i]);
            return 1;
        }
        uint64_t encoded=valid[i];
        uint64_t decoded=encoded & LOCAL_MAX;
        if (decoded != valid[i]) {
            fprintf(stderr,"CT-02 FAIL: round trip mismatch\n"); return 1;
        }
    }
    for (unsigned i=0;i<sizeof(invalid)/sizeof(invalid[0]);i++) {
        if (valid_local_id(invalid[i])) {
            fprintf(stderr,"CT-02 FAIL: out-of-range value accepted: %" PRIu64 "\n",invalid[i]);
            return 1;
        }
    }
    printf("CT-02: PASS\nValid boundary values: 4\nOut-of-range values rejected: 3\n");
    return 0;
}
