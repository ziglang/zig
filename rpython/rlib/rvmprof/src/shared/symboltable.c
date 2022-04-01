#include "symboltable.h"

#include "vmprof.h"
#include "machine.h"

#include "khash.h"

#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#include <assert.h>
#include <dlfcn.h>

#if defined(VMPROF_LINUX)
#include <link.h>
#endif

#ifdef _PY_TEST
#define LOG(...) printf(__VA_ARGS__)
#else
#define LOG(...)
#endif

#ifdef __APPLE__

#include <mach-o/loader.h>
#include <mach-o/nlist.h>
#include <mach-o/stab.h>
#include <mach-o/dyld.h>
#include <mach-o/dyld_images.h>
#include <mach-o/fat.h>

int dyld_index_for_hdr(const struct mach_header_64 * hdr)
{
    const struct mach_header_64 * it;
    int image_count = _dyld_image_count();
    for (int i = 0; i < image_count; i++) {
        it = (const struct mach_header_64*)_dyld_get_image_header(i);
        if (it == hdr) {
            return i;
        }
    }

    return -1;
}

void lookup_vmprof_debug_info(const char * name, const void * h,
                              char * srcfile, int srcfile_len, int * lineno) {

    const struct mach_header_64 * hdr = (const struct mach_header_64*)h;
    const struct symtab_command *sc;
    const struct load_command *lc;

    int index = dyld_index_for_hdr(hdr);
    intptr_t slide = _dyld_get_image_vmaddr_slide(index);
    if (hdr->magic != MH_MAGIC_64) {
        return;
    }

    if (hdr->cputype != CPU_TYPE_X86_64) {
        return;
    }

    lc = (const struct load_command *)(hdr + 1);

    struct segment_command_64 * __linkedit = NULL;
    struct segment_command_64 * __text = NULL;

    LOG(" mach-o hdr has %d commands\n", hdr->ncmds);
    for (uint32_t j = 0; j < hdr->ncmds; j++, (lc = (const struct load_command *)((char *)lc + lc->cmdsize))) {
        if (lc->cmd == LC_SEGMENT_64) {
            struct segment_command_64 * sc = (struct segment_command_64*)lc;
            //LOG("segment command %s %llx %llx foff %llx fsize %llx\n",
            //    sc->segname, sc->vmaddr, sc->vmsize, sc->fileoff, sc->filesize);
            if (strncmp("__LINKEDIT", sc->segname, 16) == 0) {
                //LOG("segment command %s\n", sc->segname);
                __linkedit = sc;
            }
            if (strncmp("__TEXT", sc->segname, 16) == 0) {
                __text = sc;
            }
        }
    }

    if (__linkedit == NULL) {
        LOG("couldn't find __linkedit\n");
        return;
    } else if (__text == NULL) {
        LOG("couldn't find __text\n");
        return;
    }

    uint64_t fileoff = __linkedit->fileoff;
    uint64_t vmaddr = __linkedit->vmaddr;
    const char * baseaddr = (const char*) vmaddr + slide - fileoff;
    const char * __text_baseaddr = (const char*) slide - __text->fileoff;
    //LOG("%llx %llx %llx\n", slide, __text->vmaddr, __text->fileoff);
    const char * path = NULL;
    const char * filename = NULL;
    uint32_t src_line = 0;

    lc = (const struct load_command *)(hdr + 1);
    for (uint32_t j = 0; j < hdr->ncmds; j++, (lc = (const struct load_command *)((char *)lc + lc->cmdsize))) {
        if (lc->cmd == LC_SYMTAB) {
            LOG(" cmd %d/%d is LC_SYMTAB\n", j, hdr->ncmds);
            sc = (const struct symtab_command*) lc;
            // skip if symtab entry is not populated
            if (sc->symoff == 0) {
                LOG("LC_SYMTAB.symoff == 0\n");
                continue;
            } else if (sc->stroff == 0) {
                LOG("LC_SYMTAB.stroff == 0\n");
                continue;
            } else if (sc->nsyms == 0) {
                LOG("LC_SYMTAB.nsym == 0\n");
                continue;
            } else if (sc->strsize == 0) {
                LOG("LC_SYMTAB.strsize == 0\n");
                continue;
            }
            const char * strtbl = (const char*)(baseaddr + sc->stroff);
            struct nlist_64 * l = (struct nlist_64*)(baseaddr + sc->symoff);
            //LOG("baseaddr %llx fileoff: %lx vmaddr %llx, symoff %llx stroff %llx slide %llx %d\n",
            //        baseaddr, fileoff, vmaddr, sc->symoff, sc->stroff, slide, sc->nsyms);
            for (uint32_t s = 0; s < sc->nsyms; s++) {
                struct nlist_64 * entry = &l[s];
                uint32_t t = entry->n_type;
                bool is_debug = (t & N_STAB) != 0;
                if (!is_debug) {
                    continue;
                }
                uint32_t off = entry->n_un.n_strx;
                if (off >= sc->strsize || off == 0) {
                    continue;
                }
                const char * sym = &strtbl[off];
                if (sym[0] == '\x00') {
                    sym = NULL;
                }
                // switch through the  different types
                switch (t) {
                    case N_FUN: {
                        if (sym != NULL && strcmp(name, sym+1) == 0) {
                            *lineno = src_line;
                            if (src_line == 0) {
                                *lineno = entry->n_desc;
                            }
                            snprintf(srcfile, srcfile_len, "%s%s", path, filename);
                        }
                        break;
                    }
                    case N_SLINE: {
                        // does not seem to occur
                        src_line = entry->n_desc;
                        break;
                    }
                    case N_SO: {
                        // the first entry is the path, the second the filename,
                        // if a null occurs, the path and filename is reset
                        if (sym == NULL) {
                            path = NULL;
                            filename = NULL;
                        } else if (path == NULL) {
                            path = sym;
                        } else if (filename == NULL) {
                            filename = sym;
                        }
                        break;
                    }
                }
            }
        }
    }
}

