//===- WriterUtils.h --------------------------------------------*- C++ -*-===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_WASM_WRITERUTILS_H
#define LLD_WASM_WRITERUTILS_H

#include "lld/Common/LLVM.h"
#include "llvm/ADT/Twine.h"
#include "llvm/Object/Wasm.h"

namespace lld {
namespace wasm {

void debugWrite(uint64_t Offset, const Twine &Msg);

void writeUleb128(raw_ostream &OS, uint32_t Number, const Twine &Msg);

void writeSleb128(raw_ostream &OS, int32_t Number, const Twine &Msg);

void writeBytes(raw_ostream &OS, const char *Bytes, size_t count,
                const Twine &Msg);

void writeStr(raw_ostream &OS, StringRef String, const Twine &Msg);

void writeU8(raw_ostream &OS, uint8_t byte, const Twine &Msg);

void writeU32(raw_ostream &OS, uint32_t Number, const Twine &Msg);

void writeValueType(raw_ostream &OS, llvm::wasm::ValType Type,
                    const Twine &Msg);

void writeSig(raw_ostream &OS, const llvm::wasm::WasmSignature &Sig);

void writeInitExpr(raw_ostream &OS, const llvm::wasm::WasmInitExpr &InitExpr);

void writeLimits(raw_ostream &OS, const llvm::wasm::WasmLimits &Limits);

void writeGlobalType(raw_ostream &OS, const llvm::wasm::WasmGlobalType &Type);

void writeGlobal(raw_ostream &OS, const llvm::wasm::WasmGlobal &Global);

void writeEventType(raw_ostream &OS, const llvm::wasm::WasmEventType &Type);

void writeEvent(raw_ostream &OS, const llvm::wasm::WasmEvent &Event);

void writeTableType(raw_ostream &OS, const llvm::wasm::WasmTable &Type);

void writeImport(raw_ostream &OS, const llvm::wasm::WasmImport &Import);

void writeExport(raw_ostream &OS, const llvm::wasm::WasmExport &Export);

} // namespace wasm

std::string toString(llvm::wasm::ValType Type);
std::string toString(const llvm::wasm::WasmSignature &Sig);
std::string toString(const llvm::wasm::WasmGlobalType &Type);
std::string toString(const llvm::wasm::WasmEventType &Type);

} // namespace lld

#endif // LLD_WASM_WRITERUTILS_H
