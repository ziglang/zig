/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#define SHADOW_IRQL_IMPLEMENTATION 1

#define PS0 0x0001
#define PS1 0x0002
#define PS2 0x0004
#define PS3 0x0008
#define PS4 0x0010
#define PS5 0x0020

#define PRP 0x0080

#define PT0 0x0040
#define PT1 0x0100
#define PT2 0x0200
#define PT3 0x0400
#define PT4 0x0800
#define PT5 0x1000
#define PT6 0x2000
#define PT7 0x4000
#define PT8 0x8000

#define NOM_BS0 0x0001
#define NOM_BS1 0x0002
#define NOM_BS2 0x0004
#define NOM_BS3 0x0008
#define NOM_BS4 0x0010
#define NOM_BS5 0x0020

#define NOM_BRP 0x0080

#define NOM_BT0 0x0040
#define NOM_BT1 0x0100
#define NOM_BT2 0x0200
#define NOM_BT3 0x0400
#define NOM_BT4 0x0800
#define NOM_BT5 0x1000
#define NOM_BT6 0x2000
#define NOM_BT7 0x4000
#define NOM_BT8 0x8000

#define PSR_MBZ4 0
#define PSR_BE 1
#define PSR_UP 2
#define PSR_AC 3
#define PSR_MFL 4
#define PSR_MFH 5

#define PSR_MBZ0 6
#define PSR_MBZ0_V 0x7fll

#define PSR_IC 13
#define PSR_I 14
#define PSR_PK 15
#define PSR_MBZ1 16
#define PSR_MBZ1_V 0x1ll
#define PSR_DT 17
#define PSR_DFL 18
#define PSR_DFH 19
#define PSR_SP 20
#define PSR_PP 21
#define PSR_DI 22
#define PSR_SI 23
#define PSR_DB 24
#define PSR_LP 25
#define PSR_TB 26
#define PSR_RT 27

#define PSR_MBZ2 28
#define PSR_MBZ2_V 0xfll

#define PSR_CPL 32
#define PSR_CPL_LEN 2
#define PSR_IS 34
#define PSR_MC 35
#define PSR_IT 36
#define PSR_ID 37
#define PSR_DA 38
#define PSR_DD 39
#define PSR_SS 40
#define PSR_RI 41
#define PSR_RI_LEN 2
#define PSR_ED 43
#define PSR_BN 44
#define PSR_IA 45

#define PSR_MBZ3 46
#define PSR_MBZ3_V 0x3ffffll

#define PL_KERNEL 0
#define PL_USER 3

#define IS_EM 0
#define IS_IA 1

#define FPSR_VD 0
#define FPSR_DD 1
#define FPSR_ZD 2
#define FPSR_OD 3
#define FPSR_UD 4
#define FPSR_ID 5

#define FPSR_FTZ0 6
#define FPSR_WRE0 7
#define FPSR_PC0 8
#define FPSR_RC0 10
#define FPSR_TD0 12

#define FPSR_V0 13
#define FPSR_D0 14
#define FPSR_Z0 15
#define FPSR_O0 16
#define FPSR_U0 17
#define FPSR_I0 18

#define FPSR_FTZ1 19
#define FPSR_WRE1 20
#define FPSR_PC1 21
#define FPSR_RC1 23
#define FPSR_TD1 25

#define FPSR_V1 26
#define FPSR_D1 27
#define FPSR_Z1 28
#define FPSR_O1 29
#define FPSR_U1 30
#define FPSR_I1 31

#define FPSR_FTZ2 32
#define FPSR_WRE2 33
#define FPSR_PC2 34
#define FPSR_RC2 36
#define FPSR_TD2 38

#define FPSR_V2 39
#define FPSR_D2 40
#define FPSR_Z2 41
#define FPSR_O2 42
#define FPSR_U2 43
#define FPSR_I2 44

#define FPSR_FTZ3 45
#define FPSR_WRE3 46
#define FPSR_PC3 47
#define FPSR_RC3 49
#define FPSR_TD3 51