#endif

#ifdef __unix__
#include "libbacktrace/backtrace.h"
void backtrace_error_cb(void *data, const char *msg, int errnum)
{
}

// a struct that helps to copy over data for the callbacks
typedef struct addr_info {
    char * name;
    int name_len;
    char * srcfile;
    int srcfile_len;
    int * lineno;
} addr_info_t;

int backtrace_full_cb(void *data, uintptr_t pc, const char *filename,
                      int lineno, const char *function)
{
    addr_info_t * info = (addr_info_t*)data;
    if (function != NULL) {
        // found the symbol name
        (void)strncpy(info->name, function, info->name_len);
    }
    if (filename != NULL) {
        (void)strncpy(info->srcfile, filename, info->srcfile_len);
    }
    *info->lineno = lineno;
    return 0;
}
#endif

static
struct backtrace_state * bstate = NULL;

int vmp_resolve_addr(void * addr, char * name, int name_len, int * lineno, char * srcfile, int srcfile_len) {
#ifdef __APPLE__
    Dl_info dlinfo;
    if (dladdr((const void*)addr, &dlinfo) == 0) {
        return 1;
    }
    if (dlinfo.dli_sname != NULL) {
        (void)strncpy(name, dlinfo.dli_sname, name_len-1);
        name[name_len-1] = 0;
    }
    lookup_vmprof_debug_info(name, dlinfo.dli_fbase, srcfile, srcfile_len, lineno);
    // copy the shared object name to the source file name if source cannot be determined
    if (srcfile[0] == 0 && dlinfo.dli_fname != NULL) {
        (void)strncpy(srcfile, dlinfo.dli_fname, srcfile_len-1);
        srcfile[srcfile_len-1] = 0;
    }
#elif defined(VMPROF_LINUX)
    if (bstate == NULL) {
        bstate = backtrace_create_state (NULL, 1, backtrace_error_cb, NULL);
    }
    addr_info_t info = { .name = name, .name_len = name_len,
                         .srcfile = srcfile, .srcfile_len = srcfile_len,
                         .lineno = lineno
                       };
    if (backtrace_pcinfo(bstate, (uintptr_t)addr, backtrace_full_cb,
                         backtrace_error_cb, (void*)&info)) {
        // failed
        return 1;
    }

    // nothing found, try with dladdr
    if (info.name[0] == 0) {
        Dl_info dlinfo;
        dlinfo.dli_sname = NULL;
        (void)dladdr((const void*)addr, &dlinfo);
        if (dlinfo.dli_sname != NULL) {
            (void)strncpy(info.name, dlinfo.dli_sname, info.name_len-1);
            name[name_len-1] = 0;
        }

    }

    // copy the shared object name to the source file name if source cannot be determined
    if (srcfile[0] == 0) {
        Dl_info dlinfo;
        dlinfo.dli_fname = NULL;
        (void)dladdr((const void*)addr, &dlinfo);
        if (dlinfo.dli_fname != NULL) {
            (void)strncpy(srcfile, dlinfo.dli_fname, srcfile_len-1);
            srcfile[srcfile_len-1] = 0;
        }
    }
#endif
    return 0;
}
