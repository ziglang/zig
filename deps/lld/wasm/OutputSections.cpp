//===- OutputSections.cpp -------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "OutputSections.h"

#include "Config.h"
#include "InputFiles.h"
#include "OutputSegment.h"
#include "SymbolTable.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Memory.h"
#include "lld/Common/Threads.h"
#include "llvm/ADT/Twine.h"
#include "llvm/Support/LEB128.h"

#define DEBUG_TYPE "lld"

using namespace llvm;
using namespace llvm::wasm;
using namespace lld;
using namespace lld::wasm;

enum class RelocEncoding {
  Uleb128,
  Sleb128,
  I32,
};

static StringRef sectionTypeToString(uint32_t SectionType) {
  switch (SectionType) {
  case WASM_SEC_CUSTOM:
    return "CUSTOM";
  case WASM_SEC_TYPE:
    return "TYPE";
  case WASM_SEC_IMPORT:
    return "IMPORT";
  case WASM_SEC_FUNCTION:
    return "FUNCTION";
  case WASM_SEC_TABLE:
    return "TABLE";
  case WASM_SEC_MEMORY:
    return "MEMORY";
  case WASM_SEC_GLOBAL:
    return "GLOBAL";
  case WASM_SEC_EXPORT:
    return "EXPORT";
  case WASM_SEC_START:
    return "START";
  case WASM_SEC_ELEM:
    return "ELEM";
  case WASM_SEC_CODE:
    return "CODE";
  case WASM_SEC_DATA:
    return "DATA";
  default:
    fatal("invalid section type");
  }
}

std::string lld::toString(const OutputSection &Section) {
  std::string rtn = Section.getSectionName();
  if (!Section.Name.empty())
    rtn += "(" + Section.Name + ")";
  return rtn;
}

static void applyRelocation(uint8_t *Buf, const OutputRelocation &Reloc) {
  DEBUG(dbgs() << "write reloc: type=" << Reloc.Reloc.Type
               << " index=" << Reloc.Reloc.Index << " value=" << Reloc.Value
               << " offset=" << Reloc.Reloc.Offset << "\n");
  Buf += Reloc.Reloc.Offset;
  int64_t ExistingValue;
  switch (Reloc.Reloc.Type) {
  case R_WEBASSEMBLY_TYPE_INDEX_LEB:
  case R_WEBASSEMBLY_FUNCTION_INDEX_LEB:
    ExistingValue = decodeULEB128(Buf);
    if (ExistingValue != Reloc.Reloc.Index) {
      DEBUG(dbgs() << "existing value: " << decodeULEB128(Buf) << "\n");
      assert(decodeULEB128(Buf) == Reloc.Reloc.Index);
    }
    LLVM_FALLTHROUGH;
  case R_WEBASSEMBLY_MEMORY_ADDR_LEB:
  case R_WEBASSEMBLY_GLOBAL_INDEX_LEB:
    encodeULEB128(Reloc.Value, Buf, 5);
    break;
  case R_WEBASSEMBLY_TABLE_INDEX_SLEB:
    ExistingValue = decodeSLEB128(Buf);
    if (ExistingValue != Reloc.Reloc.Index) {
      DEBUG(dbgs() << "existing value: " << decodeSLEB128(Buf) << "\n");
      assert(decodeSLEB128(Buf) == Reloc.Reloc.Index);
    }
    LLVM_FALLTHROUGH;
  case R_WEBASSEMBLY_MEMORY_ADDR_SLEB:
    encodeSLEB128(static_cast<int32_t>(Reloc.Value), Buf, 5);
    break;
  case R_WEBASSEMBLY_TABLE_INDEX_I32:
  case R_WEBASSEMBLY_MEMORY_ADDR_I32:
    support::endian::write32<support::little>(Buf, Reloc.Value);
    break;
  default:
    llvm_unreachable("unknown relocation type");
  }
}

static void applyRelocations(uint8_t *Buf, ArrayRef<OutputRelocation> Relocs) {
  if (!Relocs.size())
    return;
  log("applyRelocations: count=" + Twine(Relocs.size()));
  for (const OutputRelocation &Reloc : Relocs)
    applyRelocation(Buf, Reloc);
}

