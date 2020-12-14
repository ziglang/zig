/*
 * Copyright (c) 1993-2011 by Apple Inc.. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */

/*
     File:       ConditionalMacros.h
 
     Contains:   Set up for compiler independent conditionals
 
     Version:    CarbonCore-769~1
  
     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:
 
                     http://developer.apple.com/bugreporter/
 
*/
#ifndef __CONDITIONALMACROS__
#define __CONDITIONALMACROS__

#include <Availability.h>
/****************************************************************************************************
    UNIVERSAL_INTERFACES_VERSION
    
        0x0400 --> version 4.0 (Mac OS X only)
        0x0335 --> version 3.4 
        0x0331 --> version 3.3.1
        0x0330 --> version 3.3
        0x0320 --> version 3.2
        0x0310 --> version 3.1
        0x0301 --> version 3.0.1
        0x0300 --> version 3.0
        0x0210 --> version 2.1
        This conditional did not exist prior to version 2.1
****************************************************************************************************/
#define UNIVERSAL_INTERFACES_VERSION 0x0400
/****************************************************************************************************

    All TARGET_* condtionals are set up by TargetConditionals.h

****************************************************************************************************/
#include <TargetConditionals.h>




/****************************************************************************************************

    PRAGMA_*
    These conditionals specify whether the compiler supports particular #pragma's
    
        PRAGMA_IMPORT           - Compiler supports: #pragma import on/off/reset
        PRAGMA_ONCE             - Compiler supports: #pragma once
        PRAGMA_STRUCT_ALIGN     - Compiler supports: #pragma options align=mac68k/power/reset
        PRAGMA_STRUCT_PACK      - Compiler supports: #pragma pack(n)
        PRAGMA_STRUCT_PACKPUSH  - Compiler supports: #pragma pack(push, n)/pack(pop)
        PRAGMA_ENUM_PACK        - Compiler supports: #pragma options(!pack_enums)
        PRAGMA_ENUM_ALWAYSINT   - Compiler supports: #pragma enumsalwaysint on/off/reset
        PRAGMA_ENUM_OPTIONS     - Compiler supports: #pragma options enum=int/small/reset


    FOUR_CHAR_CODE
    This conditional is deprecated.  It was used to work around a bug in one obscure compiler that did not pack multiple characters in single quotes rationally.
    It was never intended for endian swapping.

        FOUR_CHAR_CODE('abcd')  - Convert a four-char-code to the correct 32-bit value


    TYPE_*
    These conditionals specify whether the compiler supports particular types.

        TYPE_LONGLONG               - Compiler supports "long long" 64-bit integers
        TYPE_EXTENDED               - Compiler supports "extended" 80/96 bit floating point
        TYPE_LONGDOUBLE_IS_DOUBLE   - Compiler implements "long double" same as "double"


    FUNCTION_*
    These conditionals specify whether the compiler supports particular language extensions
    to function prototypes and definitions.

        FUNCTION_PASCAL         - Compiler supports "pascal void Foo()"
        FUNCTION_DECLSPEC       - Compiler supports "__declspec(xxx) void Foo()"
        FUNCTION_WIN32CC        - Compiler supports "void __cdecl Foo()" and "void __stdcall Foo()"

****************************************************************************************************/

#if defined(__GNUC__) && (defined(__APPLE_CPP__) || defined(__APPLE_CC__) || defined(__NEXT_CPP__) || defined(__MACOS_CLASSIC__))
   /*
     gcc based compilers used on Mac OS X
   */
  #define PRAGMA_IMPORT               0
  #define PRAGMA_ONCE                 0

  #if __GNUC__ >= 4
    #define PRAGMA_STRUCT_PACK          1
    #define PRAGMA_STRUCT_PACKPUSH      1
  #else
    #define PRAGMA_STRUCT_PACK          0
    #define PRAGMA_STRUCT_PACKPUSH      0
  #endif

  #if __LP64__ || __arm64__ || __ARM_ARCH_7K
    #define PRAGMA_STRUCT_ALIGN         0
  #else
    #define PRAGMA_STRUCT_ALIGN         1
  #endif

  #define PRAGMA_ENUM_PACK            0
  #define PRAGMA_ENUM_ALWAYSINT       0
  #define PRAGMA_ENUM_OPTIONS         0
  #define FOUR_CHAR_CODE(x)           (x)

  #define TYPE_EXTENDED               0

  #ifdef __ppc__
  #ifdef __LONG_DOUBLE_128__
     #define TYPE_LONGDOUBLE_IS_DOUBLE 0
    #else
      #define TYPE_LONGDOUBLE_IS_DOUBLE 1
    #endif
  #else
    #define TYPE_LONGDOUBLE_IS_DOUBLE 0
  #endif

  #define TYPE_LONGLONG               1
 
  #define FUNCTION_PASCAL             0
  #define FUNCTION_DECLSPEC           0
  #define FUNCTION_WIN32CC            0 
  
  #ifdef __MACOS_CLASSIC__
    #ifndef TARGET_API_MAC_CARBON            /* gcc cfm cross compiler assumes you're building Carbon code */
       #define TARGET_API_MAC_CARBON 1
    #endif
  #endif
  


