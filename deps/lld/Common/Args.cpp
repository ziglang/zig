//===- Args.cpp -----------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "lld/Common/Args.h"
#include "lld/Common/ErrorHandler.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringExtras.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Option/ArgList.h"

using namespace llvm;
using namespace lld;

int lld::args::getInteger(opt::InputArgList &Args, unsigned Key, int Default) {
  int V = Default;
  if (auto *Arg = Args.getLastArg(Key)) {
    StringRef S = Arg->getValue();
    if (!to_integer(S, V, 10))
      error(Arg->getSpelling() + ": number expected, but got '" + S + "'");
  }
  return V;
}

std::vector<StringRef> lld::args::getStrings(opt::InputArgList &Args, int Id) {
  std::vector<StringRef> V;
  for (auto *Arg : Args.filtered(Id))
    V.push_back(Arg->getValue());
  return V;
}

uint64_t lld::args::getZOptionValue(opt::InputArgList &Args, int Id,
                                    StringRef Key, uint64_t Default) {
  for (auto *Arg : Args.filtered(Id)) {
    std::pair<StringRef, StringRef> KV = StringRef(Arg->getValue()).split('=');
    if (KV.first == Key) {
      uint64_t Result = Default;
      if (!to_integer(KV.second, Result))
        error("invalid " + Key + ": " + KV.second);
      return Result;
    }
  }
  return Default;
}

std::vector<StringRef> lld::args::getLines(MemoryBufferRef MB) {
  SmallVector<StringRef, 0> Arr;
  MB.getBuffer().split(Arr, '\n');

  std::vector<StringRef> Ret;
  for (StringRef S : Arr) {
    S = S.trim();
    if (!S.empty() && S[0] != '#')
      Ret.push_back(S);
  }
  return Ret;
}
