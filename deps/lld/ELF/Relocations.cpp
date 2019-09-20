//===- Relocations.cpp ----------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains platform-independent functions to process relocations.
// I'll describe the overview of this file here.
//
// Simple relocations are easy to handle for the linker. For example,
// for R_X86_64_PC64 relocs, the linker just has to fix up locations
// with the relative offsets to the target symbols. It would just be
// reading records from relocation sections and applying them to output.
//
// But not all relocations are that easy to handle. For example, for
// R_386_GOTOFF relocs, the linker has to create new GOT entries for
// symbols if they don't exist, and fix up locations with GOT entry
// offsets from the beginning of GOT section. So there is more than
// fixing addresses in relocation processing.
//
// ELF defines a large number of complex relocations.
//
// The functions in this file analyze relocations and do whatever needs
// to be done. It includes, but not limited to, the following.
//
//  - create GOT/PLT entries
//  - create new relocations in .dynsym to let the dynamic linker resolve
//    them at runtime (since ELF supports dynamic linking, not all
//    relocations can be resolved at link-time)
//  - create COPY relocs and reserve space in .bss
//  - replace expensive relocs (in terms of runtime cost) with cheap ones
//  - error out infeasible combinations such as PIC and non-relative relocs
//
// Note that the functions in this file don't actually apply relocations
// because it doesn't know about the output file nor the output file buffer.
// It instead stores Relocation objects to InputSection's Relocations
// vector to let it apply later in InputSection::writeTo.
//
//===----------------------------------------------------------------------===//

#include "Relocations.h"
#include "Config.h"
#include "LinkerScript.h"
#include "OutputSections.h"
#include "SymbolTable.h"
#include "Symbols.h"
#include "SyntheticSections.h"
#include "Target.h"
#include "Thunks.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Memory.h"
#include "lld/Common/Strings.h"
#include "llvm/ADT/SmallSet.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/raw_ostream.h"
#include <algorithm>

using namespace llvm;
using namespace llvm::ELF;
using namespace llvm::object;
using namespace llvm::support::endian;

using namespace lld;
using namespace lld::elf;

static Optional<std::string> getLinkerScriptLocation(const Symbol &sym) {
  for (BaseCommand *base : script->sectionCommands)
    if (auto *cmd = dyn_cast<SymbolAssignment>(base))
      if (cmd->sym == &sym)
        return cmd->location;
  return None;
}

// Construct a message in the following format.
//
// >>> defined in /home/alice/src/foo.o
// >>> referenced by bar.c:12 (/home/alice/src/bar.c:12)
// >>>               /home/alice/src/bar.o:(.text+0x1)
static std::string getLocation(InputSectionBase &s, const Symbol &sym,
                               uint64_t off) {
  std::string msg = "\n>>> defined in ";
  if (sym.file)
    msg += toString(sym.file);
  else if (Optional<std::string> loc = getLinkerScriptLocation(sym))
    msg += *loc;

  msg += "\n>>> referenced by ";
  std::string src = s.getSrcMsg(sym, off);
  if (!src.empty())
    msg += src + "\n>>>               ";
  return msg + s.getObjMsg(off);
}

namespace {
// Build a bitmask with one bit set for each RelExpr.
//
// Constexpr function arguments can't be used in static asserts, so we
// use template arguments to build the mask.
// But function template partial specializations don't exist (needed
// for base case of the recursion), so we need a dummy struct.
template <RelExpr... Exprs> struct RelExprMaskBuilder {
  static inline uint64_t build() { return 0; }
};

// Specialization for recursive case.
template <RelExpr Head, RelExpr... Tail>
struct RelExprMaskBuilder<Head, Tail...> {
  static inline uint64_t build() {
    static_assert(0 <= Head && Head < 64,
                  "RelExpr is too large for 64-bit mask!");
    return (uint64_t(1) << Head) | RelExprMaskBuilder<Tail...>::build();
  }
};
} // namespace

// Return true if `Expr` is one of `Exprs`.
// There are fewer than 64 RelExpr's, so we can represent any set of
// RelExpr's as a constant bit mask and test for membership with a
// couple cheap bitwise operations.
template <RelExpr... Exprs> bool oneof(RelExpr expr) {
  assert(0 <= expr && (int)expr < 64 &&
         "RelExpr is too large for 64-bit mask!");
  return (uint64_t(1) << expr) & RelExprMaskBuilder<Exprs...>::build();
}

// This function is similar to the `handleTlsRelocation`. MIPS does not
// support any relaxations for TLS relocations so by factoring out MIPS
// handling in to the separate function we can simplify the code and do not
// pollute other `handleTlsRelocation` by MIPS `ifs` statements.
// Mips has a custom MipsGotSection that handles the writing of GOT entries
// without dynamic relocations.
static unsigned handleMipsTlsRelocation(RelType type, Symbol &sym,
                                        InputSectionBase &c, uint64_t offset,
                                        int64_t addend, RelExpr expr) {
  if (expr == R_MIPS_TLSLD) {
    in.mipsGot->addTlsIndex(*c.file);
    c.relocations.push_back({expr, type, offset, addend, &sym});
    return 1;
  }
  if (expr == R_MIPS_TLSGD) {
    in.mipsGot->addDynTlsEntry(*c.file, sym);
    c.relocations.push_back({expr, type, offset, addend, &sym});
    return 1;
  }
  return 0;
}

// Notes about General Dynamic and Local Dynamic TLS models below. They may
// require the generation of a pair of GOT entries that have associated dynamic
// relocations. The pair of GOT entries created are of the form GOT[e0] Module
// Index (Used to find pointer to TLS block at run-time) GOT[e1] Offset of
// symbol in TLS block.
//
// Returns the number of relocations processed.
template <class ELFT>
static unsigned
handleTlsRelocation(RelType type, Symbol &sym, InputSectionBase &c,
                    typename ELFT::uint offset, int64_t addend, RelExpr expr) {
  if (!sym.isTls())
    return 0;

  if (config->emachine == EM_MIPS)
    return handleMipsTlsRelocation(type, sym, c, offset, addend, expr);

  if (oneof<R_AARCH64_TLSDESC_PAGE, R_TLSDESC, R_TLSDESC_CALL, R_TLSDESC_PC>(
          expr) &&
      config->shared) {
    if (in.got->addDynTlsEntry(sym)) {
      uint64_t off = in.got->getGlobalDynOffset(sym);
      mainPart->relaDyn->addReloc(
          {target->tlsDescRel, in.got, off, !sym.isPreemptible, &sym, 0});
    }
    if (expr != R_TLSDESC_CALL)
      c.relocations.push_back({expr, type, offset, addend, &sym});
    return 1;
  }

  bool canRelax = config->emachine != EM_ARM && config->emachine != EM_RISCV;

  // If we are producing an executable and the symbol is non-preemptable, it
  // must be defined and the code sequence can be relaxed to use Local-Exec.
  //
  // ARM and RISC-V do not support any relaxations for TLS relocations, however,
  // we can omit the DTPMOD dynamic relocations and resolve them at link time
  // because them are always 1. This may be necessary for static linking as
  // DTPMOD may not be expected at load time.
  bool isLocalInExecutable = !sym.isPreemptible && !config->shared;

  // Local Dynamic is for access to module local TLS variables, while still
  // being suitable for being dynamically loaded via dlopen. GOT[e0] is the
  // module index, with a special value of 0 for the current module. GOT[e1] is
  // unused. There only needs to be one module index entry.
  if (oneof<R_TLSLD_GOT, R_TLSLD_GOTPLT, R_TLSLD_PC, R_TLSLD_HINT>(
          expr)) {
    // Local-Dynamic relocs can be relaxed to Local-Exec.
    if (canRelax && !config->shared) {
      c.relocations.push_back(
          {target->adjustRelaxExpr(type, nullptr, R_RELAX_TLS_LD_TO_LE), type,
           offset, addend, &sym});
      return target->getTlsGdRelaxSkip(type);
    }
    if (expr == R_TLSLD_HINT)
      return 1;
    if (in.got->addTlsIndex()) {
      if (isLocalInExecutable)
        in.got->relocations.push_back(
            {R_ADDEND, target->symbolicRel, in.got->getTlsIndexOff(), 1, &sym});
      else
        mainPart->relaDyn->addReloc(target->tlsModuleIndexRel, in.got,
                                in.got->getTlsIndexOff(), nullptr);
    }
    c.relocations.push_back({expr, type, offset, addend, &sym});
    return 1;
  }

  // Local-Dynamic relocs can be relaxed to Local-Exec.
  if (expr == R_DTPREL && !config->shared) {
    c.relocations.push_back(
        {target->adjustRelaxExpr(type, nullptr, R_RELAX_TLS_LD_TO_LE), type,
         offset, addend, &sym});
    return 1;
  }

  // Local-Dynamic sequence where offset of tls variable relative to dynamic
  // thread pointer is stored in the got. This cannot be relaxed to Local-Exec.
  if (expr == R_TLSLD_GOT_OFF) {
    if (!sym.isInGot()) {
      in.got->addEntry(sym);
      uint64_t off = sym.getGotOffset();
      in.got->relocations.push_back(
          {R_ABS, target->tlsOffsetRel, off, 0, &sym});
    }
    c.relocations.push_back({expr, type, offset, addend, &sym});
    return 1;
  }

  if (oneof<R_AARCH64_TLSDESC_PAGE, R_TLSDESC, R_TLSDESC_CALL, R_TLSDESC_PC,
            R_TLSGD_GOT, R_TLSGD_GOTPLT, R_TLSGD_PC>(expr)) {
    if (!canRelax || config->shared) {
      if (in.got->addDynTlsEntry(sym)) {
        uint64_t off = in.got->getGlobalDynOffset(sym);

        if (isLocalInExecutable)
          // Write one to the GOT slot.
          in.got->relocations.push_back(
              {R_ADDEND, target->symbolicRel, off, 1, &sym});
        else
          mainPart->relaDyn->addReloc(target->tlsModuleIndexRel, in.got, off, &sym);

        // If the symbol is preemptible we need the dynamic linker to write
        // the offset too.
        uint64_t offsetOff = off + config->wordsize;
        if (sym.isPreemptible)
          mainPart->relaDyn->addReloc(target->tlsOffsetRel, in.got, offsetOff,
                                  &sym);
        else
          in.got->relocations.push_back(
              {R_ABS, target->tlsOffsetRel, offsetOff, 0, &sym});
      }
      c.relocations.push_back({expr, type, offset, addend, &sym});
      return 1;
    }

    // Global-Dynamic relocs can be relaxed to Initial-Exec or Local-Exec
    // depending on the symbol being locally defined or not.
    if (sym.isPreemptible) {
      c.relocations.push_back(
          {target->adjustRelaxExpr(type, nullptr, R_RELAX_TLS_GD_TO_IE), type,
           offset, addend, &sym});
      if (!sym.isInGot()) {
        in.got->addEntry(sym);
        mainPart->relaDyn->addReloc(target->tlsGotRel, in.got, sym.getGotOffset(),
                                &sym);
      }
    } else {
      c.relocations.push_back(
          {target->adjustRelaxExpr(type, nullptr, R_RELAX_TLS_GD_TO_LE), type,
           offset, addend, &sym});
    }
    return target->getTlsGdRelaxSkip(type);
  }

  // Initial-Exec relocs can be relaxed to Local-Exec if the symbol is locally
  // defined.
  if (oneof<R_GOT, R_GOTPLT, R_GOT_PC, R_AARCH64_GOT_PAGE_PC, R_GOT_OFF,
            R_TLSIE_HINT>(expr) &&
      canRelax && isLocalInExecutable) {
    c.relocations.push_back({R_RELAX_TLS_IE_TO_LE, type, offset, addend, &sym});
    return 1;
  }

  if (expr == R_TLSIE_HINT)
    return 1;
  return 0;
}

