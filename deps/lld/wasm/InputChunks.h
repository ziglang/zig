//===- InputChunks.h --------------------------------------------*- C++ -*-===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// An InputChunks represents an indivisible opaque region of a input wasm file.
// i.e. a single wasm data segment or a single wasm function.
//
// They are written directly to the mmap'd output file after which relocations
// are applied.  Because each Chunk is independent they can be written in
// parallel.
//
// Chunks are also unit on which garbage collection (--gc-sections) operates.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_WASM_INPUT_CHUNKS_H
#define LLD_WASM_INPUT_CHUNKS_H

#include "Config.h"
#include "InputFiles.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/LLVM.h"
#include "llvm/Object/Wasm.h"

namespace lld {
namespace wasm {

class ObjFile;
class OutputSegment;

class InputChunk {
public:
  enum Kind { DataSegment, Function, SyntheticFunction, Section };

  Kind kind() const { return SectionKind; }

  virtual uint32_t getSize() const { return data().size(); }
  virtual uint32_t getInputSize() const { return getSize(); };

  virtual void writeTo(uint8_t *SectionStart) const;

  ArrayRef<WasmRelocation> getRelocations() const { return Relocations; }
  void setRelocations(ArrayRef<WasmRelocation> Rs) { Relocations = Rs; }

  virtual StringRef getName() const = 0;
  virtual StringRef getDebugName() const = 0;
  virtual uint32_t getComdat() const = 0;
  StringRef getComdatName() const;
  virtual uint32_t getInputSectionOffset() const = 0;

  size_t NumRelocations() const { return Relocations.size(); }
  void writeRelocations(llvm::raw_ostream &OS) const;

  ObjFile *File;
  int32_t OutputOffset = 0;

  // Signals that the section is part of the output.  The garbage collector,
  // and COMDAT handling can set a sections' Live bit.
  // If GC is disabled, all sections start out as live by default.
  unsigned Live : 1;

protected:
  InputChunk(ObjFile *F, Kind K)
      : File(F), Live(!Config->GcSections), SectionKind(K) {}
  virtual ~InputChunk() = default;
  virtual ArrayRef<uint8_t> data() const = 0;

  // Verifies the existing data at relocation targets matches our expectations.
  // This is performed only debug builds as an extra sanity check.
  void verifyRelocTargets() const;

  ArrayRef<WasmRelocation> Relocations;
  Kind SectionKind;
};

// Represents a WebAssembly data segment which can be included as part of
// an output data segments.  Note that in WebAssembly, unlike ELF and other
// formats, used the term "data segment" to refer to the continous regions of
// memory that make on the data section. See:
// https://webassembly.github.io/spec/syntax/modules.html#syntax-data
//
// For example, by default, clang will produce a separate data section for
// each global variable.
class InputSegment : public InputChunk {
public:
  InputSegment(const WasmSegment &Seg, ObjFile *F)
      : InputChunk(F, InputChunk::DataSegment), Segment(Seg) {}

  static bool classof(const InputChunk *C) { return C->kind() == DataSegment; }

  uint32_t getAlignment() const { return Segment.Data.Alignment; }
  StringRef getName() const override { return Segment.Data.Name; }
  StringRef getDebugName() const override { return StringRef(); }
  uint32_t getComdat() const override { return Segment.Data.Comdat; }
  uint32_t getInputSectionOffset() const override {
    return Segment.SectionOffset;
  }

  const OutputSegment *OutputSeg = nullptr;
  int32_t OutputSegmentOffset = 0;

protected:
  ArrayRef<uint8_t> data() const override { return Segment.Data.Content; }

  const WasmSegment &Segment;
};

// Represents a single wasm function within and input file.  These are
// combined to create the final output CODE section.
class InputFunction : public InputChunk {
public:
  InputFunction(const WasmSignature &S, const WasmFunction *Func, ObjFile *F)
      : InputChunk(F, InputChunk::Function), Signature(S), Function(Func) {}

  static bool classof(const InputChunk *C) {
    return C->kind() == InputChunk::Function ||
           C->kind() == InputChunk::SyntheticFunction;
  }

  void writeTo(uint8_t *SectionStart) const override;
  StringRef getName() const override { return Function->SymbolName; }
  StringRef getDebugName() const override { return Function->DebugName; }
  uint32_t getComdat() const override { return Function->Comdat; }
  uint32_t getFunctionInputOffset() const { return getInputSectionOffset(); }
  uint32_t getFunctionCodeOffset() const { return Function->CodeOffset; }
  uint32_t getSize() const override {
    if (Config->CompressRelocations && File) {
      assert(CompressedSize);
      return CompressedSize;
    }
    return data().size();
  }
  uint32_t getInputSize() const override { return Function->Size; }
  uint32_t getFunctionIndex() const { return FunctionIndex.getValue(); }
  bool hasFunctionIndex() const { return FunctionIndex.hasValue(); }
  void setFunctionIndex(uint32_t Index);
  uint32_t getInputSectionOffset() const override {
    return Function->CodeSectionOffset;
  }
  uint32_t getTableIndex() const { return TableIndex.getValue(); }
  bool hasTableIndex() const { return TableIndex.hasValue(); }
  void setTableIndex(uint32_t Index);

  // The size of a given input function can depend on the values of the
  // LEB relocations within it.  This finalizeContents method is called after
  // all the symbol values have be calcualted but before getSize() is ever
  // called.
  void calculateSize();

  const WasmSignature &Signature;

protected:
  ArrayRef<uint8_t> data() const override {
    assert(!Config->CompressRelocations);
    return File->CodeSection->Content.slice(getInputSectionOffset(),
                                            Function->Size);
  }

  const WasmFunction *Function;
  llvm::Optional<uint32_t> FunctionIndex;
  llvm::Optional<uint32_t> TableIndex;
  uint32_t CompressedFuncSize = 0;
  uint32_t CompressedSize = 0;
};

class SyntheticFunction : public InputFunction {
public:
  SyntheticFunction(const WasmSignature &S, StringRef Name,
                    StringRef DebugName = {})
      : InputFunction(S, nullptr, nullptr), Name(Name), DebugName(DebugName) {
    SectionKind = InputChunk::SyntheticFunction;
  }

  static bool classof(const InputChunk *C) {
    return C->kind() == InputChunk::SyntheticFunction;
  }

  StringRef getName() const override { return Name; }
  StringRef getDebugName() const override { return DebugName; }
  uint32_t getComdat() const override { return UINT32_MAX; }

  void setBody(ArrayRef<uint8_t> Body_) { Body = Body_; }

protected:
  ArrayRef<uint8_t> data() const override { return Body; }

  StringRef Name;
  StringRef DebugName;
  ArrayRef<uint8_t> Body;
};

// Represents a single Wasm Section within an input file.
class InputSection : public InputChunk {
public:
  InputSection(const WasmSection &S, ObjFile *F)
      : InputChunk(F, InputChunk::Section), Section(S) {
    assert(Section.Type == llvm::wasm::WASM_SEC_CUSTOM);
  }

  StringRef getName() const override { return Section.Name; }
  StringRef getDebugName() const override { return StringRef(); }
  uint32_t getComdat() const override { return UINT32_MAX; }

protected:
  ArrayRef<uint8_t> data() const override { return Section.Content; }

  // Offset within the input section.  This is only zero since this chunk
  // type represents an entire input section, not part of one.
  uint32_t getInputSectionOffset() const override { return 0; }

  const WasmSection &Section;
};

} // namespace wasm

std::string toString(const wasm::InputChunk *);
} // namespace lld

#endif // LLD_WASM_INPUT_CHUNKS_H
