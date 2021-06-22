//===------------------------- AddressSpace.hpp ---------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//
// Abstracts accessing local vs remote address spaces.
//
//===----------------------------------------------------------------------===//

#ifndef __ADDRESSSPACE_HPP__
#define __ADDRESSSPACE_HPP__

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "libunwind.h"
#include "config.h"
#include "dwarf2.h"
#include "EHHeaderParser.hpp"
#include "Registers.hpp"

#ifndef _LIBUNWIND_USE_DLADDR
  #if !defined(_LIBUNWIND_IS_BAREMETAL) && !defined(_WIN32)
    #define _LIBUNWIND_USE_DLADDR 1
  #else
    #define _LIBUNWIND_USE_DLADDR 0
  #endif
#endif

#if _LIBUNWIND_USE_DLADDR
#include <dlfcn.h>
#if defined(__ELF__) && defined(_LIBUNWIND_LINK_DL_LIB)
#pragma comment(lib, "dl")
#endif
#endif

#if defined(_LIBUNWIND_ARM_EHABI)
struct EHABIIndexEntry {
  uint32_t functionOffset;
  uint32_t data;
};
#endif

#ifdef __APPLE__

  struct dyld_unwind_sections
  {
    const struct mach_header*   mh;
    const void*                 dwarf_section;
    uintptr_t                   dwarf_section_length;
    const void*                 compact_unwind_section;
    uintptr_t                   compact_unwind_section_length;
  };

  // In 10.7.0 or later, libSystem.dylib implements this function.
  extern "C" bool _dyld_find_unwind_sections(void *, dyld_unwind_sections *);

#elif defined(_LIBUNWIND_SUPPORT_DWARF_UNWIND) && defined(_LIBUNWIND_IS_BAREMETAL)

// When statically linked on bare-metal, the symbols for the EH table are looked
// up without going through the dynamic loader.

// The following linker script may be used to produce the necessary sections and symbols.
// Unless the --eh-frame-hdr linker option is provided, the section is not generated
// and does not take space in the output file.
//
//   .eh_frame :
//   {
//       __eh_frame_start = .;
//       KEEP(*(.eh_frame))
//       __eh_frame_end = .;
//   }
//
//   .eh_frame_hdr :
//   {
//       KEEP(*(.eh_frame_hdr))
//   }
//
//   __eh_frame_hdr_start = SIZEOF(.eh_frame_hdr) > 0 ? ADDR(.eh_frame_hdr) : 0;
//   __eh_frame_hdr_end = SIZEOF(.eh_frame_hdr) > 0 ? . : 0;

extern char __eh_frame_start;
extern char __eh_frame_end;

#if defined(_LIBUNWIND_SUPPORT_DWARF_INDEX)
extern char __eh_frame_hdr_start;
extern char __eh_frame_hdr_end;
#endif

#elif defined(_LIBUNWIND_ARM_EHABI) && defined(_LIBUNWIND_IS_BAREMETAL)

// When statically linked on bare-metal, the symbols for the EH table are looked
// up without going through the dynamic loader.
extern char __exidx_start;
extern char __exidx_end;

#elif defined(_LIBUNWIND_SUPPORT_DWARF_UNWIND) && defined(_WIN32)

#include <windows.h>
#include <psapi.h>

#elif defined(_LIBUNWIND_USE_DL_ITERATE_PHDR) ||                               \
      defined(_LIBUNWIND_USE_DL_UNWIND_FIND_EXIDX)

#include <link.h>

#endif