static RelType getMipsPairType(RelType type, bool isLocal) {
  switch (type) {
  case R_MIPS_HI16:
    return R_MIPS_LO16;
  case R_MIPS_GOT16:
    // In case of global symbol, the R_MIPS_GOT16 relocation does not
    // have a pair. Each global symbol has a unique entry in the GOT
    // and a corresponding instruction with help of the R_MIPS_GOT16
    // relocation loads an address of the symbol. In case of local
    // symbol, the R_MIPS_GOT16 relocation creates a GOT entry to hold
    // the high 16 bits of the symbol's value. A paired R_MIPS_LO16
    // relocations handle low 16 bits of the address. That allows
    // to allocate only one GOT entry for every 64 KBytes of local data.
    return isLocal ? R_MIPS_LO16 : R_MIPS_NONE;
  case R_MICROMIPS_GOT16:
    return isLocal ? R_MICROMIPS_LO16 : R_MIPS_NONE;
  case R_MIPS_PCHI16:
    return R_MIPS_PCLO16;
  case R_MICROMIPS_HI16:
    return R_MICROMIPS_LO16;
  default:
    return R_MIPS_NONE;
  }
}

// True if non-preemptable symbol always has the same value regardless of where
// the DSO is loaded.
static bool isAbsolute(const Symbol &sym) {
  if (sym.isUndefWeak())
    return true;
  if (const auto *dr = dyn_cast<Defined>(&sym))
    return dr->section == nullptr; // Absolute symbol.
  return false;
}

static bool isAbsoluteValue(const Symbol &sym) {
  return isAbsolute(sym) || sym.isTls();
}

// Returns true if Expr refers a PLT entry.
static bool needsPlt(RelExpr expr) {
  return oneof<R_PLT_PC, R_PPC32_PLTREL, R_PPC64_CALL_PLT, R_PLT>(expr);
}

// Returns true if Expr refers a GOT entry. Note that this function
// returns false for TLS variables even though they need GOT, because
// TLS variables uses GOT differently than the regular variables.
static bool needsGot(RelExpr expr) {
  return oneof<R_GOT, R_GOT_OFF, R_HEXAGON_GOT, R_MIPS_GOT_LOCAL_PAGE,
               R_MIPS_GOT_OFF, R_MIPS_GOT_OFF32, R_AARCH64_GOT_PAGE_PC,
               R_GOT_PC, R_GOTPLT>(expr);
}

// True if this expression is of the form Sym - X, where X is a position in the
// file (PC, or GOT for example).
static bool isRelExpr(RelExpr expr) {
  return oneof<R_PC, R_GOTREL, R_GOTPLTREL, R_MIPS_GOTREL, R_PPC64_CALL,
               R_PPC64_RELAX_TOC, R_AARCH64_PAGE_PC, R_RELAX_GOT_PC,
               R_RISCV_PC_INDIRECT>(expr);
}

// Returns true if a given relocation can be computed at link-time.
//
// For instance, we know the offset from a relocation to its target at
// link-time if the relocation is PC-relative and refers a
// non-interposable function in the same executable. This function
// will return true for such relocation.
//
// If this function returns false, that means we need to emit a
// dynamic relocation so that the relocation will be fixed at load-time.
static bool isStaticLinkTimeConstant(RelExpr e, RelType type, const Symbol &sym,
                                     InputSectionBase &s, uint64_t relOff) {
  // These expressions always compute a constant
  if (oneof<R_DTPREL, R_GOTPLT, R_GOT_OFF, R_HEXAGON_GOT, R_TLSLD_GOT_OFF,
            R_MIPS_GOT_LOCAL_PAGE, R_MIPS_GOTREL, R_MIPS_GOT_OFF,
            R_MIPS_GOT_OFF32, R_MIPS_GOT_GP_PC, R_MIPS_TLSGD,
            R_AARCH64_GOT_PAGE_PC, R_GOT_PC, R_GOTONLY_PC, R_GOTPLTONLY_PC,
            R_PLT_PC, R_TLSGD_GOT, R_TLSGD_GOTPLT, R_TLSGD_PC, R_PPC32_PLTREL,
            R_PPC64_CALL_PLT, R_PPC64_RELAX_TOC, R_RISCV_ADD, R_TLSDESC_CALL,
            R_TLSDESC_PC, R_AARCH64_TLSDESC_PAGE, R_HINT, R_TLSLD_HINT,
            R_TLSIE_HINT>(e))
    return true;

  // These never do, except if the entire file is position dependent or if
  // only the low bits are used.
  if (e == R_GOT || e == R_PLT || e == R_TLSDESC)
    return target->usesOnlyLowPageBits(type) || !config->isPic;

  if (sym.isPreemptible)
    return false;
  if (!config->isPic)
    return true;

  // The size of a non preemptible symbol is a constant.
  if (e == R_SIZE)
    return true;

  // For the target and the relocation, we want to know if they are
  // absolute or relative.
  bool absVal = isAbsoluteValue(sym);
  bool relE = isRelExpr(e);
  if (absVal && !relE)
    return true;
  if (!absVal && relE)
    return true;
  if (!absVal && !relE)
    return target->usesOnlyLowPageBits(type);

  // Relative relocation to an absolute value. This is normally unrepresentable,
  // but if the relocation refers to a weak undefined symbol, we allow it to
  // resolve to the image base. This is a little strange, but it allows us to
  // link function calls to such symbols. Normally such a call will be guarded
  // with a comparison, which will load a zero from the GOT.
  // Another special case is MIPS _gp_disp symbol which represents offset
  // between start of a function and '_gp' value and defined as absolute just
  // to simplify the code.
  assert(absVal && relE);
  if (sym.isUndefWeak())
    return true;

  // We set the final symbols values for linker script defined symbols later.
  // They always can be computed as a link time constant.
  if (sym.scriptDefined)
      return true;

  error("relocation " + toString(type) + " cannot refer to absolute symbol: " +
        toString(sym) + getLocation(s, sym, relOff));
  return true;
}

static RelExpr toPlt(RelExpr expr) {
  switch (expr) {
  case R_PPC64_CALL:
    return R_PPC64_CALL_PLT;
  case R_PC:
    return R_PLT_PC;
  case R_ABS:
    return R_PLT;
  default:
    return expr;
  }
}

static RelExpr fromPlt(RelExpr expr) {
  // We decided not to use a plt. Optimize a reference to the plt to a
  // reference to the symbol itself.
  switch (expr) {
  case R_PLT_PC:
  case R_PPC32_PLTREL:
    return R_PC;
  case R_PPC64_CALL_PLT:
    return R_PPC64_CALL;
  case R_PLT:
    return R_ABS;
  default:
    return expr;
  }
}

