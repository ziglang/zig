//===- Relocations.cpp ----------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
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
#include "Strings.h"
#include "SymbolTable.h"
#include "Symbols.h"
#include "SyntheticSections.h"
#include "Target.h"
#include "Thunks.h"
#include "lld/Common/Memory.h"

#include "llvm/Support/Endian.h"
#include "llvm/Support/raw_ostream.h"
#include <algorithm>

using namespace llvm;
using namespace llvm::ELF;
using namespace llvm::object;
using namespace llvm::support::endian;

using namespace lld;
using namespace lld::elf;

// Construct a message in the following format.
//
// >>> defined in /home/alice/src/foo.o
// >>> referenced by bar.c:12 (/home/alice/src/bar.c:12)
// >>>               /home/alice/src/bar.o:(.text+0x1)
static std::string getLocation(InputSectionBase &S, const Symbol &Sym,
                               uint64_t Off) {
  std::string Msg =
      "\n>>> defined in " + toString(Sym.File) + "\n>>> referenced by ";
  std::string Src = S.getSrcMsg(Sym, Off);
  if (!Src.empty())
    Msg += Src + "\n>>>               ";
  return Msg + S.getObjMsg(Off);
}

// This is a MIPS-specific rule.
//
// In case of MIPS GP-relative relocations always resolve to a definition
// in a regular input file, ignoring the one-definition rule. So we,
// for example, should not attempt to create a dynamic relocation even
// if the target symbol is preemptible. There are two two MIPS GP-relative
// relocations R_MIPS_GPREL16 and R_MIPS_GPREL32. But only R_MIPS_GPREL16
// can be against a preemptible symbol.
//
// To get MIPS relocation type we apply 0xff mask. In case of O32 ABI all
// relocation types occupy eight bit. In case of N64 ABI we extract first
// relocation from 3-in-1 packet because only the first relocation can
// be against a real symbol.
static bool isMipsGprel(RelType Type) {
  if (Config->EMachine != EM_MIPS)
    return false;
  Type &= 0xff;
  return Type == R_MIPS_GPREL16 || Type == R_MICROMIPS_GPREL16 ||
         Type == R_MICROMIPS_GPREL7_S2;
}

// This function is similar to the `handleTlsRelocation`. MIPS does not
// support any relaxations for TLS relocations so by factoring out MIPS
// handling in to the separate function we can simplify the code and do not
// pollute other `handleTlsRelocation` by MIPS `ifs` statements.
// Mips has a custom MipsGotSection that handles the writing of GOT entries
// without dynamic relocations.
template <class ELFT>
static unsigned handleMipsTlsRelocation(RelType Type, Symbol &Sym,
                                        InputSectionBase &C, uint64_t Offset,
                                        int64_t Addend, RelExpr Expr) {
  if (Expr == R_MIPS_TLSLD) {
    if (InX::MipsGot->addTlsIndex() && Config->Pic)
      InX::RelaDyn->addReloc({Target->TlsModuleIndexRel, InX::MipsGot,
                              InX::MipsGot->getTlsIndexOff(), false, nullptr,
                              0});
    C.Relocations.push_back({Expr, Type, Offset, Addend, &Sym});
    return 1;
  }

  if (Expr == R_MIPS_TLSGD) {
    if (InX::MipsGot->addDynTlsEntry(Sym) && Sym.IsPreemptible) {
      uint64_t Off = InX::MipsGot->getGlobalDynOffset(Sym);
      InX::RelaDyn->addReloc(
          {Target->TlsModuleIndexRel, InX::MipsGot, Off, false, &Sym, 0});
      if (Sym.IsPreemptible)
        InX::RelaDyn->addReloc({Target->TlsOffsetRel, InX::MipsGot,
                                Off + Config->Wordsize, false, &Sym, 0});
    }
    C.Relocations.push_back({Expr, Type, Offset, Addend, &Sym});
    return 1;
  }
  return 0;
}

// This function is similar to the `handleMipsTlsRelocation`. ARM also does not
// support any relaxations for TLS relocations. ARM is logically similar to Mips
// in how it handles TLS, but Mips uses its own custom GOT which handles some
// of the cases that ARM uses GOT relocations for.
//
// We look for TLS global dynamic and local dynamic relocations, these may
// require the generation of a pair of GOT entries that have associated
// dynamic relocations. When the results of the dynamic relocations can be
// resolved at static link time we do so. This is necessary for static linking
// as there will be no dynamic loader to resolve them at load-time.
//
// The pair of GOT entries created are of the form
// GOT[e0] Module Index (Used to find pointer to TLS block at run-time)
// GOT[e1] Offset of symbol in TLS block
template <class ELFT>
static unsigned handleARMTlsRelocation(RelType Type, Symbol &Sym,
                                       InputSectionBase &C, uint64_t Offset,
                                       int64_t Addend, RelExpr Expr) {
  // The Dynamic TLS Module Index Relocation for a symbol defined in an
  // executable is always 1. If the target Symbol is not preemptible then
  // we know the offset into the TLS block at static link time.
  bool NeedDynId = Sym.IsPreemptible || Config->Shared;
  bool NeedDynOff = Sym.IsPreemptible;

  auto AddTlsReloc = [&](uint64_t Off, RelType Type, Symbol *Dest, bool Dyn) {
    if (Dyn)
      InX::RelaDyn->addReloc({Type, InX::Got, Off, false, Dest, 0});
    else
      InX::Got->Relocations.push_back({R_ABS, Type, Off, 0, Dest});
  };

  // Local Dynamic is for access to module local TLS variables, while still
  // being suitable for being dynamically loaded via dlopen.
  // GOT[e0] is the module index, with a special value of 0 for the current
  // module. GOT[e1] is unused. There only needs to be one module index entry.
  if (Expr == R_TLSLD_PC && InX::Got->addTlsIndex()) {
    AddTlsReloc(InX::Got->getTlsIndexOff(), Target->TlsModuleIndexRel,
                NeedDynId ? nullptr : &Sym, NeedDynId);
    C.Relocations.push_back({Expr, Type, Offset, Addend, &Sym});
    return 1;
  }

  // Global Dynamic is the most general purpose access model. When we know
  // the module index and offset of symbol in TLS block we can fill these in
  // using static GOT relocations.
  if (Expr == R_TLSGD_PC) {
    if (InX::Got->addDynTlsEntry(Sym)) {
      uint64_t Off = InX::Got->getGlobalDynOffset(Sym);
      AddTlsReloc(Off, Target->TlsModuleIndexRel, &Sym, NeedDynId);
      AddTlsReloc(Off + Config->Wordsize, Target->TlsOffsetRel, &Sym,
                  NeedDynOff);
    }
    C.Relocations.push_back({Expr, Type, Offset, Addend, &Sym});
    return 1;
  }
  return 0;
}

