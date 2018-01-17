//===- lld/unittest/DarwinLdDriverTest.cpp --------------------------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
///
/// \file
/// \brief Darwin's ld driver tests.
///
//===----------------------------------------------------------------------===//

#include "lld/Common/Driver.h"
#include "lld/ReaderWriter/MachOLinkingContext.h"
#include "llvm/BinaryFormat/MachO.h"
#include "llvm/Support/raw_ostream.h"
#include "gtest/gtest.h"

using namespace llvm;
using namespace lld;

namespace lld {
namespace mach_o {
bool parse(llvm::ArrayRef<const char *> args, MachOLinkingContext &ctx,
           raw_ostream &diagnostics);
}
}

namespace {
class DarwinLdParserTest : public testing::Test {
protected:
  int inputFileCount() { return _ctx.getNodes().size(); }

  std::string inputFile(int index) {
    Node &node = *_ctx.getNodes()[index];
    if (node.kind() == Node::Kind::File)
      return cast<FileNode>(&node)->getFile()->path();
    llvm_unreachable("not handling other types of input files");
  }

  bool parse(std::vector<const char *> args) {
    args.insert(args.begin(), "ld");
    std::string errorMessage;
    raw_string_ostream os(errorMessage);
    return mach_o::parse(args, _ctx, os);
  }

  MachOLinkingContext _ctx;
};
}

TEST_F(DarwinLdParserTest, Basic) {
  EXPECT_TRUE(parse({"foo.o", "bar.o", "-arch", "i386"}));
  EXPECT_FALSE(_ctx.allowRemainingUndefines());
  EXPECT_FALSE(_ctx.deadStrip());
  EXPECT_EQ(2, inputFileCount());
  EXPECT_EQ("foo.o", inputFile(0));
  EXPECT_EQ("bar.o", inputFile(1));
}

TEST_F(DarwinLdParserTest, Output) {
  EXPECT_TRUE(parse({"-o", "my.out", "foo.o", "-arch", "i386"}));
  EXPECT_EQ("my.out", _ctx.outputPath());
}

TEST_F(DarwinLdParserTest, Dylib) {
  EXPECT_TRUE(parse({"-dylib", "foo.o", "-arch", "i386"}));
  EXPECT_EQ(llvm::MachO::MH_DYLIB, _ctx.outputMachOType());
}

TEST_F(DarwinLdParserTest, Relocatable) {
  EXPECT_TRUE(parse({"-r", "foo.o", "-arch", "i386"}));
  EXPECT_EQ(llvm::MachO::MH_OBJECT, _ctx.outputMachOType());
}

TEST_F(DarwinLdParserTest, Bundle) {
  EXPECT_TRUE(parse({"-bundle", "foo.o", "-arch", "i386"}));
  EXPECT_EQ(llvm::MachO::MH_BUNDLE, _ctx.outputMachOType());
}

TEST_F(DarwinLdParserTest, Preload) {
  EXPECT_TRUE(parse({"-preload", "foo.o", "-arch", "i386"}));
  EXPECT_EQ(llvm::MachO::MH_PRELOAD, _ctx.outputMachOType());
}

TEST_F(DarwinLdParserTest, Static) {
  EXPECT_TRUE(parse({"-static", "foo.o", "-arch", "i386"}));
  EXPECT_EQ(llvm::MachO::MH_EXECUTE, _ctx.outputMachOType());
}

TEST_F(DarwinLdParserTest, Entry) {
  EXPECT_TRUE(parse({"-e", "entryFunc", "foo.o", "-arch", "i386"}));
  EXPECT_EQ("entryFunc", _ctx.entrySymbolName());
}

TEST_F(DarwinLdParserTest, DeadStrip) {
  EXPECT_TRUE(parse({"-arch", "x86_64", "-dead_strip", "foo.o"}));
  EXPECT_TRUE(_ctx.deadStrip());
}

TEST_F(DarwinLdParserTest, DeadStripRootsExe) {
  EXPECT_TRUE(parse({"-arch", "x86_64", "-dead_strip", "foo.o"}));
  EXPECT_FALSE(_ctx.globalsAreDeadStripRoots());
}

TEST_F(DarwinLdParserTest, DeadStripRootsDylib) {
  EXPECT_TRUE(parse({"-arch", "x86_64", "-dylib", "-dead_strip", "foo.o"}));
  EXPECT_FALSE(_ctx.globalsAreDeadStripRoots());
}