// Returns true if a given shared symbol is in a read-only segment in a DSO.
template <class ELFT> static bool isReadOnly(SharedSymbol &ss) {
  using Elf_Phdr = typename ELFT::Phdr;

  // Determine if the symbol is read-only by scanning the DSO's program headers.
  const SharedFile &file = ss.getFile();
  for (const Elf_Phdr &phdr :
       check(file.template getObj<ELFT>().program_headers()))
    if ((phdr.p_type == ELF::PT_LOAD || phdr.p_type == ELF::PT_GNU_RELRO) &&
        !(phdr.p_flags & ELF::PF_W) && ss.value >= phdr.p_vaddr &&
        ss.value < phdr.p_vaddr + phdr.p_memsz)
      return true;
  return false;
}

// Returns symbols at the same offset as a given symbol, including SS itself.
//
// If two or more symbols are at the same offset, and at least one of
// them are copied by a copy relocation, all of them need to be copied.
// Otherwise, they would refer to different places at runtime.
template <class ELFT>
static SmallSet<SharedSymbol *, 4> getSymbolsAt(SharedSymbol &ss) {
  using Elf_Sym = typename ELFT::Sym;

  SharedFile &file = ss.getFile();

  SmallSet<SharedSymbol *, 4> ret;
  for (const Elf_Sym &s : file.template getGlobalELFSyms<ELFT>()) {
    if (s.st_shndx == SHN_UNDEF || s.st_shndx == SHN_ABS ||
        s.getType() == STT_TLS || s.st_value != ss.value)
      continue;
    StringRef name = check(s.getName(file.getStringTable()));
    Symbol *sym = symtab->find(name);
    if (auto *alias = dyn_cast_or_null<SharedSymbol>(sym))
      ret.insert(alias);
  }
  return ret;
}

// When a symbol is copy relocated or we create a canonical plt entry, it is
// effectively a defined symbol. In the case of copy relocation the symbol is
// in .bss and in the case of a canonical plt entry it is in .plt. This function
// replaces the existing symbol with a Defined pointing to the appropriate
// location.
static void replaceWithDefined(Symbol &sym, SectionBase *sec, uint64_t value,
                               uint64_t size) {
  Symbol old = sym;

  sym.replace(Defined{sym.file, sym.getName(), sym.binding, sym.stOther,
                      sym.type, value, size, sec});

  sym.pltIndex = old.pltIndex;
  sym.gotIndex = old.gotIndex;
  sym.verdefIndex = old.verdefIndex;
  sym.ppc64BranchltIndex = old.ppc64BranchltIndex;
  sym.isPreemptible = true;
  sym.exportDynamic = true;
  sym.isUsedInRegularObj = true;
  sym.used = true;
}

// Reserve space in .bss or .bss.rel.ro for copy relocation.
//
// The copy relocation is pretty much a hack. If you use a copy relocation
// in your program, not only the symbol name but the symbol's size, RW/RO
// bit and alignment become part of the ABI. In addition to that, if the
// symbol has aliases, the aliases become part of the ABI. That's subtle,
// but if you violate that implicit ABI, that can cause very counter-
// intuitive consequences.
//
// So, what is the copy relocation? It's for linking non-position
// independent code to DSOs. In an ideal world, all references to data
// exported by DSOs should go indirectly through GOT. But if object files
// are compiled as non-PIC, all data references are direct. There is no
// way for the linker to transform the code to use GOT, as machine
// instructions are already set in stone in object files. This is where
// the copy relocation takes a role.
//
// A copy relocation instructs the dynamic linker to copy data from a DSO
// to a specified address (which is usually in .bss) at load-time. If the
// static linker (that's us) finds a direct data reference to a DSO
// symbol, it creates a copy relocation, so that the symbol can be
// resolved as if it were in .bss rather than in a DSO.
//
// As you can see in this function, we create a copy relocation for the
// dynamic linker, and the relocation contains not only symbol name but
// various other informtion about the symbol. So, such attributes become a
// part of the ABI.
//
// Note for application developers: I can give you a piece of advice if
// you are writing a shared library. You probably should export only
// functions from your library. You shouldn't export variables.
//
// As an example what can happen when you export variables without knowing
// the semantics of copy relocations, assume that you have an exported
// variable of type T. It is an ABI-breaking change to add new members at
// end of T even though doing that doesn't change the layout of the
// existing members. That's because the space for the new members are not
// reserved in .bss unless you recompile the main program. That means they
// are likely to overlap with other data that happens to be laid out next
// to the variable in .bss. This kind of issue is sometimes very hard to
// debug. What's a solution? Instead of exporting a varaible V from a DSO,
// define an accessor getV().
template <class ELFT> static void addCopyRelSymbol(SharedSymbol &ss) {
  // Copy relocation against zero-sized symbol doesn't make sense.
  uint64_t symSize = ss.getSize();
  if (symSize == 0 || ss.alignment == 0)
    fatal("cannot create a copy relocation for symbol " + toString(ss));

  // See if this symbol is in a read-only segment. If so, preserve the symbol's
  // memory protection by reserving space in the .bss.rel.ro section.
  bool isRO = isReadOnly<ELFT>(ss);
  BssSection *sec =
      make<BssSection>(isRO ? ".bss.rel.ro" : ".bss", symSize, ss.alignment);
  if (isRO)
    in.bssRelRo->getParent()->addSection(sec);
  else
    in.bss->getParent()->addSection(sec);

  // Look through the DSO's dynamic symbol table for aliases and create a
  // dynamic symbol for each one. This causes the copy relocation to correctly
  // interpose any aliases.
  for (SharedSymbol *sym : getSymbolsAt<ELFT>(ss))
    replaceWithDefined(*sym, sec, 0, sym->size);

  mainPart->relaDyn->addReloc(target->copyRel, sec, 0, &ss);
}

// MIPS has an odd notion of "paired" relocations to calculate addends.
// For example, if a relocation is of R_MIPS_HI16, there must be a
// R_MIPS_LO16 relocation after that, and an addend is calculated using
// the two relocations.
template <class ELFT, class RelTy>
static int64_t computeMipsAddend(const RelTy &rel, const RelTy *end,
                                 InputSectionBase &sec, RelExpr expr,
                                 bool isLocal) {
  if (expr == R_MIPS_GOTREL && isLocal)
    return sec.getFile<ELFT>()->mipsGp0;

  // The ABI says that the paired relocation is used only for REL.
  // See p. 4-17 at ftp://www.linux-mips.org/pub/linux/mips/doc/ABI/mipsabi.pdf
  if (RelTy::IsRela)
    return 0;

  RelType type = rel.getType(config->isMips64EL);
  uint32_t pairTy = getMipsPairType(type, isLocal);
  if (pairTy == R_MIPS_NONE)
    return 0;

  const uint8_t *buf = sec.data().data();
  uint32_t symIndex = rel.getSymbol(config->isMips64EL);

  // To make things worse, paired relocations might not be contiguous in
  // the relocation table, so we need to do linear search. *sigh*
  for (const RelTy *ri = &rel; ri != end; ++ri)
    if (ri->getType(config->isMips64EL) == pairTy &&
        ri->getSymbol(config->isMips64EL) == symIndex)
      return target->getImplicitAddend(buf + ri->r_offset, pairTy);

  warn("can't find matching " + toString(pairTy) + " relocation for " +
       toString(type));
  return 0;
}

// Returns an addend of a given relocation. If it is RELA, an addend
// is in a relocation itself. If it is REL, we need to read it from an
// input section.
template <class ELFT, class RelTy>
static int64_t computeAddend(const RelTy &rel, const RelTy *end,
                             InputSectionBase &sec, RelExpr expr,
                             bool isLocal) {
  int64_t addend;
  RelType type = rel.getType(config->isMips64EL);

  if (RelTy::IsRela) {
    addend = getAddend<ELFT>(rel);
  } else {
    const uint8_t *buf = sec.data().data();
    addend = target->getImplicitAddend(buf + rel.r_offset, type);
  }

  if (config->emachine == EM_PPC64 && config->isPic && type == R_PPC64_TOC)
    addend += getPPC64TocBase();
  if (config->emachine == EM_MIPS)
    addend += computeMipsAddend<ELFT>(rel, end, sec, expr, isLocal);

  return addend;
}

// Custom error message if Sym is defined in a discarded section.
template <class ELFT>
static std::string maybeReportDiscarded(Undefined &sym) {
  auto *file = dyn_cast_or_null<ObjFile<ELFT>>(sym.file);
  if (!file || !sym.discardedSecIdx ||
      file->getSections()[sym.discardedSecIdx] != &InputSection::discarded)
    return "";
  ArrayRef<Elf_Shdr_Impl<ELFT>> objSections =
      CHECK(file->getObj().sections(), file);

  std::string msg;
  if (sym.type == ELF::STT_SECTION) {
    msg = "relocation refers to a discarded section: ";
    msg += CHECK(
        file->getObj().getSectionName(&objSections[sym.discardedSecIdx]), file);
  } else {
    msg = "relocation refers to a symbol in a discarded section: " +
          toString(sym);
  }
  msg += "\n>>> defined in " + toString(file);

  Elf_Shdr_Impl<ELFT> elfSec = objSections[sym.discardedSecIdx - 1];
  if (elfSec.sh_type != SHT_GROUP)
    return msg;

  // If the discarded section is a COMDAT.
  StringRef signature = file->getShtGroupSignature(objSections, elfSec);
  if (const InputFile *prevailing =
          symtab->comdatGroups.lookup(CachedHashStringRef(signature)))
    msg += "\n>>> section group signature: " + signature.str() +
           "\n>>> prevailing definition is in " + toString(prevailing);
  return msg;
}

