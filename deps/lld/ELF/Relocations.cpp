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
#include "Memory.h"
#include "OutputSections.h"
#include "Strings.h"
#include "SymbolTable.h"
#include "SyntheticSections.h"
#include "Target.h"
#include "Thunks.h"

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
template <class ELFT>
static std::string getLocation(InputSectionBase &S, const SymbolBody &Sym,
                               uint64_t Off) {
  std::string Msg =
      "\n>>> defined in " + toString(Sym.File) + "\n>>> referenced by ";
  std::string Src = S.getSrcMsg<ELFT>(Off);
  if (!Src.empty())
    Msg += Src + "\n>>>               ";
  return Msg + S.getObjMsg<ELFT>(Off);
}

static bool isPreemptible(const SymbolBody &Body, uint32_t Type) {
  // In case of MIPS GP-relative relocations always resolve to a definition
  // in a regular input file, ignoring the one-definition rule. So we,
  // for example, should not attempt to create a dynamic relocation even
  // if the target symbol is preemptible. There are two two MIPS GP-relative
  // relocations R_MIPS_GPREL16 and R_MIPS_GPREL32. But only R_MIPS_GPREL16
  // can be against a preemptible symbol.
  // To get MIPS relocation type we apply 0xff mask. In case of O32 ABI all
  // relocation types occupy eight bit. In case of N64 ABI we extract first
  // relocation from 3-in-1 packet because only the first relocation can
  // be against a real symbol.
  if (Config->EMachine == EM_MIPS && (Type & 0xff) == R_MIPS_GPREL16)
    return false;
  return Body.isPreemptible();
}

