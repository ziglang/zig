//===- Symbols.h ------------------------------------------------*- C++ -*-===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// All symbols are handled as SymbolBodies regardless of their types.
// This file defines various types of SymbolBodies.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_ELF_SYMBOLS_H
#define LLD_ELF_SYMBOLS_H

#include "InputSection.h"
#include "Strings.h"

#include "lld/Core/LLVM.h"
#include "llvm/Object/Archive.h"
#include "llvm/Object/ELF.h"

namespace lld {
namespace elf {

class ArchiveFile;
class BitcodeFile;
class InputFile;
class LazyObjectFile;
template <class ELFT> class ObjectFile;
class OutputSection;
template <class ELFT> class SharedFile;

struct Symbol;

// The base class for real symbol classes.
class SymbolBody {
public:
  enum Kind {
    DefinedFirst,
    DefinedRegularKind = DefinedFirst,
    SharedKind,
    DefinedCommonKind,
    DefinedLast = DefinedCommonKind,
    UndefinedKind,
    LazyArchiveKind,
    LazyObjectKind,
  };

  SymbolBody(Kind K) : SymbolKind(K) {}

  Symbol *symbol();
  const Symbol *symbol() const {
    return const_cast<SymbolBody *>(this)->symbol();
  }

  Kind kind() const { return static_cast<Kind>(SymbolKind); }

  bool isUndefined() const { return SymbolKind == UndefinedKind; }
  bool isDefined() const { return SymbolKind <= DefinedLast; }
  bool isCommon() const { return SymbolKind == DefinedCommonKind; }
  bool isLazy() const {
    return SymbolKind == LazyArchiveKind || SymbolKind == LazyObjectKind;
  }
  bool isShared() const { return SymbolKind == SharedKind; }
  bool isInCurrentDSO() const {
    return !isUndefined() && !isShared() && !isLazy();
  }
  bool isLocal() const { return IsLocal; }
  bool isPreemptible() const;
  StringRef getName() const { return Name; }
  uint8_t getVisibility() const { return StOther & 0x3; }
  void parseSymbolVersion();
  void copy(SymbolBody *Other);

  bool isInGot() const { return GotIndex != -1U; }
  bool isInPlt() const { return PltIndex != -1U; }

  uint64_t getVA(int64_t Addend = 0) const;

  uint64_t getGotOffset() const;
  uint64_t getGotVA() const;
  uint64_t getGotPltOffset() const;
  uint64_t getGotPltVA() const;
  uint64_t getPltVA() const;
  template <class ELFT> typename ELFT::uint getSize() const;
  OutputSection *getOutputSection() const;

  // The file from which this symbol was created.
  InputFile *File = nullptr;

  uint32_t DynsymIndex = 0;
  uint32_t GotIndex = -1;
  uint32_t GotPltIndex = -1;
  uint32_t PltIndex = -1;
  uint32_t GlobalDynIndex = -1;

protected:
  SymbolBody(Kind K, StringRefZ Name, bool IsLocal, uint8_t StOther,
             uint8_t Type);

  const unsigned SymbolKind : 8;

public:
  // True if the linker has to generate a copy relocation.
  // For SharedSymbol only.
  unsigned NeedsCopy : 1;

  // True the symbol should point to its PLT entry.
  // For SharedSymbol only.
  unsigned NeedsPltAddr : 1;

  // True if this is a local symbol.
  unsigned IsLocal : 1;

  // True if this symbol has an entry in the global part of MIPS GOT.
  unsigned IsInGlobalMipsGot : 1;

  // True if this symbol is referenced by 32-bit GOT relocations.
  unsigned Is32BitMipsGot : 1;

  // True if this symbol is in the Iplt sub-section of the Plt.
  unsigned IsInIplt : 1;

  // True if this symbol is in the Igot sub-section of the .got.plt or .got.
  unsigned IsInIgot : 1;

  // The following fields have the same meaning as the ELF symbol attributes.
  uint8_t Type;    // symbol type
  uint8_t StOther; // st_other field value

  // The Type field may also have this value. It means that we have not yet seen
  // a non-Lazy symbol with this name, so we don't know what its type is. The
  // Type field is normally set to this value for Lazy symbols unless we saw a
  // weak undefined symbol first, in which case we need to remember the original
  // symbol's type in order to check for TLS mismatches.
  enum { UnknownType = 255 };