// Undefined diagnostics are collected in a vector and emitted once all of
// them are known, so that some postprocessing on the list of undefined symbols
// can happen before lld emits diagnostics.
struct UndefinedDiag {
  Symbol *sym;
  struct Loc {
    InputSectionBase *sec;
    uint64_t offset;
  };
  std::vector<Loc> locs;
  bool isWarning;
};

static std::vector<UndefinedDiag> undefs;

template <class ELFT>
static void reportUndefinedSymbol(const UndefinedDiag &undef) {
  Symbol &sym = *undef.sym;

  auto visibility = [&]() -> std::string {
    switch (sym.visibility) {
    case STV_INTERNAL:
      return "internal ";
    case STV_HIDDEN:
      return "hidden ";
    case STV_PROTECTED:
      return "protected ";
    default:
      return "";
    }
  };

  std::string msg = maybeReportDiscarded<ELFT>(cast<Undefined>(sym));
  if (msg.empty())
    msg = "undefined " + visibility() + "symbol: " + toString(sym);

  const size_t maxUndefReferences = 10;
  size_t i = 0;
  for (UndefinedDiag::Loc l : undef.locs) {
    if (i >= maxUndefReferences)
      break;
    InputSectionBase &sec = *l.sec;
    uint64_t offset = l.offset;

    msg += "\n>>> referenced by ";
    std::string src = sec.getSrcMsg(sym, offset);
    if (!src.empty())
      msg += src + "\n>>>               ";
    msg += sec.getObjMsg(offset);
    i++;
  }

  if (i < undef.locs.size())
    msg += ("\n>>> referenced " + Twine(undef.locs.size() - i) + " more times")
               .str();

  if (sym.getName().startswith("_ZTV"))
    msg += "\nthe vtable symbol may be undefined because the class is missing "
           "its key function (see https://lld.llvm.org/missingkeyfunction)";

  if (undef.isWarning)
    warn(msg);
  else
    error(msg);
}

template <class ELFT> void elf::reportUndefinedSymbols() {
  // Find the first "undefined symbol" diagnostic for each diagnostic, and
  // collect all "referenced from" lines at the first diagnostic.
  DenseMap<Symbol *, UndefinedDiag *> firstRef;
  for (UndefinedDiag &undef : undefs) {
    assert(undef.locs.size() == 1);
    if (UndefinedDiag *canon = firstRef.lookup(undef.sym)) {
      canon->locs.push_back(undef.locs[0]);
      undef.locs.clear();
    } else
      firstRef[undef.sym] = &undef;
  }

  for (const UndefinedDiag &undef : undefs) {
    if (!undef.locs.empty())
      reportUndefinedSymbol<ELFT>(undef);
  }
  undefs.clear();
}

// Report an undefined symbol if necessary.
// Returns true if the undefined symbol will produce an error message.
template <class ELFT>
static bool maybeReportUndefined(Symbol &sym, InputSectionBase &sec,
                                 uint64_t offset) {
  if (!sym.isUndefined() || sym.isWeak())
    return false;

  bool canBeExternal = !sym.isLocal() && sym.computeBinding() != STB_LOCAL &&
                       sym.visibility == STV_DEFAULT;
  if (config->unresolvedSymbols == UnresolvedPolicy::Ignore && canBeExternal)
    return false;

  // clang (as of 2019-06-12) / gcc (as of 8.2.1) PPC64 may emit a .rela.toc
  // which references a switch table in a discarded .rodata/.text section. The
  // .toc and the .rela.toc are incorrectly not placed in the comdat. The ELF
  // spec says references from outside the group to a STB_LOCAL symbol are not
  // allowed. Work around the bug.
  if (config->emachine == EM_PPC64 &&
      cast<Undefined>(sym).discardedSecIdx != 0 && sec.name == ".toc")
    return false;

  bool isWarning =
      (config->unresolvedSymbols == UnresolvedPolicy::Warn && canBeExternal) ||
      config->noinhibitExec;
  undefs.push_back({&sym, {{&sec, offset}}, isWarning});
  return !isWarning;
}

// MIPS N32 ABI treats series of successive relocations with the same offset
// as a single relocation. The similar approach used by N64 ABI, but this ABI
// packs all relocations into the single relocation record. Here we emulate
// this for the N32 ABI. Iterate over relocation with the same offset and put
// theirs types into the single bit-set.
template <class RelTy> static RelType getMipsN32RelType(RelTy *&rel, RelTy *end) {
  RelType type = 0;
  uint64_t offset = rel->r_offset;

  int n = 0;
  while (rel != end && rel->r_offset == offset)
    type |= (rel++)->getType(config->isMips64EL) << (8 * n++);
  return type;
}

// .eh_frame sections are mergeable input sections, so their input
// offsets are not linearly mapped to output section. For each input
// offset, we need to find a section piece containing the offset and
// add the piece's base address to the input offset to compute the
// output offset. That isn't cheap.
//
// This class is to speed up the offset computation. When we process
// relocations, we access offsets in the monotonically increasing
// order. So we can optimize for that access pattern.
//
// For sections other than .eh_frame, this class doesn't do anything.
namespace {
class OffsetGetter {
public:
  explicit OffsetGetter(InputSectionBase &sec) {
    if (auto *eh = dyn_cast<EhInputSection>(&sec))
      pieces = eh->pieces;
  }

  // Translates offsets in input sections to offsets in output sections.
  // Given offset must increase monotonically. We assume that Piece is
  // sorted by inputOff.
  uint64_t get(uint64_t off) {
    if (pieces.empty())
      return off;

    while (i != pieces.size() && pieces[i].inputOff + pieces[i].size <= off)
      ++i;
    if (i == pieces.size())
      fatal(".eh_frame: relocation is not in any piece");

    // Pieces must be contiguous, so there must be no holes in between.
    assert(pieces[i].inputOff <= off && "Relocation not in any piece");

    // Offset -1 means that the piece is dead (i.e. garbage collected).
    if (pieces[i].outputOff == -1)
      return -1;
    return pieces[i].outputOff + off - pieces[i].inputOff;
  }

private:
  ArrayRef<EhSectionPiece> pieces;
  size_t i = 0;
};
} // namespace

static void addRelativeReloc(InputSectionBase *isec, uint64_t offsetInSec,
                             Symbol *sym, int64_t addend, RelExpr expr,
                             RelType type) {
  Partition &part = isec->getPartition();

  // Add a relative relocation. If relrDyn section is enabled, and the
  // relocation offset is guaranteed to be even, add the relocation to
  // the relrDyn section, otherwise add it to the relaDyn section.
  // relrDyn sections don't support odd offsets. Also, relrDyn sections
  // don't store the addend values, so we must write it to the relocated
  // address.
  if (part.relrDyn && isec->alignment >= 2 && offsetInSec % 2 == 0) {
    isec->relocations.push_back({expr, type, offsetInSec, addend, sym});
    part.relrDyn->relocs.push_back({isec, offsetInSec});
    return;
  }
  part.relaDyn->addReloc(target->relativeRel, isec, offsetInSec, sym, addend,
                         expr, type);
}

template <class ELFT, class GotPltSection>
static void addPltEntry(PltSection *plt, GotPltSection *gotPlt,
                        RelocationBaseSection *rel, RelType type, Symbol &sym) {
  plt->addEntry<ELFT>(sym);
  gotPlt->addEntry(sym);
  rel->addReloc(
      {type, gotPlt, sym.getGotPltOffset(), !sym.isPreemptible, &sym, 0});
}

static void addGotEntry(Symbol &sym) {
  in.got->addEntry(sym);

  RelExpr expr = sym.isTls() ? R_TLS : R_ABS;
  uint64_t off = sym.getGotOffset();

  // If a GOT slot value can be calculated at link-time, which is now,
  // we can just fill that out.
  //
  // (We don't actually write a value to a GOT slot right now, but we
  // add a static relocation to a Relocations vector so that
  // InputSection::relocate will do the work for us. We may be able
  // to just write a value now, but it is a TODO.)
  bool isLinkTimeConstant =
      !sym.isPreemptible && (!config->isPic || isAbsolute(sym));
  if (isLinkTimeConstant) {
    in.got->relocations.push_back({expr, target->symbolicRel, off, 0, &sym});
    return;
  }

  // Otherwise, we emit a dynamic relocation to .rel[a].dyn so that
  // the GOT slot will be fixed at load-time.
  if (!sym.isTls() && !sym.isPreemptible && config->isPic && !isAbsolute(sym)) {
    addRelativeReloc(in.got, off, &sym, 0, R_ABS, target->symbolicRel);
    return;
  }
  mainPart->relaDyn->addReloc(
      sym.isTls() ? target->tlsGotRel : target->gotRel, in.got, off, &sym, 0,
      sym.isPreemptible ? R_ADDEND : R_ABS, target->symbolicRel);
}

// Return true if we can define a symbol in the executable that
// contains the value/function of a symbol defined in a shared
// library.
static bool canDefineSymbolInExecutable(Symbol &sym) {
  // If the symbol has default visibility the symbol defined in the
  // executable will preempt it.
  // Note that we want the visibility of the shared symbol itself, not
  // the visibility of the symbol in the output file we are producing. That is
  // why we use Sym.stOther.
  if ((sym.stOther & 0x3) == STV_DEFAULT)
    return true;

  // If we are allowed to break address equality of functions, defining
  // a plt entry will allow the program to call the function in the
  // .so, but the .so and the executable will no agree on the address
  // of the function. Similar logic for objects.
  return ((sym.isFunc() && config->ignoreFunctionAddressEquality) ||
          (sym.isObject() && config->ignoreDataAddressEquality));
}