#elif defined(__MWERKS__)
   /*
       CodeWarrior compiler from Metrowerks/Motorola
   */
   #define PRAGMA_ONCE                 1
   #define PRAGMA_IMPORT               0
   #define PRAGMA_STRUCT_ALIGN         1
   #define PRAGMA_STRUCT_PACK          1
   #define PRAGMA_STRUCT_PACKPUSH      0
   #define PRAGMA_ENUM_PACK            0
   #define PRAGMA_ENUM_ALWAYSINT       1
   #define PRAGMA_ENUM_OPTIONS         0
   #if __option(enumsalwaysint) && __option(ANSI_strict)
     #define FOUR_CHAR_CODE(x)       ((long)(x)) /* otherwise compiler will complain about values with high bit set */
   #else
     #define FOUR_CHAR_CODE(x)       (x)
   #endif
   #define FUNCTION_PASCAL             1
   #define FUNCTION_DECLSPEC           1
   #define FUNCTION_WIN32CC            0           
      
   #if __option(longlong)
      #define TYPE_LONGLONG            1
   #else
     #define TYPE_LONGLONG             0
   #endif
   #define TYPE_EXTENDED               0
   #define TYPE_LONGDOUBLE_IS_DOUBLE   1



#else
    /*
     Unknown compiler, perhaps set up from the command line
    */
   #error unknown compiler
    #ifndef PRAGMA_IMPORT
  #define PRAGMA_IMPORT               0
  #endif
 #ifndef PRAGMA_STRUCT_ALIGN
    #define PRAGMA_STRUCT_ALIGN         0
  #endif
 #ifndef PRAGMA_ONCE
    #define PRAGMA_ONCE                 0
  #endif
 #ifndef PRAGMA_STRUCT_PACK
 #define PRAGMA_STRUCT_PACK          0
  #endif
 #ifndef PRAGMA_STRUCT_PACKPUSH
 #define PRAGMA_STRUCT_PACKPUSH      0
  #endif
 #ifndef PRAGMA_ENUM_PACK
   #define PRAGMA_ENUM_PACK            0
  #endif
 #ifndef PRAGMA_ENUM_ALWAYSINT
  #define PRAGMA_ENUM_ALWAYSINT       0
  #endif
 #ifndef PRAGMA_ENUM_OPTIONS
    #define PRAGMA_ENUM_OPTIONS         0
  #endif
 #ifndef FOUR_CHAR_CODE
 #define FOUR_CHAR_CODE(x)           (x)
    #endif

    #ifndef TYPE_LONGDOUBLE_IS_DOUBLE
  #define TYPE_LONGDOUBLE_IS_DOUBLE   1
  #endif
 #ifndef TYPE_EXTENDED
  #define TYPE_EXTENDED               0
  #endif
 #ifndef TYPE_LONGLONG
  #define TYPE_LONGLONG               0
  #endif
 #ifndef FUNCTION_PASCAL
    #define FUNCTION_PASCAL             0
  #endif
 #ifndef FUNCTION_DECLSPEC
  #define FUNCTION_DECLSPEC           0
  #endif
 #ifndef FUNCTION_WIN32CC
   #define FUNCTION_WIN32CC            0
  #endif
#endif