// Relocations contain an index into the function, global or table index
// space of the input file.  This function takes a relocation and returns the
// relocated index (i.e. translates from the input index space to the output
// index space).
static uint32_t calcNewIndex(const ObjFile &File, const WasmRelocation &Reloc) {
  switch (Reloc.Type) {
  case R_WEBASSEMBLY_TYPE_INDEX_LEB:
    return File.relocateTypeIndex(Reloc.Index);
  case R_WEBASSEMBLY_FUNCTION_INDEX_LEB:
    return File.relocateFunctionIndex(Reloc.Index);
  case R_WEBASSEMBLY_TABLE_INDEX_I32:
  case R_WEBASSEMBLY_TABLE_INDEX_SLEB:
    return File.relocateTableIndex(Reloc.Index);
  case R_WEBASSEMBLY_GLOBAL_INDEX_LEB:
  case R_WEBASSEMBLY_MEMORY_ADDR_LEB:
  case R_WEBASSEMBLY_MEMORY_ADDR_SLEB:
  case R_WEBASSEMBLY_MEMORY_ADDR_I32:
    return File.relocateGlobalIndex(Reloc.Index);
  default:
    llvm_unreachable("unknown relocation type");
  }
}

// Take a vector of relocations from an input file and create output
// relocations based on them. Calculates the updated index and offset for
// each relocation as well as the value to write out in the final binary.
static void calcRelocations(const ObjFile &File,
                            ArrayRef<WasmRelocation> Relocs,
                            std::vector<OutputRelocation> &OutputRelocs,
                            int32_t OutputOffset) {
  log("calcRelocations: " + File.getName() + " offset=" + Twine(OutputOffset));
  for (const WasmRelocation &Reloc : Relocs) {
    OutputRelocation NewReloc;
    NewReloc.Reloc = Reloc;
    NewReloc.Reloc.Offset += OutputOffset;
    DEBUG(dbgs() << "reloc: type=" << Reloc.Type << " index=" << Reloc.Index
                 << " offset=" << Reloc.Offset
                 << " newOffset=" << NewReloc.Reloc.Offset << "\n");

    if (Config->EmitRelocs)
      NewReloc.NewIndex = calcNewIndex(File, Reloc);
    else
      NewReloc.NewIndex = UINT32_MAX;

    switch (Reloc.Type) {
    case R_WEBASSEMBLY_MEMORY_ADDR_SLEB:
    case R_WEBASSEMBLY_MEMORY_ADDR_I32:
    case R_WEBASSEMBLY_MEMORY_ADDR_LEB:
      NewReloc.Value = File.getRelocatedAddress(Reloc.Index);
      if (NewReloc.Value != UINT32_MAX)
        NewReloc.Value += Reloc.Addend;
      break;
    default:
      NewReloc.Value = calcNewIndex(File, Reloc);
      break;
    }

    OutputRelocs.emplace_back(NewReloc);
  }
}

std::string OutputSection::getSectionName() const {
  return sectionTypeToString(Type);
}

std::string SubSection::getSectionName() const {
  return std::string("subsection <type=") + std::to_string(Type) + ">";
}

void OutputSection::createHeader(size_t BodySize) {
  raw_string_ostream OS(Header);
  debugWrite(OS.tell(), "section type [" + Twine(getSectionName()) + "]");
  writeUleb128(OS, Type, nullptr);
  writeUleb128(OS, BodySize, "section size");
  OS.flush();
  log("createHeader: " + toString(*this) + " body=" + Twine(BodySize) +
      " total=" + Twine(getSize()));
}

CodeSection::CodeSection(uint32_t NumFunctions, ArrayRef<ObjFile *> Objs)
    : OutputSection(WASM_SEC_CODE), InputObjects(Objs) {
  raw_string_ostream OS(CodeSectionHeader);
  writeUleb128(OS, NumFunctions, "function count");
  OS.flush();
  BodySize = CodeSectionHeader.size();

  for (ObjFile *File : InputObjects) {
    if (!File->CodeSection)
      continue;

    File->CodeOffset = BodySize;
    ArrayRef<uint8_t> Content = File->CodeSection->Content;
    unsigned HeaderSize = 0;
    decodeULEB128(Content.data(), &HeaderSize);

    calcRelocations(*File, File->CodeSection->Relocations,
                    File->CodeRelocations, BodySize - HeaderSize);

    size_t PayloadSize = Content.size() - HeaderSize;
    BodySize += PayloadSize;
  }

  createHeader(BodySize);
}