// The reason we have to do this early scan is as follows
// * To mmap the output file, we need to know the size
// * For that, we need to know how many dynamic relocs we will have.
// It might be possible to avoid this by outputting the file with write:
// * Write the allocated output sections, computing addresses.
// * Apply relocations, recording which ones require a dynamic reloc.
// * Write the dynamic relocations.
// * Write the rest of the file.
// This would have some drawbacks. For example, we would only know if .rela.dyn
// is needed after applying relocations. If it is, it will go after rw and rx
// sections. Given that it is ro, we will need an extra PT_LOAD. This
// complicates things for the dynamic linker and means we would have to reserve
// space for the extra PT_LOAD even if we end up not using it.
template <class ELFT, class RelTy>
static void processRelocAux(InputSectionBase &sec, RelExpr expr, RelType type,
                            uint64_t offset, Symbol &sym, const RelTy &rel,
                            int64_t addend) {
  // If the relocation is known to be a link-time constant, we know no dynamic
  // relocation will be created, pass the control to relocateAlloc() or
  // relocateNonAlloc() to resolve it.
  //
  // The behavior of an undefined weak reference is implementation defined. If
  // the relocation is to a weak undef, and we are producing an executable, let
  // relocate{,Non}Alloc() resolve it.
  if (isStaticLinkTimeConstant(expr, type, sym, sec, offset) ||
      (!config->shared && sym.isUndefWeak())) {
    sec.relocations.push_back({expr, type, offset, addend, &sym});
    return;
  }

  bool canWrite = (sec.flags & SHF_WRITE) || !config->zText;
  if (canWrite) {
    RelType rel = target->getDynRel(type);
    if (expr == R_GOT || (rel == target->symbolicRel && !sym.isPreemptible)) {
      addRelativeReloc(&sec, offset, &sym, addend, expr, type);
      return;
    } else if (rel != 0) {
      if (config->emachine == EM_MIPS && rel == target->symbolicRel)
        rel = target->relativeRel;
      sec.getPartition().relaDyn->addReloc(rel, &sec, offset, &sym, addend,
                                           R_ADDEND, type);

      // MIPS ABI turns using of GOT and dynamic relocations inside out.
      // While regular ABI uses dynamic relocations to fill up GOT entries
      // MIPS ABI requires dynamic linker to fills up GOT entries using
      // specially sorted dynamic symbol table. This affects even dynamic
      // relocations against symbols which do not require GOT entries
      // creation explicitly, i.e. do not have any GOT-relocations. So if
      // a preemptible symbol has a dynamic relocation we anyway have
      // to create a GOT entry for it.
      // If a non-preemptible symbol has a dynamic relocation against it,
      // dynamic linker takes it st_value, adds offset and writes down
      // result of the dynamic relocation. In case of preemptible symbol
      // dynamic linker performs symbol resolution, writes the symbol value
      // to the GOT entry and reads the GOT entry when it needs to perform
      // a dynamic relocation.
      // ftp://www.linux-mips.org/pub/linux/mips/doc/ABI/mipsabi.pdf p.4-19
      if (config->emachine == EM_MIPS)
        in.mipsGot->addEntry(*sec.file, sym, addend, expr);
      return;
    }
  }

  if (!canWrite && (config->isPic && !isRelExpr(expr))) {
    error(
        "can't create dynamic relocation " + toString(type) + " against " +
        (sym.getName().empty() ? "local symbol" : "symbol: " + toString(sym)) +
        " in readonly segment; recompile object files with -fPIC "
        "or pass '-Wl,-z,notext' to allow text relocations in the output" +
        getLocation(sec, sym, offset));
    return;
  }

  // Copy relocations (for STT_OBJECT) and canonical PLT (for STT_FUNC) are only
  // possible in an executable.
  //
  // Among R_ABS relocatoin types, symbolicRel has the same size as the word
  // size. Others have fewer bits and may cause runtime overflow in -pie/-shared
  // mode. Disallow them.
  if (config->shared ||
      (config->pie && expr == R_ABS && type != target->symbolicRel)) {
    errorOrWarn(
        "relocation " + toString(type) + " cannot be used against " +
        (sym.getName().empty() ? "local symbol" : "symbol " + toString(sym)) +
        "; recompile with -fPIC" + getLocation(sec, sym, offset));
    return;
  }

  // If the symbol is undefined we already reported any relevant errors.
  if (sym.isUndefined())
    return;

  if (!canDefineSymbolInExecutable(sym)) {
    error("cannot preempt symbol: " + toString(sym) +
          getLocation(sec, sym, offset));
    return;
  }

  if (sym.isObject()) {
    // Produce a copy relocation.
    if (auto *ss = dyn_cast<SharedSymbol>(&sym)) {
      if (!config->zCopyreloc)
        error("unresolvable relocation " + toString(type) +
              " against symbol '" + toString(*ss) +
              "'; recompile with -fPIC or remove '-z nocopyreloc'" +
              getLocation(sec, sym, offset));
      addCopyRelSymbol<ELFT>(*ss);
    }
    sec.relocations.push_back({expr, type, offset, addend, &sym});
    return;
  }

  if (sym.isFunc()) {
    // This handles a non PIC program call to function in a shared library. In
    // an ideal world, we could just report an error saying the relocation can
    // overflow at runtime. In the real world with glibc, crt1.o has a
    // R_X86_64_PC32 pointing to libc.so.
    //
    // The general idea on how to handle such cases is to create a PLT entry and
    // use that as the function value.
    //
    // For the static linking part, we just return a plt expr and everything
    // else will use the PLT entry as the address.
    //
    // The remaining problem is making sure pointer equality still works. We
    // need the help of the dynamic linker for that. We let it know that we have
    // a direct reference to a so symbol by creating an undefined symbol with a
    // non zero st_value. Seeing that, the dynamic linker resolves the symbol to
    // the value of the symbol we created. This is true even for got entries, so
    // pointer equality is maintained. To avoid an infinite loop, the only entry
    // that points to the real function is a dedicated got entry used by the
    // plt. That is identified by special relocation types (R_X86_64_JUMP_SLOT,
    // R_386_JMP_SLOT, etc).

    // For position independent executable on i386, the plt entry requires ebx
    // to be set. This causes two problems:
    // * If some code has a direct reference to a function, it was probably
    //   compiled without -fPIE/-fPIC and doesn't maintain ebx.
    // * If a library definition gets preempted to the executable, it will have
    //   the wrong ebx value.
    if (config->pie && config->emachine == EM_386)
      errorOrWarn("symbol '" + toString(sym) +
                  "' cannot be preempted; recompile with -fPIE" +
                  getLocation(sec, sym, offset));
    if (!sym.isInPlt())
      addPltEntry<ELFT>(in.plt, in.gotPlt, in.relaPlt, target->pltRel, sym);
    if (!sym.isDefined())
      replaceWithDefined(
          sym, in.plt,
          target->pltHeaderSize + target->pltEntrySize * sym.pltIndex, 0);
    sym.needsPltAddr = true;
    sec.relocations.push_back({expr, type, offset, addend, &sym});
    return;
  }

  errorOrWarn("symbol '" + toString(sym) + "' has no type" +
              getLocation(sec, sym, offset));
}

struct IRelativeReloc {
  RelType type;
  InputSectionBase *sec;
  uint64_t offset;
  Symbol *sym;
};

static std::vector<IRelativeReloc> iRelativeRelocs;

