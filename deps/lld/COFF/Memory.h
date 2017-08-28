//===- Memory.h -------------------------------------------------*- C++ -*-===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// See ELF/Memory.h
//
//===----------------------------------------------------------------------===//

#ifndef LLD_COFF_MEMORY_H
#define LLD_COFF_MEMORY_H

#include "llvm/Support/Allocator.h"
#include "llvm/Support/StringSaver.h"
#include <vector>

namespace lld {
namespace coff {

extern llvm::BumpPtrAllocator BAlloc;
extern llvm::StringSaver Saver;

struct SpecificAllocBase {
  SpecificAllocBase() { Instances.push_back(this); }
  virtual ~SpecificAllocBase() = default;
  virtual void reset() = 0;
  static std::vector<SpecificAllocBase *> Instances;
};

template <class T> struct SpecificAlloc : public SpecificAllocBase {
  void reset() override { Alloc.DestroyAll(); }
  llvm::SpecificBumpPtrAllocator<T> Alloc;
};

template <typename T, typename... U> T *make(U &&... Args) {
  static SpecificAlloc<T> Alloc;
  return new (Alloc.Alloc.Allocate()) T(std::forward<U>(Args)...);
}

inline void freeArena() {
  for (SpecificAllocBase *Alloc : SpecificAllocBase::Instances)
    Alloc->reset();
  BAlloc.Reset();
}
}
}

#endif
