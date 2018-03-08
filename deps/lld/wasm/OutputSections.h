//===- OutputSections.h -----------------------------------------*- C++ -*-===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_WASM_OUTPUT_SECTIONS_H
#define LLD_WASM_OUTPUT_SECTIONS_H

#include "InputSegment.h"
#include "WriterUtils.h"
#include "lld/Common/ErrorHandler.h"
#include "llvm/ADT/DenseMap.h"

using llvm::raw_ostream;
using llvm::raw_string_ostream;

namespace lld {

namespace wasm {
class OutputSection;
}
std::string toString(const wasm::OutputSection &Section);

namespace wasm {

class OutputSegment;
class ObjFile;

class OutputSection {
public:
  OutputSection(uint32_t Type, std::string Name = "")
      : Type(Type), Name(Name) {}
  virtual ~OutputSection() = default;

  std::string getSectionName() const;
  void setOffset(size_t NewOffset) {
    log("setOffset: " + toString(*this) + ": " + Twine(NewOffset));
    Offset = NewOffset;
  }
  void createHeader(size_t BodySize);
  virtual size_t getSize() const = 0;
  virtual void writeTo(uint8_t *Buf) = 0;
  virtual void finalizeContents() {}
  virtual uint32_t numRelocations() const { return 0; }
  virtual void writeRelocations(raw_ostream &OS) const {}

  std::string Header;
  uint32_t Type;
  std::string Name;

protected:
  size_t Offset = 0;
};

class SyntheticSection : public OutputSection {
public:
  SyntheticSection(uint32_t Type, std::string Name = "")
      : OutputSection(Type, Name), BodyOutputStream(Body) {
    if (!Name.empty())
      writeStr(BodyOutputStream, Name);
  }

  void writeTo(uint8_t *Buf) override {
    assert(Offset);
    log("writing " + toString(*this));
    memcpy(Buf + Offset, Header.data(), Header.size());
    memcpy(Buf + Offset + Header.size(), Body.data(), Body.size());
  }

  size_t getSize() const override { return Header.size() + Body.size(); }

  void finalizeContents() override {
    BodyOutputStream.flush();
    createHeader(Body.size());
  }

  raw_ostream &getStream() { return BodyOutputStream; }

  std::string Body;

protected:
  raw_string_ostream BodyOutputStream;
};

// Some synthetic sections (e.g. "name" and "linking") have subsections.
// Just like the synthetic sections themselves these need to be created before
// they can be written out (since they are preceded by their length). This
// class is used to create subsections and then write them into the stream
// of the parent section.
class SubSection : public SyntheticSection {
public:
  explicit SubSection(uint32_t Type) : SyntheticSection(Type) {}

  std::string getSectionName() const;
  void writeToStream(raw_ostream &OS) {
    writeBytes(OS, Header.data(), Header.size());
    writeBytes(OS, Body.data(), Body.size());
  }
};

class CodeSection : public OutputSection {
public:
  explicit CodeSection(uint32_t NumFunctions, ArrayRef<ObjFile *> Objs);
  size_t getSize() const override { return Header.size() + BodySize; }
  void writeTo(uint8_t *Buf) override;
  uint32_t numRelocations() const override;
  void writeRelocations(raw_ostream &OS) const override;

protected:
  ArrayRef<ObjFile *> InputObjects;
  std::string CodeSectionHeader;
  size_t BodySize = 0;
};

class DataSection : public OutputSection {
public:
  explicit DataSection(ArrayRef<OutputSegment *> Segments);
  size_t getSize() const override { return Header.size() + BodySize; }
  void writeTo(uint8_t *Buf) override;
  uint32_t numRelocations() const override;
  void writeRelocations(raw_ostream &OS) const override;

protected:
  ArrayRef<OutputSegment *> Segments;
  std::string DataSectionHeader;
  size_t BodySize = 0;
};

} // namespace wasm
} // namespace lld

#endif // LLD_WASM_OUTPUT_SECTIONS_H