template <class ELFT, class RelTy>
static void scanReloc(InputSectionBase &sec, OffsetGetter &getOffset, RelTy *&i,
                      RelTy *end) {
  const RelTy &rel = *i;
  uint32_t symIndex = rel.getSymbol(config->isMips64EL);
  Symbol &sym = sec.getFile<ELFT>()->getSymbol(symIndex);
  RelType type;

  // Deal with MIPS oddity.
  if (config->mipsN32Abi) {
    type = getMipsN32RelType(i, end);
  } else {
    type = rel.getType(config->isMips64EL);
    ++i;
  }

  // Get an offset in an output section this relocation is applied to.
  uint64_t offset = getOffset.get(rel.r_offset);
  if (offset == uint64_t(-1))
    return;

  // Error if the target symbol is undefined. Symbol index 0 may be used by
  // marker relocations, e.g. R_*_NONE and R_ARM_V4BX. Don't error on them.
  if (symIndex != 0 && maybeReportUndefined<ELFT>(sym, sec, rel.r_offset))
    return;

  const uint8_t *relocatedAddr = sec.data().begin() + rel.r_offset;
  RelExpr expr = target->getRelExpr(type, sym, relocatedAddr);

  // Ignore "hint" relocations because they are only markers for relaxation.
  if (oneof<R_HINT, R_NONE>(expr))
    return;

  // We can separate the small code model relocations into 2 categories:
  // 1) Those that access the compiler generated .toc sections.
  // 2) Those that access the linker allocated got entries.
  // lld allocates got entries to symbols on demand. Since we don't try to sort
  // the got entries in any way, we don't have to track which objects have
  // got-based small code model relocs. The .toc sections get placed after the
  // end of the linker allocated .got section and we do sort those so sections
  // addressed with small code model relocations come first.
  if (config->emachine == EM_PPC64 && isPPC64SmallCodeModelTocReloc(type))
    sec.file->ppc64SmallCodeModelTocRelocs = true;

  if (sym.isGnuIFunc() && !config->zText && config->warnIfuncTextrel) {
    warn("using ifunc symbols when text relocations are allowed may produce "
         "a binary that will segfault, if the object file is linked with "
         "old version of glibc (glibc 2.28 and earlier). If this applies to "
         "you, consider recompiling the object files without -fPIC and "
         "without -Wl,-z,notext option. Use -no-warn-ifunc-textrel to "
         "turn off this warning." +
         getLocation(sec, sym, offset));
  }

  // Read an addend.
  int64_t addend = computeAddend<ELFT>(rel, end, sec, expr, sym.isLocal());

  // Relax relocations.
  //
  // If we know that a PLT entry will be resolved within the same ELF module, we
  // can skip PLT access and directly jump to the destination function. For
  // example, if we are linking a main exectuable, all dynamic symbols that can
  // be resolved within the executable will actually be resolved that way at
  // runtime, because the main exectuable is always at the beginning of a search
  // list. We can leverage that fact.
  if (!sym.isPreemptible && (!sym.isGnuIFunc() || config->zIfuncNoplt)) {
    if (expr == R_GOT_PC && !isAbsoluteValue(sym)) {
      expr = target->adjustRelaxExpr(type, relocatedAddr, expr);
    } else {
      // Addend of R_PPC_PLTREL24 is used to choose call stub type. It should be
      // ignored if optimized to R_PC.
      if (config->emachine == EM_PPC && expr == R_PPC32_PLTREL)
        addend = 0;
      expr = fromPlt(expr);
    }
  }

  // If the relocation does not emit a GOT or GOTPLT entry but its computation
  // uses their addresses, we need GOT or GOTPLT to be created.
  //
  // The 4 types that relative GOTPLT are all x86 and x86-64 specific.
  if (oneof<R_GOTPLTONLY_PC, R_GOTPLTREL, R_GOTPLT, R_TLSGD_GOTPLT>(expr)) {
    in.gotPlt->hasGotPltOffRel = true;
  } else if (oneof<R_GOTONLY_PC, R_GOTREL, R_PPC64_TOCBASE, R_PPC64_RELAX_TOC>(
                 expr)) {
    in.got->hasGotOffRel = true;
  }

  // Process some TLS relocations, including relaxing TLS relocations.
  // Note that this function does not handle all TLS relocations.
  if (unsigned processed =
          handleTlsRelocation<ELFT>(type, sym, sec, offset, addend, expr)) {
    i += (processed - 1);
    return;
  }

  // We were asked not to generate PLT entries for ifuncs. Instead, pass the
  // direct relocation on through.
  if (sym.isGnuIFunc() && config->zIfuncNoplt) {
    sym.exportDynamic = true;
    mainPart->relaDyn->addReloc(type, &sec, offset, &sym, addend, R_ADDEND, type);
    return;
  }

  // Non-preemptible ifuncs require special handling. First, handle the usual
  // case where the symbol isn't one of these.
  if (!sym.isGnuIFunc() || sym.isPreemptible) {
    // If a relocation needs PLT, we create PLT and GOTPLT slots for the symbol.
    if (needsPlt(expr) && !sym.isInPlt())
      addPltEntry<ELFT>(in.plt, in.gotPlt, in.relaPlt, target->pltRel, sym);

    // Create a GOT slot if a relocation needs GOT.
    if (needsGot(expr)) {
      if (config->emachine == EM_MIPS) {
        // MIPS ABI has special rules to process GOT entries and doesn't
        // require relocation entries for them. A special case is TLS
        // relocations. In that case dynamic loader applies dynamic
        // relocations to initialize TLS GOT entries.
        // See "Global Offset Table" in Chapter 5 in the following document
        // for detailed description:
        // ftp://www.linux-mips.org/pub/linux/mips/doc/ABI/mipsabi.pdf
        in.mipsGot->addEntry(*sec.file, sym, addend, expr);
      } else if (!sym.isInGot()) {
        addGotEntry(sym);
      }
    }
  } else {
    // Handle a reference to a non-preemptible ifunc. These are special in a
    // few ways:
    //
    // - Unlike most non-preemptible symbols, non-preemptible ifuncs do not have
    //   a fixed value. But assuming that all references to the ifunc are
    //   GOT-generating or PLT-generating, the handling of an ifunc is
    //   relatively straightforward. We create a PLT entry in Iplt, which is
    //   usually at the end of .plt, which makes an indirect call using a
    //   matching GOT entry in igotPlt, which is usually at the end of .got.plt.
    //   The GOT entry is relocated using an IRELATIVE relocation in relaIplt,
    //   which is usually at the end of .rela.plt. Unlike most relocations in
    //   .rela.plt, which may be evaluated lazily without -z now, dynamic
    //   loaders evaluate IRELATIVE relocs eagerly, which means that for
    //   IRELATIVE relocs only, GOT-generating relocations can point directly to
    //   .got.plt without requiring a separate GOT entry.
    //
    // - Despite the fact that an ifunc does not have a fixed value, compilers
    //   that are not passed -fPIC will assume that they do, and will emit
    //   direct (non-GOT-generating, non-PLT-generating) relocations to the
    //   symbol. This means that if a direct relocation to the symbol is
    //   seen, the linker must set a value for the symbol, and this value must
    //   be consistent no matter what type of reference is made to the symbol.
    //   This can be done by creating a PLT entry for the symbol in the way
    //   described above and making it canonical, that is, making all references
    //   point to the PLT entry instead of the resolver. In lld we also store
    //   the address of the PLT entry in the dynamic symbol table, which means
    //   that the symbol will also have the same value in other modules.
    //   Because the value loaded from the GOT needs to be consistent with
    //   the value computed using a direct relocation, a non-preemptible ifunc
    //   may end up with two GOT entries, one in .got.plt that points to the
    //   address returned by the resolver and is used only by the PLT entry,
    //   and another in .got that points to the PLT entry and is used by
    //   GOT-generating relocations.
    //
    // - The fact that these symbols do not have a fixed value makes them an
    //   exception to the general rule that a statically linked executable does
    //   not require any form of dynamic relocation. To handle these relocations
    //   correctly, the IRELATIVE relocations are stored in an array which a
    //   statically linked executable's startup code must enumerate using the
    //   linker-defined symbols __rela?_iplt_{start,end}.
    //
    // - An absolute relocation to a non-preemptible ifunc (such as a global
    //   variable containing a pointer to the ifunc) needs to be relocated in
    //   the exact same way as a GOT entry, so we can avoid needing to make the
    //   PLT entry canonical by translating such relocations into IRELATIVE
    //   relocations in the relaIplt.
    if (!sym.isInPlt()) {
      // Create PLT and GOTPLT slots for the symbol.
      sym.isInIplt = true;

      // Create a copy of the symbol to use as the target of the IRELATIVE
      // relocation in the igotPlt. This is in case we make the PLT canonical
      // later, which would overwrite the original symbol.
      //
      // FIXME: Creating a copy of the symbol here is a bit of a hack. All
      // that's really needed to create the IRELATIVE is the section and value,
      // so ideally we should just need to copy those.
      auto *directSym = make<Defined>(cast<Defined>(sym));
      addPltEntry<ELFT>(in.iplt, in.igotPlt, in.relaIplt, target->iRelativeRel,
                        *directSym);
      sym.pltIndex = directSym->pltIndex;
    }
    if (expr == R_ABS && addend == 0 && (sec.flags & SHF_WRITE)) {
      // We might be able to represent this as an IRELATIVE. But we don't know
      // yet whether some later relocation will make the symbol point to a
      // canonical PLT, which would make this either a dynamic RELATIVE (PIC) or
      // static (non-PIC) relocation. So we keep a record of the information
      // required to process the relocation, and after scanRelocs() has been
      // called on all relocations, the relocation is resolved by
      // addIRelativeRelocs().
      iRelativeRelocs.push_back({type, &sec, offset, &sym});
      return;
    }
    if (needsGot(expr)) {
      // Redirect GOT accesses to point to the Igot.
      //
      // This field is also used to keep track of whether we ever needed a GOT
      // entry. If we did and we make the PLT canonical later, we'll need to
      // create a GOT entry pointing to the PLT entry for Sym.
      sym.gotInIgot = true;
    } else if (!needsPlt(expr)) {
      // Make the ifunc's PLT entry canonical by changing the value of its
      // symbol to redirect all references to point to it.
      unsigned entryOffset = sym.pltIndex * target->pltEntrySize;
      if (config->zRetpolineplt)
        entryOffset += target->pltHeaderSize;

      auto &d = cast<Defined>(sym);
      d.section = in.iplt;
      d.value = entryOffset;
      d.size = 0;
      // It's important to set the symbol type here so that dynamic loaders
      // don't try to call the PLT as if it were an ifunc resolver.
      d.type = STT_FUNC;

      if (sym.gotInIgot) {
        // We previously encountered a GOT generating reference that we
        // redirected to the Igot. Now that the PLT entry is canonical we must
        // clear the redirection to the Igot and add a GOT entry. As we've
        // changed the symbol type to STT_FUNC future GOT generating references
        // will naturally use this GOT entry.
        //
        // We don't need to worry about creating a MIPS GOT here because ifuncs
        // aren't a thing on MIPS.
        sym.gotInIgot = false;
        addGotEntry(sym);
      }
    }
  }

  processRelocAux<ELFT>(sec, expr, type, offset, sym, rel, addend);
}

