/* This optional file only works for GCC on an x86-64.
 */

#define READ_TIMESTAMP(val) do {                        \
    Unsigned _rax, _rdx;                           \
    asm volatile("rdtsc" : "=a"(_rax), "=d"(_rdx)); \
    val = (_rdx << 32) | _rax;                          \
} while (0)

#define READ_TIMESTAMP_UNIT TIMESTAMP_UNIT_TSC

#define RPy_YieldProcessor()  asm("pause")
