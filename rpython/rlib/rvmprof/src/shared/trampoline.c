#include "trampoline.h"

#include "vmprof.h"
#include "machine.h"

#define _GNU_SOURCE 1
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <dlfcn.h>
#include <errno.h>
#include <stdint.h>
#include <unistd.h>

#if __APPLE__
#include <mach-o/dyld.h>
#endif

#define PAGE_ALIGNED(a,size) (void*)(((uintptr_t)a) & ~(size - 1)) 

/*
 * The trampoline works the following way:
 *
 * `eval` is the traditional PyEval_EvalFrameEx (for 2.7)
 * `page` is allocated and used as memory block to execute
 *        the first few instructions from eval
 * `vmprof_eval` is a function just saving the
 *               frame in rbx
 *
 *          +--- eval ----------+
 *     +----| jmp vmprof_eval   | <-- patched, original bits moved to page
 *     | +->| asm instr 1       |
 *     | |  | asm instr 2       |
 *     | |  | ...               |
 *     | |  +-------------------+
 *     | |                          
 *     | |  +--- page ----------+<-+
 *     | |  | push rbp          | <-- copied from PyEval_Loop
 *     | |  | mov rsp -> rbp    |  |
 *     | |  | ...               |  |
 *     | |  | ...               |  |
 *     | +--| jmp eval+copied   |  |
 *     |    +-------------------+  |
 *     |                           |
 *     +--->+--- vmprof_eval ---+  |
 *          | ...               |  |
 *          | push rbx          |  |
 *          | mov rdi -> rbx    | <-- save the frame, custom method
 *          | call eval         |--+
 *          | ...               |
 *          | retq              |
 *          +-------------------+
 */

static
int g_patched = 0;

static char * g_trampoline = NULL;
// the machine code size copied over from the callee
static int g_trampoline_length;

int _jmp_to(char * a, uintptr_t addr) {
#ifdef X86_64
    // moveabsq <addr>, <reg>
    a[0] = 0x48; // REX.W
    a[1] = 0xba; // %rdx
    a[2] = addr & 0xff;
    a[3] = (addr >> 8) & 0xff;
    a[4] = (addr >> 16) & 0xff;
    a[5] = (addr >> 24) & 0xff;
    a[6] = (addr >> 32) & 0xff;
    a[7] = (addr >> 40) & 0xff;
    a[8] = (addr >> 48) & 0xff;
    a[9] = (addr >> 56) & 0xff;

    // jmp %edx
    a[10] = 0xff;
    a[11] = 0xe2;
    return 12;
#elif defined(X86_32)
    // mov <addr>, %edx
    a[0] = 0xba;
    a[1] = addr & 0xff;
    a[2] = (addr >> 8) & 0xff;
    a[3] = (addr >> 16) & 0xff;
    a[4] = (addr >> 24) & 0xff;
    // jmp %edx
    a[5] = 0xff;
    a[6] = 0xe2;
    return 7;
#endif
    return 0;
}

#ifdef X86_32
int patch_relative_call(void * base, char * rel_call, char *rel_call_end, int bytes_after) {
    if (bytes_after != 0) {
        return 0;
    }

    char * r = rel_call+1;

    int off = r[0] |
              ((r[1] & 0xff) << 8) |
              ((r[2] & 0xff) << 16) |
              ((r[3] & 0xff) << 24);
    // instruction pointer is just after the whole instruction
    intptr_t addr = (intptr_t)base + 5 + off;

    rel_call[0] = 0xb8;
    rel_call[1] = addr & 0xff;
    rel_call[2] = (addr >> 8) & 0xff;
    rel_call[3] = (addr >> 16) & 0xff;
    rel_call[4] = (addr >> 24) & 0xff;
    // jmp %edx
    rel_call[5] = 0xff;
    rel_call[6] = 0xd0;

    return 2;
}
#endif