// Returns the number of relocations processed.
template <class ELFT>
static unsigned
handleTlsRelocation(RelType Type, Symbol &Sym, InputSectionBase &C,
                    typename ELFT::uint Offset, int64_t Addend, RelExpr Expr) {
  if (!(C.Flags & SHF_ALLOC))
    return 0;

  if (!Sym.isTls())
    return 0;

  if (Config->EMachine == EM_ARM)
    return handleARMTlsRelocation<ELFT>(Type, Sym, C, Offset, Addend, Expr);
  if (Config->EMachine == EM_MIPS)
    return handleMipsTlsRelocation<ELFT>(Type, Sym, C, Offset, Addend, Expr);

  if (isRelExprOneOf<R_TLSDESC, R_TLSDESC_PAGE, R_TLSDESC_CALL>(Expr) &&
      Config->Shared) {
    if (InX::Got->addDynTlsEntry(Sym)) {
      uint64_t Off = InX::Got->getGlobalDynOffset(Sym);
      InX::RelaDyn->addReloc(
          {Target->TlsDescRel, InX::Got, Off, !Sym.IsPreemptible, &Sym, 0});
    }
    if (Expr != R_TLSDESC_CALL)
      C.Relocations.push_back({Expr, Type, Offset, Addend, &Sym});
    return 1;
  }

  if (isRelExprOneOf<R_TLSLD_PC, R_TLSLD>(Expr)) {
    // Local-Dynamic relocs can be relaxed to Local-Exec.
    if (!Config->Shared) {
      C.Relocations.push_back(
          {R_RELAX_TLS_LD_TO_LE, Type, Offset, Addend, &Sym});
      return 2;
    }
    if (InX::Got->addTlsIndex())
      InX::RelaDyn->addReloc({Target->TlsModuleIndexRel, InX::Got,
                              InX::Got->getTlsIndexOff(), false, nullptr, 0});
    C.Relocations.push_back({Expr, Type, Offset, Addend, &Sym});
    return 1;
  }

  // Local-Dynamic relocs can be relaxed to Local-Exec.
  if (isRelExprOneOf<R_ABS, R_TLSLD, R_TLSLD_PC>(Expr) && !Config->Shared) {
    C.Relocations.push_back({R_RELAX_TLS_LD_TO_LE, Type, Offset, Addend, &Sym});
    return 1;
  }

  if (isRelExprOneOf<R_TLSDESC, R_TLSDESC_PAGE, R_TLSDESC_CALL, R_TLSGD,
                     R_TLSGD_PC>(Expr)) {
    if (Config->Shared) {
      if (InX::Got->addDynTlsEntry(Sym)) {
        uint64_t Off = InX::Got->getGlobalDynOffset(Sym);
        InX::RelaDyn->addReloc(
            {Target->TlsModuleIndexRel, InX::Got, Off, false, &Sym, 0});

        // If the symbol is preemptible we need the dynamic linker to write
        // the offset too.
        uint64_t OffsetOff = Off + Config->Wordsize;
        if (Sym.IsPreemptible)
          InX::RelaDyn->addReloc(
              {Target->TlsOffsetRel, InX::Got, OffsetOff, false, &Sym, 0});
        else
          InX::Got->Relocations.push_back(
              {R_ABS, Target->TlsOffsetRel, OffsetOff, 0, &Sym});
      }
      C.Relocations.push_back({Expr, Type, Offset, Addend, &Sym});
      return 1;
    }

    // Global-Dynamic relocs can be relaxed to Initial-Exec or Local-Exec
    // depending on the symbol being locally defined or not.
    if (Sym.IsPreemptible) {
      C.Relocations.push_back(
          {Target->adjustRelaxExpr(Type, nullptr, R_RELAX_TLS_GD_TO_IE), Type,
           Offset, Addend, &Sym});
      if (!Sym.isInGot()) {
        InX::Got->addEntry(Sym);
        InX::RelaDyn->addReloc(
            {Target->TlsGotRel, InX::Got, Sym.getGotOffset(), false, &Sym, 0});
      }
    } else {
      C.Relocations.push_back(
          {Target->adjustRelaxExpr(Type, nullptr, R_RELAX_TLS_GD_TO_LE), Type,
           Offset, Addend, &Sym});
    }
    return Target->TlsGdRelaxSkip;
  }

  // Initial-Exec relocs can be relaxed to Local-Exec if the symbol is locally
  // defined.
  if (isRelExprOneOf<R_GOT, R_GOT_FROM_END, R_GOT_PC, R_GOT_PAGE_PC>(Expr) &&
      !Config->Shared && !Sym.IsPreemptible) {
    C.Relocations.push_back({R_RELAX_TLS_IE_TO_LE, Type, Offset, Addend, &Sym});
    return 1;
  }

  if (Expr == R_TLSDESC_CALL)
    return 1;
  return 0;
}