/****************************************************************************************************

    Under MacOS, the classic 68k runtime has two calling conventions: pascal or C
    Under Win32, there are two calling conventions: __cdecl or __stdcall
    Headers and implementation files can use the following macros to make their
    source more portable by hiding the calling convention details:

    EXTERN_API*
    These macros are used to specify the calling convention on a function prototype.

        EXTERN_API              - Classic 68k: pascal, Win32: __cdecl
        EXTERN_API_C            - Classic 68k: C,      Win32: __cdecl
        EXTERN_API_STDCALL      - Classic 68k: pascal, Win32: __stdcall
        EXTERN_API_C_STDCALL    - Classic 68k: C,      Win32: __stdcall


    DEFINE_API*
    These macros are used to specify the calling convention on a function definition.

        DEFINE_API              - Classic 68k: pascal, Win32: __cdecl
        DEFINE_API_C            - Classic 68k: C,      Win32: __cdecl
        DEFINE_API_STDCALL      - Classic 68k: pascal, Win32: __stdcall
        DEFINE_API_C_STDCALL    - Classic 68k: C,      Win32: __stdcall


    CALLBACK_API*
    These macros are used to specify the calling convention of a function pointer.

        CALLBACK_API            - Classic 68k: pascal, Win32: __stdcall
        CALLBACK_API_C          - Classic 68k: C,      Win32: __stdcall
        CALLBACK_API_STDCALL    - Classic 68k: pascal, Win32: __cdecl
        CALLBACK_API_C_STDCALL  - Classic 68k: C,      Win32: __cdecl

****************************************************************************************************/

#if FUNCTION_PASCAL && !FUNCTION_DECLSPEC && !FUNCTION_WIN32CC
    /* compiler supports pascal keyword only  */
    #define EXTERN_API(_type)                       extern pascal _type
    #define EXTERN_API_C(_type)                     extern        _type
    #define EXTERN_API_STDCALL(_type)               extern pascal _type
    #define EXTERN_API_C_STDCALL(_type)             extern        _type
    
    #define DEFINE_API(_type)                       pascal _type
    #define DEFINE_API_C(_type)                            _type
    #define DEFINE_API_STDCALL(_type)               pascal _type
    #define DEFINE_API_C_STDCALL(_type)                    _type
    
    #define CALLBACK_API(_type, _name)              pascal _type (*_name)
    #define CALLBACK_API_C(_type, _name)                   _type (*_name)
    #define CALLBACK_API_STDCALL(_type, _name)      pascal _type (*_name)
    #define CALLBACK_API_C_STDCALL(_type, _name)           _type (*_name)

#elif FUNCTION_PASCAL && FUNCTION_DECLSPEC && !FUNCTION_WIN32CC
    /* compiler supports pascal and __declspec() */
    #define EXTERN_API(_type)                       extern pascal __declspec(dllimport) _type
    #define EXTERN_API_C(_type)                     extern        __declspec(dllimport) _type
    #define EXTERN_API_STDCALL(_type)               extern pascal __declspec(dllimport) _type
    #define EXTERN_API_C_STDCALL(_type)             extern        __declspec(dllimport) _type
    
    #define DEFINE_API(_type)                       pascal __declspec(dllexport) _type
    #define DEFINE_API_C(_type)                            __declspec(dllexport) _type
    #define DEFINE_API_STDCALL(_type)               pascal __declspec(dllexport) _type
    #define DEFINE_API_C_STDCALL(_type)                    __declspec(dllexport) _type

    #define CALLBACK_API(_type, _name)              pascal _type (*_name)
    #define CALLBACK_API_C(_type, _name)                   _type (*_name)
    #define CALLBACK_API_STDCALL(_type, _name)      pascal _type (*_name)
    #define CALLBACK_API_C_STDCALL(_type, _name)           _type (*_name)

