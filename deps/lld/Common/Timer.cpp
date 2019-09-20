//===- Timer.cpp ----------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "lld/Common/Timer.h"
#include "lld/Common/ErrorHandler.h"
#include "llvm/Support/Format.h"

using namespace lld;
using namespace llvm;

ScopedTimer::ScopedTimer(Timer &t) : t(&t) { t.start(); }

void ScopedTimer::stop() {
  if (!t)
    return;
  t->stop();
  t = nullptr;
}

ScopedTimer::~ScopedTimer() { stop(); }

Timer::Timer(llvm::StringRef name) : name(name), parent(nullptr) {}
Timer::Timer(llvm::StringRef name, Timer &parent)
    : name(name), parent(&parent) {}

void Timer::start() {
  if (parent && total.count() == 0)
    parent->children.push_back(this);
  startTime = std::chrono::high_resolution_clock::now();
}

void Timer::stop() {
  total += (std::chrono::high_resolution_clock::now() - startTime);
}

Timer &Timer::root() {
  static Timer rootTimer("Total Link Time");
  return rootTimer;
}

void Timer::print() {
  double totalDuration = static_cast<double>(root().millis());

  // We want to print the grand total under all the intermediate phases, so we
  // print all children first, then print the total under that.
  for (const auto &child : children)
    child->print(1, totalDuration);

  message(std::string(49, '-'));

  root().print(0, root().millis(), false);
}

double Timer::millis() const {
  return std::chrono::duration_cast<std::chrono::duration<double, std::milli>>(
             total)
      .count();
}

void Timer::print(int depth, double totalDuration, bool recurse) const {
  double p = 100.0 * millis() / totalDuration;

  SmallString<32> str;
  llvm::raw_svector_ostream stream(str);
  std::string s = std::string(depth * 2, ' ') + name + std::string(":");
  stream << format("%-30s%5d ms (%5.1f%%)", s.c_str(), (int)millis(), p);

  message(str);

  if (recurse) {
    for (const auto &child : children)
      child->print(depth + 1, totalDuration);
  }
}