  bool isSection() const { return Type == llvm::ELF::STT_SECTION; }
  bool isTls() const { return Type == llvm::ELF::STT_TLS; }
  bool isFunc() const { return Type == llvm::ELF::STT_FUNC; }
  bool isGnuIFunc() const { return Type == llvm::ELF::STT_GNU_IFUNC; }
  bool isObject() const { return Type == llvm::ELF::STT_OBJECT; }
  bool isFile() const { return Type == llvm::ELF::STT_FILE; }

protected:
  StringRefZ Name;
};

// The base class for any defined symbols.
class Defined : public SymbolBody {
public:
  Defined(Kind K, StringRefZ Name, bool IsLocal, uint8_t StOther, uint8_t Type);
  static bool classof(const SymbolBody *S) { return S->isDefined(); }
};

class DefinedCommon : public Defined {
public:
  DefinedCommon(StringRef N, uint64_t Size, uint32_t Alignment, uint8_t StOther,
                uint8_t Type, InputFile *File);

  static bool classof(const SymbolBody *S) {
    return S->kind() == SymbolBody::DefinedCommonKind;
  }

  // The output offset of this common symbol in the output bss. Computed by the
  // writer.
  uint64_t Offset;

  // The maximum alignment we have seen for this symbol.
  uint32_t Alignment;

  uint64_t Size;
};

// Regular defined symbols read from object file symbol tables.
class DefinedRegular : public Defined {
public:
  DefinedRegular(StringRefZ Name, bool IsLocal, uint8_t StOther, uint8_t Type,
                 uint64_t Value, uint64_t Size, SectionBase *Section,
                 InputFile *File)
      : Defined(SymbolBody::DefinedRegularKind, Name, IsLocal, StOther, Type),
        Value(Value), Size(Size), Section(Section) {
    this->File = File;
  }

  // Return true if the symbol is a PIC function.
  template <class ELFT> bool isMipsPIC() const;

  static bool classof(const SymbolBody *S) {
    return S->kind() == SymbolBody::DefinedRegularKind;
  }

  uint64_t Value;
  uint64_t Size;
  SectionBase *Section;
};

class Undefined : public SymbolBody {
public:
  Undefined(StringRefZ Name, bool IsLocal, uint8_t StOther, uint8_t Type,
            InputFile *F);

  static bool classof(const SymbolBody *S) {
    return S->kind() == UndefinedKind;
  }
};

class SharedSymbol : public Defined {
public:
  static bool classof(const SymbolBody *S) {
    return S->kind() == SymbolBody::SharedKind;
  }

  SharedSymbol(InputFile *File, StringRef Name, uint8_t StOther, uint8_t Type,
               const void *ElfSym, const void *Verdef)
      : Defined(SymbolBody::SharedKind, Name, /*IsLocal=*/false, StOther, Type),
        Verdef(Verdef), ElfSym(ElfSym) {
    // IFuncs defined in DSOs are treated as functions by the static linker.
    if (isGnuIFunc())
      this->Type = llvm::ELF::STT_FUNC;
    this->File = File;
  }

  template <class ELFT> uint64_t getShndx() const {
    return getSym<ELFT>().st_shndx;
  }

  template <class ELFT> uint64_t getValue() const {
    return getSym<ELFT>().st_value;
  }

  template <class ELFT> uint64_t getSize() const {
    return getSym<ELFT>().st_size;
  }

  template <class ELFT> uint32_t getAlignment() const;

  // This field is a pointer to the symbol's version definition.
  const void *Verdef;

  // CopyRelSec and CopyRelSecOff are significant only when NeedsCopy is true.
  InputSection *CopyRelSec;
  uint64_t CopyRelSecOff;

private:
  template <class ELFT> const typename ELFT::Sym &getSym() const {
    return *(const typename ELFT::Sym *)ElfSym;
  }

  const void *ElfSym;
};

// This class represents a symbol defined in an archive file. It is
// created from an archive file header, and it knows how to load an
// object file from an archive to replace itself with a defined
// symbol. If the resolver finds both Undefined and Lazy for
// the same name, it will ask the Lazy to load a file.
class Lazy : public SymbolBody {
public:
  static bool classof(const SymbolBody *S) { return S->isLazy(); }

  // Returns an object file for this symbol, or a nullptr if the file
  // was already returned.
  InputFile *fetch();

protected:
  Lazy(SymbolBody::Kind K, StringRef Name, uint8_t Type)
      : SymbolBody(K, Name, /*IsLocal=*/false, llvm::ELF::STV_DEFAULT, Type) {}
};

// LazyArchive symbols represents symbols in archive files.
class LazyArchive : public Lazy {
public:
  LazyArchive(ArchiveFile &File, const llvm::object::Archive::Symbol S,
              uint8_t Type);

  static bool classof(const SymbolBody *S) {
    return S->kind() == LazyArchiveKind;
  }