#elif !FUNCTION_PASCAL && FUNCTION_DECLSPEC && !FUNCTION_WIN32CC
    /* compiler supports __declspec() */
    #define EXTERN_API(_type)                       extern __declspec(dllimport) _type
    #define EXTERN_API_C(_type)                     extern __declspec(dllimport) _type
    #define EXTERN_API_STDCALL(_type)               extern __declspec(dllimport) _type
    #define EXTERN_API_C_STDCALL(_type)             extern __declspec(dllimport) _type
    
    #define DEFINE_API(_type)                       __declspec(dllexport) _type 
    #define DEFINE_API_C(_type)                     __declspec(dllexport) _type
    #define DEFINE_API_STDCALL(_type)               __declspec(dllexport) _type
    #define DEFINE_API_C_STDCALL(_type)             __declspec(dllexport) _type

    #define CALLBACK_API(_type, _name)              _type ( * _name)
    #define CALLBACK_API_C(_type, _name)            _type ( * _name)
    #define CALLBACK_API_STDCALL(_type, _name)      _type ( * _name)
    #define CALLBACK_API_C_STDCALL(_type, _name)    _type ( * _name)

#elif !FUNCTION_PASCAL && FUNCTION_DECLSPEC && FUNCTION_WIN32CC
    /* compiler supports __declspec() and __cdecl */
    #define EXTERN_API(_type)                       __declspec(dllimport) _type __cdecl
    #define EXTERN_API_C(_type)                     __declspec(dllimport) _type __cdecl
    #define EXTERN_API_STDCALL(_type)               __declspec(dllimport) _type __stdcall
    #define EXTERN_API_C_STDCALL(_type)             __declspec(dllimport) _type __stdcall
    
    #define DEFINE_API(_type)                       __declspec(dllexport) _type __cdecl
    #define DEFINE_API_C(_type)                     __declspec(dllexport) _type __cdecl
    #define DEFINE_API_STDCALL(_type)               __declspec(dllexport) _type __stdcall
    #define DEFINE_API_C_STDCALL(_type)             __declspec(dllexport) _type __stdcall
    
    #define CALLBACK_API(_type, _name)              _type (__cdecl * _name)
    #define CALLBACK_API_C(_type, _name)            _type (__cdecl * _name)
    #define CALLBACK_API_STDCALL(_type, _name)      _type (__stdcall * _name)
    #define CALLBACK_API_C_STDCALL(_type, _name)    _type (__stdcall * _name)

#elif !FUNCTION_PASCAL && !FUNCTION_DECLSPEC && FUNCTION_WIN32CC
    /* compiler supports __cdecl */
    #define EXTERN_API(_type)                       _type __cdecl
    #define EXTERN_API_C(_type)                     _type __cdecl
    #define EXTERN_API_STDCALL(_type)               _type __stdcall
    #define EXTERN_API_C_STDCALL(_type)             _type __stdcall
    
    #define DEFINE_API(_type)                       _type __cdecl
    #define DEFINE_API_C(_type)                     _type __cdecl
    #define DEFINE_API_STDCALL(_type)               _type __stdcall
    #define DEFINE_API_C_STDCALL(_type)             _type __stdcall
    
    #define CALLBACK_API(_type, _name)              _type (__cdecl * _name)
    #define CALLBACK_API_C(_type, _name)            _type (__cdecl * _name)
    #define CALLBACK_API_STDCALL(_type, _name)      _type (__stdcall * _name)
    #define CALLBACK_API_C_STDCALL(_type, _name)    _type (__stdcall * _name)

#else 
    /* compiler supports no extensions */
    #define EXTERN_API(_type)                       extern _type
    #define EXTERN_API_C(_type)                     extern _type
    #define EXTERN_API_STDCALL(_type)               extern _type
    #define EXTERN_API_C_STDCALL(_type)             extern _type
    
    #define DEFINE_API(_type)                       _type
    #define DEFINE_API_C(_type)                     _type
    #define DEFINE_API_STDCALL(_type)               _type
    #define DEFINE_API_C_STDCALL(_type)             _type

    #define CALLBACK_API(_type, _name)              _type ( * _name)
    #define CALLBACK_API_C(_type, _name)            _type ( * _name)
    #define CALLBACK_API_STDCALL(_type, _name)      _type ( * _name)
    #define CALLBACK_API_C_STDCALL(_type, _name)    _type ( * _name)
    #undef pascal
    #define pascal
#endif

