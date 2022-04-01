#include "vmp_stack.h"

#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <stddef.h>
#include <assert.h>

#include "vmprof.h"
#include "compat.h"

#ifdef VMP_SUPPORTS_NATIVE_PROFILING

#if defined(VMPROF_LINUX) || defined(VMPROF_BSD)
#include "unwind/vmprof_unwind.h"
typedef mcontext_t unw_context_t;

// functions copied from libunwind using dlopen
static int (*unw_get_reg)(unw_cursor_t*, int, unw_word_t*) = NULL;
static int (*unw_step)(unw_cursor_t*) = NULL;
static int (*unw_init_local)(unw_cursor_t *, unw_context_t *) = NULL;
static int (*unw_get_proc_info)(unw_cursor_t *, unw_proc_info_t *) = NULL;
static int (*unw_get_proc_name)(unw_cursor_t *, char *, size_t, unw_word_t*) = NULL;
static int (*unw_is_signal_frame)(unw_cursor_t *) = NULL;
static int (*unw_getcontext)(unw_context_t *) = NULL;
#else
#define UNW_LOCAL_ONLY
#include <libunwind.h>
#endif

#endif

#ifdef __APPLE__
#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <mach/message.h>
#include <mach/kern_return.h>
#include <mach/task_info.h>
#include <sys/types.h>
#include <unistd.h>
#include <dlfcn.h>
#elif defined(__unix__)
#include <dlfcn.h>
#endif

#ifdef PYPY_JIT_CODEMAP
void *pypy_find_codemap_at_addr(long addr, long *start_addr);
#endif

int _per_loop(void) {
    // how many void* are written to the stack trace per loop iterations?
#ifdef RPYTHON_VMPROF
    return 2;
#else
    if (vmp_profiles_python_lines()) {
        return 2;
    }
    return 1;
#endif
}


#ifdef PY_TEST
// for testing only!
PY_EVAL_RETURN_T * vmprof_eval(PY_STACK_FRAME_T *f, int throwflag) { return NULL; }
#endif

#ifdef VMP_SUPPORTS_NATIVE_PROFILING
static intptr_t *vmp_ranges = NULL;
static ssize_t vmp_range_count = 0;
static int vmp_native_traces_enabled = 0;
#endif
static int _vmp_profiles_lines = 0;

void vmp_profile_lines(int lines) {
    _vmp_profiles_lines = lines;
}
int vmp_profiles_python_lines(void) {
    return _vmp_profiles_lines;
}

static PY_STACK_FRAME_T * _write_python_stack_entry(PY_STACK_FRAME_T * frame, void ** result, int * depth, int max_depth)
{
#ifndef RPYTHON_VMPROF // pypy does not support line profiling
    if (vmp_profiles_python_lines()) {
        // In the line profiling mode we save a line number for every frame.
        // Actual line number isn't stored in the frame directly (f_lineno
        // points to the beginning of the frame), so we need to compute it
        // from f_lasti and f_code->co_lnotab. Here is explained what co_lnotab
        // is:
        // https://svn.python.org/projects/python/trunk/Objects/lnotab_notes.txt

        // NOTE: the profiling overhead can be reduced by storing co_lnotab in the dump and
        // moving this computation to the reader instead of doing it here.
        result[*depth] = (void*) (int64_t) PyFrame_GetLineNumber(frame);
        *depth = *depth + 1;
    }
    result[*depth] = (void*)CODE_ADDR_TO_UID(FRAME_CODE(frame));
    *depth = *depth + 1;
#else

    if (frame->kind == VMPROF_CODE_TAG) {
        int n = *depth;
        result[n++] = (void*)frame->kind;
        result[n++] = (void*)frame->value;
        *depth = n;
    }
#ifdef PYPY_JIT_CODEMAP
    else if (frame->kind == VMPROF_JITTED_TAG) {
        intptr_t pc = ((intptr_t*)(frame->value - sizeof(intptr_t)))[0];
        *depth = vmprof_write_header_for_jit_addr(result, *depth, pc, max_depth);
    }
#endif


#endif

    return FRAME_STEP(frame);
}

int vmp_walk_and_record_python_stack_only(PY_STACK_FRAME_T *frame, void ** result,
                                          int max_depth, int depth, intptr_t pc)
{
    while ((depth + _per_loop()) <= max_depth && frame) {
        frame = _write_python_stack_entry(frame, result, &depth, max_depth);
    }
    return depth;
}

