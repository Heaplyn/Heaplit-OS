/* ============================================================================
 * Heaplit OS - Canonical Freestanding Types Header
 * Ring Placement: rings/ring_1/ring_1/include/heaplit/types.h (Ring 1)
 * Description: Standard integer definitions, NULL, size_t, and freestanding math prototypes.
 * ============================================================================ */

#ifndef HEAPLIT_TYPES_H
#define HEAPLIT_TYPES_H

#include <stdint.h>
#include <stddef.h>

typedef uint64_t phys_addr_t;
typedef uint64_t virt_addr_t;

// Freestanding square root float implementation
static inline float sqrtf(float number) {
    long i;
    float x2, y;
    const float threehalfs = 1.5F;

    if (number <= 0.0F) return 0.0F;

    x2 = number * 0.5F;
    y  = number;
    i  = * ( long * ) &y;
    i  = 0x5f3759df - ( i >> 1 );
    y  = * ( float * ) &i;
    y  = y * ( threehalfs - ( x2 * y * y ) );
    y  = y * ( threehalfs - ( x2 * y * y ) );

    return 1.0F / y;
}

#endif // HEAPLIT_TYPES_H
