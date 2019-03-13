#if ((__ARM_ARCH_6K__ || __ARM_ARCH_6KZ__ || __ARM_ARCH_6ZK__) && !__thumb__) \
 || __ARM_ARCH_7A__ || __ARM_ARCH_7R__ || __ARM_ARCH >= 7

static inline pthread_t __pthread_self()
{
	char *p;
	__asm__ ( "mrc p15,0,%0,c13,c0,3" : "=r"(p) );
	return (void *)(p-sizeof(struct pthread));
}

#else

#if __ARM_ARCH_4__ || __ARM_ARCH_4T__ || __ARM_ARCH == 4
#define BLX "mov lr,pc\n\tbx"
#else
#define BLX "blx"
#endif

static inline pthread_t __pthread_self()
{
	extern hidden uintptr_t __a_gettp_ptr;
	register uintptr_t p __asm__("r0");
	__asm__ ( BLX " %1" : "=r"(p) : "r"(__a_gettp_ptr) : "cc", "lr" );
	return (void *)(p-sizeof(struct pthread));
}

#endif

#define TLS_ABOVE_TP
#define GAP_ABOVE_TP 8
#define TP_ADJ(p) ((char *)(p) + sizeof(struct pthread))

#define MC_PC arm_pc
