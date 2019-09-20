//===- OutputSections.cpp -------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "OutputSections.h"
#include "InputChunks.h"
#include "InputFiles.h"
#include "OutputSegment.h"
#include "WriterUtils.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Threads.h"
#include "llvm/ADT/Twine.h"
#include "llvm/Support/LEB128.h"

#define DEBUG_TYPE "lld"

using namespace llvm;
using namespace llvm::wasm;
using namespace lld;
using namespace lld::wasm;

static StringRef sectionTypeToString(uint32_t sectionType) {
  switch (sectionType) {
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
  case WASM_SEC_EVENT:
    return "EVENT";
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
  case WASM_SEC_DATACOUNT:
    return "DATACOUNT";
  default:
    fatal("invalid section type");
  }
}

// Returns a string, e.g. "FUNCTION(.text)".
std::string lld::toString(const OutputSection &sec) {
  if (!sec.name.empty())
    return (sec.getSectionName() + "(" + sec.name + ")").str();
  return sec.getSectionName();
}

StringRef OutputSection::getSectionName() const {
  return sectionTypeToString(type);
}

void OutputSection::createHeader(size_t bodySize) {
  raw_string_ostream os(header);
  debugWrite(os.tell(), "section type [" + getSectionName() + "]");
  encodeULEB128(type, os);
  writeUleb128(os, bodySize, "section size");
  os.flush();
  log("createHeader: " + toString(*this) + " body=" + Twine(bodySize) +
      " total=" + Twine(getSize()));
}

void CodeSection::finalizeContents() {
  raw_string_ostream os(codeSectionHeader);
  writeUleb128(os, functions.size(), "function count");
  os.flush();
  bodySize = codeSectionHeader.size();

  for (InputFunction *func : functions) {
    func->outputOffset = bodySize;
    func->calculateSize();
    bodySize += func->getSize();
  }

  createHeader(bodySize);
}

void CodeSection::writeTo(uint8_t *buf) {
  log("writing " + toString(*this));
  log(" size=" + Twine(getSize()));
  log(" headersize=" + Twine(header.size()));
  log(" codeheadersize=" + Twine(codeSectionHeader.size()));
  buf += offset;

  // Write section header
  memcpy(buf, header.data(), header.size());
  buf += header.size();

  // Write code section headers
  memcpy(buf, codeSectionHeader.data(), codeSectionHeader.size());

  // Write code section bodies
  for (const InputChunk *chunk : functions)
    chunk->writeTo(buf);
}

uint32_t CodeSection::getNumRelocations() const {
  uint32_t count = 0;
  for (const InputChunk *func : functions)
    count += func->getNumRelocations();
  return count;
}

void CodeSection::writeRelocations(raw_ostream &os) const {
  for (const InputChunk *c : functions)
    c->writeRelocations(os);
}

void DataSection::finalizeContents() {
  raw_string_ostream os(dataSectionHeader);

  writeUleb128(os, segments.size(), "data segment count");
  os.flush();
  bodySize = dataSectionHeader.size();

  assert((!config->isPic || segments.size() <= 1) &&
         "Currenly only a single data segment is supported in PIC mode");

  for (OutputSegment *segment : segments) {
    raw_string_ostream os(segment->header);
    writeUleb128(os, segment->initFlags, "init flags");
    if (segment->initFlags & WASM_SEGMENT_HAS_MEMINDEX)
      writeUleb128(os, 0, "memory index");
    if ((segment->initFlags & WASM_SEGMENT_IS_PASSIVE) == 0) {
      WasmInitExpr initExpr;
      if (config->isPic) {
        initExpr.Opcode = WASM_OPCODE_GLOBAL_GET;
        initExpr.Value.Global = WasmSym::memoryBase->getGlobalIndex();
      } else {
        initExpr.Opcode = WASM_OPCODE_I32_CONST;
        initExpr.Value.Int32 = segment->startVA;
      }
      writeInitExpr(os, initExpr);
    }
    writeUleb128(os, segment->size, "segment size");
    os.flush();

    segment->sectionOffset = bodySize;
    bodySize += segment->header.size() + segment->size;
    log("Data segment: size=" + Twine(segment->size) + ", startVA=" +
        Twine::utohexstr(segment->startVA) + ", name=" + segment->name);

    for (InputSegment *inputSeg : segment->inputSegments)
      inputSeg->outputOffset = segment->sectionOffset + segment->header.size() +
                               inputSeg->outputSegmentOffset;
  }

  createHeader(bodySize);
}

void DataSection::writeTo(uint8_t *buf) {
  log("writing " + toString(*this) + " size=" + Twine(getSize()) +
      " body=" + Twine(bodySize));
  buf += offset;

  // Write section header
  memcpy(buf, header.data(), header.size());
  buf += header.size();

  // Write data section headers
  memcpy(buf, dataSectionHeader.data(), dataSectionHeader.size());

  for (const OutputSegment *segment : segments) {
    // Write data segment header
    uint8_t *segStart = buf + segment->sectionOffset;
    memcpy(segStart, segment->header.data(), segment->header.size());

    // Write segment data payload
    for (const InputChunk *chunk : segment->inputSegments)
      chunk->writeTo(buf);
  }
}

uint32_t DataSection::getNumRelocations() const {
  uint32_t count = 0;
  for (const OutputSegment *seg : segments)
    for (const InputChunk *inputSeg : seg->inputSegments)
      count += inputSeg->getNumRelocations();
  return count;
}

void DataSection::writeRelocations(raw_ostream &os) const {
  for (const OutputSegment *seg : segments)
    for (const InputChunk *c : seg->inputSegments)
      c->writeRelocations(os);
}

void CustomSection::finalizeContents() {
  raw_string_ostream os(nameData);
  encodeULEB128(name.size(), os);
  os << name;
  os.flush();

  for (InputSection *section : inputSections) {
    section->outputOffset = payloadSize;
    section->outputSec = this;
    payloadSize += section->getSize();
  }

  createHeader(payloadSize + nameData.size());
}

void CustomSection::writeTo(uint8_t *buf) {
  log("writing " + toString(*this) + " size=" + Twine(getSize()) +
      " chunks=" + Twine(inputSections.size()));

  assert(offset);
  buf += offset;

  // Write section header
  memcpy(buf, header.data(), header.size());
  buf += header.size();
  memcpy(buf, nameData.data(), nameData.size());
  buf += nameData.size();

  // Write custom sections payload
  for (const InputSection *section : inputSections)
    section->writeTo(buf);
}

uint32_t CustomSection::getNumRelocations() const {
  uint32_t count = 0;
  for (const InputSection *inputSect : inputSections)
    count += inputSect->getNumRelocations();
  return count;
}

void CustomSection::writeRelocations(raw_ostream &os) const {
  for (const InputSection *s : inputSections)
    s->writeRelocations(os);
}