// This function is similar to the `handleTlsRelocation`. MIPS does not
// support any relaxations for TLS relocations so by factoring out MIPS
// handling in to the separate function we can simplify the code and do not
// pollute other `handleTlsRelocation` by MIPS `ifs` statements.
// Mips has a custom MipsGotSection that handles the writing of GOT entries
// without dynamic relocations.
template <class ELFT>
static unsigned handleMipsTlsRelocation(uint32_t Type, SymbolBody &Body,
                                        InputSectionBase &C, uint64_t Offset,
                                        int64_t Addend, RelExpr Expr) {
  if (Expr == R_MIPS_TLSLD) {
    if (InX::MipsGot->addTlsIndex() && Config->Pic)
      In<ELFT>::RelaDyn->addReloc({Target->TlsModuleIndexRel, InX::MipsGot,
                                   InX::MipsGot->getTlsIndexOff(), false,
                                   nullptr, 0});
    C.Relocations.push_back({Expr, Type, Offset, Addend, &Body});
    return 1;
  }

  if (Expr == R_MIPS_TLSGD) {
    if (InX::MipsGot->addDynTlsEntry(Body) && Body.isPreemptible()) {
      uint64_t Off = InX::MipsGot->getGlobalDynOffset(Body);
      In<ELFT>::RelaDyn->addReloc(
          {Target->TlsModuleIndexRel, InX::MipsGot, Off, false, &Body, 0});
      if (Body.isPreemptible())
        In<ELFT>::RelaDyn->addReloc({Target->TlsOffsetRel, InX::MipsGot,
                                     Off + Config->Wordsize, false, &Body, 0});
    }
    C.Relocations.push_back({Expr, Type, Offset, Addend, &Body});
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
static unsigned handleARMTlsRelocation(uint32_t Type, SymbolBody &Body,
                                       InputSectionBase &C, uint64_t Offset,
                                       int64_t Addend, RelExpr Expr) {
  // The Dynamic TLS Module Index Relocation for a symbol defined in an
  // executable is always 1. If the target Symbol is not preemtible then
  // we know the offset into the TLS block at static link time.
  bool NeedDynId = Body.isPreemptible() || Config->Shared;
  bool NeedDynOff = Body.isPreemptible();

  auto AddTlsReloc = [&](uint64_t Off, uint32_t Type, SymbolBody *Dest,
                         bool Dyn) {
    if (Dyn)
      In<ELFT>::RelaDyn->addReloc({Type, InX::Got, Off, false, Dest, 0});
    else
      InX::Got->Relocations.push_back({R_ABS, Type, Off, 0, Dest});
  };

  // Local Dynamic is for access to module local TLS variables, while still
  // being suitable for being dynamically loaded via dlopen.
  // GOT[e0] is the module index, with a special value of 0 for the current
  // module. GOT[e1] is unused. There only needs to be one module index entry.
  if (Expr == R_TLSLD_PC && InX::Got->addTlsIndex()) {
    AddTlsReloc(InX::Got->getTlsIndexOff(), Target->TlsModuleIndexRel,
                NeedDynId ? nullptr : &Body, NeedDynId);
    C.Relocations.push_back({Expr, Type, Offset, Addend, &Body});
    return 1;
  }

  // Global Dynamic is the most general purpose access model. When we know
  // the module index and offset of symbol in TLS block we can fill these in
  // using static GOT relocations.
  if (Expr == R_TLSGD_PC) {
    if (InX::Got->addDynTlsEntry(Body)) {
      uint64_t Off = InX::Got->getGlobalDynOffset(Body);
      AddTlsReloc(Off, Target->TlsModuleIndexRel, &Body, NeedDynId);
      AddTlsReloc(Off + Config->Wordsize, Target->TlsOffsetRel, &Body,
                  NeedDynOff);
    }
    C.Relocations.push_back({Expr, Type, Offset, Addend, &Body});
    return 1;
  }
  return 0;
}

// Returns the number of relocations processed.
template <class ELFT>
static unsigned
handleTlsRelocation(uint32_t Type, SymbolBody &Body, InputSectionBase &C,
                    typename ELFT::uint Offset, int64_t Addend, RelExpr Expr) {
  if (!(C.Flags & SHF_ALLOC))
    return 0;

  if (!Body.isTls())
    return 0;

  if (Config->EMachine == EM_ARM)
    return handleARMTlsRelocation<ELFT>(Type, Body, C, Offset, Addend, Expr);
  if (Config->EMachine == EM_MIPS)
    return handleMipsTlsRelocation<ELFT>(Type, Body, C, Offset, Addend, Expr);

  bool IsPreemptible = isPreemptible(Body, Type);
  if (isRelExprOneOf<R_TLSDESC, R_TLSDESC_PAGE, R_TLSDESC_CALL>(Expr) &&
      Config->Shared) {
    if (InX::Got->addDynTlsEntry(Body)) {
      uint64_t Off = InX::Got->getGlobalDynOffset(Body);
      In<ELFT>::RelaDyn->addReloc(
          {Target->TlsDescRel, InX::Got, Off, !IsPreemptible, &Body, 0});
    }
    if (Expr != R_TLSDESC_CALL)
      C.Relocations.push_back({Expr, Type, Offset, Addend, &Body});
    return 1;
  }

  if (isRelExprOneOf<R_TLSLD_PC, R_TLSLD>(Expr)) {
    // Local-Dynamic relocs can be relaxed to Local-Exec.
    if (!Config->Shared) {
      C.Relocations.push_back(
          {R_RELAX_TLS_LD_TO_LE, Type, Offset, Addend, &Body});
      return 2;
    }
    if (InX::Got->addTlsIndex())
      In<ELFT>::RelaDyn->addReloc({Target->TlsModuleIndexRel, InX::Got,
                                   InX::Got->getTlsIndexOff(), false, nullptr,
                                   0});
    C.Relocations.push_back({Expr, Type, Offset, Addend, &Body});
    return 1;
  }

  // Local-Dynamic relocs can be relaxed to Local-Exec.
  if (isRelExprOneOf<R_ABS, R_TLSLD, R_TLSLD_PC>(Expr) && !Config->Shared) {
    C.Relocations.push_back(
        {R_RELAX_TLS_LD_TO_LE, Type, Offset, Addend, &Body});
    return 1;
  }

  if (isRelExprOneOf<R_TLSDESC, R_TLSDESC_PAGE, R_TLSDESC_CALL, R_TLSGD,
                     R_TLSGD_PC>(Expr)) {
    if (Config->Shared) {
      if (InX::Got->addDynTlsEntry(Body)) {
        uint64_t Off = InX::Got->getGlobalDynOffset(Body);
        In<ELFT>::RelaDyn->addReloc(
            {Target->TlsModuleIndexRel, InX::Got, Off, false, &Body, 0});

        // If the symbol is preemptible we need the dynamic linker to write
        // the offset too.
        uint64_t OffsetOff = Off + Config->Wordsize;
        if (IsPreemptible)
          In<ELFT>::RelaDyn->addReloc(
              {Target->TlsOffsetRel, InX::Got, OffsetOff, false, &Body, 0});
        else
          InX::Got->Relocations.push_back(
              {R_ABS, Target->TlsOffsetRel, OffsetOff, 0, &Body});
      }
      C.Relocations.push_back({Expr, Type, Offset, Addend, &Body});
      return 1;
    }

    // Global-Dynamic relocs can be relaxed to Initial-Exec or Local-Exec
    // depending on the symbol being locally defined or not.
    if (IsPreemptible) {
      C.Relocations.push_back(
          {Target->adjustRelaxExpr(Type, nullptr, R_RELAX_TLS_GD_TO_IE), Type,
           Offset, Addend, &Body});
      if (!Body.isInGot()) {
        InX::Got->addEntry(Body);
        In<ELFT>::RelaDyn->addReloc({Target->TlsGotRel, InX::Got,
                                     Body.getGotOffset(), false, &Body, 0});
      }
    } else {
      C.Relocations.push_back(
          {Target->adjustRelaxExpr(Type, nullptr, R_RELAX_TLS_GD_TO_LE), Type,
           Offset, Addend, &Body});
    }
    return Target->TlsGdRelaxSkip;
  }

  // Initial-Exec relocs can be relaxed to Local-Exec if the symbol is locally
  // defined.
  if (isRelExprOneOf<R_GOT, R_GOT_FROM_END, R_GOT_PC, R_GOT_PAGE_PC>(Expr) &&
      !Config->Shared && !IsPreemptible) {
    C.Relocations.push_back(
        {R_RELAX_TLS_IE_TO_LE, Type, Offset, Addend, &Body});
    return 1;
  }

  if (Expr == R_TLSDESC_CALL)
    return 1;
  return 0;
}

static uint32_t getMipsPairType(uint32_t Type, const SymbolBody &Sym) {
  switch (Type) {
  case R_MIPS_HI16:
    return R_MIPS_LO16;
  case R_MIPS_GOT16:
    return Sym.isLocal() ? R_MIPS_LO16 : R_MIPS_NONE;
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
static bool isAbsolute(const SymbolBody &Body) {
  if (Body.isUndefined())
    return !Body.isLocal() && Body.symbol()->isWeak();
  if (const auto *DR = dyn_cast<DefinedRegular>(&Body))
    return DR->Section == nullptr; // Absolute symbol.
  return false;
}

static bool isAbsoluteValue(const SymbolBody &Body) {
  return isAbsolute(Body) || Body.isTls();
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
template <class ELFT>
static bool isStaticLinkTimeConstant(RelExpr E, uint32_t Type,
                                     const SymbolBody &Body,
                                     InputSectionBase &S, uint64_t RelOff) {
  // These expressions always compute a constant
  if (isRelExprOneOf<R_SIZE, R_GOT_FROM_END, R_GOT_OFF, R_MIPS_GOT_LOCAL_PAGE,
                     R_MIPS_GOT_OFF, R_MIPS_GOT_OFF32, R_MIPS_GOT_GP_PC,
                     R_MIPS_TLSGD, R_GOT_PAGE_PC, R_GOT_PC, R_GOTONLY_PC,
                     R_GOTONLY_PC_FROM_END, R_PLT_PC, R_TLSGD_PC, R_TLSGD,
                     R_PPC_PLT_OPD, R_TLSDESC_CALL, R_TLSDESC_PAGE, R_HINT>(E))
    return true;

  // These never do, except if the entire file is position dependent or if
  // only the low bits are used.
  if (E == R_GOT || E == R_PLT || E == R_TLSDESC)
    return Target->usesOnlyLowPageBits(Type) || !Config->Pic;

  if (isPreemptible(Body, Type))
    return false;
  if (!Config->Pic)
    return true;

  // For the target and the relocation, we want to know if they are
  // absolute or relative.
  bool AbsVal = isAbsoluteValue(Body);
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
  if (Body.isUndefined() && !Body.isLocal() && Body.symbol()->isWeak())
    return true;

  error("relocation " + toString(Type) + " cannot refer to absolute symbol: " +
        toString(Body) + getLocation<ELFT>(S, Body, RelOff));
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
  uint64_t Value = SS->getValue<ELFT>();

  // Determine if the symbol is read-only by scanning the DSO's program headers.
  auto *File = cast<SharedFile<ELFT>>(SS->File);
  for (const Elf_Phdr &Phdr : check(File->getObj().program_headers()))
    if ((Phdr.p_type == ELF::PT_LOAD || Phdr.p_type == ELF::PT_GNU_RELRO) &&
        !(Phdr.p_flags & ELF::PF_W) && Value >= Phdr.p_vaddr &&
        Value < Phdr.p_vaddr + Phdr.p_memsz)
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

  auto *File = cast<SharedFile<ELFT>>(SS->File);
  uint64_t Shndx = SS->getShndx<ELFT>();
  uint64_t Value = SS->getValue<ELFT>();

  std::vector<SharedSymbol *> Ret;
  for (const Elf_Sym &S : File->getGlobalSymbols()) {
    if (S.st_shndx != Shndx || S.st_value != Value)
      continue;
    StringRef Name = check(S.getName(File->getStringTable()));
    SymbolBody *Sym = Symtab<ELFT>::X->find(Name);
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
  uint64_t SymSize = SS->template getSize<ELFT>();
  if (SymSize == 0)
    fatal("cannot create a copy relocation for symbol " + toString(*SS));

  // See if this symbol is in a read-only segment. If so, preserve the symbol's
  // memory protection by reserving space in the .bss.rel.ro section.
  bool IsReadOnly = isReadOnly<ELFT>(SS);
  BssSection *Sec = IsReadOnly ? InX::BssRelRo : InX::Bss;
  uint64_t Off = Sec->reserveSpace(SymSize, SS->getAlignment<ELFT>());

  // Look through the DSO's dynamic symbol table for aliases and create a
  // dynamic symbol for each one. This causes the copy relocation to correctly
  // interpose any aliases.
  for (SharedSymbol *Sym : getSymbolsAt<ELFT>(SS)) {
    Sym->NeedsCopy = true;
    Sym->CopyRelSec = Sec;
    Sym->CopyRelSecOff = Off;
    Sym->symbol()->IsUsedInRegularObj = true;
  }

  In<ELFT>::RelaDyn->addReloc({Target->CopyRel, Sec, Off, false, SS, 0});
}

template <class ELFT>
static RelExpr adjustExpr(SymbolBody &Body, RelExpr Expr, uint32_t Type,
                          const uint8_t *Data, InputSectionBase &S,
                          typename ELFT::uint RelOff) {
  if (Body.isGnuIFunc()) {
    Expr = toPlt(Expr);
  } else if (!isPreemptible(Body, Type)) {
    if (needsPlt(Expr))
      Expr = fromPlt(Expr);
    if (Expr == R_GOT_PC && !isAbsoluteValue(Body))
      Expr = Target->adjustRelaxExpr(Type, Data, Expr);
  }

  bool IsWrite = !Config->ZText || (S.Flags & SHF_WRITE);
  if (IsWrite || isStaticLinkTimeConstant<ELFT>(Expr, Type, Body, S, RelOff))
    return Expr;

  // This relocation would require the dynamic linker to write a value to read
  // only memory. We can hack around it if we are producing an executable and
  // the refered symbol can be preemepted to refer to the executable.
  if (Config->Shared || (Config->Pic && !isRelExpr(Expr))) {
    error("can't create dynamic relocation " + toString(Type) + " against " +
          (Body.getName().empty() ? "local symbol"
                                  : "symbol: " + toString(Body)) +
          " in readonly segment" + getLocation<ELFT>(S, Body, RelOff));
    return Expr;
  }

  if (Body.getVisibility() != STV_DEFAULT) {
    error("cannot preempt symbol: " + toString(Body) +
          getLocation<ELFT>(S, Body, RelOff));
    return Expr;
  }

  if (Body.isObject()) {
    // Produce a copy relocation.
    auto *B = cast<SharedSymbol>(&Body);
    if (!B->NeedsCopy) {
      if (Config->ZNocopyreloc)
        error("unresolvable relocation " + toString(Type) +
              " against symbol '" + toString(*B) +
              "'; recompile with -fPIC or remove '-z nocopyreloc'" +
              getLocation<ELFT>(S, Body, RelOff));

      addCopyRelSymbol<ELFT>(B);
    }
    return Expr;
  }

  if (Body.isFunc()) {
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
    Body.NeedsPltAddr = true;
    return toPlt(Expr);
  }

  error("symbol '" + toString(Body) + "' defined in " + toString(Body.File) +
        " has no type");
  return Expr;
}

// Returns an addend of a given relocation. If it is RELA, an addend
// is in a relocation itself. If it is REL, we need to read it from an
// input section.
template <class ELFT, class RelTy>
static int64_t computeAddend(const RelTy &Rel, const uint8_t *Buf) {
  uint32_t Type = Rel.getType(Config->IsMips64EL);
  int64_t A = RelTy::IsRela
                  ? getAddend<ELFT>(Rel)
                  : Target->getImplicitAddend(Buf + Rel.r_offset, Type);

  if (Config->EMachine == EM_PPC64 && Config->Pic && Type == R_PPC64_TOC)
    A += getPPC64TocBase();
  return A;
}

// MIPS has an odd notion of "paired" relocations to calculate addends.
// For example, if a relocation is of R_MIPS_HI16, there must be a
// R_MIPS_LO16 relocation after that, and an addend is calculated using
// the two relocations.
template <class ELFT, class RelTy>
static int64_t computeMipsAddend(const RelTy &Rel, InputSectionBase &Sec,
                                 RelExpr Expr, SymbolBody &Body,
                                 const RelTy *End) {
  if (Expr == R_MIPS_GOTREL && Body.isLocal())
    return Sec.getFile<ELFT>()->MipsGp0;

  // The ABI says that the paired relocation is used only for REL.
  // See p. 4-17 at ftp://www.linux-mips.org/pub/linux/mips/doc/ABI/mipsabi.pdf
  if (RelTy::IsRela)
    return 0;

  uint32_t Type = Rel.getType(Config->IsMips64EL);
  uint32_t PairTy = getMipsPairType(Type, Body);
  if (PairTy == R_MIPS_NONE)
    return 0;

  const uint8_t *Buf = Sec.Data.data();
  uint32_t SymIndex = Rel.getSymbol(Config->IsMips64EL);

  // To make things worse, paired relocations might not be contiguous in
  // the relocation table, so we need to do linear search. *sigh*
  for (const RelTy *RI = &Rel; RI != End; ++RI) {
    if (RI->getType(Config->IsMips64EL) != PairTy)
      continue;
    if (RI->getSymbol(Config->IsMips64EL) != SymIndex)
      continue;

    endianness E = Config->Endianness;
    int32_t Hi = (read32(Buf + Rel.r_offset, E) & 0xffff) << 16;
    int32_t Lo = SignExtend32<16>(read32(Buf + RI->r_offset, E));
    return Hi + Lo;
  }

  warn("can't find matching " + toString(PairTy) + " relocation for " +
       toString(Type));
  return 0;
}

template <class ELFT>
static void reportUndefined(SymbolBody &Sym, InputSectionBase &S,
                            uint64_t Offset) {
  if (Config->UnresolvedSymbols == UnresolvedPolicy::IgnoreAll)
    return;

  bool CanBeExternal = Sym.symbol()->computeBinding() != STB_LOCAL &&
                       Sym.getVisibility() == STV_DEFAULT;
  if (Config->UnresolvedSymbols == UnresolvedPolicy::Ignore && CanBeExternal)
    return;

  std::string Msg =
      "undefined symbol: " + toString(Sym) + "\n>>> referenced by ";

  std::string Src = S.getSrcMsg<ELFT>(Offset);
  if (!Src.empty())
    Msg += Src + "\n>>>               ";
  Msg += S.getObjMsg<ELFT>(Offset);

  if (Config->UnresolvedSymbols == UnresolvedPolicy::WarnAll ||
      (Config->UnresolvedSymbols == UnresolvedPolicy::Warn && CanBeExternal)) {
    warn(Msg);
  } else {
    error(Msg);
  }
}

template <class RelTy>
static std::pair<uint32_t, uint32_t>
mergeMipsN32RelTypes(uint32_t Type, uint32_t Offset, RelTy *I, RelTy *E) {
  // MIPS N32 ABI treats series of successive relocations with the same offset
  // as a single relocation. The similar approach used by N64 ABI, but this ABI
  // packs all relocations into the single relocation record. Here we emulate
  // this for the N32 ABI. Iterate over relocation with the same offset and put
  // theirs types into the single bit-set.
  uint32_t Processed = 0;
  for (; I != E && Offset == I->r_offset; ++I) {
    ++Processed;
    Type |= I->getType(Config->IsMips64EL) << (8 * Processed);
  }
  return std::make_pair(Type, Processed);
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
    if (auto *Eh = dyn_cast<EhInputSection>(&Sec)) {
      P = Eh->Pieces;
      Size = Eh->Pieces.size();
    }
  }

  // Translates offsets in input sections to offsets in output sections.
  // Given offset must increase monotonically. We assume that P is
  // sorted by InputOff.
  uint64_t get(uint64_t Off) {
    if (P.empty())
      return Off;

    while (I != Size && P[I].InputOff + P[I].size() <= Off)
      ++I;
    if (I == Size)
      return Off;

    // P must be contiguous, so there must be no holes in between.
    assert(P[I].InputOff <= Off && "Relocation not in any piece");

    // Offset -1 means that the piece is dead (i.e. garbage collected).
    if (P[I].OutputOff == -1)
      return -1;
    return P[I].OutputOff + Off - P[I].InputOff;
  }

private:
  ArrayRef<EhSectionPiece> P;
  size_t I = 0;
  size_t Size;
};
} // namespace

template <class ELFT, class GotPltSection>
static void addPltEntry(PltSection *Plt, GotPltSection *GotPlt,
                        RelocationSection<ELFT> *Rel, uint32_t Type,
                        SymbolBody &Sym, bool UseSymVA) {
  Plt->addEntry<ELFT>(Sym);
  GotPlt->addEntry(Sym);
  Rel->addReloc({Type, GotPlt, Sym.getGotPltOffset(), UseSymVA, &Sym, 0});
}

template <class ELFT>
static void addGotEntry(SymbolBody &Sym, bool Preemptible) {
  InX::Got->addEntry(Sym);

  uint64_t Off = Sym.getGotOffset();
  uint32_t DynType;
  RelExpr Expr = R_ABS;

  if (Sym.isTls()) {
    DynType = Target->TlsGotRel;
    Expr = R_TLS;
  } else if (!Preemptible && Config->Pic && !isAbsolute(Sym)) {
    DynType = Target->RelativeRel;
  } else {
    DynType = Target->GotRel;
  }

  bool Constant = !Preemptible && !(Config->Pic && !isAbsolute(Sym));
  if (!Constant)
    In<ELFT>::RelaDyn->addReloc(
        {DynType, InX::Got, Off, !Preemptible, &Sym, 0});

  if (Constant || (!Config->IsRela && !Preemptible))
    InX::Got->Relocations.push_back({Expr, DynType, Off, 0, &Sym});
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

  for (auto I = Rels.begin(), End = Rels.end(); I != End; ++I) {
    const RelTy &Rel = *I;
    SymbolBody &Body = Sec.getFile<ELFT>()->getRelocTargetSym(Rel);
    uint32_t Type = Rel.getType(Config->IsMips64EL);

    if (Config->MipsN32Abi) {
      uint32_t Processed;
      std::tie(Type, Processed) =
          mergeMipsN32RelTypes(Type, Rel.r_offset, I + 1, End);
      I += Processed;
    }

    // Compute the offset of this section in the output section.
    uint64_t Offset = GetOffset.get(Rel.r_offset);
    if (Offset == uint64_t(-1))
      continue;

    // Report undefined symbols. The fact that we report undefined
    // symbols here means that we report undefined symbols only when
    // they have relocations pointing to them. We don't care about
    // undefined symbols that are in dead-stripped sections.
    if (!Body.isLocal() && Body.isUndefined() && !Body.symbol()->isWeak())
      reportUndefined<ELFT>(Body, Sec, Rel.r_offset);

    RelExpr Expr =
        Target->getRelExpr(Type, Body, Sec.Data.begin() + Rel.r_offset);

    // Ignore "hint" relocations because they are only markers for relaxation.
    if (isRelExprOneOf<R_HINT, R_NONE>(Expr))
      continue;

    bool Preemptible = isPreemptible(Body, Type);
    Expr = adjustExpr<ELFT>(Body, Expr, Type, Sec.Data.data() + Rel.r_offset,
                            Sec, Rel.r_offset);
    if (ErrorCount)
      continue;

    // This relocation does not require got entry, but it is relative to got and
    // needs it to be created. Here we request for that.
    if (isRelExprOneOf<R_GOTONLY_PC, R_GOTONLY_PC_FROM_END, R_GOTREL,
                       R_GOTREL_FROM_END, R_PPC_TOC>(Expr))
      InX::Got->HasGotOffRel = true;

    // Read an addend.
    int64_t Addend = computeAddend<ELFT>(Rel, Sec.Data.data());
    if (Config->EMachine == EM_MIPS)
      Addend += computeMipsAddend<ELFT>(Rel, Sec, Expr, Body, End);

    // Process some TLS relocations, including relaxing TLS relocations.
    // Note that this function does not handle all TLS relocations.
    if (unsigned Processed =
            handleTlsRelocation<ELFT>(Type, Body, Sec, Offset, Addend, Expr)) {
      I += (Processed - 1);
      continue;
    }

    // If a relocation needs PLT, we create PLT and GOTPLT slots for the symbol.
    if (needsPlt(Expr) && !Body.isInPlt()) {
      if (Body.isGnuIFunc() && !Preemptible)
        addPltEntry(InX::Iplt, InX::IgotPlt, In<ELFT>::RelaIplt,
                    Target->IRelativeRel, Body, true);
      else
        addPltEntry(InX::Plt, InX::GotPlt, In<ELFT>::RelaPlt, Target->PltRel,
                    Body, !Preemptible);
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
        InX::MipsGot->addEntry(Body, Addend, Expr);
        if (Body.isTls() && Body.isPreemptible())
          In<ELFT>::RelaDyn->addReloc({Target->TlsGotRel, InX::MipsGot,
                                       Body.getGotOffset(), false, &Body, 0});
      } else if (!Body.isInGot()) {
        addGotEntry<ELFT>(Body, Preemptible);
      }
    }

    if (!needsPlt(Expr) && !needsGot(Expr) && isPreemptible(Body, Type)) {
      // We don't know anything about the finaly symbol. Just ask the dynamic
      // linker to handle the relocation for us.
      if (!Target->isPicRel(Type))
        error("relocation " + toString(Type) +
              " cannot be used against shared object; recompile with -fPIC" +
              getLocation<ELFT>(Sec, Body, Offset));

      In<ELFT>::RelaDyn->addReloc(
          {Target->getDynRel(Type), &Sec, Offset, false, &Body, Addend});

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
        InX::MipsGot->addEntry(Body, Addend, Expr);
      continue;
    }

    // If the relocation points to something in the file, we can process it.
    bool IsConstant =
        isStaticLinkTimeConstant<ELFT>(Expr, Type, Body, Sec, Rel.r_offset);

    // The size is not going to change, so we fold it in here.
    if (Expr == R_SIZE)
      Addend += Body.getSize<ELFT>();

    // If the output being produced is position independent, the final value
    // is still not known. In that case we still need some help from the
    // dynamic linker. We can however do better than just copying the incoming
    // relocation. We can process some of it and and just ask the dynamic
    // linker to add the load address.
    if (!IsConstant)
      In<ELFT>::RelaDyn->addReloc(
          {Target->RelativeRel, &Sec, Offset, true, &Body, Addend});

    // If the produced value is a constant, we just remember to write it
    // when outputting this section. We also have to do it if the format
    // uses Elf_Rel, since in that case the written value is the addend.
    if (IsConstant || !RelTy::IsRela)
      Sec.Relocations.push_back({Expr, Type, Offset, Addend, &Body});
  }
}

template <class ELFT> void elf::scanRelocations(InputSectionBase &S) {
  if (S.AreRelocsRela)
    scanRelocs<ELFT>(S, S.relas<ELFT>());
  else
    scanRelocs<ELFT>(S, S.rels<ELFT>());
}

// Insert the Thunks for OutputSection OS into their designated place
// in the Sections vector, and recalculate the InputSection output section
// offsets.
// This may invalidate any output section offsets stored outside of InputSection
void ThunkCreator::mergeThunks() {
  for (auto &KV : ThunkSections) {
    std::vector<InputSection *> *ISR = KV.first;
    std::vector<ThunkSection *> &Thunks = KV.second;

    // Order Thunks in ascending OutSecOff
    auto ThunkCmp = [](const ThunkSection *A, const ThunkSection *B) {
      return A->OutSecOff < B->OutSecOff;
    };
    std::stable_sort(Thunks.begin(), Thunks.end(), ThunkCmp);

    // Merge sorted vectors of Thunks and InputSections by OutSecOff
    std::vector<InputSection *> Tmp;
    Tmp.reserve(ISR->size() + Thunks.size());
    auto MergeCmp = [](const InputSection *A, const InputSection *B) {
      // std::merge requires a strict weak ordering.
      if (A->OutSecOff < B->OutSecOff)
        return true;
      if (A->OutSecOff == B->OutSecOff)
        // Check if Thunk is immediately before any specific Target InputSection
        // for example Mips LA25 Thunks.
        if (auto *TA = dyn_cast<ThunkSection>(A))
          if (TA && TA->getTargetInputSection() == B)
            return true;
      return false;
    };
    std::merge(ISR->begin(), ISR->end(), Thunks.begin(), Thunks.end(),
               std::back_inserter(Tmp), MergeCmp);
    *ISR = std::move(Tmp);
  }
}

static uint32_t findEndOfFirstNonExec(OutputSectionCommand &Cmd) {
  for (BaseCommand *Base : Cmd.Commands)
    if (auto *ISD = dyn_cast<InputSectionDescription>(Base))
      for (auto *IS : ISD->Sections)
        if ((IS->Flags & SHF_EXECINSTR) == 0)
          return IS->OutSecOff + IS->getSize();
  return 0;
}

ThunkSection *ThunkCreator::getOSThunkSec(OutputSectionCommand *Cmd,
                                          std::vector<InputSection *> *ISR) {
  if (CurTS == nullptr) {
    uint32_t Off = findEndOfFirstNonExec(*Cmd);
    CurTS = addThunkSection(Cmd->Sec, ISR, Off);
  }
  return CurTS;
}

ThunkSection *ThunkCreator::getISThunkSec(InputSection *IS, OutputSection *OS) {
  ThunkSection *TS = ThunkedSections.lookup(IS);
  if (TS)
    return TS;
  auto *TOS = IS->getParent();

  // Find InputSectionRange within TOS that IS is in
  OutputSectionCommand *C = Script->getCmd(TOS);
  std::vector<InputSection *> *Range = nullptr;
  for (BaseCommand *BC : C->Commands)
    if (auto *ISD = dyn_cast<InputSectionDescription>(BC)) {
      InputSection *first = ISD->Sections.front();
      InputSection *last = ISD->Sections.back();
      if (IS->OutSecOff >= first->OutSecOff &&
          IS->OutSecOff <= last->OutSecOff) {
        Range = &ISD->Sections;
        break;
      }
    }
  TS = addThunkSection(TOS, Range, IS->OutSecOff);
  ThunkedSections[IS] = TS;
  return TS;
}

ThunkSection *ThunkCreator::addThunkSection(OutputSection *OS,
                                            std::vector<InputSection *> *ISR,
                                            uint64_t Off) {
  auto *TS = make<ThunkSection>(OS, Off);
  ThunkSections[ISR].push_back(TS);
  return TS;
}

std::pair<Thunk *, bool> ThunkCreator::getThunk(SymbolBody &Body,
                                                uint32_t Type) {
  auto Res = ThunkedSymbols.insert({&Body, std::vector<Thunk *>()});
  if (!Res.second) {
    // Check existing Thunks for Body to see if they can be reused
    for (Thunk *ET : Res.first->second)
      if (ET->isCompatibleWith(Type))
        return std::make_pair(ET, false);
  }
  // No existing compatible Thunk in range, create a new one
  Thunk *T = addThunk(Type, Body);
  Res.first->second.push_back(T);
  return std::make_pair(T, true);
}

// Call Fn on every executable InputSection accessed via the linker script
// InputSectionDescription::Sections.
void ThunkCreator::forEachExecInputSection(
    ArrayRef<OutputSectionCommand *> OutputSections,
    std::function<void(OutputSectionCommand *, std::vector<InputSection *> *,
                       InputSection *)>
        Fn) {
  for (OutputSectionCommand *Cmd : OutputSections) {
    OutputSection *OS = Cmd->Sec;
    if (!(OS->Flags & SHF_ALLOC) || !(OS->Flags & SHF_EXECINSTR))
      continue;
    for (BaseCommand *BC : Cmd->Commands)
      if (auto *ISD = dyn_cast<InputSectionDescription>(BC)) {
        CurTS = nullptr;
        for (InputSection *IS : ISD->Sections)
          Fn(Cmd, &ISD->Sections, IS);
      }
  }
}

// Process all relocations from the InputSections that have been assigned
// to OutputSections and redirect through Thunks if needed.
//
// createThunks must be called after scanRelocs has created the Relocations for
// each InputSection. It must be called before the static symbol table is
// finalized. If any Thunks are added to an OutputSection the output section
// offsets of the InputSections will change.
//
// FIXME: All Thunks are assumed to be in range of the relocation. Range
// extension Thunks are not yet supported.
bool ThunkCreator::createThunks(
    ArrayRef<OutputSectionCommand *> OutputSections) {
  if (Pass > 0)
    ThunkSections.clear();

  // Create all the Thunks and insert them into synthetic ThunkSections. The
  // ThunkSections are later inserted back into the OutputSection.

  // We separate the creation of ThunkSections from the insertion of the
  // ThunkSections back into the OutputSection as ThunkSections are not always
  // inserted into the same OutputSection as the caller.
  forEachExecInputSection(OutputSections, [&](OutputSectionCommand *Cmd,
                                              std::vector<InputSection *> *ISR,
                                              InputSection *IS) {
    for (Relocation &Rel : IS->Relocations) {
      SymbolBody &Body = *Rel.Sym;
      if (Thunks.find(&Body) != Thunks.end() ||
          !Target->needsThunk(Rel.Expr, Rel.Type, IS->File, Body))
        continue;
      Thunk *T;
      bool IsNew;
      std::tie(T, IsNew) = getThunk(Body, Rel.Type);
      if (IsNew) {
        // Find or create a ThunkSection for the new Thunk
        ThunkSection *TS;
        if (auto *TIS = T->getTargetInputSection())
          TS = getISThunkSec(TIS, Cmd->Sec);
        else
          TS = getOSThunkSec(Cmd, ISR);
        TS->addThunk(T);
        Thunks[T->ThunkSym] = T;
      }
      // Redirect relocation to Thunk, we never go via the PLT to a Thunk
      Rel.Sym = T->ThunkSym;
      Rel.Expr = fromPlt(Rel.Expr);
    }
  });
  // Merge all created synthetic ThunkSections back into OutputSection
  mergeThunks();
  ++Pass;
  return !ThunkSections.empty();
}

template void elf::scanRelocations<ELF32LE>(InputSectionBase &);
template void elf::scanRelocations<ELF32BE>(InputSectionBase &);
template void elf::scanRelocations<ELF64LE>(InputSectionBase &);
template void elf::scanRelocations<ELF64BE>(InputSectionBase &);
