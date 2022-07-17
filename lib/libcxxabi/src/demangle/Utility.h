//===--- Utility.h ----------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Provide some utility classes for use in the demangler.
// There are two copies of this file in the source tree.  The one in libcxxabi
// is the original and the one in llvm is the copy.  Use cp-to-llvm.sh to update
// the copy.  See README.txt for more details.
//
//===----------------------------------------------------------------------===//

#ifndef DEMANGLE_UTILITY_H
#define DEMANGLE_UTILITY_H

#include "StringView.h"
#include <array>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <limits>

DEMANGLE_NAMESPACE_BEGIN

// Stream that AST nodes write their string representation into after the AST
// has been parsed.
class OutputBuffer {
  char *Buffer = nullptr;
  size_t CurrentPosition = 0;
  size_t BufferCapacity = 0;

  // Ensure there is at least n more positions in buffer.
  void grow(size_t N) {
    if (N + CurrentPosition >= BufferCapacity) {
      BufferCapacity *= 2;
      if (BufferCapacity < N + CurrentPosition)
        BufferCapacity = N + CurrentPosition;
      Buffer = static_cast<char *>(std::realloc(Buffer, BufferCapacity));
      if (Buffer == nullptr)
        std::terminate();
    }
  }

  void writeUnsigned(uint64_t N, bool isNeg = false) {
    // Handle special case...
    if (N == 0) {
      *this << '0';
      return;
    }

    std::array<char, 21> Temp;
    char *TempPtr = Temp.data() + Temp.size();

    while (N) {
      *--TempPtr = char('0' + N % 10);
      N /= 10;
    }

    // Add negative sign...
    if (isNeg)
      *--TempPtr = '-';
    this->operator<<(StringView(TempPtr, Temp.data() + Temp.size()));
  }

public:
  OutputBuffer(char *StartBuf, size_t Size)
      : Buffer(StartBuf), CurrentPosition(0), BufferCapacity(Size) {}
  OutputBuffer() = default;
  void reset(char *Buffer_, size_t BufferCapacity_) {
    CurrentPosition = 0;
    Buffer = Buffer_;
    BufferCapacity = BufferCapacity_;
  }

  /// If a ParameterPackExpansion (or similar type) is encountered, the offset
  /// into the pack that we're currently printing.
  unsigned CurrentPackIndex = std::numeric_limits<unsigned>::max();
  unsigned CurrentPackMax = std::numeric_limits<unsigned>::max();

  OutputBuffer &operator+=(StringView R) {
    size_t Size = R.size();
    if (Size == 0)
      return *this;
    grow(Size);
    std::memmove(Buffer + CurrentPosition, R.begin(), Size);
    CurrentPosition += Size;
    return *this;
  }

  OutputBuffer &operator+=(char C) {
    grow(1);
    Buffer[CurrentPosition++] = C;
    return *this;
  }

  OutputBuffer &operator<<(StringView R) { return (*this += R); }

  OutputBuffer prepend(StringView R) {
    size_t Size = R.size();

    grow(Size);
    std::memmove(Buffer + Size, Buffer, CurrentPosition);
    std::memcpy(Buffer, R.begin(), Size);
    CurrentPosition += Size;

    return *this;
  }

  OutputBuffer &operator<<(char C) { return (*this += C); }

  OutputBuffer &operator<<(long long N) {
    if (N < 0)
      writeUnsigned(static_cast<unsigned long long>(-N), true);
    else
      writeUnsigned(static_cast<unsigned long long>(N));
    return *this;
  }

  OutputBuffer &operator<<(unsigned long long N) {
    writeUnsigned(N, false);
    return *this;
  }

  OutputBuffer &operator<<(long N) {
    return this->operator<<(static_cast<long long>(N));
  }

  OutputBuffer &operator<<(unsigned long N) {
    return this->operator<<(static_cast<unsigned long long>(N));
  }

  OutputBuffer &operator<<(int N) {
    return this->operator<<(static_cast<long long>(N));
  }

  OutputBuffer &operator<<(unsigned int N) {
    return this->operator<<(static_cast<unsigned long long>(N));
  }

  void insert(size_t Pos, const char *S, size_t N) {
    assert(Pos <= CurrentPosition);
    if (N == 0)
      return;
    grow(N);
    std::memmove(Buffer + Pos + N, Buffer + Pos, CurrentPosition - Pos);
    std::memcpy(Buffer + Pos, S, N);
    CurrentPosition += N;
  }

  size_t getCurrentPosition() const { return CurrentPosition; }
  void setCurrentPosition(size_t NewPos) { CurrentPosition = NewPos; }

  char back() const {
    return CurrentPosition ? Buffer[CurrentPosition - 1] : '\0';
  }

  bool empty() const { return CurrentPosition == 0; }

  char *getBuffer() { return Buffer; }
  char *getBufferEnd() { return Buffer + CurrentPosition - 1; }
  size_t getBufferCapacity() const { return BufferCapacity; }
};

template <class T> class SwapAndRestore {
  T &Restore;
  T OriginalValue;
  bool ShouldRestore = true;

public:
  SwapAndRestore(T &Restore_) : SwapAndRestore(Restore_, Restore_) {}

  SwapAndRestore(T &Restore_, T NewVal)
      : Restore(Restore_), OriginalValue(Restore) {
    Restore = std::move(NewVal);
  }
  ~SwapAndRestore() {
    if (ShouldRestore)
      Restore = std::move(OriginalValue);
  }

  void shouldRestore(bool ShouldRestore_) { ShouldRestore = ShouldRestore_; }

  void restoreNow(bool Force) {
    if (!Force && !ShouldRestore)
      return;

    Restore = std::move(OriginalValue);
    ShouldRestore = false;
  }

  SwapAndRestore(const SwapAndRestore &) = delete;
  SwapAndRestore &operator=(const SwapAndRestore &) = delete;
};

inline bool initializeOutputBuffer(char *Buf, size_t *N, OutputBuffer &OB,
                                   size_t InitSize) {
  size_t BufferSize;
  if (Buf == nullptr) {
    Buf = static_cast<char *>(std::malloc(InitSize));
    if (Buf == nullptr)
      return false;
    BufferSize = InitSize;
  } else
    BufferSize = *N;

  OB.reset(Buf, BufferSize);
  return true;
}

DEMANGLE_NAMESPACE_END

#endif