#ifdef VMP_SUPPORTS_NATIVE_PROFILING
int _write_native_stack(void* addr, void ** result, int depth, int max_depth) {
#ifdef RPYTHON_VMPROF
    if (depth + 2 >= max_depth) {
        // bail, do not write to unknown memory
        return depth;
    }
    result[depth++] = (void*)VMPROF_NATIVE_TAG;
#else
    if (vmp_profiles_python_lines()) {
        if (depth + 2 >= max_depth) {
            // bail, do not write to unknown memory
            return depth;
        }
        // even if we do not log a python line number,
        // we must keep the profile readable
        result[depth++] = 0;
    }
#endif
    result[depth++] = addr;
    return depth;
}
#endif

int vmp_walk_and_record_stack(PY_STACK_FRAME_T *frame, void ** result,
                              int max_depth, int signal, intptr_t pc) {

    // called in signal handler
    //
    // This function records the stack trace for a python program. It also
    // tracks native function calls if libunwind can be found on the system.
    //
    // The idea is the following (in the native case):
    //
    // 1) Remove frames until the signal frame is found (skipping it as well)
    // 2) if the current frame corresponds to PyEval_EvalFrameEx (or the equivalent
    //    for each python version), the jump to 4)
    // 3) jump to 2)
    // 4) walk each python frame and record it
    //
    //
    // There are several cases that need to be taken care of.
    //
    // CPython supports line profiling, PyPy does not. At the same time
    // PyPy saves the information of an address in the same way as line information
    // is saved in CPython. _write_python_stack_entry for details.
    //
#ifdef VMP_SUPPORTS_NATIVE_PROFILING
    void * func_addr;
    unw_cursor_t cursor;
    unw_context_t uc;
    unw_proc_info_t pip;
    int ret;

    if (vmp_native_enabled() == 0) {
        return vmp_walk_and_record_python_stack_only(frame, result, max_depth, 0, pc);
    }

    ret = unw_getcontext(&uc);
    if (ret < 0) {
        // could not initialize lib unwind cursor and context
#if DEBUG
        fprintf(stderr, "WARNING: unw_getcontext did not retreive context, switching to python profiling mode \n");
#endif
        vmp_native_disable();
        return vmp_walk_and_record_python_stack_only(frame, result, max_depth, 0, pc);
    }
    ret = unw_init_local(&cursor, &uc);
    if (ret < 0) {
        // could not initialize lib unwind cursor and context
#if DEBUG
        fprintf(stderr, "WARNING: unw_init_local did not succeed, switching to python profiling mode \n");
#endif
        vmp_native_disable();
        return vmp_walk_and_record_python_stack_only(frame, result, max_depth, 0, pc);
    }

    if (signal < 0) {
        while (signal < 0) {
            int err = unw_step(&cursor);
            if (err <= 0) {
#if DEBUG
                fprintf(stderr, "WARNING: did not find signal frame, skipping sample\n");
#endif
                return 0;
            }
            signal++;
        }
    } else {
#ifdef VMPROF_LINUX
        while (signal) {
            int is_signal_frame = unw_is_signal_frame(&cursor);
            if (is_signal_frame) {
                unw_step(&cursor); // step once more discard signal frame
                break;
            }
            int err = unw_step(&cursor);
            if (err <= 0) {
#if DEBUG
                fprintf(stderr,"WARNING: did not find signal frame, skipping sample\n");
#endif
                return 0;
            }
        }
#else
        // who would have guessed that unw_is_signal_frame does not work on mac os x
        if (signal) {
            unw_step(&cursor); // vmp_walk_and_record_stack
            // get_stack_trace is inlined
            unw_step(&cursor); // _vmprof_sample_stack
            unw_step(&cursor); // sigprof_handler
            unw_step(&cursor); // _sigtramp
        }
#endif
    }

    int depth = 0;
    //PY_STACK_FRAME_T * top_most_frame = frame;
    while ((depth + _per_loop()) <= max_depth) {
        unw_get_proc_info(&cursor, &pip);

        func_addr = (void*)pip.start_ip;

        //{
        //    char name[64];
        //    unw_word_t x;
        //    unw_get_proc_name(&cursor, name, 64, &x);
        //    printf("  %s %p\n", name, func_addr);
        //}

        //if (func_addr == 0) {
        //    unw_word_t rip = 0;
        //    if (unw_get_reg(&cursor, UNW_REG_IP, &rip) < 0) {
        //        printf("failed failed failed\n");
        //    }
        //    func_addr = rip;
        //    printf("func_addr is 0, now %p\n", rip);
        //}

#ifdef PYPY_JIT_CODEMAP
        long start_addr = 0;
        unw_word_t rip = 0;
        if (unw_get_reg(&cursor, UNW_REG_IP, &rip) < 0) {
            return 0;
        }
#endif

        if (IS_VMPROF_EVAL((void*)pip.start_ip)) {
            // yes we found one stack entry of the python frames!
            return vmp_walk_and_record_python_stack_only(frame, result, max_depth, depth, pc);
#ifdef PYPY_JIT_CODEMAP
        } else if (pypy_find_codemap_at_addr(rip, &start_addr) != NULL) {
            depth = vmprof_write_header_for_jit_addr(result, depth, pc, max_depth);
            return vmp_walk_and_record_python_stack_only(frame, result, max_depth, depth, pc);
#endif
        } else {
            // mark native routines with the first bit set,
            // this is possible because compiler align to 8 bytes.
            //
            if (func_addr != 0x0) {
                depth = _write_native_stack((void*)(((uint64_t)func_addr) | 0x1), result, depth, max_depth);
            }
        }

        int err = unw_step(&cursor);
        if (err == 0) {
            break;
        } else if (err < 0) {
            // this sample is broken, cannot walk native level... record python level (at least)
            return vmp_walk_and_record_python_stack_only(frame, result, max_depth, 0, pc);
        }
    }

    // if we come here, the found stack trace is removed and only python stacks are recorded
#endif
    return vmp_walk_and_record_python_stack_only(frame, result, max_depth, 0, pc);
}