#define FPSR_V3 52
#define FPSR_D3 53
#define FPSR_Z3 54
#define FPSR_O3 55
#define FPSR_U3 56
#define FPSR_I3 57

#define FPSR_MBZ0 58
#define FPSR_MBZ0_V 0x3fll

#define FPSR_FOR_KERNEL 0x9804C0270033F

#define TPR_MIC 4
#define TPR_MIC_LEN 4

#define TPR_MMI 16

#define TPR_IRQL_SHIFT TPR_MIC

#define VECTOR_IRQL_SHIFT TPR_IRQL_SHIFT

#define ISR_CODE 0
#define ISR_CODE_LEN 16
#define ISR_CODE_MASK 0xFFFF
#define ISR_NA_CODE_MASK 0xF
#define ISR_IA_VECTOR 16
#define ISR_IA_VECTOR_LEN 8

#define ISR_MBZ0 24
#define ISR_MBZ0_V 0xff
#define ISR_X 32
#define ISR_W 33
#define ISR_R 34
#define ISR_NA 35
#define ISR_SP 36
#define ISR_RS 37
#define ISR_IR 38
#define ISR_NI 39

#define ISR_MBZ1 40
#define ISR_EI 41
#define ISR_ED 43

#define ISR_MBZ2 44
#define ISR_MBZ2_V 0xfffff

#define ISR_TPA 0
#define ISR_FC 1
#define ISR_PROBE 2
#define ISR_TAK 3
#define ISR_LFETCH 4
#define ISR_PROBE_FAULT 5

#define ISR_ILLEGAL_OP 0
#define ISR_PRIV_OP 1
#define ISR_PRIV_REG 2
#define ISR_RESVD_REG 3
#define ISR_ILLEGAL_ISA 4
#define ISR_ILLEGAL_HAZARD 8

#define ISR_NAT_REG 1
#define ISR_NAT_PAGE 2

#define ISR_FP_TRAP 0

#define ISR_LP_TRAP 1

#define ISR_TB_TRAP 2

#define ISR_SS_TRAP 3

#define ISR_UI_TRAP 4

#define DCR_PP 0
#define DCR_BE 1
#define DCR_LC 2

#define DCR_DM 8
#define DCR_DP 9
#define DCR_DK 10
#define DCR_DX 11
#define DCR_DR 12
#define DCR_DA 13
#define DCR_DD 14
#define DCR_DEFER_ALL 0x7f00

#define DCR_MBZ1 2
#define DCR_MBZ1_V 0xffffffffffffll

#define RSC_MODE 0
#define RSC_PL 2
#define RSC_BE 4

#define RSC_MBZ0 5
#define RSC_MBZ0_V 0x3ff
#define RSC_LOADRS 16
#define RSC_LOADRS_LEN 14

#define RSC_MBZ1 30
#define RSC_MBZ1_LEN 34
#define RSC_MBZ1_V 0x3ffffffffll

#define RSC_MODE_LY (0x0)

#define RSC_MODE_SI (0x1)

#define RSC_MODE_LI (0x2)

#define RSC_MODE_EA (0x3)

#define RSC_BE_LITTLE 0
#define RSC_BE_BIG 1

#define RSC_KERNEL ((RSC_MODE_EA<<RSC_MODE) | (RSC_BE_LITTLE<<RSC_BE))

#define RSC_KERNEL_DISABLED ((RSC_MODE_LY<<RSC_MODE) | (RSC_BE_LITTLE<<RSC_BE))

#define IFS_IFM 0
#define IFS_IFM_LEN 38
#define IFS_MBZ0 38
#define IFS_MBZ0_V 0x1ffffffll
#define IFS_V 63
#define IFS_V_LEN 1

#define IFS_VALID 1

#define PFS_PPL 62
#define PFS_PPL_LEN PSR_CPL_LEN
#define PFS_EC_SHIFT 52
#define PFS_EC_SIZE 6
#define PFS_EC_MASK 0x3F
#define PFS_SIZE_SHIFT 7
#define PFS_SIZE_MASK 0x7F
#define NAT_BITS_PER_RNAT_REG 63
#define RNAT_ALIGNMENT (NAT_BITS_PER_RNAT_REG << 3)