template <class ELFT, class RelTy>
static void scanRelocs(InputSectionBase &sec, ArrayRef<RelTy> rels) {
  OffsetGetter getOffset(sec);

  // Not all relocations end up in Sec.Relocations, but a lot do.
  sec.relocations.reserve(rels.size());

  for (auto i = rels.begin(), end = rels.end(); i != end;)
    scanReloc<ELFT>(sec, getOffset, i, end);

  // Sort relocations by offset for more efficient searching for
  // R_RISCV_PCREL_HI20 and R_PPC64_ADDR64.
  if (config->emachine == EM_RISCV ||
      (config->emachine == EM_PPC64 && sec.name == ".toc"))
    llvm::stable_sort(sec.relocations,
                      [](const Relocation &lhs, const Relocation &rhs) {
                        return lhs.offset < rhs.offset;
                      });
}

template <class ELFT> void elf::scanRelocations(InputSectionBase &s) {
  if (s.areRelocsRela)
    scanRelocs<ELFT>(s, s.relas<ELFT>());
  else
    scanRelocs<ELFT>(s, s.rels<ELFT>());
}

// Figure out which representation to use for any absolute relocs to
// non-preemptible ifuncs that we visited during scanRelocs().
void elf::addIRelativeRelocs() {
  for (IRelativeReloc &r : iRelativeRelocs) {
    if (r.sym->type == STT_GNU_IFUNC)
      in.relaIplt->addReloc(
          {target->iRelativeRel, r.sec, r.offset, true, r.sym, 0});
    else if (config->isPic)
      addRelativeReloc(r.sec, r.offset, r.sym, 0, R_ABS, r.type);
    else
      r.sec->relocations.push_back({R_ABS, r.type, r.offset, 0, r.sym});
  }
  iRelativeRelocs.clear();
}

static bool mergeCmp(const InputSection *a, const InputSection *b) {
  // std::merge requires a strict weak ordering.
  if (a->outSecOff < b->outSecOff)
    return true;

  if (a->outSecOff == b->outSecOff) {
    auto *ta = dyn_cast<ThunkSection>(a);
    auto *tb = dyn_cast<ThunkSection>(b);

    // Check if Thunk is immediately before any specific Target
    // InputSection for example Mips LA25 Thunks.
    if (ta && ta->getTargetInputSection() == b)
      return true;

    // Place Thunk Sections without specific targets before
    // non-Thunk Sections.
    if (ta && !tb && !ta->getTargetInputSection())
      return true;
  }

  return false;
}

// Call Fn on every executable InputSection accessed via the linker script
// InputSectionDescription::Sections.
static void forEachInputSectionDescription(
    ArrayRef<OutputSection *> outputSections,
    llvm::function_ref<void(OutputSection *, InputSectionDescription *)> fn) {
  for (OutputSection *os : outputSections) {
    if (!(os->flags & SHF_ALLOC) || !(os->flags & SHF_EXECINSTR))
      continue;
    for (BaseCommand *bc : os->sectionCommands)
      if (auto *isd = dyn_cast<InputSectionDescription>(bc))
        fn(os, isd);
  }
}

// Thunk Implementation
//
// Thunks (sometimes called stubs, veneers or branch islands) are small pieces
// of code that the linker inserts inbetween a caller and a callee. The thunks
// are added at link time rather than compile time as the decision on whether
// a thunk is needed, such as the caller and callee being out of range, can only
// be made at link time.
//
// It is straightforward to tell given the current state of the program when a
// thunk is needed for a particular call. The more difficult part is that
// the thunk needs to be placed in the program such that the caller can reach
// the thunk and the thunk can reach the callee; furthermore, adding thunks to
// the program alters addresses, which can mean more thunks etc.
//
// In lld we have a synthetic ThunkSection that can hold many Thunks.
// The decision to have a ThunkSection act as a container means that we can
// more easily handle the most common case of a single block of contiguous
// Thunks by inserting just a single ThunkSection.
//
// The implementation of Thunks in lld is split across these areas
// Relocations.cpp : Framework for creating and placing thunks
// Thunks.cpp : The code generated for each supported thunk
// Target.cpp : Target specific hooks that the framework uses to decide when
//              a thunk is used
// Synthetic.cpp : Implementation of ThunkSection
// Writer.cpp : Iteratively call framework until no more Thunks added
//
// Thunk placement requirements:
// Mips LA25 thunks. These must be placed immediately before the callee section
// We can assume that the caller is in range of the Thunk. These are modelled
// by Thunks that return the section they must precede with
// getTargetInputSection().
//
// ARM interworking and range extension thunks. These thunks must be placed
// within range of the caller. All implemented ARM thunks can always reach the
// callee as they use an indirect jump via a register that has no range
// restrictions.
//
// Thunk placement algorithm:
// For Mips LA25 ThunkSections; the placement is explicit, it has to be before
// getTargetInputSection().
//
// For thunks that must be placed within range of the caller there are many
// possible choices given that the maximum range from the caller is usually
// much larger than the average InputSection size. Desirable properties include:
// - Maximize reuse of thunks by multiple callers
// - Minimize number of ThunkSections to simplify insertion
// - Handle impact of already added Thunks on addresses
// - Simple to understand and implement
//
// In lld for the first pass, we pre-create one or more ThunkSections per
// InputSectionDescription at Target specific intervals. A ThunkSection is
// placed so that the estimated end of the ThunkSection is within range of the
// start of the InputSectionDescription or the previous ThunkSection. For
// example:
// InputSectionDescription
// Section 0
// ...
// Section N
// ThunkSection 0
// Section N + 1
// ...
// Section N + K
// Thunk Section 1
//
// The intention is that we can add a Thunk to a ThunkSection that is well
// spaced enough to service a number of callers without having to do a lot
// of work. An important principle is that it is not an error if a Thunk cannot
// be placed in a pre-created ThunkSection; when this happens we create a new
// ThunkSection placed next to the caller. This allows us to handle the vast
// majority of thunks simply, but also handle rare cases where the branch range
// is smaller than the target specific spacing.
//
// The algorithm is expected to create all the thunks that are needed in a
// single pass, with a small number of programs needing a second pass due to
// the insertion of thunks in the first pass increasing the offset between
// callers and callees that were only just in range.
//
// A consequence of allowing new ThunkSections to be created outside of the
// pre-created ThunkSections is that in rare cases calls to Thunks that were in
// range in pass K, are out of range in some pass > K due to the insertion of
// more Thunks in between the caller and callee. When this happens we retarget
// the relocation back to the original target and create another Thunk.

// Remove ThunkSections that are empty, this should only be the initial set
// precreated on pass 0.

// Insert the Thunks for OutputSection OS into their designated place
// in the Sections vector, and recalculate the InputSection output section
// offsets.
// This may invalidate any output section offsets stored outside of InputSection
void ThunkCreator::mergeThunks(ArrayRef<OutputSection *> outputSections) {
  forEachInputSectionDescription(
      outputSections, [&](OutputSection *os, InputSectionDescription *isd) {
        if (isd->thunkSections.empty())
          return;

        // Remove any zero sized precreated Thunks.
        llvm::erase_if(isd->thunkSections,
                       [](const std::pair<ThunkSection *, uint32_t> &ts) {
                         return ts.first->getSize() == 0;
                       });

        // ISD->ThunkSections contains all created ThunkSections, including
        // those inserted in previous passes. Extract the Thunks created this
        // pass and order them in ascending outSecOff.
        std::vector<ThunkSection *> newThunks;
        for (const std::pair<ThunkSection *, uint32_t> ts : isd->thunkSections)
          if (ts.second == pass)
            newThunks.push_back(ts.first);
        llvm::stable_sort(newThunks,
                          [](const ThunkSection *a, const ThunkSection *b) {
                            return a->outSecOff < b->outSecOff;
                          });

        // Merge sorted vectors of Thunks and InputSections by outSecOff
        std::vector<InputSection *> tmp;
        tmp.reserve(isd->sections.size() + newThunks.size());

        std::merge(isd->sections.begin(), isd->sections.end(),
                   newThunks.begin(), newThunks.end(), std::back_inserter(tmp),
                   mergeCmp);

        isd->sections = std::move(tmp);
      });
}

// Find or create a ThunkSection within the InputSectionDescription (ISD) that
// is in range of Src. An ISD maps to a range of InputSections described by a
// linker script section pattern such as { .text .text.* }.
ThunkSection *ThunkCreator::getISDThunkSec(OutputSection *os, InputSection *isec,
                                           InputSectionDescription *isd,
                                           uint32_t type, uint64_t src) {
  for (std::pair<ThunkSection *, uint32_t> tp : isd->thunkSections) {
    ThunkSection *ts = tp.first;
    uint64_t tsBase = os->addr + ts->outSecOff;
    uint64_t tsLimit = tsBase + ts->getSize();
    if (target->inBranchRange(type, src, (src > tsLimit) ? tsBase : tsLimit))
      return ts;
  }

  // No suitable ThunkSection exists. This can happen when there is a branch
  // with lower range than the ThunkSection spacing or when there are too
  // many Thunks. Create a new ThunkSection as close to the InputSection as
  // possible. Error if InputSection is so large we cannot place ThunkSection
  // anywhere in Range.
  uint64_t thunkSecOff = isec->outSecOff;
  if (!target->inBranchRange(type, src, os->addr + thunkSecOff)) {
    thunkSecOff = isec->outSecOff + isec->getSize();
    if (!target->inBranchRange(type, src, os->addr + thunkSecOff))
      fatal("InputSection too large for range extension thunk " +
            isec->getObjMsg(src - (os->addr + isec->outSecOff)));
  }
  return addThunkSection(os, isd, thunkSecOff);
}

