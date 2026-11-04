#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>

#define CLASS_MASK    (UINT64_C(0x0F) << 50)
#define RESERVED_MASK (UINT64_C(0x0F) << 54)
#define ROLE_MASK     (UINT64_C(1) << 58)
#define REVISION_MASK (UINT64_C(0x0F) << 59)
#define VERSION_MASK  (UINT64_C(1) << 63)

static int valid(uint64_t id) {
    unsigned c=(unsigned)((id & CLASS_MASK)>>50);
    unsigned version=(unsigned)((id & VERSION_MASK)>>63);
    return c>=1 && c<=8 && (id & RESERVED_MASK)==0 && version==1;
}
int main(void) {
    unsigned valid_count=0, invalid_count=0;
    for (unsigned c=1;c<=8;c++)
    for (unsigned role=0;role<=1;role++)
    for (unsigned revision=0;revision<=15;revision++) {
        uint64_t id=((uint64_t)c<<50)|((uint64_t)role<<58)|
                    ((uint64_t)revision<<59)|VERSION_MASK;
        if (!valid(id)) { fprintf(stderr,"CT-05 FAIL: valid profile rejected\n"); return 1; }
        valid_count++;
    }
    const uint64_t invalid[] = {
        (UINT64_C(0)<<50)|VERSION_MASK,
        (UINT64_C(9)<<50)|VERSION_MASK,
        (UINT64_C(1)<<54)|VERSION_MASK,
        0
    };
    for (unsigned i=0;i<sizeof(invalid)/sizeof(invalid[0]);i++) {
        if (valid(invalid[i])) { fprintf(stderr,"CT-05 FAIL: invalid profile accepted\n"); return 1; }
        invalid_count++;
    }
    /* Role is one bit and Revision is four bits: all representable values
       are valid encodings unless the S64 specification adds semantic rules. */
    printf("CT-05: PASS\nValid profiles: %u\nInvalid profiles rejected: %u\n",valid_count,invalid_count);
    printf("Role patterns covered: 2; Revision patterns covered: 16\n");
    return 0;
}