#define RR_VE 0
#define RR_MBZ0 1
#define RR_PS 2
#define RR_PS_LEN 6
#define RR_RID 8
#define RR_RID_LEN 24
#define RR_MBZ1 32

#define RR_INDEX 61
#define RR_INDEX_LEN 3

#define RR_PS_VE ((PAGE_SHIFT<<RR_PS) | (1<<RR_VE))

#define NT_RR_SIZE 4

#define RR_SIZE 8

#define PKR_V 0
#define PKR_WD 1
#define PKR_RD 2
#define PKR_XD 3
#define PKR_MBZ0 4
#define PKR_KEY 8
#define PKR_KEY_LEN 24
#define PKR_MBZ1 32

#define PKR_VALID (1<<PKR_V)

#define PKRNUM 16

#define ITIR_RV0 0
#define ITIR_PS 2
#define ITIR_KEY 8
#define ITIR_RV1 32

#define IDTR_MBZ0 0
#define IDTR_PS 2
#define IDTR_KEY 8
#define IDTR_MBZ1 32
#define IDTR_IGN0 48
#define IDTR_PPN 56
#define IDTR_MBZ2 63

#define IITR_MBZ0 IDTR_MBZ0
#define IITR_PS IDTR_PS
#define IITR_KEY IDTR_KEY
#define IITR_MBZ1 IDTR_MBZ1
#define IITR_IGN0 IDTR_IGN0
#define IITR_PPN IDTR_PPN
#define IITR_MBZ2 IDTR_MBZ2

#define IITR_PPN_MASK 0x7FFF000000000000
#define IITR_ATTRIBUTE_PPN_MASK 0x0003FFFFFFFFF000

#define TR_P 0
#define TR_RV0 1
#define TR_MA 2
#define TR_A 5
#define TR_D 6
#define TR_PL 7
#define TR_AR 9
#define TR_PPN 13
#define TR_RV1 50
#define TR_ED 52
#define TR_IGN0 53

#define TR_VALUE(ed,ppn,ar,pl,d,a,ma,p) ((ed << TR_ED) | (ppn & IITR_ATTRIBUTE_PPN_MASK) | (ar << TR_AR) | (pl << TR_PL) | (d << TR_D) | (a << TR_A) | (ma << TR_MA) | (p << TR_P))

#define ITIR_VALUE(key,ps) ((ps << ITIR_PS) | (key << ITIR_KEY))

#define PS_4K 0xC
#define PS_8K 0xD
#define PS_16K 0xE
#define PS_64K 0x10
#define PS_256K 0x12
#define PS_1M 0x14
#define PS_4M 0x16
#define PS_16M 0x18
#define PS_64M 0x1a
#define PS_256M 0x1c

#define NUMBER_OF_DEBUG_REGISTER_PAIRS 4

#define DR_MASK 0
#define DR_MASK_LEN 56
#define DR_PLM0 56
#define DR_PLM1 57
#define DR_PLM2 58
#define DR_PLM3 59
#define DR_IG 60
#define DR_RW 62
#define DR_RW_LEN 2
#define DR_X 63

#define NUMBER_OF_PERFMON_REGISTER_PAIRS 4

#define MASK_IA64(bp,value) (value << bp)

#define APC_VECTOR APC_LEVEL << VECTOR_IRQL_SHIFT
#define DISPATCH_VECTOR DISPATCH_LEVEL << VECTOR_IRQL_SHIFT

#define OFFSET_VECTOR_BREAK 0x2800
#define OFFSET_VECTOR_EXT_INTERRUPT 0x2c00
#define OFFSET_VECTOR_EXC_GENERAL 0x4400

#define PAGEMASK_4KB 0x0
#define PAGEMASK_16KB 0x3
#define PAGEMASK_64KB 0xf
#define PAGEMASK_256KB 0x3f
#define PAGEMASK_1MB 0xff
#define PAGEMASK_4MB 0x3ff
#define PAGEMASK_16MB 0xfff