static RelType getMipsPairType(RelType Type, bool IsLocal) {
  switch (Type) {
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
    return IsLocal ? R_MIPS_LO16 : R_MIPS_NONE;
  case R_MICROMIPS_GOT16:
    return IsLocal ? R_MICROMIPS_LO16 : R_MIPS_NONE;
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
static bool isAbsolute(const Symbol &Sym) {
  if (Sym.isUndefWeak())
    return true;
  if (const auto *DR = dyn_cast<Defined>(&Sym))
    return DR->Section == nullptr; // Absolute symbol.
  return false;
}

static bool isAbsoluteValue(const Symbol &Sym) {
  return isAbsolute(Sym) || Sym.isTls();
}

// Returns true if Expr refers a PLT entry.
static bool needsPlt(RelExpr Expr) {
  return isRelExprOneOf<R_PLT_PC, R_PPC_PLT_OPD, R_PLT, R_PLT_PAGE_PC>(Expr);
}

// Returns true if Expr refers a GOT entry. Note that this function
// returns false for TLS variables even though they need GOT, because
// TLS variables uses GOT differently than the regular variables.
static bool needsGot(RelExpr Expr) {
  return isRelExprOneOf<R_GOT, R_GOT_OFF, R_MIPS_GOT_LOCAL_PAGE, R_MIPS_GOT_OFF,
                        R_MIPS_GOT_OFF32, R_GOT_PAGE_PC, R_GOT_PC,
                        R_GOT_FROM_END>(Expr);
}

// True if this expression is of the form Sym - X, where X is a position in the
// file (PC, or GOT for example).
static bool isRelExpr(RelExpr Expr) {
  return isRelExprOneOf<R_PC, R_GOTREL, R_GOTREL_FROM_END, R_MIPS_GOTREL,
                        R_PAGE_PC, R_RELAX_GOT_PC>(Expr);
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
static bool isStaticLinkTimeConstant(RelExpr E, RelType Type, const Symbol &Sym,
                                     InputSectionBase &S, uint64_t RelOff) {
  // These expressions always compute a constant
  if (isRelExprOneOf<R_GOT_FROM_END, R_GOT_OFF, R_MIPS_GOT_LOCAL_PAGE,
                     R_MIPS_GOT_OFF, R_MIPS_GOT_OFF32, R_MIPS_GOT_GP_PC,
                     R_MIPS_TLSGD, R_GOT_PAGE_PC, R_GOT_PC, R_GOTONLY_PC,
                     R_GOTONLY_PC_FROM_END, R_PLT_PC, R_TLSGD_PC, R_TLSGD,
                     R_PPC_PLT_OPD, R_TLSDESC_CALL, R_TLSDESC_PAGE, R_HINT>(E))
    return true;

  // These never do, except if the entire file is position dependent or if
  // only the low bits are used.
  if (E == R_GOT || E == R_PLT || E == R_TLSDESC)
    return Target->usesOnlyLowPageBits(Type) || !Config->Pic;

  if (Sym.IsPreemptible)
    return false;
  if (!Config->Pic)
    return true;

  // The size of a non preemptible symbol is a constant.
  if (E == R_SIZE)
    return true;

  // For the target and the relocation, we want to know if they are
  // absolute or relative.
  bool AbsVal = isAbsoluteValue(Sym);
  bool RelE = isRelExpr(E);
  if (AbsVal && !RelE)
    return true;
  if (!AbsVal && RelE)
    return true;
  if (!AbsVal && !RelE)
    return Target->usesOnlyLowPageBits(Type);

  // Relative relocation to an absolute value. This is normally unrepresentable,
  // but if the relocation refers to a weak undefined symbol, we allow it to
  // resolve to the image base. This is a little strange, but it allows us to
  // link function calls to such symbols. Normally such a call will be guarded
  // with a comparison, which will load a zero from the GOT.
  // Another special case is MIPS _gp_disp symbol which represents offset
  // between start of a function and '_gp' value and defined as absolute just
  // to simplify the code.
  assert(AbsVal && RelE);
  if (Sym.isUndefWeak())
    return true;

  error("relocation " + toString(Type) + " cannot refer to absolute symbol: " +
        toString(Sym) + getLocation(S, Sym, RelOff));
  return true;
}

static RelExpr toPlt(RelExpr Expr) {
  if (Expr == R_PPC_OPD)
    return R_PPC_PLT_OPD;
  if (Expr == R_PC)
    return R_PLT_PC;
  if (Expr == R_PAGE_PC)
    return R_PLT_PAGE_PC;
  if (Expr == R_ABS)
    return R_PLT;
  return Expr;
}

static RelExpr fromPlt(RelExpr Expr) {
  // We decided not to use a plt. Optimize a reference to the plt to a
  // reference to the symbol itself.
  if (Expr == R_PLT_PC)
    return R_PC;
  if (Expr == R_PPC_PLT_OPD)
    return R_PPC_OPD;
  if (Expr == R_PLT)
    return R_ABS;
  return Expr;
}

// Returns true if a given shared symbol is in a read-only segment in a DSO.
template <class ELFT> static bool isReadOnly(SharedSymbol *SS) {
  typedef typename ELFT::Phdr Elf_Phdr;

  // Determine if the symbol is read-only by scanning the DSO's program headers.
  const SharedFile<ELFT> &File = SS->getFile<ELFT>();
  for (const Elf_Phdr &Phdr : check(File.getObj().program_headers()))
    if ((Phdr.p_type == ELF::PT_LOAD || Phdr.p_type == ELF::PT_GNU_RELRO) &&
        !(Phdr.p_flags & ELF::PF_W) && SS->Value >= Phdr.p_vaddr &&
        SS->Value < Phdr.p_vaddr + Phdr.p_memsz)
      return true;
  return false;
}

// Returns symbols at the same offset as a given symbol, including SS itself.
//
// If two or more symbols are at the same offset, and at least one of
// them are copied by a copy relocation, all of them need to be copied.
// Otherwise, they would refer different places at runtime.
template <class ELFT>
static std::vector<SharedSymbol *> getSymbolsAt(SharedSymbol *SS) {
  typedef typename ELFT::Sym Elf_Sym;

  SharedFile<ELFT> &File = SS->getFile<ELFT>();

  std::vector<SharedSymbol *> Ret;
  for (const Elf_Sym &S : File.getGlobalELFSyms()) {
    if (S.st_shndx == SHN_UNDEF || S.st_shndx == SHN_ABS ||
        S.st_value != SS->Value)
      continue;
    StringRef Name = check(S.getName(File.getStringTable()));
    Symbol *Sym = Symtab->find(Name);
    if (auto *Alias = dyn_cast_or_null<SharedSymbol>(Sym))
      Ret.push_back(Alias);
  }
  return Ret;
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
template <class ELFT> static void addCopyRelSymbol(SharedSymbol *SS) {
  // Copy relocation against zero-sized symbol doesn't make sense.
  uint64_t SymSize = SS->getSize();
  if (SymSize == 0)
    fatal("cannot create a copy relocation for symbol " + toString(*SS));

  // See if this symbol is in a read-only segment. If so, preserve the symbol's
  // memory protection by reserving space in the .bss.rel.ro section.
  bool IsReadOnly = isReadOnly<ELFT>(SS);
  BssSection *Sec = make<BssSection>(IsReadOnly ? ".bss.rel.ro" : ".bss",
                                     SymSize, SS->Alignment);
  if (IsReadOnly)
    InX::BssRelRo->getParent()->addSection(Sec);
  else
    InX::Bss->getParent()->addSection(Sec);

  // Look through the DSO's dynamic symbol table for aliases and create a
  // dynamic symbol for each one. This causes the copy relocation to correctly
  // interpose any aliases.
  for (SharedSymbol *Sym : getSymbolsAt<ELFT>(SS)) {
    Sym->CopyRelSec = Sec;
    Sym->IsPreemptible = false;
    Sym->IsUsedInRegularObj = true;
    Sym->Used = true;
  }

  InX::RelaDyn->addReloc({Target->CopyRel, Sec, 0, false, SS, 0});
}

static void errorOrWarn(const Twine &Msg) {
  if (!Config->NoinhibitExec)
    error(Msg);
  else
    warn(Msg);
}

// Returns PLT relocation expression.
//
// This handles a non PIC program call to function in a shared library. In
// an ideal world, we could just report an error saying the relocation can
// overflow at runtime. In the real world with glibc, crt1.o has a
// R_X86_64_PC32 pointing to libc.so.
//
// The general idea on how to handle such cases is to create a PLT entry and
// use that as the function value.
//
// For the static linking part, we just return a plt expr and everything
// else will use the the PLT entry as the address.
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
static RelExpr getPltExpr(Symbol &Sym, RelExpr Expr, bool &IsConstant) {
  Sym.NeedsPltAddr = true;
  Sym.IsPreemptible = false;
  IsConstant = true;
  return toPlt(Expr);
}

// This modifies the expression if we can use a copy relocation or point the
// symbol to the PLT.
template <class ELFT>
static RelExpr adjustExpr(Symbol &Sym, RelExpr Expr, RelType Type,
                          InputSectionBase &S, uint64_t RelOff,
                          bool &IsConstant) {
  // If a relocation can be applied at link-time, we don't need to
  // create a dynamic relocation in the first place.
  if (IsConstant)
    return Expr;

  // We can create any dynamic relocation supported by the dynamic linker if a
  // section is writable or we are passed -z notext.
  bool CanWrite = (S.Flags & SHF_WRITE) || !Config->ZText;
  if (CanWrite && Target->isPicRel(Type))
    return Expr;

  // If the relocation is to a weak undef, and we are producing
  // executable, give up on it and produce a non preemptible 0.
  if (!Config->Shared && Sym.isUndefWeak()) {
    Sym.IsPreemptible = false;
    IsConstant = true;
    return Expr;
  }

  // If we got here we know that this relocation would require the dynamic
  // linker to write a value to read only memory or use an unsupported
  // relocation.

  // We can hack around it if we are producing an executable and
  // the refered symbol can be preemepted to refer to the executable.
  if (!CanWrite && (Config->Shared || (Config->Pic && !isRelExpr(Expr)))) {
    error(
        "can't create dynamic relocation " + toString(Type) + " against " +
        (Sym.getName().empty() ? "local symbol" : "symbol: " + toString(Sym)) +
        " in readonly segment; recompile object files with -fPIC" +
        getLocation(S, Sym, RelOff));
    return Expr;
  }

  // Copy relocations are only possible if we are creating an executable and the
  // symbol is shared.
  if (!Sym.isShared() || Config->Shared)
    return Expr;

  if (Sym.getVisibility() != STV_DEFAULT) {
    error("cannot preempt symbol: " + toString(Sym) +
          getLocation(S, Sym, RelOff));
    return Expr;
  }

  if (Sym.isObject()) {
    // Produce a copy relocation.
    auto *B = dyn_cast<SharedSymbol>(&Sym);
    if (B && !B->CopyRelSec) {
      if (Config->ZNocopyreloc)
        error("unresolvable relocation " + toString(Type) +
              " against symbol '" + toString(*B) +
              "'; recompile with -fPIC or remove '-z nocopyreloc'" +
              getLocation(S, Sym, RelOff));

      addCopyRelSymbol<ELFT>(B);
    }
    IsConstant = true;
    return Expr;
  }

  if (Sym.isFunc())
    return getPltExpr(Sym, Expr, IsConstant);

  errorOrWarn("symbol '" + toString(Sym) + "' defined in " +
              toString(Sym.File) + " has no type");
  return Expr;
}

// MIPS has an odd notion of "paired" relocations to calculate addends.
// For example, if a relocation is of R_MIPS_HI16, there must be a
// R_MIPS_LO16 relocation after that, and an addend is calculated using
// the two relocations.
template <class ELFT, class RelTy>
static int64_t computeMipsAddend(const RelTy &Rel, const RelTy *End,
                                 InputSectionBase &Sec, RelExpr Expr,
                                 bool IsLocal) {
  if (Expr == R_MIPS_GOTREL && IsLocal)
    return Sec.getFile<ELFT>()->MipsGp0;

  // The ABI says that the paired relocation is used only for REL.
  // See p. 4-17 at ftp://www.linux-mips.org/pub/linux/mips/doc/ABI/mipsabi.pdf
  if (RelTy::IsRela)
    return 0;

  RelType Type = Rel.getType(Config->IsMips64EL);
  uint32_t PairTy = getMipsPairType(Type, IsLocal);
  if (PairTy == R_MIPS_NONE)
    return 0;

  const uint8_t *Buf = Sec.Data.data();
  uint32_t SymIndex = Rel.getSymbol(Config->IsMips64EL);

  // To make things worse, paired relocations might not be contiguous in
  // the relocation table, so we need to do linear search. *sigh*
  for (const RelTy *RI = &Rel; RI != End; ++RI)
    if (RI->getType(Config->IsMips64EL) == PairTy &&
        RI->getSymbol(Config->IsMips64EL) == SymIndex)
      return Target->getImplicitAddend(Buf + RI->r_offset, PairTy);

  warn("can't find matching " + toString(PairTy) + " relocation for " +
       toString(Type));
  return 0;
}

// Returns an addend of a given relocation. If it is RELA, an addend
// is in a relocation itself. If it is REL, we need to read it from an
// input section.
template <class ELFT, class RelTy>
static int64_t computeAddend(const RelTy &Rel, const RelTy *End,
                             InputSectionBase &Sec, RelExpr Expr,
                             bool IsLocal) {
  int64_t Addend;
  RelType Type = Rel.getType(Config->IsMips64EL);

  if (RelTy::IsRela) {
    Addend = getAddend<ELFT>(Rel);
  } else {
    const uint8_t *Buf = Sec.Data.data();
    Addend = Target->getImplicitAddend(Buf + Rel.r_offset, Type);
  }

  if (Config->EMachine == EM_PPC64 && Config->Pic && Type == R_PPC64_TOC)
    Addend += getPPC64TocBase();
  if (Config->EMachine == EM_MIPS)
    Addend += computeMipsAddend<ELFT>(Rel, End, Sec, Expr, IsLocal);

  return Addend;
}

// Report an undefined symbol if necessary.
// Returns true if this function printed out an error message.
static bool maybeReportUndefined(Symbol &Sym, InputSectionBase &Sec,
                                 uint64_t Offset) {
  if (Config->UnresolvedSymbols == UnresolvedPolicy::IgnoreAll)
    return false;

  if (Sym.isLocal() || !Sym.isUndefined() || Sym.isWeak())
    return false;

  bool CanBeExternal =
      Sym.computeBinding() != STB_LOCAL && Sym.getVisibility() == STV_DEFAULT;
  if (Config->UnresolvedSymbols == UnresolvedPolicy::Ignore && CanBeExternal)
    return false;

  std::string Msg =
      "undefined symbol: " + toString(Sym) + "\n>>> referenced by ";

  std::string Src = Sec.getSrcMsg(Sym, Offset);
  if (!Src.empty())
    Msg += Src + "\n>>>               ";
  Msg += Sec.getObjMsg(Offset);

  if ((Config->UnresolvedSymbols == UnresolvedPolicy::Warn && CanBeExternal) ||
      Config->NoinhibitExec) {
    warn(Msg);
    return false;
  }

  error(Msg);
  return true;
}

// MIPS N32 ABI treats series of successive relocations with the same offset
// as a single relocation. The similar approach used by N64 ABI, but this ABI
// packs all relocations into the single relocation record. Here we emulate
// this for the N32 ABI. Iterate over relocation with the same offset and put
// theirs types into the single bit-set.
template <class RelTy> static RelType getMipsN32RelType(RelTy *&Rel, RelTy *End) {
  RelType Type = Rel->getType(Config->IsMips64EL);
  uint64_t Offset = Rel->r_offset;

  int N = 0;
  while (Rel + 1 != End && (Rel + 1)->r_offset == Offset)
    Type |= (++Rel)->getType(Config->IsMips64EL) << (8 * ++N);
  return Type;
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
  explicit OffsetGetter(InputSectionBase &Sec) {
    if (auto *Eh = dyn_cast<EhInputSection>(&Sec))
      Pieces = Eh->Pieces;
  }

  // Translates offsets in input sections to offsets in output sections.
  // Given offset must increase monotonically. We assume that Piece is
  // sorted by InputOff.
  uint64_t get(uint64_t Off) {
    if (Pieces.empty())
      return Off;

    while (I != Pieces.size() && Pieces[I].InputOff + Pieces[I].Size <= Off)
      ++I;
    if (I == Pieces.size())
      return Off;

    // Pieces must be contiguous, so there must be no holes in between.
    assert(Pieces[I].InputOff <= Off && "Relocation not in any piece");

    // Offset -1 means that the piece is dead (i.e. garbage collected).
    if (Pieces[I].OutputOff == -1)
      return -1;
    return Pieces[I].OutputOff + Off - Pieces[I].InputOff;
  }

private:
  ArrayRef<EhSectionPiece> Pieces;
  size_t I = 0;
};
} // namespace

template <class ELFT, class GotPltSection>
static void addPltEntry(PltSection *Plt, GotPltSection *GotPlt,
                        RelocationBaseSection *Rel, RelType Type, Symbol &Sym,
                        bool UseSymVA) {
  Plt->addEntry<ELFT>(Sym);
  GotPlt->addEntry(Sym);
  Rel->addReloc({Type, GotPlt, Sym.getGotPltOffset(), UseSymVA, &Sym, 0});
}

template <class ELFT> static void addGotEntry(Symbol &Sym, bool Preemptible) {
  InX::Got->addEntry(Sym);

  RelExpr Expr = Sym.isTls() ? R_TLS : R_ABS;
  uint64_t Off = Sym.getGotOffset();

  // If a GOT slot value can be calculated at link-time, which is now,
  // we can just fill that out.
  //
  // (We don't actually write a value to a GOT slot right now, but we
  // add a static relocation to a Relocations vector so that
  // InputSection::relocate will do the work for us. We may be able
  // to just write a value now, but it is a TODO.)
  bool IsLinkTimeConstant = !Preemptible && (!Config->Pic || isAbsolute(Sym));
  if (IsLinkTimeConstant) {
    InX::Got->Relocations.push_back({Expr, Target->GotRel, Off, 0, &Sym});
    return;
  }

  // Otherwise, we emit a dynamic relocation to .rel[a].dyn so that
  // the GOT slot will be fixed at load-time.
  RelType Type;
  if (Sym.isTls())
    Type = Target->TlsGotRel;
  else if (!Preemptible && Config->Pic && !isAbsolute(Sym))
    Type = Target->RelativeRel;
  else
    Type = Target->GotRel;
  InX::RelaDyn->addReloc({Type, InX::Got, Off, !Preemptible, &Sym, 0});

  // REL type relocations don't have addend fields unlike RELAs, and
  // their addends are stored to the section to which they are applied.
  // So, store addends if we need to.
  //
  // This is ugly -- the difference between REL and RELA should be
  // handled in a better way. It's a TODO.
  if (!Config->IsRela && !Preemptible)
    InX::Got->Relocations.push_back({R_ABS, Target->GotRel, Off, 0, &Sym});
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
static void scanRelocs(InputSectionBase &Sec, ArrayRef<RelTy> Rels) {
  OffsetGetter GetOffset(Sec);

  // Not all relocations end up in Sec.Relocations, but a lot do.
  Sec.Relocations.reserve(Rels.size());

  for (auto I = Rels.begin(), End = Rels.end(); I != End; ++I) {
    const RelTy &Rel = *I;
    Symbol &Sym = Sec.getFile<ELFT>()->getRelocTargetSym(Rel);
    RelType Type = Rel.getType(Config->IsMips64EL);

    // Deal with MIPS oddity.
    if (Config->MipsN32Abi)
      Type = getMipsN32RelType(I, End);

    // Get an offset in an output section this relocation is applied to.
    uint64_t Offset = GetOffset.get(Rel.r_offset);
    if (Offset == uint64_t(-1))
      continue;

    // Skip if the target symbol is an erroneous undefined symbol.
    if (maybeReportUndefined(Sym, Sec, Rel.r_offset))
      continue;

    RelExpr Expr =
        Target->getRelExpr(Type, Sym, Sec.Data.begin() + Rel.r_offset);

    // Ignore "hint" relocations because they are only markers for relaxation.
    if (isRelExprOneOf<R_HINT, R_NONE>(Expr))
      continue;

    // Handle yet another MIPS-ness.
    if (isMipsGprel(Type)) {
      int64_t Addend = computeAddend<ELFT>(Rel, End, Sec, Expr, Sym.isLocal());
      Sec.Relocations.push_back({R_MIPS_GOTREL, Type, Offset, Addend, &Sym});
      continue;
    }

    bool Preemptible = Sym.IsPreemptible;

    // Strenghten or relax a PLT access.
    //
    // GNU ifunc symbols must be accessed via PLT because their addresses
    // are determined by runtime.
    //
    // On the other hand, if we know that a PLT entry will be resolved within
    // the same ELF module, we can skip PLT access and directly jump to the
    // destination function. For example, if we are linking a main exectuable,
    // all dynamic symbols that can be resolved within the executable will
    // actually be resolved that way at runtime, because the main exectuable
    // is always at the beginning of a search list. We can leverage that fact.
    if (Sym.isGnuIFunc())
      Expr = toPlt(Expr);
    else if (!Preemptible && Expr == R_GOT_PC && !isAbsoluteValue(Sym))
      Expr =
          Target->adjustRelaxExpr(Type, Sec.Data.data() + Rel.r_offset, Expr);
    else if (!Preemptible)
      Expr = fromPlt(Expr);

    bool IsConstant =
        isStaticLinkTimeConstant(Expr, Type, Sym, Sec, Rel.r_offset);

    Expr = adjustExpr<ELFT>(Sym, Expr, Type, Sec, Rel.r_offset, IsConstant);
    if (errorCount())
      continue;

    // This relocation does not require got entry, but it is relative to got and
    // needs it to be created. Here we request for that.
    if (isRelExprOneOf<R_GOTONLY_PC, R_GOTONLY_PC_FROM_END, R_GOTREL,
                       R_GOTREL_FROM_END, R_PPC_TOC>(Expr))
      InX::Got->HasGotOffRel = true;

    // Read an addend.
    int64_t Addend = computeAddend<ELFT>(Rel, End, Sec, Expr, Sym.isLocal());

    // Process some TLS relocations, including relaxing TLS relocations.
    // Note that this function does not handle all TLS relocations.
    if (unsigned Processed =
            handleTlsRelocation<ELFT>(Type, Sym, Sec, Offset, Addend, Expr)) {
      I += (Processed - 1);
      continue;
    }

    // If a relocation needs PLT, we create PLT and GOTPLT slots for the symbol.
    if (needsPlt(Expr) && !Sym.isInPlt()) {
      if (Sym.isGnuIFunc() && !Preemptible)
        addPltEntry<ELFT>(InX::Iplt, InX::IgotPlt, InX::RelaIplt,
                          Target->IRelativeRel, Sym, true);
      else
        addPltEntry<ELFT>(InX::Plt, InX::GotPlt, InX::RelaPlt, Target->PltRel,
                          Sym, !Preemptible);
    }

    // Create a GOT slot if a relocation needs GOT.
    if (needsGot(Expr)) {
      if (Config->EMachine == EM_MIPS) {
        // MIPS ABI has special rules to process GOT entries and doesn't
        // require relocation entries for them. A special case is TLS
        // relocations. In that case dynamic loader applies dynamic
        // relocations to initialize TLS GOT entries.
        // See "Global Offset Table" in Chapter 5 in the following document
        // for detailed description:
        // ftp://www.linux-mips.org/pub/linux/mips/doc/ABI/mipsabi.pdf
        InX::MipsGot->addEntry(Sym, Addend, Expr);
        if (Sym.isTls() && Sym.IsPreemptible)
          InX::RelaDyn->addReloc({Target->TlsGotRel, InX::MipsGot,
                                  Sym.getGotOffset(), false, &Sym, 0});
      } else if (!Sym.isInGot()) {
        addGotEntry<ELFT>(Sym, Preemptible);
      }
    }

    if (!needsPlt(Expr) && !needsGot(Expr) && Sym.IsPreemptible) {
      // We don't know anything about the finaly symbol. Just ask the dynamic
      // linker to handle the relocation for us.
      if (!Target->isPicRel(Type))
        errorOrWarn(
            "relocation " + toString(Type) +
            " cannot be used against shared object; recompile with -fPIC" +
            getLocation(Sec, Sym, Offset));

      InX::RelaDyn->addReloc(
          {Target->getDynRel(Type), &Sec, Offset, false, &Sym, Addend});

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
      if (Config->EMachine == EM_MIPS)
        InX::MipsGot->addEntry(Sym, Addend, Expr);
      continue;
    }

    // The size is not going to change, so we fold it in here.
    if (Expr == R_SIZE)
      Addend += Sym.getSize();

    // If the produced value is a constant, we just remember to write it
    // when outputting this section. We also have to do it if the format
    // uses Elf_Rel, since in that case the written value is the addend.
    if (IsConstant) {
      Sec.Relocations.push_back({Expr, Type, Offset, Addend, &Sym});
      continue;
    }

    // If the output being produced is position independent, the final value
    // is still not known. In that case we still need some help from the
    // dynamic linker. We can however do better than just copying the incoming
    // relocation. We can process some of it and and just ask the dynamic
    // linker to add the load address.
    if (Config->IsRela) {
      InX::RelaDyn->addReloc(
          {Target->RelativeRel, &Sec, Offset, true, &Sym, Addend});
    } else {
      // In REL, addends are stored to the target section.
      InX::RelaDyn->addReloc(
          {Target->RelativeRel, &Sec, Offset, true, &Sym, 0});
      Sec.Relocations.push_back({Expr, Type, Offset, Addend, &Sym});
    }
  }
}

template <class ELFT> void elf::scanRelocations(InputSectionBase &S) {
  if (S.AreRelocsRela)
    scanRelocs<ELFT>(S, S.relas<ELFT>());
  else
    scanRelocs<ELFT>(S, S.rels<ELFT>());
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
void ThunkCreator::mergeThunks(ArrayRef<OutputSection *> OutputSections) {
  forEachInputSectionDescription(
      OutputSections, [&](OutputSection *OS, InputSectionDescription *ISD) {
        if (ISD->ThunkSections.empty())
          return;

        // Remove any zero sized precreated Thunks.
        llvm::erase_if(ISD->ThunkSections,
                       [](const std::pair<ThunkSection *, uint32_t> &TS) {
                         return TS.first->getSize() == 0;
                       });
        // ISD->ThunkSections contains all created ThunkSections, including
        // those inserted in previous passes. Extract the Thunks created this
        // pass and order them in ascending OutSecOff.
        std::vector<ThunkSection *> NewThunks;
        for (const std::pair<ThunkSection *, uint32_t> TS : ISD->ThunkSections)
          if (TS.second == Pass)
            NewThunks.push_back(TS.first);
        std::stable_sort(NewThunks.begin(), NewThunks.end(),
                         [](const ThunkSection *A, const ThunkSection *B) {
                           return A->OutSecOff < B->OutSecOff;
                         });

        // Merge sorted vectors of Thunks and InputSections by OutSecOff
        std::vector<InputSection *> Tmp;
        Tmp.reserve(ISD->Sections.size() + NewThunks.size());
        auto MergeCmp = [](const InputSection *A, const InputSection *B) {
          // std::merge requires a strict weak ordering.
          if (A->OutSecOff < B->OutSecOff)
            return true;
          if (A->OutSecOff == B->OutSecOff) {
            auto *TA = dyn_cast<ThunkSection>(A);
            auto *TB = dyn_cast<ThunkSection>(B);
            // Check if Thunk is immediately before any specific Target
            // InputSection for example Mips LA25 Thunks.
            if (TA && TA->getTargetInputSection() == B)
              return true;
            if (TA && !TB && !TA->getTargetInputSection())
              // Place Thunk Sections without specific targets before
              // non-Thunk Sections.
              return true;
          }
          return false;
        };
        std::merge(ISD->Sections.begin(), ISD->Sections.end(),
                   NewThunks.begin(), NewThunks.end(), std::back_inserter(Tmp),
                   MergeCmp);
        ISD->Sections = std::move(Tmp);
      });
}

// Find or create a ThunkSection within the InputSectionDescription (ISD) that
// is in range of Src. An ISD maps to a range of InputSections described by a
// linker script section pattern such as { .text .text.* }.
ThunkSection *ThunkCreator::getISDThunkSec(OutputSection *OS, InputSection *IS,
                                           InputSectionDescription *ISD,
                                           uint32_t Type, uint64_t Src) {
  for (std::pair<ThunkSection *, uint32_t> TP : ISD->ThunkSections) {
    ThunkSection *TS = TP.first;
    uint64_t TSBase = OS->Addr + TS->OutSecOff;
    uint64_t TSLimit = TSBase + TS->getSize();
    if (Target->inBranchRange(Type, Src, (Src > TSLimit) ? TSBase : TSLimit))
      return TS;
  }

  // No suitable ThunkSection exists. This can happen when there is a branch
  // with lower range than the ThunkSection spacing or when there are too
  // many Thunks. Create a new ThunkSection as close to the InputSection as
  // possible. Error if InputSection is so large we cannot place ThunkSection
  // anywhere in Range.
  uint64_t ThunkSecOff = IS->OutSecOff;
  if (!Target->inBranchRange(Type, Src, OS->Addr + ThunkSecOff)) {
    ThunkSecOff = IS->OutSecOff + IS->getSize();
    if (!Target->inBranchRange(Type, Src, OS->Addr + ThunkSecOff))
      fatal("InputSection too large for range extension thunk " +
            IS->getObjMsg(Src - (OS->Addr + IS->OutSecOff)));
  }
  return addThunkSection(OS, ISD, ThunkSecOff);
}

// Add a Thunk that needs to be placed in a ThunkSection that immediately
// precedes its Target.
ThunkSection *ThunkCreator::getISThunkSec(InputSection *IS) {
  ThunkSection *TS = ThunkedSections.lookup(IS);
  if (TS)
    return TS;

  // Find InputSectionRange within Target Output Section (TOS) that the
  // InputSection (IS) that we need to precede is in.
  OutputSection *TOS = IS->getParent();
  for (BaseCommand *BC : TOS->SectionCommands)
    if (auto *ISD = dyn_cast<InputSectionDescription>(BC)) {
      if (ISD->Sections.empty())
        continue;
      InputSection *first = ISD->Sections.front();
      InputSection *last = ISD->Sections.back();
      if (IS->OutSecOff >= first->OutSecOff &&
          IS->OutSecOff <= last->OutSecOff) {
        TS = addThunkSection(TOS, ISD, IS->OutSecOff);
        ThunkedSections[IS] = TS;
        break;
      }
    }
  return TS;
}

// Create one or more ThunkSections per OS that can be used to place Thunks.
// We attempt to place the ThunkSections using the following desirable
// properties:
// - Within range of the maximum number of callers
// - Minimise the number of ThunkSections
//
// We follow a simple but conservative heuristic to place ThunkSections at
// offsets that are multiples of a Target specific branch range.
// For an InputSectionRange that is smaller than the range, a single
// ThunkSection at the end of the range will do.
void ThunkCreator::createInitialThunkSections(
    ArrayRef<OutputSection *> OutputSections) {
  forEachInputSectionDescription(
      OutputSections, [&](OutputSection *OS, InputSectionDescription *ISD) {
        if (ISD->Sections.empty())
          return;
        uint32_t ISLimit;
        uint32_t PrevISLimit = ISD->Sections.front()->OutSecOff;
        uint32_t ThunkUpperBound = PrevISLimit + Target->ThunkSectionSpacing;

        for (const InputSection *IS : ISD->Sections) {
          ISLimit = IS->OutSecOff + IS->getSize();
          if (ISLimit > ThunkUpperBound) {
            addThunkSection(OS, ISD, PrevISLimit);
            ThunkUpperBound = PrevISLimit + Target->ThunkSectionSpacing;
          }
          PrevISLimit = ISLimit;
        }
        addThunkSection(OS, ISD, ISLimit);
      });
}

ThunkSection *ThunkCreator::addThunkSection(OutputSection *OS,
                                            InputSectionDescription *ISD,
                                            uint64_t Off) {
  auto *TS = make<ThunkSection>(OS, Off);
  ISD->ThunkSections.push_back(std::make_pair(TS, Pass));
  return TS;
}

std::pair<Thunk *, bool> ThunkCreator::getThunk(Symbol &Sym, RelType Type,
                                                uint64_t Src) {
  auto Res = ThunkedSymbols.insert({&Sym, std::vector<Thunk *>()});
  if (!Res.second) {
    // Check existing Thunks for Sym to see if they can be reused
    for (Thunk *ET : Res.first->second)
      if (ET->isCompatibleWith(Type) &&
          Target->inBranchRange(Type, Src, ET->ThunkSym->getVA()))
        return std::make_pair(ET, false);
  }
  // No existing compatible Thunk in range, create a new one
  Thunk *T = addThunk(Type, Sym);
  Res.first->second.push_back(T);
  return std::make_pair(T, true);
}

// Call Fn on every executable InputSection accessed via the linker script
// InputSectionDescription::Sections.
void ThunkCreator::forEachInputSectionDescription(
    ArrayRef<OutputSection *> OutputSections,
    std::function<void(OutputSection *, InputSectionDescription *)> Fn) {
  for (OutputSection *OS : OutputSections) {
    if (!(OS->Flags & SHF_ALLOC) || !(OS->Flags & SHF_EXECINSTR))
      continue;
    for (BaseCommand *BC : OS->SectionCommands)
      if (auto *ISD = dyn_cast<InputSectionDescription>(BC))
        Fn(OS, ISD);
  }
}

// Return true if the relocation target is an in range Thunk.
// Return false if the relocation is not to a Thunk. If the relocation target
// was originally to a Thunk, but is no longer in range we revert the
// relocation back to its original non-Thunk target.
bool ThunkCreator::normalizeExistingThunk(Relocation &Rel, uint64_t Src) {
  if (Thunk *ET = Thunks.lookup(Rel.Sym)) {
    if (Target->inBranchRange(Rel.Type, Src, Rel.Sym->getVA()))
      return true;
    Rel.Sym = &ET->Destination;
    if (Rel.Sym->isInPlt())
      Rel.Expr = toPlt(Rel.Expr);
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
bool ThunkCreator::createThunks(ArrayRef<OutputSection *> OutputSections) {
  bool AddressesChanged = false;
  if (Pass == 0 && Target->ThunkSectionSpacing)
    createInitialThunkSections(OutputSections);
  else if (Pass == 10)
    // With Thunk Size much smaller than branch range we expect to
    // converge quickly; if we get to 10 something has gone wrong.
    fatal("thunk creation not converged");

  // Create all the Thunks and insert them into synthetic ThunkSections. The
  // ThunkSections are later inserted back into InputSectionDescriptions.
  // We separate the creation of ThunkSections from the insertion of the
  // ThunkSections as ThunkSections are not always inserted into the same
  // InputSectionDescription as the caller.
  forEachInputSectionDescription(
      OutputSections, [&](OutputSection *OS, InputSectionDescription *ISD) {
        for (InputSection *IS : ISD->Sections)
          for (Relocation &Rel : IS->Relocations) {
            uint64_t Src = OS->Addr + IS->OutSecOff + Rel.Offset;

            // If we are a relocation to an existing Thunk, check if it is
            // still in range. If not then Rel will be altered to point to its
            // original target so another Thunk can be generated.
            if (Pass > 0 && normalizeExistingThunk(Rel, Src))
              continue;

            if (!Target->needsThunk(Rel.Expr, Rel.Type, IS->File, Src,
                                    *Rel.Sym))
              continue;
            Thunk *T;
            bool IsNew;
            std::tie(T, IsNew) = getThunk(*Rel.Sym, Rel.Type, Src);
            if (IsNew) {
              AddressesChanged = true;
              // Find or create a ThunkSection for the new Thunk
              ThunkSection *TS;
              if (auto *TIS = T->getTargetInputSection())
                TS = getISThunkSec(TIS);
              else
                TS = getISDThunkSec(OS, IS, ISD, Rel.Type, Src);
              TS->addThunk(T);
              Thunks[T->ThunkSym] = T;
            }
            // Redirect relocation to Thunk, we never go via the PLT to a Thunk
            Rel.Sym = T->ThunkSym;
            Rel.Expr = fromPlt(Rel.Expr);
          }
      });
  // Merge all created synthetic ThunkSections back into OutputSection
  mergeThunks(OutputSections);
  ++Pass;
  return AddressesChanged;
}

template void elf::scanRelocations<ELF32LE>(InputSectionBase &);
template void elf::scanRelocations<ELF32BE>(InputSectionBase &);
template void elf::scanRelocations<ELF64LE>(InputSectionBase &);
template void elf::scanRelocations<ELF64BE>(InputSectionBase &);