int vmp_native_enabled(void) {
#ifdef VMP_SUPPORTS_NATIVE_PROFILING
    return vmp_native_traces_enabled;
#else
    return 0;
#endif
}

#ifdef VMP_SUPPORTS_NATIVE_PROFILING
int _ignore_symbols_from_path(const char * name) {
    // which symbols should not be considered while walking
    // the native stack?
#ifdef RPYTHON_VMPROF
    if (strstr(name, "libpypy-c.so") != NULL
        || strstr(name, "pypy-c") != NULL) {
        return 1;
    }
#else
    // cpython
    if (strstr(name, "python") != NULL &&
#  ifdef __unix__
        strstr(name, ".so\n") == NULL
#  elif defined(__APPLE__)
        strstr(name, ".so") == NULL
#  endif
       ) {
        return 1;
    }
#endif
    return 0;
}

int _reset_vmp_ranges(void) {
    // initially 10 (start, stop) entries!
    int max_count = 10;
    vmp_range_count = 0;
    if (vmp_ranges != NULL) { free(vmp_ranges); }
    vmp_ranges = malloc(max_count * sizeof(intptr_t));
    return max_count;
}


int _resize_ranges(intptr_t ** cursor, int max_count) {
    ptrdiff_t diff = (*cursor - vmp_ranges);
    if (diff + 2 > max_count) {
        max_count *= 2;
        vmp_ranges = realloc(vmp_ranges, max_count*sizeof(intptr_t));
        *cursor = vmp_ranges + diff;
    }
    return max_count;
}

intptr_t * _add_to_range(intptr_t * cursor, intptr_t start, intptr_t end) {
    if (cursor[0] == start) {
        // the last range is extended, this reduces the entry count
        // which makes the querying faster
        cursor[0] = end;
    } else {
        if (cursor != vmp_ranges) {
            // not pointing to the first entry
            cursor++;
        }
        cursor[0] = start;
        cursor[1] = end;
        vmp_range_count += 2;
        cursor++;
    }
    return cursor;
}