namespace libunwind {

/// Used by findUnwindSections() to return info about needed sections.
struct UnwindInfoSections {
#if defined(_LIBUNWIND_SUPPORT_DWARF_UNWIND) ||                                \
    defined(_LIBUNWIND_SUPPORT_COMPACT_UNWIND) ||                              \
    defined(_LIBUNWIND_USE_DL_ITERATE_PHDR)
  // No dso_base for SEH.
  uintptr_t       dso_base;
#endif
#if defined(_LIBUNWIND_USE_DL_ITERATE_PHDR)
  uintptr_t       text_segment_length;
#endif
#if defined(_LIBUNWIND_SUPPORT_DWARF_UNWIND)
  uintptr_t       dwarf_section;
  uintptr_t       dwarf_section_length;
#endif
#if defined(_LIBUNWIND_SUPPORT_DWARF_INDEX)
  uintptr_t       dwarf_index_section;
  uintptr_t       dwarf_index_section_length;
#endif
#if defined(_LIBUNWIND_SUPPORT_COMPACT_UNWIND)
  uintptr_t       compact_unwind_section;
  uintptr_t       compact_unwind_section_length;
#endif
#if defined(_LIBUNWIND_ARM_EHABI)
  uintptr_t       arm_section;
  uintptr_t       arm_section_length;
#endif
};


/// LocalAddressSpace is used as a template parameter to UnwindCursor when
/// unwinding a thread in the same process.  The wrappers compile away,
/// making local unwinds fast.
class _LIBUNWIND_HIDDEN LocalAddressSpace {
public:
  typedef uintptr_t pint_t;
  typedef intptr_t  sint_t;
  uint8_t         get8(pint_t addr) {
    uint8_t val;
    memcpy(&val, (void *)addr, sizeof(val));
    return val;
  }
  uint16_t         get16(pint_t addr) {
    uint16_t val;
    memcpy(&val, (void *)addr, sizeof(val));
    return val;
  }
  uint32_t         get32(pint_t addr) {
    uint32_t val;
    memcpy(&val, (void *)addr, sizeof(val));
    return val;
  }
  uint64_t         get64(pint_t addr) {
    uint64_t val;
    memcpy(&val, (void *)addr, sizeof(val));
    return val;
  }
  double           getDouble(pint_t addr) {
    double val;
    memcpy(&val, (void *)addr, sizeof(val));
    return val;
  }
  v128             getVector(pint_t addr) {
    v128 val;
    memcpy(&val, (void *)addr, sizeof(val));
    return val;
  }
  uintptr_t       getP(pint_t addr);
  uint64_t        getRegister(pint_t addr);
  static uint64_t getULEB128(pint_t &addr, pint_t end);
  static int64_t  getSLEB128(pint_t &addr, pint_t end);

  pint_t getEncodedP(pint_t &addr, pint_t end, uint8_t encoding,
                     pint_t datarelBase = 0);
  bool findFunctionName(pint_t addr, char *buf, size_t bufLen,
                        unw_word_t *offset);
  bool findUnwindSections(pint_t targetAddr, UnwindInfoSections &info);
  bool findOtherFDE(pint_t targetAddr, pint_t &fde);