TEST_F(DarwinLdParserTest, DeadStripRootsRelocatable) {
  EXPECT_TRUE(parse({"-arch", "x86_64", "-r", "-dead_strip", "foo.o"}));
  EXPECT_FALSE(_ctx.globalsAreDeadStripRoots());
}

TEST_F(DarwinLdParserTest, DeadStripRootsExportDynamicExe) {
  EXPECT_TRUE(
      parse({"-arch", "x86_64", "-dead_strip", "-export_dynamic", "foo.o"}));
  EXPECT_TRUE(_ctx.globalsAreDeadStripRoots());
}

TEST_F(DarwinLdParserTest, DeadStripRootsExportDynamicDylib) {
  EXPECT_TRUE(parse({"-arch", "x86_64", "-dylib", "-dead_strip",
                     "-export_dynamic", "foo.o"}));
  EXPECT_TRUE(_ctx.globalsAreDeadStripRoots());
}

TEST_F(DarwinLdParserTest, DeadStripRootsExportDynamicRelocatable) {
  EXPECT_TRUE(parse(
      {"-arch", "x86_64", "-r", "-dead_strip", "-export_dynamic", "foo.o"}));
  EXPECT_FALSE(_ctx.globalsAreDeadStripRoots());
}

TEST_F(DarwinLdParserTest, Arch) {
  EXPECT_TRUE(parse({"-arch", "x86_64", "foo.o"}));
  EXPECT_EQ(MachOLinkingContext::arch_x86_64, _ctx.arch());
  EXPECT_EQ((uint32_t)llvm::MachO::CPU_TYPE_X86_64, _ctx.getCPUType());
  EXPECT_EQ(llvm::MachO::CPU_SUBTYPE_X86_64_ALL, _ctx.getCPUSubType());
}

TEST_F(DarwinLdParserTest, Arch_x86) {
  EXPECT_TRUE(parse({"-arch", "i386", "foo.o"}));
  EXPECT_EQ(MachOLinkingContext::arch_x86, _ctx.arch());
  EXPECT_EQ((uint32_t)llvm::MachO::CPU_TYPE_I386, _ctx.getCPUType());
  EXPECT_EQ(llvm::MachO::CPU_SUBTYPE_X86_ALL, _ctx.getCPUSubType());
}

TEST_F(DarwinLdParserTest, Arch_armv6) {
  EXPECT_TRUE(parse({"-arch", "armv6", "foo.o"}));
  EXPECT_EQ(MachOLinkingContext::arch_armv6, _ctx.arch());
  EXPECT_EQ((uint32_t)llvm::MachO::CPU_TYPE_ARM, _ctx.getCPUType());
  EXPECT_EQ(llvm::MachO::CPU_SUBTYPE_ARM_V6, _ctx.getCPUSubType());
}

TEST_F(DarwinLdParserTest, Arch_armv7) {
  EXPECT_TRUE(parse({"-arch", "armv7", "foo.o"}));
  EXPECT_EQ(MachOLinkingContext::arch_armv7, _ctx.arch());
  EXPECT_EQ((uint32_t)llvm::MachO::CPU_TYPE_ARM, _ctx.getCPUType());
  EXPECT_EQ(llvm::MachO::CPU_SUBTYPE_ARM_V7, _ctx.getCPUSubType());
}

TEST_F(DarwinLdParserTest, Arch_armv7s) {
  EXPECT_TRUE(parse({"-arch", "armv7s", "foo.o"}));
  EXPECT_EQ(MachOLinkingContext::arch_armv7s, _ctx.arch());
  EXPECT_EQ((uint32_t)llvm::MachO::CPU_TYPE_ARM, _ctx.getCPUType());
  EXPECT_EQ(llvm::MachO::CPU_SUBTYPE_ARM_V7S, _ctx.getCPUSubType());
}

TEST_F(DarwinLdParserTest, MinMacOSX10_7) {
  EXPECT_TRUE(
      parse({"-macosx_version_min", "10.7", "foo.o", "-arch", "x86_64"}));
  EXPECT_EQ(MachOLinkingContext::OS::macOSX, _ctx.os());
  EXPECT_TRUE(_ctx.minOS("10.7", ""));
  EXPECT_FALSE(_ctx.minOS("10.8", ""));
}

TEST_F(DarwinLdParserTest, MinMacOSX10_8) {
  EXPECT_TRUE(
      parse({"-macosx_version_min", "10.8.3", "foo.o", "-arch", "x86_64"}));
  EXPECT_EQ(MachOLinkingContext::OS::macOSX, _ctx.os());
  EXPECT_TRUE(_ctx.minOS("10.7", ""));
  EXPECT_TRUE(_ctx.minOS("10.8", ""));
}

