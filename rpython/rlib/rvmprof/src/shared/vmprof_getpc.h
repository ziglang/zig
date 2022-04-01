// -*- Mode: C++; c-basic-offset: 2; indent-tabs-mode: nil -*-
// Copyright (c) 2005, Google Inc.
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//     * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//     * Neither the name of Google Inc. nor the names of its
// contributors may be used to endorse or promote products derived from
// this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

// ---
// Author: Craig Silverstein
//
// This is an internal header file used by profiler.cc.  It defines
// the single (inline) function GetPC.  GetPC is used in a signal
// handler to figure out the instruction that was being executed when
// the signal-handler was triggered.
//
// To get this, we use the ucontext_t argument to the signal-handler
// callback, which holds the full context of what was going on when
// the signal triggered.  How to get from a ucontext_t to a Program
// Counter is OS-dependent.

#ifndef BASE_GETPC_H_
#define BASE_GETPC_H_
// On many linux systems, we may need _GNU_SOURCE to get access to
// the defined constants that define the register we want to see (eg
// REG_EIP).  Note this #define must come first!
#define _GNU_SOURCE 1
// If #define _GNU_SOURCE causes problems, this might work instead.
// It will cause problems for FreeBSD though!, because it turns off
// the needed __BSD_VISIBLE.
#ifdef __APPLE__
#include <limits.h>
#define _XOPEN_SOURCE 700
#endif

#include "vmprof_config.h"

#include <string.h>         // for memcmp
#if defined(HAVE_SYS_UCONTEXT_H)
#include <sys/ucontext.h>
#elif defined(HAVE_UCONTEXT_H)
#include <ucontext.h>       // for ucontext_t (and also mcontext_t)
#elif defined(HAVE_CYGWIN_SIGNAL_H)
#include <cygwin/signal.h>
typedef ucontext ucontext_t;
#elif defined(HAVE_SIGNAL_H)
#include <signal.h>
#else
#  error "don't know how to get the pc on this platform"
#endif


// Take the example where function Foo() calls function Bar().  For
// many architectures, Bar() is responsible for setting up and tearing
// down its own stack frame.  In that case, it's possible for the
// interrupt to happen when execution is in Bar(), but the stack frame
// is not properly set up (either before it's done being set up, or
// after it's been torn down but before Bar() returns).  In those
// cases, the stack trace cannot see the caller function anymore.
//
// GetPC can try to identify this situation, on architectures where it
// might occur, and unwind the current function call in that case to
// avoid false edges in the profile graph (that is, edges that appear
// to show a call skipping over a function).  To do this, we hard-code
// in the asm instructions we might see when setting up or tearing
// down a stack frame.
//
// This is difficult to get right: the instructions depend on the
// processor, the compiler ABI, and even the optimization level.  This
// is a best effort patch -- if we fail to detect such a situation, or
// mess up the PC, nothing happens; the returned PC is not used for
// any further processing.
struct CallUnrollInfo {
  // Offset from (e)ip register where this instruction sequence
  // should be matched. Interpreted as bytes. Offset 0 is the next
  // instruction to execute. Be extra careful with negative offsets in
  // architectures of variable instruction length (like x86) - it is
  // not that easy as taking an offset to step one instruction back!
  int pc_offset;
  // The actual instruction bytes. Feel free to make it larger if you
  // need a longer sequence.
  unsigned char ins[16];
  // How many bytes to match from ins array?
  int ins_size;
  // The offset from the stack pointer (e)sp where to look for the
  // call return address. Interpreted as bytes.
  int return_sp_offset;
};


// The dereferences needed to get the PC from a struct ucontext were
// determined at configure time, and stored in the macro
// PC_FROM_UCONTEXT in config.h.  The only thing we need to do here,
// then, is to do the magic call-unrolling for systems that support it.

// Special case Windows, which has to do something totally different.
#if defined(_WIN32) || defined(__CYGWIN__) || defined(__CYGWIN32__) || defined(__MINGW32__)
// If this is ever implemented, probably the way to do it is to have
// profiler.cc use a high-precision timer via timeSetEvent:
//    http://msdn2.microsoft.com/en-us/library/ms712713.aspx
// We'd use it in mode TIME_CALLBACK_FUNCTION/TIME_PERIODIC.
// The callback function would be something like prof_handler, but
// alas the arguments are different: no ucontext_t!  I don't know
// how we'd get the PC (using StackWalk64?)
//    http://msdn2.microsoft.com/en-us/library/ms680650.aspx

// #include "base/logging.h"   // for RAW_LOG
// #ifndef HAVE_CYGWIN_SIGNAL_H
// typedef int ucontext_t;
// #endif

static intptr_t GetPC(ucontext_t *signal_ucontext) {
  // RAW_LOG(ERROR, "GetPC is not yet implemented on Windows\n");
  fprintf(stderr, "GetPC is not yet implemented on Windows\n");
  return NULL;
}

// Normal cases.  If this doesn't compile, it's probably because
// PC_FROM_UCONTEXT is the empty string.  You need to figure out
// the right value for your system, and add it to the list in
// vmrpof_config.h
#else

static intptr_t GetPC(ucontext_t *signal_ucontext) {
  return signal_ucontext->PC_FROM_UCONTEXT;   // defined in config.h
}

#endif

#endif  // BASE_GETPC_H_
