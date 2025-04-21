/* $NetBSD: machdep.h,v 1.7 2002/02/21 02:52:21 thorpej Exp $ */

#ifndef _MACHDEP_BOOT_MACHDEP_H_
#define _MACHDEP_BOOT_MACHDEP_H_

/* Structs that need to be initialised by initarm */
extern vm_offset_t irqstack;
extern vm_offset_t undstack;
extern vm_offset_t abtstack;

/* Define various stack sizes in pages */
#define IRQ_STACK_SIZE	1
#define ABT_STACK_SIZE	1
#define UND_STACK_SIZE	1

/* misc prototypes used by the many arm machdeps */
struct trapframe;
void init_proc0(vm_offset_t kstack);
void halt(void);
void abort_handler(struct trapframe *, int );
void set_stackptrs(int cpu);
void undefinedinstruction_bounce(struct trapframe *);

/* Early boot related helper functions */
struct arm_boot_params;
vm_offset_t default_parse_boot_param(struct arm_boot_params *abp);
vm_offset_t fake_preload_metadata(struct arm_boot_params *abp,
    void *dtb_ptr, size_t dtb_size);
vm_offset_t parse_boot_param(struct arm_boot_params *abp);
void arm_parse_fdt_bootargs(void);
void arm_print_kenv(void);

int arm_get_vfpstate(struct thread *td, void *args);

/* Board-specific attributes */
void board_set_serial(uint64_t);
void board_set_revision(uint32_t);

int arm_predict_branch(void *, u_int, register_t, register_t *,
    u_int (*)(void*, int), u_int (*)(void*, vm_offset_t, u_int*));

#ifdef PLATFORM
typedef void delay_func(int, void *);
void arm_set_delay(delay_func *, void *);
#endif

#ifdef EFI
struct efi_map_header;
struct mem_region;
void arm_add_efi_map_entries(struct efi_map_header *efihdr,
    struct mem_region *mr, int *mrcnt);
#endif

/*
 * Symbols created by ldscript.arm which are accessible in the kernel as global
 * symbols. They have uint8 type because they mark the byte location where the
 * corresponding data starts or ends (in the end case, it's the next byte
 * following the data, so the data size is end-start).  These are listed below
 * in the order they occur within the kernel (i.e., the address of each variable
 * should be greater than any of the ones before it).
 */
extern uint8_t _start;		/* Kernel entry point in locore.S */
extern uint8_t _etext;		/* text segment end */
extern uint8_t _extab_start;	/* unwind table start */
extern uint8_t _exidx_start;	/* unwind index start */
extern uint8_t _exidx_end;	/* unwind index end */
extern uint8_t _start_ctors;	/* ctors data start */
extern uint8_t _stop_ctors;	/* ctors data end */
extern uint8_t _edata;		/* data segment end */
extern uint8_t __bss_start;	/* bss segment start */
extern uint8_t _ebss;		/* bss segment end */
extern uint8_t _end;		/* End of kernel (text+ctors+unwind+data+bss) */

#endif /* !_MACHINE_MACHDEP_H_ */