#include "libudis86/udis86.h"
unsigned int vmp_machine_code_instr_length(char* pc)
{
    struct ud u;
    ud_init(&u);
    ud_set_input_buffer(&u, (uint8_t*)pc, 12);
    ud_set_mode(&u, vmp_machine_bits());
    return ud_decode(&u);
}

// a hilarious typo, tramp -> trump :)
int _redirect_trampoline_and_back(char * eval, char * trump, char * vmprof_eval) {

    char * trump_first_byte = trump;
#ifdef X86_64
    int needed_bytes = 12;
#elif defined(X86_32)
    int needed_bytes = 8;
    int relative_call_at_pos = -1;
#else
#   error "platform not supported"
#endif
    int bytes = 0;
    int off = 0;
    char * ptr = eval;

    // 1) copy the instructions that should be redone in the trampoline
    while (bytes < needed_bytes) {
        unsigned int res = vmp_machine_code_instr_length(ptr);
        if (res == 0) {
            fprintf(stderr, "could not determine length of instr for trampoline\n");
            fprintf(stderr, " %x %x %x %x %x\n", ptr[0], ptr[1],
                            ptr[2], ptr[3], ptr[4]);
            return 1;
        }
#ifdef X86_32
        if (ptr[0] == '\xe8') {
            // occur on 32bit linux
            relative_call_at_pos = bytes;
        }
#endif
        bytes += res;
        ptr += res;
    }
    g_trampoline_length = bytes;

    // 2) initiate the first few instructions of the eval loop
    {
        (void)memcpy(trump, eval, bytes);
#ifdef X86_32
        if (relative_call_at_pos != -1) {
            off = patch_relative_call(eval+relative_call_at_pos, trump+relative_call_at_pos,
                                          trump+relative_call_at_pos+5, bytes-relative_call_at_pos-5);
        }
#endif
        _jmp_to(trump+bytes+off, (uintptr_t)eval+bytes);
    }

    // 3) overwrite the first few bytes of callee to jump to tramp
    // callee must call back 
    _jmp_to(eval, (uintptr_t)vmprof_eval);

    return 0;
}


int vmp_patch_callee_trampoline(void * callee_addr, void * vmprof_eval, void ** vmprof_eval_target)
{
    int result;
    int pagesize;

    if (g_trampoline != NULL) {
        //fprintf(stderr, "trampoline already patched\n");
        return 0; // already patched
    }

    pagesize = sysconf(_SC_PAGESIZE);
    errno = 0;

    result = mprotect(PAGE_ALIGNED(callee_addr, pagesize), pagesize*2, PROT_READ|PROT_WRITE);
    if (result != 0) {
        fprintf(stderr, "read|write protecting callee_addr\n");
        return -1;
    }
    // create a new page and set it all of it writable
    char * page = (char*)mmap(NULL, pagesize, PROT_READ|PROT_WRITE|PROT_EXEC,
                              MAP_ANON | MAP_PRIVATE, 0, 0);
    if (page == NULL) {
        fprintf(stderr, "could not allocate page for trampoline\n");
        return -1;
    }

    char * a = (char*)callee_addr;
    if (_redirect_trampoline_and_back(a, page, vmprof_eval) != 0) {
        fprintf(stderr, "could not redirect eval->vmprof_eval->trampoline->eval+off\n");
        return -1;
    }

    result = mprotect(PAGE_ALIGNED(callee_addr, pagesize), pagesize*2, PROT_READ|PROT_EXEC);
    if (result != 0) {
        fprintf(stderr, "read|exec protecting callee addr\n");
        return -1;
    }
    // revert, the page should not be writable any more now!
    result = mprotect((void*)page, pagesize, PROT_READ|PROT_EXEC);
    if (result != 0) {
        fprintf(stderr, "read|exec protecting tramp\n");
        return -1;
    }

    g_trampoline = page;
    *vmprof_eval_target = page;

    return 0;
}

int vmp_unpatch_callee_trampoline(void * callee_addr)
{
    return 0; // currently the trampoline is not removed
}