  static LocalAddressSpace sThisAddressSpace;
};

inline uintptr_t LocalAddressSpace::getP(pint_t addr) {
#if __SIZEOF_POINTER__ == 8
  return get64(addr);
#else
  return get32(addr);
#endif
}

inline uint64_t LocalAddressSpace::getRegister(pint_t addr) {
#if __SIZEOF_POINTER__ == 8 || defined(__mips64)
  return get64(addr);
#else
  return get32(addr);
#endif
}

/// Read a ULEB128 into a 64-bit word.
inline uint64_t LocalAddressSpace::getULEB128(pint_t &addr, pint_t end) {
  const uint8_t *p = (uint8_t *)addr;
  const uint8_t *pend = (uint8_t *)end;
  uint64_t result = 0;
  int bit = 0;
  do {
    uint64_t b;

    if (p == pend)
      _LIBUNWIND_ABORT("truncated uleb128 expression");

    b = *p & 0x7f;

    if (bit >= 64 || b << bit >> bit != b) {
      _LIBUNWIND_ABORT("malformed uleb128 expression");
    } else {
      result |= b << bit;
      bit += 7;
    }
  } while (*p++ >= 0x80);
  addr = (pint_t) p;
  return result;
}

/// Read a SLEB128 into a 64-bit word.
inline int64_t LocalAddressSpace::getSLEB128(pint_t &addr, pint_t end) {
  const uint8_t *p = (uint8_t *)addr;
  const uint8_t *pend = (uint8_t *)end;
  int64_t result = 0;
  int bit = 0;
  uint8_t byte;
  do {
    if (p == pend)
      _LIBUNWIND_ABORT("truncated sleb128 expression");
    byte = *p++;
    result |= (uint64_t)(byte & 0x7f) << bit;
    bit += 7;
  } while (byte & 0x80);
  // sign extend negative numbers
  if ((byte & 0x40) != 0 && bit < 64)
    result |= (-1ULL) << bit;
  addr = (pint_t) p;
  return result;
}

inline LocalAddressSpace::pint_t
LocalAddressSpace::getEncodedP(pint_t &addr, pint_t end, uint8_t encoding,
                               pint_t datarelBase) {
  pint_t startAddr = addr;
  const uint8_t *p = (uint8_t *)addr;
  pint_t result;

  // first get value
  switch (encoding & 0x0F) {
  case DW_EH_PE_ptr:
    result = getP(addr);
    p += sizeof(pint_t);
    addr = (pint_t) p;
    break;
  case DW_EH_PE_uleb128:
    result = (pint_t)getULEB128(addr, end);
    break;
  case DW_EH_PE_udata2:
    result = get16(addr);
    p += 2;
    addr = (pint_t) p;
    break;
  case DW_EH_PE_udata4:
    result = get32(addr);
    p += 4;
    addr = (pint_t) p;
    break;
  case DW_EH_PE_udata8:
    result = (pint_t)get64(addr);
    p += 8;
    addr = (pint_t) p;
    break;
  case DW_EH_PE_sleb128:
    result = (pint_t)getSLEB128(addr, end);
    break;
  case DW_EH_PE_sdata2:
    // Sign extend from signed 16-bit value.
    result = (pint_t)(int16_t)get16(addr);
    p += 2;
    addr = (pint_t) p;
    break;
  case DW_EH_PE_sdata4:
    // Sign extend from signed 32-bit value.
    result = (pint_t)(int32_t)get32(addr);
    p += 4;
    addr = (pint_t) p;
    break;
  case DW_EH_PE_sdata8:
    result = (pint_t)get64(addr);
    p += 8;
    addr = (pint_t) p;
    break;
  default:
    _LIBUNWIND_ABORT("unknown pointer encoding");
  }

  // then add relative offset
  switch (encoding & 0x70) {
  case DW_EH_PE_absptr:
    // do nothing
    break;
  case DW_EH_PE_pcrel:
    result += startAddr;
    break;
  case DW_EH_PE_textrel:
    _LIBUNWIND_ABORT("DW_EH_PE_textrel pointer encoding not supported");
    break;
  case DW_EH_PE_datarel:
    // DW_EH_PE_datarel is only valid in a few places, so the parameter has a
    // default value of 0, and we abort in the event that someone calls this
    // function with a datarelBase of 0 and DW_EH_PE_datarel encoding.
    if (datarelBase == 0)
      _LIBUNWIND_ABORT("DW_EH_PE_datarel is invalid with a datarelBase of 0");
    result += datarelBase;
    break;
  case DW_EH_PE_funcrel:
    _LIBUNWIND_ABORT("DW_EH_PE_funcrel pointer encoding not supported");
    break;
  case DW_EH_PE_aligned:
    _LIBUNWIND_ABORT("DW_EH_PE_aligned pointer encoding not supported");
    break;
  default:
    _LIBUNWIND_ABORT("unknown pointer encoding");
    break;
  }

  if (encoding & DW_EH_PE_indirect)
    result = getP(result);

  return result;
}

#if defined(_LIBUNWIND_USE_DL_ITERATE_PHDR)

// The ElfW() macro for pointer-size independent ELF header traversal is not
// provided by <link.h> on some systems (e.g., FreeBSD). On these systems the
// data structures are just called Elf_XXX. Define ElfW() locally.
#if !defined(ElfW)
  #define ElfW(type) Elf_##type
#endif
#if !defined(Elf_Half)
  typedef ElfW(Half) Elf_Half;
#endif
#if !defined(Elf_Phdr)
  typedef ElfW(Phdr) Elf_Phdr;
#endif
#if !defined(Elf_Addr)
  typedef ElfW(Addr) Elf_Addr;
#endif

static Elf_Addr calculateImageBase(struct dl_phdr_info *pinfo) {
  Elf_Addr image_base = pinfo->dlpi_addr;
#if defined(__ANDROID__) && __ANDROID_API__ < 18
  if (image_base == 0) {
    // Normally, an image base of 0 indicates a non-PIE executable. On
    // versions of Android prior to API 18, the dynamic linker reported a
    // dlpi_addr of 0 for PIE executables. Compute the true image base
    // using the PT_PHDR segment.
    // See https://github.com/android/ndk/issues/505.
    for (Elf_Half i = 0; i < pinfo->dlpi_phnum; i++) {
      const Elf_Phdr *phdr = &pinfo->dlpi_phdr[i];
      if (phdr->p_type == PT_PHDR) {
        image_base = reinterpret_cast<Elf_Addr>(pinfo->dlpi_phdr) -
          phdr->p_vaddr;
        break;
      }
    }
  }
#endif
  return image_base;
}

struct _LIBUNWIND_HIDDEN dl_iterate_cb_data {
  LocalAddressSpace *addressSpace;
  UnwindInfoSections *sects;
  uintptr_t targetAddr;
};

#if defined(_LIBUNWIND_USE_FRAME_HEADER_CACHE)
#include "FrameHeaderCache.hpp"

// Typically there is one cache per process, but when libunwind is built as a
// hermetic static library, then each shared object may have its own cache.
static FrameHeaderCache TheFrameHeaderCache;
#endif

static bool checkAddrInSegment(const Elf_Phdr *phdr, size_t image_base,
                               dl_iterate_cb_data *cbdata) {
  if (phdr->p_type == PT_LOAD) {
    uintptr_t begin = image_base + phdr->p_vaddr;
    uintptr_t end = begin + phdr->p_memsz;
    if (cbdata->targetAddr >= begin && cbdata->targetAddr < end) {
      cbdata->sects->dso_base = begin;
      cbdata->sects->text_segment_length = phdr->p_memsz;
      return true;
    }
  }
  return false;
}

static bool checkForUnwindInfoSegment(const Elf_Phdr *phdr, size_t image_base,
                                      dl_iterate_cb_data *cbdata) {
#if defined(_LIBUNWIND_SUPPORT_DWARF_INDEX)
  if (phdr->p_type == PT_GNU_EH_FRAME) {
    EHHeaderParser<LocalAddressSpace>::EHHeaderInfo hdrInfo;
    uintptr_t eh_frame_hdr_start = image_base + phdr->p_vaddr;
    cbdata->sects->dwarf_index_section = eh_frame_hdr_start;
    cbdata->sects->dwarf_index_section_length = phdr->p_memsz;
    if (EHHeaderParser<LocalAddressSpace>::decodeEHHdr(
            *cbdata->addressSpace, eh_frame_hdr_start, phdr->p_memsz,
            hdrInfo)) {
      // .eh_frame_hdr records the start of .eh_frame, but not its size.
      // Rely on a zero terminator to find the end of the section.
      cbdata->sects->dwarf_section = hdrInfo.eh_frame_ptr;
      cbdata->sects->dwarf_section_length = UINTPTR_MAX;
      return true;
    }
  }
  return false;
#elif defined(_LIBUNWIND_ARM_EHABI)
  if (phdr->p_type == PT_ARM_EXIDX) {
    uintptr_t exidx_start = image_base + phdr->p_vaddr;
    cbdata->sects->arm_section = exidx_start;
    cbdata->sects->arm_section_length = phdr->p_memsz;
    return true;
  }
  return false;
#else
#error Need one of _LIBUNWIND_SUPPORT_DWARF_INDEX or _LIBUNWIND_ARM_EHABI
#endif
}

static int findUnwindSectionsByPhdr(struct dl_phdr_info *pinfo,
                                    size_t pinfo_size, void *data) {
  auto cbdata = static_cast<dl_iterate_cb_data *>(data);
  if (pinfo->dlpi_phnum == 0 || cbdata->targetAddr < pinfo->dlpi_addr)
    return 0;
#if defined(_LIBUNWIND_USE_FRAME_HEADER_CACHE)
  if (TheFrameHeaderCache.find(pinfo, pinfo_size, data))
    return 1;
#else
  // Avoid warning about unused variable.
  (void)pinfo_size;
#endif

  Elf_Addr image_base = calculateImageBase(pinfo);

  // Most shared objects seen in this callback function likely don't contain the
  // target address, so optimize for that. Scan for a matching PT_LOAD segment
  // first and bail when it isn't found.
  bool found_text = false;
  for (Elf_Half i = 0; i < pinfo->dlpi_phnum; ++i) {
    if (checkAddrInSegment(&pinfo->dlpi_phdr[i], image_base, cbdata)) {
      found_text = true;
      break;
    }
  }
  if (!found_text)
    return 0;

  // PT_GNU_EH_FRAME and PT_ARM_EXIDX are usually near the end. Iterate
  // backward.
  bool found_unwind = false;
  for (Elf_Half i = pinfo->dlpi_phnum; i > 0; i--) {
    const Elf_Phdr *phdr = &pinfo->dlpi_phdr[i - 1];
    if (checkForUnwindInfoSegment(phdr, image_base, cbdata)) {
      found_unwind = true;
      break;
    }
  }
  if (!found_unwind)
    return 0;

#if defined(_LIBUNWIND_USE_FRAME_HEADER_CACHE)
  TheFrameHeaderCache.add(cbdata->sects);
#endif
  return 1;
}

#endif  // defined(_LIBUNWIND_USE_DL_ITERATE_PHDR)


inline bool LocalAddressSpace::findUnwindSections(pint_t targetAddr,
                                                  UnwindInfoSections &info) {
#ifdef __APPLE__
  dyld_unwind_sections dyldInfo;
  if (_dyld_find_unwind_sections((void *)targetAddr, &dyldInfo)) {
    info.dso_base                      = (uintptr_t)dyldInfo.mh;
 #if defined(_LIBUNWIND_SUPPORT_DWARF_UNWIND)
    info.dwarf_section                 = (uintptr_t)dyldInfo.dwarf_section;
    info.dwarf_section_length          = dyldInfo.dwarf_section_length;
 #endif
    info.compact_unwind_section        = (uintptr_t)dyldInfo.compact_unwind_section;
    info.compact_unwind_section_length = dyldInfo.compact_unwind_section_length;
    return true;
  }
#elif defined(_LIBUNWIND_SUPPORT_DWARF_UNWIND) && defined(_LIBUNWIND_IS_BAREMETAL)
  info.dso_base = 0;
  // Bare metal is statically linked, so no need to ask the dynamic loader
  info.dwarf_section_length = (uintptr_t)(&__eh_frame_end - &__eh_frame_start);
  info.dwarf_section =        (uintptr_t)(&__eh_frame_start);
  _LIBUNWIND_TRACE_UNWINDING("findUnwindSections: section %p length %p",
                             (void *)info.dwarf_section, (void *)info.dwarf_section_length);
#if defined(_LIBUNWIND_SUPPORT_DWARF_INDEX)
  info.dwarf_index_section =        (uintptr_t)(&__eh_frame_hdr_start);
  info.dwarf_index_section_length = (uintptr_t)(&__eh_frame_hdr_end - &__eh_frame_hdr_start);
  _LIBUNWIND_TRACE_UNWINDING("findUnwindSections: index section %p length %p",
                             (void *)info.dwarf_index_section, (void *)info.dwarf_index_section_length);
#endif
  if (info.dwarf_section_length)
    return true;
#elif defined(_LIBUNWIND_ARM_EHABI) && defined(_LIBUNWIND_IS_BAREMETAL)
  // Bare metal is statically linked, so no need to ask the dynamic loader
  info.arm_section =        (uintptr_t)(&__exidx_start);
  info.arm_section_length = (uintptr_t)(&__exidx_end - &__exidx_start);
  _LIBUNWIND_TRACE_UNWINDING("findUnwindSections: section %p length %p",
                             (void *)info.arm_section, (void *)info.arm_section_length);
  if (info.arm_section && info.arm_section_length)
    return true;
#elif defined(_LIBUNWIND_SUPPORT_DWARF_UNWIND) && defined(_WIN32)
  HMODULE mods[1024];
  HANDLE process = GetCurrentProcess();
  DWORD needed;

  if (!EnumProcessModules(process, mods, sizeof(mods), &needed)) {
    DWORD err = GetLastError();
    _LIBUNWIND_TRACE_UNWINDING("findUnwindSections: EnumProcessModules failed, "
                               "returned error %d", (int)err);
    return false;
  }

  for (unsigned i = 0; i < (needed / sizeof(HMODULE)); i++) {
    PIMAGE_DOS_HEADER pidh = (PIMAGE_DOS_HEADER)mods[i];
    PIMAGE_NT_HEADERS pinh = (PIMAGE_NT_HEADERS)((BYTE *)pidh + pidh->e_lfanew);
    PIMAGE_FILE_HEADER pifh = (PIMAGE_FILE_HEADER)&pinh->FileHeader;
    PIMAGE_SECTION_HEADER pish = IMAGE_FIRST_SECTION(pinh);
    bool found_obj = false;
    bool found_hdr = false;

    info.dso_base = (uintptr_t)mods[i];
    for (unsigned j = 0; j < pifh->NumberOfSections; j++, pish++) {
      uintptr_t begin = pish->VirtualAddress + (uintptr_t)mods[i];
      uintptr_t end = begin + pish->Misc.VirtualSize;
      if (!strncmp((const char *)pish->Name, ".text",
                   IMAGE_SIZEOF_SHORT_NAME)) {
        if (targetAddr >= begin && targetAddr < end)
          found_obj = true;
      } else if (!strncmp((const char *)pish->Name, ".eh_frame",
                          IMAGE_SIZEOF_SHORT_NAME)) {
        info.dwarf_section = begin;
        info.dwarf_section_length = pish->Misc.VirtualSize;
        found_hdr = true;
      }
      if (found_obj && found_hdr)
        return true;
    }
  }
  return false;
#elif defined(_LIBUNWIND_SUPPORT_SEH_UNWIND) && defined(_WIN32)
  // Don't even bother, since Windows has functions that do all this stuff
  // for us.
  (void)targetAddr;
  (void)info;
  return true;
#elif defined(_LIBUNWIND_USE_DL_UNWIND_FIND_EXIDX)
  int length = 0;
  info.arm_section =
      (uintptr_t)dl_unwind_find_exidx((_Unwind_Ptr)targetAddr, &length);
  info.arm_section_length = (uintptr_t)length * sizeof(EHABIIndexEntry);
  if (info.arm_section && info.arm_section_length)
    return true;
#elif defined(_LIBUNWIND_USE_DL_ITERATE_PHDR)
  dl_iterate_cb_data cb_data = {this, &info, targetAddr};
  int found = dl_iterate_phdr(findUnwindSectionsByPhdr, &cb_data);
  return static_cast<bool>(found);
#endif

  return false;
}


inline bool LocalAddressSpace::findOtherFDE(pint_t targetAddr, pint_t &fde) {
  // TO DO: if OS has way to dynamically register FDEs, check that.
  (void)targetAddr;
  (void)fde;
  return false;
}

inline bool LocalAddressSpace::findFunctionName(pint_t addr, char *buf,
                                                size_t bufLen,
                                                unw_word_t *offset) {
#if _LIBUNWIND_USE_DLADDR
  Dl_info dyldInfo;
  if (dladdr((void *)addr, &dyldInfo)) {
    if (dyldInfo.dli_sname != NULL) {
      snprintf(buf, bufLen, "%s", dyldInfo.dli_sname);
      *offset = (addr - (pint_t) dyldInfo.dli_saddr);
      return true;
    }
  }
#else
  (void)addr;
  (void)buf;
  (void)bufLen;
  (void)offset;
#endif
  return false;
}

} // namespace libunwind

#endif // __ADDRESSSPACE_HPP__