#define PRIMARY_CACHE_INVALID 0x0
#define PRIMARY_CACHE_SHARED 0x1
#define PRIMARY_CACHE_CLEAN_EXCLUSIVE 0x2
#define PRIMARY_CACHE_DIRTY_EXCLUSIVE 0x3

#define PS_SHIFT 2
#define PS_LEN 6
#define PTE_VALID_MASK 1
#define PTE_ACCESS_MASK 0x20
#define PTE_NOCACHE 0x10
#define PTE_CACHE_SHIFT 2
#define PTE_CACHE_LEN 3
#define PTE_LARGE_PAGE 54
#define PTE_PFN_SHIFT 8
#define PTE_PFN_LEN 24
#define PTE_ATTR_SHIFT 1
#define PTE_ATTR_LEN 5
#define PTE_PS 55
#define PTE_OFFSET_LEN 10
#define PDE_OFFSET_LEN 10
#define VFN_LEN 19
#define VFN_LEN64 24
#define TB_USER_MASK 0x180
#define PTE_DIRTY_MASK 0x40
#define PTE_WRITE_MASK 0x400
#define PTE_EXECUTE_MASK 0x200
#define PTE_CACHE_MASK 0x0
#define PTE_EXC_DEFER 0x10000000000000

#define VALID_KERNEL_PTE (PTE_VALID_MASK|PTE_ACCESS_MASK|PTE_WRITE_MASK|PTE_CACHE_MASK|PTE_DIRTY_MASK)
#define VALID_KERNEL_EXECUTE_PTE (PTE_VALID_MASK|PTE_ACCESS_MASK|PTE_EXECUTE_MASK|PTE_WRITE_MASK|PTE_CACHE_MASK|PTE_DIRTY_MASK|PTE_EXC_DEFER)
#define PTE_VALID 0
#define PTE_ACCESS 5
#define PTE_OWNER 7
#define PTE_WRITE 10
#define PTE_LP_CACHE_SHIFT 53
#define ATE_INDIRECT 62
#define ATE_MASK 0xFFFFFFFFFFFFF9DE
#define ATE_MASK0 0x621
#define PAGE4K_SHIFT 12
#define ALT4KB_BASE 0x6FC00000000
#define ALT4KB_END 0x6FC00800000

#define VRN_SHIFT 61
#define KSEG3_VRN 4
#define KSEG4_VRN 5
#define MAX_PHYSICAL_SHIFT 44

#define DISABLE_TAR_FIX 0
#define DISABLE_BTB_FIX 1
#define DISABLE_DATA_BP_FIX 2
#define DISABLE_DET_STALL_FIX 3
#define ENABLE_FULL_DISPERSAL 4
#define ENABLE_TB_BROADCAST 5
#define DISABLE_CPL_FIX 6
#define ENABLE_POWER_MANAGEMENT 7
#define DISABLE_IA32BR_FIX 8
#define DISABLE_L1_BYPASS 9
#define DISABLE_VHPT_WALKER 10
#define DISABLE_IA32RSB_FIX 11
#define DISABLE_INTERRUPTION_LOG 13
#define DISABLE_UNSAFE_FILL 14
#define DISABLE_STORE_UPDATE 15
#define ENABLE_HISTORY_BUFFER 16

#define BL_4M 0x00400000
#define BL_16M 0x01000000
#define BL_20M 0x01400000
#define BL_24M 0x01800000
#define BL_28M 0x01C00000
#define BL_32M 0x02000000
#define BL_36M 0x02400000
#define BL_40M 0x02800000
#define BL_48M 0x03000000
#define BL_64M 0x04000000
#define BL_80M 0x05000000
#define BL_128M 0x08000000

#define TR_INFO_TABLE_SIZE 10

#define BL_SAL_INDEX 0
#define BL_KERNEL_INDEX 1
#define BL_DRIVER0_INDEX 2
#define BL_DRIVER1_INDEX 3
#define BL_DECOMPRESS_INDEX 4
#define BL_IO_PORT_INDEX 5
#define BL_PAL_INDEX 6
#define BL_LOADER_INDEX 7

#define DTR_KIPCR_INDEX 0
#define DTR_KERNEL_INDEX 1