  ArchiveFile *file() { return (ArchiveFile *)this->File; }
  InputFile *fetch();

private:
  const llvm::object::Archive::Symbol Sym;
};

// LazyObject symbols represents symbols in object files between
// --start-lib and --end-lib options.
class LazyObject : public Lazy {
public:
  LazyObject(StringRef Name, LazyObjectFile &File, uint8_t Type);

  static bool classof(const SymbolBody *S) {
    return S->kind() == LazyObjectKind;
  }

  LazyObjectFile *file() { return (LazyObjectFile *)this->File; }
  InputFile *fetch();
};

// Some linker-generated symbols need to be created as
// DefinedRegular symbols.
struct ElfSym {
  // __bss_start
  static DefinedRegular *Bss;

  // etext and _etext
  static DefinedRegular *Etext1;
  static DefinedRegular *Etext2;

  // edata and _edata
  static DefinedRegular *Edata1;
  static DefinedRegular *Edata2;

  // end and _end
  static DefinedRegular *End1;
  static DefinedRegular *End2;

  // The _GLOBAL_OFFSET_TABLE_ symbol is defined by target convention to
  // be at some offset from the base of the .got section, usually 0 or
  // the end of the .got.
  static DefinedRegular *GlobalOffsetTable;

  // _gp, _gp_disp and __gnu_local_gp symbols. Only for MIPS.
  static DefinedRegular *MipsGp;
  static DefinedRegular *MipsGpDisp;
  static DefinedRegular *MipsLocalGp;
};

// A real symbol object, SymbolBody, is usually stored within a Symbol. There's
// always one Symbol for each symbol name. The resolver updates the SymbolBody
// stored in the Body field of this object as it resolves symbols. Symbol also
// holds computed properties of symbol names.
struct Symbol {
  // Symbol binding. This is on the Symbol to track changes during resolution.
  // In particular:
  // An undefined weak is still weak when it resolves to a shared library.
  // An undefined weak will not fetch archive members, but we have to remember
  // it is weak.
  uint8_t Binding;

  // Version definition index.
  uint16_t VersionId;

  // Symbol visibility. This is the computed minimum visibility of all
  // observed non-DSO symbols.
  unsigned Visibility : 2;

  // True if the symbol was used for linking and thus need to be added to the
  // output file's symbol table. This is true for all symbols except for
  // unreferenced DSO symbols and bitcode symbols that are unreferenced except
  // by other bitcode objects.
  unsigned IsUsedInRegularObj : 1;

  // If this flag is true and the symbol has protected or default visibility, it
  // will appear in .dynsym. This flag is set by interposable DSO symbols in
  // executables, by most symbols in DSOs and executables built with
  // --export-dynamic, and by dynamic lists.
  unsigned ExportDynamic : 1;

  // True if this symbol is specified by --trace-symbol option.
  unsigned Traced : 1;

  // This symbol version was found in a version script.
  unsigned InVersionScript : 1;

  bool includeInDynsym() const;
  uint8_t computeBinding() const;
  bool isWeak() const { return Binding == llvm::ELF::STB_WEAK; }

  // This field is used to store the Symbol's SymbolBody. This instantiation of
  // AlignedCharArrayUnion gives us a struct with a char array field that is
  // large and aligned enough to store any derived class of SymbolBody.
  llvm::AlignedCharArrayUnion<DefinedCommon, DefinedRegular, Undefined,
                              SharedSymbol, LazyArchive, LazyObject>
      Body;

  SymbolBody *body() { return reinterpret_cast<SymbolBody *>(Body.buffer); }
  const SymbolBody *body() const { return const_cast<Symbol *>(this)->body(); }
};

void printTraceSymbol(Symbol *Sym);

template <typename T, typename... ArgT>
void replaceBody(Symbol *S, ArgT &&... Arg) {
  static_assert(sizeof(T) <= sizeof(S->Body), "Body too small");
  static_assert(alignof(T) <= alignof(decltype(S->Body)),
                "Body not aligned enough");
  assert(static_cast<SymbolBody *>(static_cast<T *>(nullptr)) == nullptr &&
         "Not a SymbolBody");

  new (S->Body.buffer) T(std::forward<ArgT>(Arg)...);

  // Print out a log message if --trace-symbol was specified.
  // This is for debugging.
  if (S->Traced)
    printTraceSymbol(S);
}

inline Symbol *SymbolBody::symbol() {
  assert(!isLocal());
  return reinterpret_cast<Symbol *>(reinterpret_cast<char *>(this) -
                                    offsetof(Symbol, Body));
}
} // namespace elf

std::string toString(const elf::SymbolBody &B);
} // namespace lld

#endif
