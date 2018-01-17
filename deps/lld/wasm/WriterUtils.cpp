//===- WriterUtils.cpp ----------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "WriterUtils.h"

#include "lld/Common/ErrorHandler.h"

#include "llvm/Support/Debug.h"
#include "llvm/Support/EndianStream.h"
#include "llvm/Support/FormatVariadic.h"
#include "llvm/Support/LEB128.h"

#define DEBUG_TYPE "lld"

using namespace llvm;
using namespace llvm::wasm;
using namespace lld::wasm;

static const char *valueTypeToString(int32_t Type) {
  switch (Type) {
  case WASM_TYPE_I32:
    return "i32";
  case WASM_TYPE_I64:
    return "i64";
  case WASM_TYPE_F32:
    return "f32";
  case WASM_TYPE_F64:
    return "f64";
  default:
    llvm_unreachable("invalid value type");
  }
}

namespace lld {

void wasm::debugWrite(uint64_t offset, Twine msg) {
  DEBUG(dbgs() << format("  | %08" PRIx64 ": ", offset) << msg << "\n");
}

void wasm::writeUleb128(raw_ostream &OS, uint32_t Number, const char *msg) {
  if (msg)
    debugWrite(OS.tell(), msg + formatv(" [{0:x}]", Number));
  encodeULEB128(Number, OS);
}

void wasm::writeSleb128(raw_ostream &OS, int32_t Number, const char *msg) {
  if (msg)
    debugWrite(OS.tell(), msg + formatv(" [{0:x}]", Number));
  encodeSLEB128(Number, OS);
}

void wasm::writeBytes(raw_ostream &OS, const char *bytes, size_t count,
                      const char *msg) {
  if (msg)
    debugWrite(OS.tell(), msg + formatv(" [data[{0}]]", count));
  OS.write(bytes, count);
}

void wasm::writeStr(raw_ostream &OS, const StringRef String, const char *msg) {
  if (msg)
    debugWrite(OS.tell(),
               msg + formatv(" [str[{0}]: {1}]", String.size(), String));
  writeUleb128(OS, String.size(), nullptr);
  writeBytes(OS, String.data(), String.size());
}

void wasm::writeU8(raw_ostream &OS, uint8_t byte, const char *msg) {
  OS << byte;
}

void wasm::writeU32(raw_ostream &OS, uint32_t Number, const char *msg) {
  debugWrite(OS.tell(), msg + formatv("[{0:x}]", Number));
  support::endian::Writer<support::little>(OS).write(Number);
}

void wasm::writeValueType(raw_ostream &OS, int32_t Type, const char *msg) {
  debugWrite(OS.tell(), msg + formatv("[type: {0}]", valueTypeToString(Type)));
  writeSleb128(OS, Type, nullptr);
}

void wasm::writeSig(raw_ostream &OS, const WasmSignature &Sig) {
  writeSleb128(OS, WASM_TYPE_FUNC, "signature type");
  writeUleb128(OS, Sig.ParamTypes.size(), "param count");
  for (int32_t ParamType : Sig.ParamTypes) {
    writeValueType(OS, ParamType, "param type");
  }
  if (Sig.ReturnType == WASM_TYPE_NORESULT) {
    writeUleb128(OS, 0, "result count");
  } else {
    writeUleb128(OS, 1, "result count");
    writeValueType(OS, Sig.ReturnType, "result type");
  }
}

void wasm::writeInitExpr(raw_ostream &OS, const WasmInitExpr &InitExpr) {
  writeU8(OS, InitExpr.Opcode, "opcode");
  switch (InitExpr.Opcode) {
  case WASM_OPCODE_I32_CONST:
    writeSleb128(OS, InitExpr.Value.Int32, "literal (i32)");
    break;
  case WASM_OPCODE_I64_CONST:
    writeSleb128(OS, InitExpr.Value.Int64, "literal (i64)");
    break;
  case WASM_OPCODE_GET_GLOBAL:
    writeUleb128(OS, InitExpr.Value.Global, "literal (global index)");
    break;
  default:
    fatal("unknown opcode in init expr: " + Twine(InitExpr.Opcode));
  }
  writeU8(OS, WASM_OPCODE_END, "opcode:end");
}

void wasm::writeLimits(raw_ostream &OS, const WasmLimits &Limits) {
  writeUleb128(OS, Limits.Flags, "limits flags");
  writeUleb128(OS, Limits.Initial, "limits initial");
  if (Limits.Flags & WASM_LIMITS_FLAG_HAS_MAX)
    writeUleb128(OS, Limits.Maximum, "limits max");
}

void wasm::writeGlobal(raw_ostream &OS, const WasmGlobal &Global) {
  writeValueType(OS, Global.Type, "global type");
  writeUleb128(OS, Global.Mutable, "global mutable");
  writeInitExpr(OS, Global.InitExpr);
}

void wasm::writeImport(raw_ostream &OS, const WasmImport &Import) {
  writeStr(OS, Import.Module, "import module name");
  writeStr(OS, Import.Field, "import field name");
  writeU8(OS, Import.Kind, "import kind");
  switch (Import.Kind) {
  case WASM_EXTERNAL_FUNCTION:
    writeUleb128(OS, Import.SigIndex, "import sig index");
    break;
  case WASM_EXTERNAL_GLOBAL:
    writeValueType(OS, Import.Global.Type, "import global type");
    writeUleb128(OS, Import.Global.Mutable, "import global mutable");
    break;
  case WASM_EXTERNAL_MEMORY:
    writeLimits(OS, Import.Memory);
    break;
  default:
    fatal("unsupported import type: " + Twine(Import.Kind));
  }
}

void wasm::writeExport(raw_ostream &OS, const WasmExport &Export) {
  writeStr(OS, Export.Name, "export name");
  writeU8(OS, Export.Kind, "export kind");
  switch (Export.Kind) {
  case WASM_EXTERNAL_FUNCTION:
    writeUleb128(OS, Export.Index, "function index");
    break;
  case WASM_EXTERNAL_GLOBAL:
    writeUleb128(OS, Export.Index, "global index");
    break;
  case WASM_EXTERNAL_MEMORY:
    writeUleb128(OS, Export.Index, "memory index");
    break;
  default:
    fatal("unsupported export type: " + Twine(Export.Kind));
  }
}

void wasm::writeReloc(raw_ostream &OS, const OutputRelocation &Reloc) {
  writeUleb128(OS, Reloc.Reloc.Type, "reloc type");
  writeUleb128(OS, Reloc.Reloc.Offset, "reloc offset");
  writeUleb128(OS, Reloc.NewIndex, "reloc index");

  switch (Reloc.Reloc.Type) {
  case R_WEBASSEMBLY_MEMORY_ADDR_LEB:
  case R_WEBASSEMBLY_MEMORY_ADDR_SLEB:
  case R_WEBASSEMBLY_MEMORY_ADDR_I32:
    writeUleb128(OS, Reloc.Reloc.Addend, "reloc addend");
    break;
  default:
    break;
  }
}

} // namespace lld

std::string lld::toString(ValType Type) {
  switch (Type) {
  case ValType::I32:
    return "I32";
  case ValType::I64:
    return "I64";
  case ValType::F32:
    return "F32";
  case ValType::F64:
    return "F64";
  }
  llvm_unreachable("Invalid wasm::ValType");
}

std::string lld::toString(const WasmSignature &Sig) {
  SmallString<128> S("(");
  for (uint32_t Type : Sig.ParamTypes) {
    if (S.size() != 1)
      S += ", ";
    S += toString(static_cast<ValType>(Type));
  }
  S += ") -> ";
  if (Sig.ReturnType == WASM_TYPE_NORESULT)
    S += "void";
  else
    S += toString(static_cast<ValType>(Sig.ReturnType));
  return S.str();
}