#define DTR_DRIVER0_INDEX 2
#define DTR_KTBASE_INDEX 2

#define DTR_DRIVER1_INDEX 3
#define DTR_UTBASE_INDEX 3
#define DTR_VIDEO_INDEX 3

#define DTR_KIPCR2_INDEX 4
#define DTR_STBASE_INDEX 4

#define DTR_IO_PORT_INDEX 5

#define DTR_KTBASE_INDEX_TMP 6
#define DTR_HAL_INDEX 6
#define DTR_PAL_INDEX 6

#define DTR_UTBASE_INDEX_TMP 7
#define DTR_LOADER_INDEX 7
#define DTR_UTBASE_INDEX_TMP 7

#define ITR_EPC_INDEX 0

#define ITR_KERNEL_INDEX 1

#define ITR_DRIVER0_INDEX 2

#define ITR_DRIVER1_INDEX 3

#define ITR_HAL_INDEX 4
#define ITR_PAL_INDEX 4

#define ITR_LOADER_INDEX 7

#define MEM_4K 0x1000
#define MEM_8K 0x2000
#define MEM_16K 0x4000
#define MEM_64K 0x10000
#define MEM_256K 0x40000
#define MEM_1M 0x100000
#define MEM_4M 0x400000
#define MEM_16M 0x1000000
#define MEM_64M 0x4000000
#define MEM_256M 0x10000000

#define MEM_SIZE_TO_PS(MemSize,TrPageSize) if (MemSize <= MEM_4K) { TrPageSize = PS_4K; } else if (MemSize <= MEM_8K) { TrPageSize = PS_8K; } else if (MemSize <= MEM_16K) { TrPageSize = PS_16K; } else if (MemSize <= MEM_64K) { TrPageSize = PS_64K; } else if (MemSize <= MEM_256K) { TrPageSize = PS_256K; } else if (MemSize <= MEM_1M) { TrPageSize = PS_1M; } else if (MemSize <= MEM_4M) { TrPageSize = PS_4M; } else if (MemSize <= MEM_16M) { TrPageSize = PS_16M; } else if (MemSize <= MEM_64M) { TrPageSize = PS_64M; } else if (MemSize <= MEM_256M) { TrPageSize = PS_256M; }

#define NUMBER_OF_FWP_ENTRIES 8

#define KERNEL_BASE KADDRESS_BASE+0x80000000
#define KERNEL_BASE2 KADDRESS_BASE+0x81000000

#define PDR_TR_INITIAL TR_VALUE(0,0,2,0,1,1,0,1)
#define KIPCR_TR_INITIAL TR_VALUE(0,0,2,0,1,1,0,1)
#define USPCR_TR_INITIAL TR_VALUE(0,0,0,3,1,1,0,1)

#define PTA_INITIAL 0x001

#define DCR_INITIAL 0x0000000000007e05

#define PSRL_INITIAL 0x086a2008

#define USER_PSR_INITIAL 0x00001013082a6008ll

#define USER_FPSR_INITIAL 0x9804C0270033F

#define USER_DCR_INITIAL 0x0000000000007f05ll

#define USER_RSC_INITIAL ((RSC_MODE_LY<<RSC_MODE) | (RSC_BE_LITTLE<<RSC_BE) | (0x3<<RSC_PL))

#define USER_CODE_DESCRIPTOR 0xCFBFFFFF00000000
#define USER_DATA_DESCRIPTOR 0xCF3FFFFF00000000

#define STACK_SCRATCH_AREA 16

#ifdef _WIN64
#define INT_ROUTINES_SHIFT 3
#else
#define INT_ROUTINES_SHIFT 2
#endif

#define DISABLE_INTERRUPTS(reg) mov reg = psr; rsm 1 << PSR_I

#define RESTORE_INTERRUPTS(reg) tbit##.##nz pt0,pt1 = reg,PSR_I;; ;(pt0) ssm 1 << PSR_I ;(pt1) rsm 1 << PSR_I

#define FAST_DISABLE_INTERRUPTS rsm 1 << PSR_I

#define FAST_ENABLE_INTERRUPTS ssm 1 << PSR_I