#ifdef __unix__
int vmp_read_vmaps(const char * fname) {

    FILE * fd = fopen(fname, "rb");
    if (fd == NULL) {
        return 0;
    }
    char * saveptr = NULL;
    char * line = NULL;
    char * he = NULL;
    char * name;
    char *start_hex = NULL, *end_hex = NULL;
    size_t n = 0;
    ssize_t size;
    intptr_t start, end;

    // assumptions to be verified:
    // 1) /proc/self/maps is ordered ascending by start address
    // 2) libraries that contain the name 'python' are considered
    //    candidates in the mapping to be ignored
    // 3) libraries containing site-packages are not considered
    //    candidates

    int max_count = _reset_vmp_ranges();
    intptr_t * cursor = vmp_ranges;
    cursor[0] = -1;
    while ((size = getline(&line, &n, fd)) >= 0) {
        assert(line != NULL);
        start_hex = strtok_r(line, "-", &saveptr);
        if (start_hex == NULL) { continue; }
        start = strtoll(start_hex, &he, 16);
        end_hex = strtok_r(NULL, " ", &saveptr);
        if (end_hex == NULL) { continue; }
        end = strtoll(end_hex, &he, 16);
        // skip over flags, ...
        strtok_r(NULL, " ", &saveptr);
        strtok_r(NULL, " ", &saveptr);
        strtok_r(NULL, " ", &saveptr);
        strtok_r(NULL, " ", &saveptr);

        name = saveptr;
        if (_ignore_symbols_from_path(name)) {
            max_count = _resize_ranges(&cursor, max_count);
            cursor = _add_to_range(cursor, start, end);
        }
        free(line);
        line = NULL;
        n = 0;
    }

    fclose(fd);
    return 1;
}
#endif

#ifdef __APPLE__
int vmp_read_vmaps(const char * fname) {
    kern_return_t kr;
    task_t task;
    mach_vm_address_t addr;
    mach_vm_size_t vmsize;
    vm_region_top_info_data_t topinfo;
    mach_msg_type_number_t count;
    memory_object_name_t obj;
    int ret = 0;
    pid_t pid;

    pid = getpid();
    kr = task_for_pid(mach_task_self(), pid, &task);
    if (kr != KERN_SUCCESS) {
        goto teardown;
    }

    addr = 0;
    int max_count = _reset_vmp_ranges();
    intptr_t * cursor = vmp_ranges;
    cursor[0] = -1;

    do {
        // extract the top info using vm_region
        count = VM_REGION_TOP_INFO_COUNT;
        vmsize = 0;
        kr = mach_vm_region(task, &addr, &vmsize, VM_REGION_TOP_INFO,
                          (vm_region_info_t)&topinfo, &count, &obj);
        if (kr == KERN_SUCCESS) {
            vm_address_t start = (vm_address_t)addr, end = (vm_address_t)(addr + vmsize);
            // dladdr now gives the path of the shared object
            Dl_info info;
            if (dladdr((const void*)start, &info) == 0) {
                // could not find image containing start
                addr += vmsize;
                continue;
            }
            if (_ignore_symbols_from_path(info.dli_fname)) {
                // realloc if the chunk is to small
                max_count = _resize_ranges(&cursor, max_count);
                cursor = _add_to_range(cursor, start, end);
            }
            addr = addr + vmsize;
        } else if (kr != KERN_INVALID_ADDRESS) {
            goto teardown;
        }
    } while (kr == KERN_SUCCESS);

    ret = 1;

teardown:
    if (task != MACH_PORT_NULL) {
        mach_port_deallocate(mach_task_self(), task);
    }
    return ret;
}
#endif

static const char * vmprof_error = NULL;
static void * libhandle = NULL;

#ifdef VMPROF_LINUX
#include <link.h>
#define LIBUNWIND "libunwind.so"
#ifdef __i386__
#define PREFIX "x86"
#define LIBUNWIND_SUFFIX ""
#elif __x86_64__
#define PREFIX "x86_64"
#define LIBUNWIND_SUFFIX "-x86_64"
#elif __powerpc64__
#define PREFIX "ppc64"
#define LIBUNWIND_SUFFIX "-ppc64"
#endif
#define U_PREFIX "_U"
#define UL_PREFIX "_UL"
#endif

