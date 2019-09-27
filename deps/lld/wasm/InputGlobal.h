//===- InputGlobal.h --------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLD_WASM_INPUT_GLOBAL_H
#define LLD_WASM_INPUT_GLOBAL_H

#include "Config.h"
#include "InputFiles.h"
#include "WriterUtils.h"
#include "lld/Common/ErrorHandler.h"
#include "llvm/Object/Wasm.h"

namespace lld {
namespace wasm {

// Represents a single Wasm Global Variable within an input file. These are
// combined to form the final GLOBALS section.
class InputGlobal {
public:
  InputGlobal(const WasmGlobal &g, ObjFile *f)
      : file(f), global(g), live(!config->gcSections) {}

  StringRef getName() const { return global.SymbolName; }
  const WasmGlobalType &getType() const { return global.Type; }

  uint32_t getGlobalIndex() const { return globalIndex.getValue(); }
  bool hasGlobalIndex() const { return globalIndex.hasValue(); }
  void setGlobalIndex(uint32_t index) {
    assert(!hasGlobalIndex());
    globalIndex = index;
  }

  ObjFile *file;
  WasmGlobal global;

  bool live = false;

protected:
  llvm::Optional<uint32_t> globalIndex;
};

} // namespace wasm

inline std::string toString(const wasm::InputGlobal *g) {
  return (toString(g->file) + ":(" + g->getName() + ")").str();
}

} // namespace lld

#endif // LLD_WASM_INPUT_GLOBAL_H