#define YIELD hint##.##m 0

#define PCR_ENTRY 0
#define PDR_ENTRY 2
#define LARGE_ENTRY 3
#define DMA_ENTRY 4

#define TB_ENTRY_SIZE (3 *4)
#define FIXED_BASE 0
#define FIXED_ENTRIES (DMA_ENTRY + 1)

#define DCACHE_SIZE 4 *1024
#define ICACHE_SIZE 4 *1024
#define MINIMUM_CACHE_SIZE 4 *1024
#define MAXIMUM_CACHE_SIZE 128 *1024

#define KSEG3_RID 0x00000
#define START_GLOBAL_RID 0x00001
#define HAL_RID 0x00002
#define START_SESSION_RID 0x00003
#define START_PROCESS_RID 0x00004

#define MAXIMUM_RID 0x3FFFF

#define START_SEQUENCE 1
#define MAXIMUM_SEQUENCE 0xFFFFFFFFFFFFFFFF

#define SBTTL(x)

#define PROLOGUE_BEGIN .##prologue;
#define PROLOGUE_END .##body;

#define ALTERNATE_ENTRY(Name) .##global Name; .##type Name,@function; Name::

#define CPUBLIC_LEAF_ENTRY(Name,i) .##text; .##proc Name##@##i; Name##@##i::

#define LEAF_ENTRY(Name) .##text; .##global Name; .##proc Name; Name::

#define LEAF_SETUP(i,l,o,r) .##regstk i,l,o,r; alloc r31=ar##.##pfs,i,l,o,r

#define CPUBLIC_NESTED_ENTRY(Name,i) .##text; .##proc Name##@##i; .##unwentry; Name##@##i::

#define NESTED_ENTRY_EX(Name,Handler) .##text; .##global Name; .##proc Name; .##personality Handler; Name::

#define NESTED_ENTRY(Name) .##text; .##global Name; .##proc Name; Name::

#define NESTED_SETUP(i,l,o,r) .##regstk i,l,o,r; .##prologue 0xC,loc0; alloc savedpfs=ar##.##pfs,i,l,o,r ; mov savedbrp=brp;

#define LEAF_RETURN br##.##ret##.##sptk##.##few##.##clr brp

#define NESTED_RETURN mov ar##.##pfs = savedpfs; mov brp = savedbrp; br##.##ret##.##sptk##.##few##.##clr brp

#define LEAF_EXIT(Name) .##endp Name;

#define NESTED_EXIT(Name) .##endp Name;

#ifdef _WIN64
#define LDPTR(rD,rPtr) ld8 rD = [rPtr]
#else
#define LDPTR(rD,rPtr) ld4 rD = [rPtr] ; ;; ; sxt4 rD = rD
#endif

#ifdef _WIN64
#define LDPTRINC(rD,rPtr,imm) ld8 rD = [rPtr],imm
#else
#define LDPTRINC(rD,rPtr,imm) ld4 rD = [rPtr],imm ; ;; ; sxt4 rD = rD
#endif

#ifdef _WIN64
#define PLDPTRINC(rP,rD,rPtr,imm) (rP) ld8 rD = [rPtr],imm
#else
#define PLDPTRINC(rP,rD,rPtr,imm) (rP) ld4 rD = [rPtr],imm ; ;; ;(rP) sxt4 rD = rD
#endif

#ifdef _WIN64
#define PLDPTR(rP,rD,rPtr) (rP) ld8 rD = [rPtr]
#else
#define PLDPTR(rP,rD,rPtr) (rP) ld4 rD = [rPtr] ; ;; ;(rP) sxt4 rD = rD
#endif

#ifdef _WIN64
#define STPTR(rPtr,rS) st8 [rPtr] = rS
#else
#define STPTR(rPtr,rS) st4 [rPtr] = rS
#endif

#ifdef _WIN64
#define PSTPTR(rP,rPtr,rS) (rP) st8 [rPtr] = rS
#else
#define PSTPTR(rP,rPtr,rS) (rP) st4 [rPtr] = rS
#endif

