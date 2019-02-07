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
#include "llvm/Support/LEB128.h"

#define DEBUG_TYPE "lld"

using namespace llvm;
using namespace llvm::wasm;

namespace lld {

void wasm::debugWrite(uint64_t Offset, const Twine &Msg) {
  LLVM_DEBUG(dbgs() << format("  | %08lld: ", Offset) << Msg << "\n");
}

void wasm::writeUleb128(raw_ostream &OS, uint32_t Number, const Twine &Msg) {
  debugWrite(OS.tell(), Msg + "[" + utohexstr(Number) + "]");
  encodeULEB128(Number, OS);
}

void wasm::writeSleb128(raw_ostream &OS, int32_t Number, const Twine &Msg) {
  debugWrite(OS.tell(), Msg + "[" + utohexstr(Number) + "]");
  encodeSLEB128(Number, OS);
}

void wasm::writeBytes(raw_ostream &OS, const char *Bytes, size_t Count,
                      const Twine &Msg) {
  debugWrite(OS.tell(), Msg + " [data[" + Twine(Count) + "]]");
  OS.write(Bytes, Count);
}

void wasm::writeStr(raw_ostream &OS, StringRef String, const Twine &Msg) {
  debugWrite(OS.tell(),
             Msg + " [str[" + Twine(String.size()) + "]: " + String + "]");
  encodeULEB128(String.size(), OS);
  OS.write(String.data(), String.size());
}

void wasm::writeU8(raw_ostream &OS, uint8_t Byte, const Twine &Msg) {
  debugWrite(OS.tell(), Msg + " [0x" + utohexstr(Byte) + "]");
  OS << Byte;
}

void wasm::writeU32(raw_ostream &OS, uint32_t Number, const Twine &Msg) {
  debugWrite(OS.tell(), Msg + "[0x" + utohexstr(Number) + "]");
  support::endian::write(OS, Number, support::little);
}

void wasm::writeValueType(raw_ostream &OS, ValType Type, const Twine &Msg) {
  writeU8(OS, static_cast<uint8_t>(Type),
          Msg + "[type: " + toString(Type) + "]");
}

void wasm::writeSig(raw_ostream &OS, const WasmSignature &Sig) {
  writeU8(OS, WASM_TYPE_FUNC, "signature type");
  writeUleb128(OS, Sig.Params.size(), "param Count");
  for (ValType ParamType : Sig.Params) {
    writeValueType(OS, ParamType, "param type");
  }
  writeUleb128(OS, Sig.Returns.size(), "result Count");
  if (Sig.Returns.size()) {
    writeValueType(OS, Sig.Returns[0], "result type");
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
  case WASM_OPCODE_GLOBAL_GET:
    writeUleb128(OS, InitExpr.Value.Global, "literal (global index)");
    break;
  default:
    fatal("unknown opcode in init expr: " + Twine(InitExpr.Opcode));
  }
  writeU8(OS, WASM_OPCODE_END, "opcode:end");
}

void wasm::writeLimits(raw_ostream &OS, const WasmLimits &Limits) {
  writeU8(OS, Limits.Flags, "limits flags");
  writeUleb128(OS, Limits.Initial, "limits initial");
  if (Limits.Flags & WASM_LIMITS_FLAG_HAS_MAX)
    writeUleb128(OS, Limits.Maximum, "limits max");
}

void wasm::writeGlobalType(raw_ostream &OS, const WasmGlobalType &Type) {
  // TODO: Update WasmGlobalType to use ValType and remove this cast.
  writeValueType(OS, ValType(Type.Type), "global type");
  writeU8(OS, Type.Mutable, "global mutable");
}

void wasm::writeGlobal(raw_ostream &OS, const WasmGlobal &Global) {
  writeGlobalType(OS, Global.Type);
  writeInitExpr(OS, Global.InitExpr);
}

void wasm::writeEventType(raw_ostream &OS, const WasmEventType &Type) {
  writeUleb128(OS, Type.Attribute, "event attribute");
  writeUleb128(OS, Type.SigIndex, "sig index");
}

void wasm::writeEvent(raw_ostream &OS, const WasmEvent &Event) {
  writeEventType(OS, Event.Type);
}

void wasm::writeTableType(raw_ostream &OS, const llvm::wasm::WasmTable &Type) {
  writeU8(OS, WASM_TYPE_FUNCREF, "table type");
  writeLimits(OS, Type.Limits);
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
    writeGlobalType(OS, Import.Global);
    break;
  case WASM_EXTERNAL_EVENT:
    writeEventType(OS, Import.Event);
    break;
  case WASM_EXTERNAL_MEMORY:
    writeLimits(OS, Import.Memory);
    break;
  case WASM_EXTERNAL_TABLE:
    writeTableType(OS, Import.Table);
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
  case WASM_EXTERNAL_TABLE:
    writeUleb128(OS, Export.Index, "table index");
    break;
  default:
    fatal("unsupported export type: " + Twine(Export.Kind));
  }
}
} // namespace lld

std::string lld::toString(ValType Type) {
  switch (Type) {
  case ValType::I32:
    return "i32";
  case ValType::I64:
    return "i64";
  case ValType::F32:
    return "f32";
  case ValType::F64:
    return "f64";
  case ValType::V128:
    return "v128";
  case ValType::EXCEPT_REF:
    return "except_ref";
  }
  llvm_unreachable("Invalid wasm::ValType");
}

std::string lld::toString(const WasmSignature &Sig) {
  SmallString<128> S("(");
  for (ValType Type : Sig.Params) {
    if (S.size() != 1)
      S += ", ";
    S += toString(Type);
  }
  S += ") -> ";
  if (Sig.Returns.size() == 0)
    S += "void";
  else
    S += toString(Sig.Returns[0]);
  return S.str();
}

std::string lld::toString(const WasmGlobalType &Type) {
  return (Type.Mutable ? "var " : "const ") +
         toString(static_cast<ValType>(Type.Type));
}

std::string lld::toString(const WasmEventType &Type) {
  if (Type.Attribute == WASM_EVENT_ATTRIBUTE_EXCEPTION)
    return "exception";
  return "unknown";
}
