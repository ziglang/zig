
#define __SYSCALL_LL_E(x) \
((union { long long ll; long l[2]; }){ .ll = x }).l[0], \
((union { long long ll; long l[2]; }){ .ll = x }).l[1]
#define __SYSCALL_LL_O(x) 0, __SYSCALL_LL_E((x))

#define __asm_syscall(...) do { \
    __asm__ __volatile__ ( "trap0(#1)" \
    : "=r"(r0) : __VA_ARGS__ : "memory"); \
    return r0; \
    } while (0)

static inline long __syscall0(long n)
{
  register long r6 __asm__("r6") = n;
  register long r0 __asm__("r0");
  __asm_syscall("r"(r6));
}

static inline long __syscall1(long n, long a)
{
  register long r6 __asm__("r6") = n;
  register long r0 __asm__("r0") = a;
  __asm_syscall("r"(r6), "0"(r0));
}

static inline long __syscall2(long n, long a, long b)
{
  register long r6 __asm__("r6") = n;
  register long r0 __asm__("r0") = a;
  register long r1 __asm__("r1") = b;
  __asm_syscall("r"(r6), "0"(r0), "r"(r1));
}

static inline long __syscall3(long n, long a, long b, long c)
{
  register long r6 __asm__("r6") = n;
  register long r0 __asm__("r0") = a;
  register long r1 __asm__("r1") = b;
  register long r2 __asm__("r2") = c;
  __asm_syscall("r"(r6), "0"(r0), "r"(r1), "r"(r2));
}

static inline long __syscall4(long n, long a, long b, long c, long d)
{
  register long r6 __asm__("r6") = n;
  register long r0 __asm__("r0") = a;
  register long r1 __asm__("r1") = b;
  register long r2 __asm__("r2") = c;
  register long r3 __asm__("r3") = d;
  __asm_syscall("r"(r6), "0"(r0), "r"(r1), "r"(r2), "r"(r3));
}

static inline long __syscall5(long n, long a, long b, long c, long d, long e)
{
  register long r6 __asm__("r6") = n;
  register long r0 __asm__("r0") = a;
  register long r1 __asm__("r1") = b;
  register long r2 __asm__("r2") = c;
  register long r3 __asm__("r3") = d;
  register long r4 __asm__("r4") = e;
  __asm_syscall("r"(r6), "0"(r0), "r"(r1), "r"(r2), "r"(r3), "r"(r4));
}

static inline long __syscall6(long n, long a, long b, long c, long d, long e,
                              long f)
{
  register long r6 __asm__("r6") = n;
  register long r0 __asm__("r0") = a;
  register long r1 __asm__("r1") = b;
  register long r2 __asm__("r2") = c;
  register long r3 __asm__("r3") = d;
  register long r4 __asm__("r4") = e;
  register long r5 __asm__("r5") = f;
  __asm_syscall("r"(r6), "0"(r0), "r"(r1), "r"(r2), "r"(r3), "r"(r4), "r"(r5));
}

#define SYSCALL_FADVISE_6_ARG
