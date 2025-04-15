// Hexagon supports variant 2 TLS.
static inline uintptr_t __get_tp()
{
  uintptr_t tp;
  __asm__ ( "%0 = ugp" : "=r"(tp));
  return tp;
}

#define TP_ADJ(p) (p)

#define CANCEL_REG_IP 43

#define MC_PC pc