int vmp_native_enable(void) {
#ifdef VMPROF_LINUX
    void * oldhandle = NULL;
    struct link_map * map = NULL;
    if (libhandle == NULL) {
        // on linux, the wheel includes the libunwind shared object.
        libhandle = dlopen(NULL, RTLD_NOW);
        if (libhandle != NULL) {
            // load the link map, it will contain an entry to
            // .libs_vmprof/libunwind-...so, this is the file that is
            // distributed with the wheel.
            if (dlinfo(libhandle, RTLD_DI_LINKMAP, &map) != 0) {
                (void)dlclose(libhandle);
                libhandle = NULL;
                goto bail_out;
            }
            // grab the new handle
            do {
                if (strstr(map->l_name, ".libs_vmprof/libunwind" LIBUNWIND_SUFFIX) != NULL) {
                    oldhandle = libhandle;
                    libhandle = dlopen(map->l_name, RTLD_LAZY|RTLD_LOCAL);
                    (void)dlclose(oldhandle);
                    oldhandle = NULL;
                    goto loaded_libunwind;
                }
                map = map->l_next;
            } while (map != NULL);
            // did not find .libs_vmprof/libunwind...
            (void)dlclose(libhandle);
            libhandle = NULL;
        }

        // fallback! try to load the system's libunwind.so
        if ((libhandle = dlopen(LIBUNWIND, RTLD_LAZY | RTLD_LOCAL)) == NULL) {
            goto bail_out;
        }
loaded_libunwind:
        if ((unw_get_reg = dlsym(libhandle, UL_PREFIX PREFIX "_get_reg")) == NULL) {
            goto bail_out;
        }
        if ((unw_get_proc_info = dlsym(libhandle, UL_PREFIX PREFIX "_get_proc_info")) == NULL){
            goto bail_out;
        }
        if ((unw_get_proc_name = dlsym(libhandle, UL_PREFIX PREFIX "_get_proc_name")) == NULL){
            goto bail_out;
        }
        if ((unw_init_local = dlsym(libhandle, UL_PREFIX PREFIX "_init_local")) == NULL) {
            goto bail_out;
        }
        if ((unw_step = dlsym(libhandle, UL_PREFIX PREFIX "_step")) == NULL) {
            goto bail_out;
        }
        if ((unw_is_signal_frame = dlsym(libhandle, UL_PREFIX PREFIX "_is_signal_frame")) == NULL) {
            goto bail_out;
        }
#if __powerpc64__
//getcontext() naming follows a different pattern on PPC64
#define U_PREFIX
#define PREFIX
#define USCORE
#else
#define USCORE "_"
#endif
        if ((unw_getcontext = dlsym(libhandle, U_PREFIX PREFIX USCORE "getcontext")) == NULL) {
            goto bail_out;
        }
    }
#endif

    vmp_native_traces_enabled = 1;
    return 1;

#ifdef VMPROF_LINUX
bail_out:
    vmprof_error = dlerror();
    fprintf(stderr, "could not load libunwind at runtime. error: %s\n", vmprof_error);
    vmp_native_traces_enabled = 0;
    return 0;
#endif
}

void vmp_native_disable(void) {

    if (libhandle != NULL) {
        if (dlclose(libhandle)) {
            vmprof_error = dlerror();
#if DEBUG
            fprintf(stderr, "could not close libunwind at runtime. error: %s\n", vmprof_error);
#endif
        }
        libhandle = NULL;
    }

    vmp_native_traces_enabled = 0;
    if (vmp_ranges != NULL) {
        free(vmp_ranges);
        vmp_ranges = NULL;
    }
    vmp_range_count = 0;
}

int vmp_ignore_ip(intptr_t ip) {
    if (vmp_range_count == 0) {
        return 0;
    }
    int i = vmp_binary_search_ranges(ip, vmp_ranges, (int)vmp_range_count);
    if (i == -1) {
        return 0;
    }

    assert((i & 1) == 0 && "returned index MUST be even");

    intptr_t v = vmp_ranges[i];
    intptr_t v2 = vmp_ranges[i+1];
    return v <= ip && ip <= v2;
}

int vmp_binary_search_ranges(intptr_t ip, intptr_t * l, int count) {
    intptr_t * r = l + count;
    intptr_t * ol = l;
    intptr_t * or = r-1;
    while (1) {
        ptrdiff_t i = (r-l)/2;
        if (i == 0) {
            if (l == ol && *l > ip) {
                // at the start
                return -1;
            } else if (l == or && *l < ip) {
                // at the end
                return -1;
            } else {
                // we found the lower bound
                i = l - ol;
                if ((i & 1) == 1) {
                    return (int)i-1;
                }
                return (int)i;
            }
        }
        intptr_t * m = l + i;
        if (ip < *m) {
            r = m;
        } else {
            l = m;
        }
    }
    return -1;
}

int vmp_ignore_symbol_count(void) {
    return (int)vmp_range_count;
}

intptr_t * vmp_ignore_symbols(void) {
    return vmp_ranges;
}

void vmp_set_ignore_symbols(intptr_t * symbols, int count) {
    vmp_ranges = symbols;
    vmp_range_count = count;
}
#endif