// Add a Thunk that needs to be placed in a ThunkSection that immediately
// precedes its Target.
ThunkSection *ThunkCreator::getISThunkSec(InputSection *isec) {
  ThunkSection *ts = thunkedSections.lookup(isec);
  if (ts)
    return ts;

  // Find InputSectionRange within Target Output Section (TOS) that the
  // InputSection (IS) that we need to precede is in.
  OutputSection *tos = isec->getParent();
  for (BaseCommand *bc : tos->sectionCommands) {
    auto *isd = dyn_cast<InputSectionDescription>(bc);
    if (!isd || isd->sections.empty())
      continue;

    InputSection *first = isd->sections.front();
    InputSection *last = isd->sections.back();

    if (isec->outSecOff < first->outSecOff || last->outSecOff < isec->outSecOff)
      continue;

    ts = addThunkSection(tos, isd, isec->outSecOff);
    thunkedSections[isec] = ts;
    return ts;
  }

  return nullptr;
}

// Create one or more ThunkSections per OS that can be used to place Thunks.
// We attempt to place the ThunkSections using the following desirable
// properties:
// - Within range of the maximum number of callers
// - Minimise the number of ThunkSections
//
// We follow a simple but conservative heuristic to place ThunkSections at
// offsets that are multiples of a Target specific branch range.
// For an InputSectionDescription that is smaller than the range, a single
// ThunkSection at the end of the range will do.
//
// For an InputSectionDescription that is more than twice the size of the range,
// we place the last ThunkSection at range bytes from the end of the
// InputSectionDescription in order to increase the likelihood that the
// distance from a thunk to its target will be sufficiently small to
// allow for the creation of a short thunk.
void ThunkCreator::createInitialThunkSections(
    ArrayRef<OutputSection *> outputSections) {
  uint32_t thunkSectionSpacing = target->getThunkSectionSpacing();

  forEachInputSectionDescription(
      outputSections, [&](OutputSection *os, InputSectionDescription *isd) {
        if (isd->sections.empty())
          return;

        uint32_t isdBegin = isd->sections.front()->outSecOff;
        uint32_t isdEnd =
            isd->sections.back()->outSecOff + isd->sections.back()->getSize();
        uint32_t lastThunkLowerBound = -1;
        if (isdEnd - isdBegin > thunkSectionSpacing * 2)
          lastThunkLowerBound = isdEnd - thunkSectionSpacing;

        uint32_t isecLimit;
        uint32_t prevIsecLimit = isdBegin;
        uint32_t thunkUpperBound = isdBegin + thunkSectionSpacing;

        for (const InputSection *isec : isd->sections) {
          isecLimit = isec->outSecOff + isec->getSize();
          if (isecLimit > thunkUpperBound) {
            addThunkSection(os, isd, prevIsecLimit);
            thunkUpperBound = prevIsecLimit + thunkSectionSpacing;
          }
          if (isecLimit > lastThunkLowerBound)
            break;
          prevIsecLimit = isecLimit;
        }
        addThunkSection(os, isd, isecLimit);
      });
}

ThunkSection *ThunkCreator::addThunkSection(OutputSection *os,
                                            InputSectionDescription *isd,
                                            uint64_t off) {
  auto *ts = make<ThunkSection>(os, off);
  ts->partition = os->partition;
  isd->thunkSections.push_back({ts, pass});
  return ts;
}

static bool isThunkSectionCompatible(InputSection *source,
                                     SectionBase *target) {
  // We can't reuse thunks in different loadable partitions because they might
  // not be loaded. But partition 1 (the main partition) will always be loaded.
  if (source->partition != target->partition)
    return target->partition == 1;
  return true;
}

std::pair<Thunk *, bool> ThunkCreator::getThunk(InputSection *isec,
                                                Relocation &rel, uint64_t src) {
  std::vector<Thunk *> *thunkVec = nullptr;

  // We use (section, offset) pair to find the thunk position if possible so
  // that we create only one thunk for aliased symbols or ICFed sections.
  if (auto *d = dyn_cast<Defined>(rel.sym))
    if (!d->isInPlt() && d->section)
      thunkVec = &thunkedSymbolsBySection[{d->section->repl, d->value}];
  if (!thunkVec)
    thunkVec = &thunkedSymbols[rel.sym];

  // Check existing Thunks for Sym to see if they can be reused
  for (Thunk *t : *thunkVec)
    if (isThunkSectionCompatible(isec, t->getThunkTargetSym()->section) &&
        t->isCompatibleWith(*isec, rel) &&
        target->inBranchRange(rel.type, src, t->getThunkTargetSym()->getVA()))
      return std::make_pair(t, false);

  // No existing compatible Thunk in range, create a new one
  Thunk *t = addThunk(*isec, rel);
  thunkVec->push_back(t);
  return std::make_pair(t, true);
}

// Return true if the relocation target is an in range Thunk.
// Return false if the relocation is not to a Thunk. If the relocation target
// was originally to a Thunk, but is no longer in range we revert the
// relocation back to its original non-Thunk target.
bool ThunkCreator::normalizeExistingThunk(Relocation &rel, uint64_t src) {
  if (Thunk *t = thunks.lookup(rel.sym)) {
    if (target->inBranchRange(rel.type, src, rel.sym->getVA()))
      return true;
    rel.sym = &t->destination;
    if (rel.sym->isInPlt())
      rel.expr = toPlt(rel.expr);
  }
  return false;
}

// Process all relocations from the InputSections that have been assigned
// to InputSectionDescriptions and redirect through Thunks if needed. The
// function should be called iteratively until it returns false.
//
// PreConditions:
// All InputSections that may need a Thunk are reachable from
// OutputSectionCommands.
//
// All OutputSections have an address and all InputSections have an offset
// within the OutputSection.
//
// The offsets between caller (relocation place) and callee
// (relocation target) will not be modified outside of createThunks().
//
// PostConditions:
// If return value is true then ThunkSections have been inserted into
// OutputSections. All relocations that needed a Thunk based on the information
// available to createThunks() on entry have been redirected to a Thunk. Note
// that adding Thunks changes offsets between caller and callee so more Thunks
// may be required.
//
// If return value is false then no more Thunks are needed, and createThunks has
// made no changes. If the target requires range extension thunks, currently
// ARM, then any future change in offset between caller and callee risks a
// relocation out of range error.
bool ThunkCreator::createThunks(ArrayRef<OutputSection *> outputSections) {
  bool addressesChanged = false;

  if (pass == 0 && target->getThunkSectionSpacing())
    createInitialThunkSections(outputSections);

  // With Thunk Size much smaller than branch range we expect to
  // converge quickly; if we get to 10 something has gone wrong.
  if (pass == 10)
    fatal("thunk creation not converged");

  // Create all the Thunks and insert them into synthetic ThunkSections. The
  // ThunkSections are later inserted back into InputSectionDescriptions.
  // We separate the creation of ThunkSections from the insertion of the
  // ThunkSections as ThunkSections are not always inserted into the same
  // InputSectionDescription as the caller.
  forEachInputSectionDescription(
      outputSections, [&](OutputSection *os, InputSectionDescription *isd) {
        for (InputSection *isec : isd->sections)
          for (Relocation &rel : isec->relocations) {
            uint64_t src = isec->getVA(rel.offset);

            // If we are a relocation to an existing Thunk, check if it is
            // still in range. If not then Rel will be altered to point to its
            // original target so another Thunk can be generated.
            if (pass > 0 && normalizeExistingThunk(rel, src))
              continue;

            if (!target->needsThunk(rel.expr, rel.type, isec->file, src,
                                    *rel.sym))
              continue;

            Thunk *t;
            bool isNew;
            std::tie(t, isNew) = getThunk(isec, rel, src);

            if (isNew) {
              // Find or create a ThunkSection for the new Thunk
              ThunkSection *ts;
              if (auto *tis = t->getTargetInputSection())
                ts = getISThunkSec(tis);
              else
                ts = getISDThunkSec(os, isec, isd, rel.type, src);
              ts->addThunk(t);
              thunks[t->getThunkTargetSym()] = t;
            }

            // Redirect relocation to Thunk, we never go via the PLT to a Thunk
            rel.sym = t->getThunkTargetSym();
            rel.expr = fromPlt(rel.expr);

            // The addend of R_PPC_PLTREL24 should be ignored after changing to
            // R_PC.
            if (config->emachine == EM_PPC && rel.type == R_PPC_PLTREL24)
              rel.addend = 0;
          }

        for (auto &p : isd->thunkSections)
          addressesChanged |= p.first->assignOffsets();
      });

  for (auto &p : thunkedSections)
    addressesChanged |= p.second->assignOffsets();

  // Merge all created synthetic ThunkSections back into OutputSection
  mergeThunks(outputSections);
  ++pass;
  return addressesChanged;
}

template void elf::scanRelocations<ELF32LE>(InputSectionBase &);
template void elf::scanRelocations<ELF32BE>(InputSectionBase &);
template void elf::scanRelocations<ELF64LE>(InputSectionBase &);
template void elf::scanRelocations<ELF64BE>(InputSectionBase &);
template void elf::reportUndefinedSymbols<ELF32LE>();
template void elf::reportUndefinedSymbols<ELF32BE>();
template void elf::reportUndefinedSymbols<ELF64LE>();
template void elf::reportUndefinedSymbols<ELF64BE>();