#ifdef _WIN64
#define STPTRINC(rPtr,rS,imm) st8 [rPtr] = rS,imm
#else
#define STPTRINC(rPtr,rS,imm) st4 [rPtr] = rS,imm
#endif

#ifdef _WIN64
#define ARGPTR(rPtr)
#else
#define ARGPTR(rPtr) sxt4 rPtr = rPtr
#endif

#define ACQUIRE_SPINLOCK(rpLock,rOwn,Loop) cmp##.##eq pt0,pt1 = zero,zero ; ;; ;Loop: ;.pred.rel "mutex",pt0,pt1 ;(pt1) YIELD ;(pt0) xchg8 t22 = [rpLock],rOwn ;(pt1) ld8##.##nt1 t22 = [rpLock] ; ;; ;(pt0) cmp##.##ne pt2 = zero,t22 ; cmp##.##eq pt0,pt1 = zero,t22 ;(pt2) br##.##dpnt Loop

#define RELEASE_SPINLOCK(rpLock) st8##.##rel [rpLock] = zero

#define PRELEASE_SPINLOCK(px,rpLock) (px) st8##.##rel [rpLock] = zero

#define END_OF_INTERRUPT mov cr##.##eoi = zero ; ;; ; srlz##.##d

#ifndef SHADOW_IRQL_IMPLEMENTATION
#define GET_IRQL(rOldIrql) mov rOldIrql = cr##.##tpr ;; extr##.##u rOldIrql = rOldIrql,TPR_MIC,TPR_MIC_LEN
#else
#define GET_IRQL(rOldIrql) movl rOldIrql = KiPcr+PcCurrentIrql;; ld1 rOldIrql = [rOldIrql]
#endif

#ifndef SHADOW_IRQL_IMPLEMENTATION
#define SET_IRQL(rNewIrql) dep##.##z t22 = rNewIrql,TPR_MIC,TPR_MIC_LEN;; ; mov cr##.##tpr = t22;; ; srlz##.##d
#else
#define SET_IRQL(rNewIrql) dep##.##z t22 = rNewIrql,TPR_MIC,TPR_MIC_LEN;; ; movl t21 = KiPcr+PcCurrentIrql;; ; mov cr##.##tpr = t22 ; st1 [t21] = rNewIrql
#endif

#ifndef SHADOW_IRQL_IMPLEMENTATION
#define PSET_IRQL(pr,rNewIrql) dep##.##z t22 = rNewIrql,TPR_MIC,TPR_MIC_LEN;; ;(pr) mov cr##.##tpr = t22;; ;(pr) srlz##.##d
#else
#define PSET_IRQL(pr,rNewIrql) mov t21 = rNewIrql ; dep##.##z t22 = rNewIrql,TPR_MIC,TPR_MIC_LEN;; ;(pr) mov cr##.##tpr = t22 ;(pr) movl t22 = KiPcr+PcCurrentIrql;; ;(pr) st1 [t22] = t21
#endif

#define SWAP_IRQL(rNewIrql) movl t22 = KiPcr+PcCurrentIrql;; ; ld1 v0 = [t22] ; dep##.##z t21 = rNewIrql,TPR_MIC,TPR_MIC_LEN;; ; mov cr##.##tpr = t21 ; st1 [t22] = rNewIrql
#define GET_IRQL_FOR_VECTOR(pGet,rIrql,rVector) (pGet) shr rIrql = rVector,VECTOR_IRQL_SHIFT
#define GET_VECTOR_FOR_IRQL(pGet,rVector,rIrql) (pGet) shl rVector = rIrql,VECTOR_IRQL_SHIFT
#define REQUEST_APC_INT(pReq) mov t20 = 1 ; movl t21 = KiPcr+PcApcInterrupt ; ;; ;(pReq) st1 [t21] = t20
#define REQUEST_DISPATCH_INT(pReq) mov t20 = 1 ; movl t21 = KiPcr+PcDispatchInterrupt ; ;; ;(pReq) st1 [t21] = t20

#define beginSection(SectName) .##section .CRT$##SectName,"a","progbits"
#define endSection(SectName)

#define PublicFunction(Name) .##global Name; .##type Name,@function
