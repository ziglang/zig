//===- Symbols.cpp --------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "Symbols.h"
#include "InputFiles.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Memory.h"
#include "lld/Common/Strings.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;
using namespace llvm::object;

using namespace lld::coff;

namespace lld {

static_assert(sizeof(SymbolUnion) <= 48,
              "symbols should be optimized for memory usage");

// Returns a symbol name for an error message.
static std::string demangle(StringRef symName) {
  if (config->demangle)
    if (Optional<std::string> s = demangleMSVC(symName))
      return *s;
  return symName;
}
std::string toString(coff::Symbol &b) { return demangle(b.getName()); }
std::string toCOFFString(const Archive::Symbol &b) {
  return demangle(b.getName());
}

namespace coff {

StringRef Symbol::getName() {
  // COFF symbol names are read lazily for a performance reason.
  // Non-external symbol names are never used by the linker except for logging
  // or debugging. Their internal references are resolved not by name but by
  // symbol index. And because they are not external, no one can refer them by
  // name. Object files contain lots of non-external symbols, and creating
  // StringRefs for them (which involves lots of strlen() on the string table)
  // is a waste of time.
  if (nameData == nullptr) {
    auto *d = cast<DefinedCOFF>(this);
    StringRef nameStr;
    cast<ObjFile>(d->file)->getCOFFObj()->getSymbolName(d->sym, nameStr);
    nameData = nameStr.data();
    nameSize = nameStr.size();
    assert(nameSize == nameStr.size() && "name length truncated");
  }
  return StringRef(nameData, nameSize);
}

InputFile *Symbol::getFile() {
  if (auto *sym = dyn_cast<DefinedCOFF>(this))
    return sym->file;
  if (auto *sym = dyn_cast<Lazy>(this))
    return sym->file;
  return nullptr;
}

bool Symbol::isLive() const {
  if (auto *r = dyn_cast<DefinedRegular>(this))
    return r->getChunk()->live;
  if (auto *imp = dyn_cast<DefinedImportData>(this))
    return imp->file->live;
  if (auto *imp = dyn_cast<DefinedImportThunk>(this))
    return imp->wrappedSym->file->thunkLive;
  // Assume any other kind of symbol is live.
  return true;
}

// MinGW specific.
void Symbol::replaceKeepingName(Symbol *other, size_t size) {
  StringRef origName = getName();
  memcpy(this, other, size);
  nameData = origName.data();
  nameSize = origName.size();
}

COFFSymbolRef DefinedCOFF::getCOFFSymbol() {
  size_t symSize = cast<ObjFile>(file)->getCOFFObj()->getSymbolTableEntrySize();
  if (symSize == sizeof(coff_symbol16))
    return COFFSymbolRef(reinterpret_cast<const coff_symbol16 *>(sym));
  assert(symSize == sizeof(coff_symbol32));
  return COFFSymbolRef(reinterpret_cast<const coff_symbol32 *>(sym));
}

uint16_t DefinedAbsolute::numOutputSections;

static Chunk *makeImportThunk(DefinedImportData *s, uint16_t machine) {
  if (machine == AMD64)
    return make<ImportThunkChunkX64>(s);
  if (machine == I386)
    return make<ImportThunkChunkX86>(s);
  if (machine == ARM64)
    return make<ImportThunkChunkARM64>(s);
  assert(machine == ARMNT);
  return make<ImportThunkChunkARM>(s);
}

DefinedImportThunk::DefinedImportThunk(StringRef name, DefinedImportData *s,
                                       uint16_t machine)
    : Defined(DefinedImportThunkKind, name), wrappedSym(s),
      data(makeImportThunk(s, machine)) {}

Defined *Undefined::getWeakAlias() {
  // A weak alias may be a weak alias to another symbol, so check recursively.
  for (Symbol *a = weakAlias; a; a = cast<Undefined>(a)->weakAlias)
    if (auto *d = dyn_cast<Defined>(a))
      return d;
  return nullptr;
}

MemoryBufferRef Lazy::getMemberBuffer() {
  Archive::Child c =
    CHECK(sym.getMember(),
          "could not get the member for symbol " + toCOFFString(sym));
  return CHECK(c.getMemoryBufferRef(),
      "could not get the buffer for the member defining symbol " +
      toCOFFString(sym));
}
} // namespace coff
} // namespace lld