void CodeSection::writeTo(uint8_t *Buf) {
  log("writing " + toString(*this));
  log(" size=" + Twine(getSize()));
  Buf += Offset;

  // Write section header
  memcpy(Buf, Header.data(), Header.size());
  Buf += Header.size();

  uint8_t *ContentsStart = Buf;

  // Write code section headers
  memcpy(Buf, CodeSectionHeader.data(), CodeSectionHeader.size());
  Buf += CodeSectionHeader.size();

  // Write code section bodies
  parallelForEach(InputObjects, [ContentsStart](ObjFile *File) {
    if (!File->CodeSection)
      return;

    ArrayRef<uint8_t> Content(File->CodeSection->Content);

    // Payload doesn't include the initial header (function count)
    unsigned HeaderSize = 0;
    decodeULEB128(Content.data(), &HeaderSize);

    size_t PayloadSize = Content.size() - HeaderSize;
    memcpy(ContentsStart + File->CodeOffset, Content.data() + HeaderSize,
           PayloadSize);

    log("applying relocations for: " + File->getName());
    applyRelocations(ContentsStart, File->CodeRelocations);
  });
}

uint32_t CodeSection::numRelocations() const {
  uint32_t Count = 0;
  for (ObjFile *File : InputObjects)
    Count += File->CodeRelocations.size();
  return Count;
}

void CodeSection::writeRelocations(raw_ostream &OS) const {
  for (ObjFile *File : InputObjects)
    for (const OutputRelocation &Reloc : File->CodeRelocations)
      writeReloc(OS, Reloc);
}

DataSection::DataSection(ArrayRef<OutputSegment *> Segments)
    : OutputSection(WASM_SEC_DATA), Segments(Segments) {
  raw_string_ostream OS(DataSectionHeader);

  writeUleb128(OS, Segments.size(), "data segment count");
  OS.flush();
  BodySize = DataSectionHeader.size();

  for (OutputSegment *Segment : Segments) {
    raw_string_ostream OS(Segment->Header);
    writeUleb128(OS, 0, "memory index");
    writeUleb128(OS, WASM_OPCODE_I32_CONST, "opcode:i32const");
    writeSleb128(OS, Segment->StartVA, "memory offset");
    writeUleb128(OS, WASM_OPCODE_END, "opcode:end");
    writeUleb128(OS, Segment->Size, "segment size");
    OS.flush();
    Segment->setSectionOffset(BodySize);
    BodySize += Segment->Header.size();
    log("Data segment: size=" + Twine(Segment->Size));
    for (InputSegment *InputSeg : Segment->InputSegments) {
      uint32_t InputOffset = InputSeg->getInputSectionOffset();
      uint32_t OutputOffset = Segment->getSectionOffset() +
                              Segment->Header.size() +
                              InputSeg->getOutputSegmentOffset();
      calcRelocations(*InputSeg->File, InputSeg->Relocations,
                      InputSeg->OutRelocations, OutputOffset - InputOffset);
    }
    BodySize += Segment->Size;
  }

  createHeader(BodySize);
}

void DataSection::writeTo(uint8_t *Buf) {
  log("writing " + toString(*this) + " size=" + Twine(getSize()) +
      " body=" + Twine(BodySize));
  Buf += Offset;

  // Write section header
  memcpy(Buf, Header.data(), Header.size());
  Buf += Header.size();

  uint8_t *ContentsStart = Buf;

  // Write data section headers
  memcpy(Buf, DataSectionHeader.data(), DataSectionHeader.size());

  parallelForEach(Segments, [ContentsStart](const OutputSegment *Segment) {
    // Write data segment header
    uint8_t *SegStart = ContentsStart + Segment->getSectionOffset();
    memcpy(SegStart, Segment->Header.data(), Segment->Header.size());

    // Write segment data payload
    for (const InputSegment *Input : Segment->InputSegments) {
      ArrayRef<uint8_t> Content(Input->Segment->Data.Content);
      memcpy(SegStart + Segment->Header.size() +
                 Input->getOutputSegmentOffset(),
             Content.data(), Content.size());
      applyRelocations(ContentsStart, Input->OutRelocations);
    }
  });
}

uint32_t DataSection::numRelocations() const {
  uint32_t Count = 0;
  for (const OutputSegment *Seg : Segments)
    for (const InputSegment *InputSeg : Seg->InputSegments)
      Count += InputSeg->OutRelocations.size();
  return Count;
}

void DataSection::writeRelocations(raw_ostream &OS) const {
  for (const OutputSegment *Seg : Segments)
    for (const InputSegment *InputSeg : Seg->InputSegments)
      for (const OutputRelocation &Reloc : InputSeg->OutRelocations)
        writeReloc(OS, Reloc);
}