TEST_F(DarwinLdParserTest, iOS5) {
  EXPECT_TRUE(parse({"-ios_version_min", "5.0", "foo.o", "-arch", "armv7"}));
  EXPECT_EQ(MachOLinkingContext::OS::iOS, _ctx.os());
  EXPECT_TRUE(_ctx.minOS("", "5.0"));
  EXPECT_FALSE(_ctx.minOS("", "6.0"));
}

TEST_F(DarwinLdParserTest, iOS6) {
  EXPECT_TRUE(parse({"-ios_version_min", "6.0", "foo.o", "-arch", "armv7"}));
  EXPECT_EQ(MachOLinkingContext::OS::iOS, _ctx.os());
  EXPECT_TRUE(_ctx.minOS("", "5.0"));
  EXPECT_TRUE(_ctx.minOS("", "6.0"));
}

TEST_F(DarwinLdParserTest, iOS_Simulator5) {
  EXPECT_TRUE(
      parse({"-ios_simulator_version_min", "5.0", "a.o", "-arch", "i386"}));
  EXPECT_EQ(MachOLinkingContext::OS::iOS_simulator, _ctx.os());
  EXPECT_TRUE(_ctx.minOS("", "5.0"));
  EXPECT_FALSE(_ctx.minOS("", "6.0"));
}

TEST_F(DarwinLdParserTest, iOS_Simulator6) {
  EXPECT_TRUE(
      parse({"-ios_simulator_version_min", "6.0", "a.o", "-arch", "i386"}));
  EXPECT_EQ(MachOLinkingContext::OS::iOS_simulator, _ctx.os());
  EXPECT_TRUE(_ctx.minOS("", "5.0"));
  EXPECT_TRUE(_ctx.minOS("", "6.0"));
}

TEST_F(DarwinLdParserTest, compatibilityVersion) {
  EXPECT_TRUE(parse(
      {"-dylib", "-compatibility_version", "1.2.3", "a.o", "-arch", "i386"}));
  EXPECT_EQ(_ctx.compatibilityVersion(), 0x10203U);
}

TEST_F(DarwinLdParserTest, compatibilityVersionInvalidType) {
  EXPECT_FALSE(parse(
      {"-bundle", "-compatibility_version", "1.2.3", "a.o", "-arch", "i386"}));
}

TEST_F(DarwinLdParserTest, compatibilityVersionInvalidValue) {
  EXPECT_FALSE(parse(
      {"-bundle", "-compatibility_version", "1,2,3", "a.o", "-arch", "i386"}));
}

TEST_F(DarwinLdParserTest, currentVersion) {
  EXPECT_TRUE(
      parse({"-dylib", "-current_version", "1.2.3", "a.o", "-arch", "i386"}));
  EXPECT_EQ(_ctx.currentVersion(), 0x10203U);
}

TEST_F(DarwinLdParserTest, currentVersionInvalidType) {
  EXPECT_FALSE(
      parse({"-bundle", "-current_version", "1.2.3", "a.o", "-arch", "i386"}));
}

TEST_F(DarwinLdParserTest, currentVersionInvalidValue) {
  EXPECT_FALSE(
      parse({"-bundle", "-current_version", "1,2,3", "a.o", "-arch", "i386"}));
}

TEST_F(DarwinLdParserTest, bundleLoader) {
  EXPECT_TRUE(
      parse({"-bundle", "-bundle_loader", "/bin/ls", "a.o", "-arch", "i386"}));
  EXPECT_EQ(_ctx.bundleLoader(), "/bin/ls");
}

TEST_F(DarwinLdParserTest, bundleLoaderInvalidType) {
  EXPECT_FALSE(parse({"-bundle_loader", "/bin/ls", "a.o", "-arch", "i386"}));
}

TEST_F(DarwinLdParserTest, deadStrippableDylib) {
  EXPECT_TRUE(
      parse({"-dylib", "-mark_dead_strippable_dylib", "a.o", "-arch", "i386"}));
  EXPECT_EQ(true, _ctx.deadStrippableDylib());
}

TEST_F(DarwinLdParserTest, deadStrippableDylibInvalidType) {
  EXPECT_FALSE(parse({"-mark_dead_strippable_dylib", "a.o", "-arch", "i386"}));
}
