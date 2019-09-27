//===- Args.cpp -----------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "lld/Common/Args.h"
#include "lld/Common/ErrorHandler.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringExtras.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Option/ArgList.h"
#include "llvm/Support/Path.h"

using namespace llvm;
using namespace lld;

// TODO(sbc): Remove this once CGOptLevel can be set completely based on bitcode
// function metadata.
CodeGenOpt::Level lld::args::getCGOptLevel(int optLevelLTO) {
  if (optLevelLTO == 3)
    return CodeGenOpt::Aggressive;
  assert(optLevelLTO < 3);
  return CodeGenOpt::Default;
}

int64_t lld::args::getInteger(opt::InputArgList &args, unsigned key,
                              int64_t Default) {
  auto *a = args.getLastArg(key);
  if (!a)
    return Default;

  int64_t v;
  if (to_integer(a->getValue(), v, 10))
    return v;

  StringRef spelling = args.getArgString(a->getIndex());
  error(spelling + ": number expected, but got '" + a->getValue() + "'");
  return 0;
}

std::vector<StringRef> lld::args::getStrings(opt::InputArgList &args, int id) {
  std::vector<StringRef> v;
  for (auto *arg : args.filtered(id))
    v.push_back(arg->getValue());
  return v;
}

uint64_t lld::args::getZOptionValue(opt::InputArgList &args, int id,
                                    StringRef key, uint64_t Default) {
  for (auto *arg : args.filtered_reverse(id)) {
    std::pair<StringRef, StringRef> kv = StringRef(arg->getValue()).split('=');
    if (kv.first == key) {
      uint64_t result = Default;
      if (!to_integer(kv.second, result))
        error("invalid " + key + ": " + kv.second);
      return result;
    }
  }
  return Default;
}

std::vector<StringRef> lld::args::getLines(MemoryBufferRef mb) {
  SmallVector<StringRef, 0> arr;
  mb.getBuffer().split(arr, '\n');

  std::vector<StringRef> ret;
  for (StringRef s : arr) {
    s = s.trim();
    if (!s.empty() && s[0] != '#')
      ret.push_back(s);
  }
  return ret;
}

StringRef lld::args::getFilenameWithoutExe(StringRef path) {
  if (path.endswith_lower(".exe"))
    return sys::path::stem(path);
  return sys::path::filename(path);
}
