//===- Symbols.cpp --------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "Symbols.h"

#include "Config.h"
#include "InputFiles.h"
#include "InputSegment.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Strings.h"

#define DEBUG_TYPE "lld"

using namespace llvm;
using namespace lld;
using namespace lld::wasm;

uint32_t Symbol::getGlobalIndex() const {
  assert(!Sym->isFunction());
  return Sym->ElementIndex;
}

uint32_t Symbol::getFunctionIndex() const {
  assert(Sym->isFunction());
  return Sym->ElementIndex;
}

const WasmSignature &Symbol::getFunctionType() const {
  assert(FunctionType != nullptr);
  return *FunctionType;
}

uint32_t Symbol::getVirtualAddress() const {
  assert(isGlobal());
  DEBUG(dbgs() << "getVirtualAddress: " << getName() << "\n");
  if (isUndefined())
    return UINT32_MAX;
  if (VirtualAddress.hasValue())
    return VirtualAddress.getValue();

  assert(Sym != nullptr);
  ObjFile *Obj = cast<ObjFile>(File);
  const WasmGlobal &Global =
      Obj->getWasmObj()->globals()[getGlobalIndex() - Obj->NumGlobalImports()];
  assert(Global.Type == llvm::wasm::WASM_TYPE_I32);
  assert(Segment);
  return Segment->translateVA(Global.InitExpr.Value.Int32);
}

uint32_t Symbol::getOutputIndex() const {
  if (isUndefined() && isWeak())
    return 0;
  return OutputIndex.getValue();
}

void Symbol::setVirtualAddress(uint32_t Value) {
  DEBUG(dbgs() << "setVirtualAddress " << Name << " -> " << Value << "\n");
  assert(!VirtualAddress.hasValue());
  VirtualAddress = Value;
}

void Symbol::setOutputIndex(uint32_t Index) {
  DEBUG(dbgs() << "setOutputIndex " << Name << " -> " << Index << "\n");
  assert(!OutputIndex.hasValue());
  OutputIndex = Index;
}

void Symbol::setTableIndex(uint32_t Index) {
  DEBUG(dbgs() << "setTableIndex " << Name << " -> " << Index << "\n");
  assert(!TableIndex.hasValue());
  TableIndex = Index;
}

void Symbol::update(Kind K, InputFile *F, const WasmSymbol *WasmSym,
                    const InputSegment *Seg, const WasmSignature *Sig) {
  SymbolKind = K;
  File = F;
  Sym = WasmSym;
  Segment = Seg;
  FunctionType = Sig;
}

bool Symbol::isWeak() const { return Sym && Sym->isWeak(); }

bool Symbol::isHidden() const { return Sym && Sym->isHidden(); }

std::string lld::toString(const wasm::Symbol &Sym) {
  if (Config->Demangle)
    if (Optional<std::string> S = demangleItanium(Sym.getName()))
      return "`" + *S + "'";
  return Sym.getName();
}

std::string lld::toString(wasm::Symbol::Kind Kind) {
  switch (Kind) {
  case wasm::Symbol::DefinedFunctionKind:
    return "DefinedFunction";
  case wasm::Symbol::DefinedGlobalKind:
    return "DefinedGlobal";
  case wasm::Symbol::UndefinedFunctionKind:
    return "UndefinedFunction";
  case wasm::Symbol::UndefinedGlobalKind:
    return "UndefinedGlobal";
  case wasm::Symbol::LazyKind:
    return "LazyKind";
  }
  llvm_unreachable("Invalid symbol kind!");
}
