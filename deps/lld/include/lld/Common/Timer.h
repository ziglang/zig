//===- Timer.h ----------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLD_COMMON_TIMER_H
#define LLD_COMMON_TIMER_H

#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/StringRef.h"
#include <assert.h>
#include <chrono>
#include <map>
#include <memory>

namespace lld {

class Timer;

struct ScopedTimer {
  explicit ScopedTimer(Timer &t);

  ~ScopedTimer();

  void stop();

  Timer *t = nullptr;
};

class Timer {
public:
  Timer(llvm::StringRef name, Timer &parent);

  static Timer &root();

  void start();
  void stop();
  void print();

  double millis() const;

private:
  explicit Timer(llvm::StringRef name);
  void print(int depth, double totalDuration, bool recurse = true) const;

  std::chrono::time_point<std::chrono::high_resolution_clock> startTime;
  std::chrono::nanoseconds total;
  std::vector<Timer *> children;
  std::string name;
  Timer *parent;
};

} // namespace lld

#endif
