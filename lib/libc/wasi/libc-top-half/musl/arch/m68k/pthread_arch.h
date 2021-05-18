static inline uintptr_t __get_tp()
{
	return __syscall(SYS_get_thread_area);
}

#define TLS_ABOVE_TP
#define GAP_ABOVE_TP 0

#define TP_OFFSET 0x7000
#define DTP_OFFSET 0x8000

#define MC_PC gregs[R_PC]