/****************************************************************************************************
    
    Set up TARGET_API_*_* values

****************************************************************************************************/
#if !defined(TARGET_API_MAC_OS8) && !defined(TARGET_API_MAC_OSX) && !defined(TARGET_API_MAC_CARBON)
/* No TARGET_API_MAC_* predefined on command line */
#if TARGET_RT_MAC_MACHO
/* Looks like MachO style compiler */
#define TARGET_API_MAC_OS8 0
#define TARGET_API_MAC_CARBON 1
#define TARGET_API_MAC_OSX 1
#elif defined(TARGET_CARBON) && TARGET_CARBON
/* grandfather in use of TARGET_CARBON */
#define TARGET_API_MAC_OS8 0
#define TARGET_API_MAC_CARBON 1
#define TARGET_API_MAC_OSX 0
#elif TARGET_CPU_PPC && TARGET_RT_MAC_CFM
/* Looks like CFM style PPC compiler */
#define TARGET_API_MAC_OS8 1
#define TARGET_API_MAC_CARBON 0
#define TARGET_API_MAC_OSX 0
#else
/* 68k or some other compiler */
#define TARGET_API_MAC_OS8 1
#define TARGET_API_MAC_CARBON 0
#define TARGET_API_MAC_OSX 0
#endif  /*  */

#else
#ifndef TARGET_API_MAC_OS8
#define TARGET_API_MAC_OS8 0
#endif  /* !defined(TARGET_API_MAC_OS8) */

#ifndef TARGET_API_MAC_OSX
#define TARGET_API_MAC_OSX TARGET_RT_MAC_MACHO
#endif  /* !defined(TARGET_API_MAC_OSX) */

#ifndef TARGET_API_MAC_CARBON
#define TARGET_API_MAC_CARBON TARGET_API_MAC_OSX
#endif  /* !defined(TARGET_API_MAC_CARBON) */

#endif  /* !defined(TARGET_API_MAC_OS8) && !defined(TARGET_API_MAC_OSX) && !defined(TARGET_API_MAC_CARBON) */

#if TARGET_API_MAC_OS8 && TARGET_API_MAC_OSX
#error TARGET_API_MAC_OS8 and TARGET_API_MAC_OSX are mutually exclusive
#endif  /* TARGET_API_MAC_OS8 && TARGET_API_MAC_OSX */

#if !TARGET_API_MAC_OS8 && !TARGET_API_MAC_CARBON && !TARGET_API_MAC_OSX
#error At least one of TARGET_API_MAC_* must be true
#endif  /* !TARGET_API_MAC_OS8 && !TARGET_API_MAC_CARBON && !TARGET_API_MAC_OSX */

/* Support source code still using TARGET_CARBON */
#ifndef TARGET_CARBON
#if TARGET_API_MAC_CARBON && !TARGET_API_MAC_OS8
#define TARGET_CARBON 1
#else
#define TARGET_CARBON 0
#endif  /* TARGET_API_MAC_CARBON && !TARGET_API_MAC_OS8 */

#endif  /* !defined(TARGET_CARBON) */

/****************************************************************************************************
    Backward compatibility for clients expecting 2.x version on ConditionalMacros.h

    GENERATINGPOWERPC       - Compiler is generating PowerPC instructions
    GENERATING68K           - Compiler is generating 68k family instructions
    GENERATING68881         - Compiler is generating mc68881 floating point instructions
    GENERATINGCFM           - Code being generated assumes CFM calling conventions
    CFMSYSTEMCALLS          - No A-traps.  Systems calls are made using CFM and UPP's
    PRAGMA_ALIGN_SUPPORTED  - Compiler supports: #pragma options align=mac68k/power/reset
    PRAGMA_IMPORT_SUPPORTED - Compiler supports: #pragma import on/off/reset
    CGLUESUPPORTED          - Clients can use all lowercase toolbox functions that take C strings instead of pascal strings

****************************************************************************************************/
#if !TARGET_API_MAC_CARBON
#define GENERATINGPOWERPC TARGET_CPU_PPC
#define GENERATING68K 0
#define GENERATING68881 TARGET_RT_MAC_68881
#define GENERATINGCFM TARGET_RT_MAC_CFM
#define CFMSYSTEMCALLS TARGET_RT_MAC_CFM
#ifndef CGLUESUPPORTED
#define CGLUESUPPORTED 0
#endif  /* !defined(CGLUESUPPORTED) */

#ifndef OLDROUTINELOCATIONS
#define OLDROUTINELOCATIONS 0
#endif  /* !defined(OLDROUTINELOCATIONS) */

