#undef __WORDSIZE
#define __WORDSIZE 32
#define PT_D1 0
#define PT_D2 1
#define PT_D3 2
#define PT_D4 3
#define PT_D5 4
#define PT_D6 5
#define PT_D7 6
#define PT_A0 7
#define PT_A1 8
#define PT_A2 9
#define PT_A3 10
#define PT_A4 11
#define PT_A5 12
#define PT_A6 13
#define PT_D0 14
#define PT_USP 15
#define PT_ORIG_D0 16
#define PT_SR 17
#define PT_PC 18

#if __mcffpu__
#define PT_FP0 21
#define PT_FP1 23
#define PT_FP2 25
#define PT_FP3 27
#define PT_FP4 29
#define PT_FP5 31
#define PT_FP6 33
#define PT_FP7 35
#else
#define PT_FP0 21
#define PT_FP1 24
#define PT_FP2 27
#define PT_FP3 30
#define PT_FP4 33
#define PT_FP5 36
#define PT_FP6 39
#define PT_FP7 42
#endif

#define PT_FPCR 45
#define PT_FPSR 46
#define PT_FPIAR 47
