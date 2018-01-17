//===- Thunks.h --------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_ELF_THUNKS_H
#define LLD_ELF_THUNKS_H

#include "Relocations.h"

namespace lld {
namespace elf {
class Symbol;
class ThunkSection;
// Class to describe an instance of a Thunk.
// A Thunk is a code-sequence inserted by the linker in between a caller and
// the callee. The relocation to the callee is redirected to the Thunk, which
// after executing transfers control to the callee. Typical uses of Thunks
// include transferring control from non-pi to pi and changing state on
// targets like ARM.
//
// Thunks can be created for Defined, Shared and Undefined Symbols.
// Thunks are assigned to synthetic ThunkSections
class Thunk {
public:
  Thunk(Symbol &Destination);
  virtual ~Thunk();

  virtual uint32_t size() const { return 0; }
  virtual void writeTo(uint8_t *Buf, ThunkSection &IS) const {}

  // All Thunks must define at least one symbol ThunkSym so that we can
  // redirect relocations to it.
  virtual void addSymbols(ThunkSection &IS) {}

  // Some Thunks must be placed immediately before their Target as they elide
  // a branch and fall through to the first Symbol in the Target.
  virtual InputSection *getTargetInputSection() const { return nullptr; }

  // To reuse a Thunk the caller as identified by the Type must be
  // compatible with it.
  virtual bool isCompatibleWith(RelType Type) const { return true; }

  // The alignment requirement for this Thunk, defaults to the size of the
  // typical code section alignment.
  Symbol &Destination;
  Symbol *ThunkSym;
  uint64_t Offset = 0;
  uint32_t Alignment = 4;
};

// For a Relocation to symbol S create a Thunk to be added to a synthetic
// ThunkSection. At present there are implementations for ARM and Mips Thunks.
Thunk *addThunk(RelType Type, Symbol &S);

} // namespace elf
} // namespace lld

#endif