#define PRAGMA_ALIGN_SUPPORTED  PRAGMA_STRUCT_ALIGN
#define PRAGMA_IMPORT_SUPPORTED PRAGMA_IMPORT
#else
/* Carbon code should not use old conditionals */
#define PRAGMA_ALIGN_SUPPORTED  ..PRAGMA_ALIGN_SUPPORTED_is_obsolete..
#define GENERATINGPOWERPC       ..GENERATINGPOWERPC_is_obsolete..
#define GENERATING68K           ..GENERATING68K_is_obsolete..
#define GENERATING68881         ..GENERATING68881_is_obsolete..
#define GENERATINGCFM           ..GENERATINGCFM_is_obsolete..
#define CFMSYSTEMCALLS          ..CFMSYSTEMCALLS_is_obsolete..
#endif  /* !TARGET_API_MAC_CARBON */



/****************************************************************************************************

    OLDROUTINENAMES         - "Old" names for Macintosh system calls are allowed in source code.
                              (e.g. DisposPtr instead of DisposePtr). The names of system routine
                              are now more sensitive to change because CFM binds by name.  In the 
                              past, system routine names were compiled out to just an A-Trap.  
                              Macros have been added that each map an old name to its new name.  
                              This allows old routine names to be used in existing source files,
                              but the macros only work if OLDROUTINENAMES is true.  This support
                              will be removed in the near future.  Thus, all source code should 
                              be changed to use the new names! You can set OLDROUTINENAMES to false
                              to see if your code has any old names left in it.
    
****************************************************************************************************/
#ifndef OLDROUTINENAMES
#define OLDROUTINENAMES 0
#endif  /* !defined(OLDROUTINENAMES) */



/****************************************************************************************************
 The following macros isolate the use of 68K inlines in function prototypes.
    On the Mac OS under the Classic 68K runtime, function prototypes were followed
 by a list of 68K opcodes which the compiler inserted in the generated code instead
 of a JSR.  Under Classic 68K on the Mac OS, this macro will put the opcodes
    in the right syntax.  For all other OS's and runtimes the macro suppress the opcodes.
  Example:
   
       EXTERN_P void DrawPicture(PicHandle myPicture, const Rect *dstRect)
            ONEWORDINLINE(0xA8F6);
 
****************************************************************************************************/

#if TARGET_OS_MAC && TARGET_CPU_68K && !TARGET_RT_MAC_CFM
 #define ONEWORDINLINE(w1) = w1
 #define TWOWORDINLINE(w1,w2) = {w1,w2}
 #define THREEWORDINLINE(w1,w2,w3) = {w1,w2,w3}
 #define FOURWORDINLINE(w1,w2,w3,w4)  = {w1,w2,w3,w4}
   #define FIVEWORDINLINE(w1,w2,w3,w4,w5) = {w1,w2,w3,w4,w5}
  #define SIXWORDINLINE(w1,w2,w3,w4,w5,w6)     = {w1,w2,w3,w4,w5,w6}
 #define SEVENWORDINLINE(w1,w2,w3,w4,w5,w6,w7)    = {w1,w2,w3,w4,w5,w6,w7}
  #define EIGHTWORDINLINE(w1,w2,w3,w4,w5,w6,w7,w8)     = {w1,w2,w3,w4,w5,w6,w7,w8}
   #define NINEWORDINLINE(w1,w2,w3,w4,w5,w6,w7,w8,w9)   = {w1,w2,w3,w4,w5,w6,w7,w8,w9}
    #define TENWORDINLINE(w1,w2,w3,w4,w5,w6,w7,w8,w9,w10)  = {w1,w2,w3,w4,w5,w6,w7,w8,w9,w10}
  #define ELEVENWORDINLINE(w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11)     = {w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11}
    #define TWELVEWORDINLINE(w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12)     = {w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12}
#else
  #define ONEWORDINLINE(w1)
  #define TWOWORDINLINE(w1,w2)
   #define THREEWORDINLINE(w1,w2,w3)
  #define FOURWORDINLINE(w1,w2,w3,w4)
    #define FIVEWORDINLINE(w1,w2,w3,w4,w5)
 #define SIXWORDINLINE(w1,w2,w3,w4,w5,w6)
   #define SEVENWORDINLINE(w1,w2,w3,w4,w5,w6,w7)
  #define EIGHTWORDINLINE(w1,w2,w3,w4,w5,w6,w7,w8)
   #define NINEWORDINLINE(w1,w2,w3,w4,w5,w6,w7,w8,w9)
 #define TENWORDINLINE(w1,w2,w3,w4,w5,w6,w7,w8,w9,w10)
  #define ELEVENWORDINLINE(w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11)
   #define TWELVEWORDINLINE(w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12)
#endif


/****************************************************************************************************

    TARGET_CARBON                   - default: false. Switches all of the above as described.  Overrides all others
                                    - NOTE: If you set TARGET_CARBON to 1, then the other switches will be setup by
                                            ConditionalMacros, and should not be set manually.

    If you wish to do development for pre-Carbon Systems, you can set the following:

    OPAQUE_TOOLBOX_STRUCTS          - default: false. True for Carbon builds, hides struct fields.
    OPAQUE_UPP_TYPES                - default: false. True for Carbon builds, UPP types are unique and opaque.
    ACCESSOR_CALLS_ARE_FUNCTIONS    - default: false. True for Carbon builds, enables accessor functions.
    CALL_NOT_IN_CARBON              - default: true.  False for Carbon builds, hides calls not supported in Carbon.
    
    Specifically, if you are building a non-Carbon application (one that links against InterfaceLib)
    but you wish to use some of the accessor functions, you can set ACCESSOR_CALLS_ARE_FUNCTIONS to 1
    and link with CarbonAccessors.o, which implements just the accessor functions. This will help you
    preserve source compatibility between your Carbon and non-Carbon application targets.
    
    MIXEDMODE_CALLS_ARE_FUNCTIONS   - deprecated.

****************************************************************************************************/
#if TARGET_API_MAC_CARBON && !TARGET_API_MAC_OS8
#ifndef OPAQUE_TOOLBOX_STRUCTS
#define OPAQUE_TOOLBOX_STRUCTS 1
#endif  /* !defined(OPAQUE_TOOLBOX_STRUCTS) */

#ifndef OPAQUE_UPP_TYPES
#define OPAQUE_UPP_TYPES 1
#endif  /* !defined(OPAQUE_UPP_TYPES) */

#ifndef ACCESSOR_CALLS_ARE_FUNCTIONS
#define ACCESSOR_CALLS_ARE_FUNCTIONS 1
#endif  /* !defined(ACCESSOR_CALLS_ARE_FUNCTIONS) */

#ifndef CALL_NOT_IN_CARBON
#define CALL_NOT_IN_CARBON 0
#endif  /* !defined(CALL_NOT_IN_CARBON) */

#ifndef MIXEDMODE_CALLS_ARE_FUNCTIONS
#define MIXEDMODE_CALLS_ARE_FUNCTIONS 1
#endif  /* !defined(MIXEDMODE_CALLS_ARE_FUNCTIONS) */

#else
#ifndef OPAQUE_TOOLBOX_STRUCTS
#define OPAQUE_TOOLBOX_STRUCTS 0
#endif  /* !defined(OPAQUE_TOOLBOX_STRUCTS) */

#ifndef ACCESSOR_CALLS_ARE_FUNCTIONS
#define ACCESSOR_CALLS_ARE_FUNCTIONS 0
#endif  /* !defined(ACCESSOR_CALLS_ARE_FUNCTIONS) */

/*
     * It's possible to have ACCESSOR_CALLS_ARE_FUNCTIONS set to true and OPAQUE_TOOLBOX_STRUCTS
     * set to false, but not the other way around, so make sure the defines are not set this way.
     */
#ifndef CALL_NOT_IN_CARBON
#define CALL_NOT_IN_CARBON 1
#endif  /* !defined(CALL_NOT_IN_CARBON) */

#ifndef MIXEDMODE_CALLS_ARE_FUNCTIONS
#define MIXEDMODE_CALLS_ARE_FUNCTIONS 0
#endif  /* !defined(MIXEDMODE_CALLS_ARE_FUNCTIONS) */

#endif  /* TARGET_API_MAC_CARBON && !TARGET_API_MAC_OS8 */




#endif /* __CONDITIONALMACROS__ */