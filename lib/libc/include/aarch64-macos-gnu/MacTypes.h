/*
 * Copyright (c) 1985-2011 by Apple Inc.. All rights reserved.
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
     File:       MacTypes.h
 
     Contains:   Basic Macintosh data types.
 
     Version:    CarbonCore-769~1
  
     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:
 
                     http://developer.apple.com/bugreporter/
 
*/
#ifndef __MACTYPES__
#define __MACTYPES__

#ifndef __CONDITIONALMACROS__
#include <ConditionalMacros.h>
#endif

#include <stdbool.h>

#include <sys/types.h>

#include <Availability.h>

#if PRAGMA_ONCE
#pragma once
#endif

#ifdef __cplusplus
extern "C" {
#endif

#pragma pack(push, 2)


/*
        CarbonCore Deprecation flags.

     Certain Carbon API functions are deprecated in 10.3 and later
      systems.  These will produce a warning when compiling on 10.3.

        Other functions and constants do not produce meaningful
        results when building Carbon for Mac OS X.  For these
      functions, no-op macros are provided, but only when the
        ALLOW_OBSOLETE_CARBON flag is defined to be 0: eg
      -DALLOW_OBSOLETE_CARBON=0.
*/

#if  ! defined(ALLOW_OBSOLETE_CARBON) || ! ALLOW_OBSOLETE_CARBON

#define ALLOW_OBSOLETE_CARBON_MACMEMORY        0
#define ALLOW_OBSOLETE_CARBON_OSUTILS     0

#else

#define ALLOW_OBSOLETE_CARBON_MACMEMORY       1       /* Removes obsolete constants; turns HLock/HUnlock into no-op macros */
#define ALLOW_OBSOLETE_CARBON_OSUTILS       1       /* Removes obsolete structures */

#endif

#ifndef NULL
#define NULL    __DARWIN_NULL
#endif /* ! NULL */
#ifndef nil
  #if defined(__has_feature) 
    #if __has_feature(cxx_nullptr)
      #define nil nullptr
    #else
      #define nil __DARWIN_NULL
    #endif
  #else
    #define nil __DARWIN_NULL
  #endif
#endif

/********************************************************************************

    Base integer types for all target OS's and CPU's
    
        UInt8            8-bit unsigned integer 
        SInt8            8-bit signed integer
        UInt16          16-bit unsigned integer 
        SInt16          16-bit signed integer           
        UInt32          32-bit unsigned integer 
        SInt32          32-bit signed integer   
        UInt64          64-bit unsigned integer 
        SInt64          64-bit signed integer   

*********************************************************************************/
typedef unsigned char                   UInt8;
typedef signed char                     SInt8;
typedef unsigned short                  UInt16;
typedef signed short                    SInt16;

#if __LP64__
typedef unsigned int                    UInt32;
typedef signed int                      SInt32;
#else
typedef unsigned long                   UInt32;
typedef signed long                     SInt32;
#endif

/* avoid redeclaration if libkern/OSTypes.h */
#ifndef _OS_OSTYPES_H
#if TARGET_RT_BIG_ENDIAN
struct wide {
  SInt32              hi;
  UInt32              lo;
};
typedef struct wide                     wide;
struct UnsignedWide {
  UInt32              hi;
  UInt32              lo;
};
typedef struct UnsignedWide             UnsignedWide;
#else
struct wide {
  UInt32              lo;
  SInt32              hi;
};
typedef struct wide                     wide;
struct UnsignedWide {
  UInt32              lo;
  UInt32              hi;
};
typedef struct UnsignedWide             UnsignedWide;
#endif  /* TARGET_RT_BIG_ENDIAN */

#endif

#if TYPE_LONGLONG
/*
  Note:   wide and UnsignedWide must always be structs for source code
           compatibility. On the other hand UInt64 and SInt64 can be
          either a struct or a long long, depending on the compiler.
         
           If you use UInt64 and SInt64 you should do all operations on 
          those data types through the functions/macros in Math64.h.  
           This will assure that your code compiles with compilers that
           support long long and those that don't.
            
           The MS Visual C/C++ compiler uses __int64 instead of long long. 
*/
    #if defined(_MSC_VER) && !defined(__MWERKS__) && defined(_M_IX86)
      typedef   signed __int64                SInt64;
        typedef unsigned __int64                UInt64;
    #else
      typedef   signed long long              SInt64;
        typedef unsigned long long              UInt64;
    #endif
#else


typedef wide                            SInt64;
typedef UnsignedWide                    UInt64;
#endif  /* TYPE_LONGLONG */

/********************************************************************************

    Base fixed point types 
    
        Fixed           16-bit signed integer plus 16-bit fraction
        UnsignedFixed   16-bit unsigned integer plus 16-bit fraction
        Fract           2-bit signed integer plus 30-bit fraction
        ShortFixed      8-bit signed integer plus 8-bit fraction
        
*********************************************************************************/
typedef SInt32                          Fixed;
typedef Fixed *                         FixedPtr;
typedef SInt32                          Fract;
typedef Fract *                         FractPtr;
typedef UInt32                          UnsignedFixed;
typedef UnsignedFixed *                 UnsignedFixedPtr;
typedef short                           ShortFixed;
typedef ShortFixed *                    ShortFixedPtr;


/********************************************************************************

    Base floating point types 
    
        Float32         32 bit IEEE float:  1 sign bit, 8 exponent bits, 23 fraction bits
        Float64         64 bit IEEE float:  1 sign bit, 11 exponent bits, 52 fraction bits  
        Float80         80 bit MacOS float: 1 sign bit, 15 exponent bits, 1 integer bit, 63 fraction bits
        Float96         96 bit 68881 float: 1 sign bit, 15 exponent bits, 16 pad bits, 1 integer bit, 63 fraction bits
        
    Note: These are fixed size floating point types, useful when writing a floating
          point value to disk.  If your compiler does not support a particular size 
          float, a struct is used instead.
          Use one of the NCEG types (e.g. double_t) or an ANSI C type (e.g. double) if
          you want a floating point representation that is natural for any given
          compiler, but might be a different size on different compilers.

*********************************************************************************/
typedef float               Float32;
typedef double              Float64;
struct Float80 {
    SInt16  exp;
    UInt16  man[4];
};
typedef struct Float80 Float80;

struct Float96 {
    SInt16  exp[2];     /* the second 16-bits are undefined */
    UInt16  man[4];
};
typedef struct Float96 Float96;
struct Float32Point {
    Float32             x;
    Float32             y;
};
typedef struct Float32Point Float32Point;

/********************************************************************************

    MacOS Memory Manager types
    
        Ptr             Pointer to a non-relocatable block
        Handle          Pointer to a master pointer to a relocatable block
        Size            The number of bytes in a block (signed for historical reasons)
        
*********************************************************************************/
typedef char *                          Ptr;
typedef Ptr *                           Handle;
typedef long                            Size;

/********************************************************************************

    Higher level basic types
    
        OSErr                   16-bit result error code
        OSStatus                32-bit result error code
        LogicalAddress          Address in the clients virtual address space
        ConstLogicalAddress     Address in the clients virtual address space that will only be read
        PhysicalAddress         Real address as used on the hardware bus
        BytePtr                 Pointer to an array of bytes
        ByteCount               The size of an array of bytes
        ByteOffset              An offset into an array of bytes
        ItemCount               32-bit iteration count
        OptionBits              Standard 32-bit set of bit flags
        PBVersion               ?
        Duration                32-bit millisecond timer for drivers
        AbsoluteTime            64-bit clock
        ScriptCode              A particular set of written characters (e.g. Roman vs Cyrillic) and their encoding
        LangCode                A particular language (e.g. English), as represented using a particular ScriptCode
        RegionCode              Designates a language as used in a particular region (e.g. British vs American
                                English) together with other region-dependent characteristics (e.g. date format)
        FourCharCode            A 32-bit value made by packing four 1 byte characters together
        OSType                  A FourCharCode used in the OS and file system (e.g. creator)
        ResType                 A FourCharCode used to tag resources (e.g. 'DLOG')
        
*********************************************************************************/
typedef SInt16                          OSErr;
typedef SInt32                          OSStatus;
typedef void *                          LogicalAddress;
typedef const void *                    ConstLogicalAddress;
typedef void *                          PhysicalAddress;
typedef UInt8 *                         BytePtr;
typedef unsigned long                   ByteCount;
typedef unsigned long                   ByteOffset;
typedef SInt32                          Duration;
typedef UnsignedWide                    AbsoluteTime;
typedef UInt32                          OptionBits;
typedef unsigned long                   ItemCount;
typedef UInt32                          PBVersion;
typedef SInt16                          ScriptCode;
typedef SInt16                          LangCode;
typedef SInt16                          RegionCode;
typedef UInt32                          FourCharCode;
typedef FourCharCode                    OSType;
typedef FourCharCode                    ResType;
typedef OSType *                        OSTypePtr;
typedef ResType *                       ResTypePtr;
/********************************************************************************

    Boolean types and values
    
        Boolean         Mac OS historic type, sizeof(Boolean)==1
        bool            Defined in stdbool.h, ISO C/C++ standard type
        false           Now defined in stdbool.h
        true            Now defined in stdbool.h
        
*********************************************************************************/
typedef unsigned char                   Boolean;
/********************************************************************************

    Function Pointer Types
    
        ProcPtr                 Generic pointer to a function
        Register68kProcPtr      Pointer to a 68K function that expects parameters in registers
        UniversalProcPtr        Pointer to classic 68K code or a RoutineDescriptor
        
        ProcHandle              Pointer to a ProcPtr
        UniversalProcHandle     Pointer to a UniversalProcPtr
        
*********************************************************************************/
typedef CALLBACK_API_C( long , ProcPtr )(void);
typedef CALLBACK_API( void , Register68kProcPtr )(void);
#if TARGET_RT_MAC_CFM
/*  The RoutineDescriptor structure is defined in MixedMode.h */
typedef struct RoutineDescriptor *UniversalProcPtr;
#else
typedef ProcPtr                         UniversalProcPtr;
#endif  /* TARGET_RT_MAC_CFM */

typedef ProcPtr *                       ProcHandle;
typedef UniversalProcPtr *              UniversalProcHandle;
/********************************************************************************

    RefCon Types
    
        For access to private data in callbacks, etc.; refcons are generally
        used as a pointer to something, but in the 32-bit world refcons in
        different APIs have had various types: pointer, unsigned scalar, and
        signed scalar. The RefCon types defined here support the current 32-bit
        usage but provide normalization to pointer types for 64-bit.
        
        PRefCon is preferred for new APIs; URefCon and SRefCon are primarily
        for compatibility with existing APIs.
        
*********************************************************************************/
typedef void *                          PRefCon;
#if __LP64__
typedef void *                          URefCon;
typedef void *                          SRefCon;
#else
typedef UInt32                          URefCon;
typedef SInt32                          SRefCon;
#endif  /* __LP64__ */

/********************************************************************************

    Common Constants
    
        noErr                   OSErr: function performed properly - no error
        kNilOptions             OptionBits: all flags false
        kInvalidID              KernelID: NULL is for pointers as kInvalidID is for ID's
        kVariableLengthArray    array bounds: variable length array

    Note: kVariableLengthArray was used in array bounds to specify a variable length array,
          usually the last field in a struct.  Now that the C language supports 
		  the concept of flexible array members, you can instead use: 
		
		struct BarList
		{
			short	listLength;
			Bar		elements[];
		};

		However, this changes the semantics somewhat, as sizeof( BarList ) contains
		no space for any of the elements, so to allocate a list with space for
		the count elements

		struct BarList* l = (struct BarList*) malloc( sizeof(BarList) + count * sizeof(Bar) );
        
*********************************************************************************/
enum {
  noErr                         = 0
};

enum {
  kNilOptions                   = 0
};

#define kInvalidID   0
enum {
  kVariableLengthArray  
#ifdef __has_extension
   #if __has_extension(enumerator_attributes)
		__attribute__((deprecated))  
	#endif
#endif
  = 1
};

enum {
  kUnknownType                  = 0x3F3F3F3F /* "????" QuickTime 3.0: default unknown ResType or OSType */
};



/********************************************************************************

    String Types and Unicode Types
    
        UnicodeScalarValue,     A complete Unicode character in UTF-32 format, with
        UTF32Char               values from 0 through 0x10FFFF (excluding the surrogate
                                range 0xD800-0xDFFF and certain disallowed values).

        UniChar,                A 16-bit Unicode code value in the default UTF-16 format.
        UTF16Char               UnicodeScalarValues 0-0xFFFF are expressed in UTF-16
                                format using a single UTF16Char with the same value.
                                UnicodeScalarValues 0x10000-0x10FFFF are expressed in
                                UTF-16 format using a pair of UTF16Chars - one in the
                                high surrogate range (0xD800-0xDBFF) followed by one in
                                the low surrogate range (0xDC00-0xDFFF). All of the
                                characters defined in Unicode versions through 3.0 are
                                in the range 0-0xFFFF and can be expressed using a single
                                UTF16Char, thus the term "Unicode character" generally
                                refers to a UniChar = UTF16Char.

        UTF8Char                An 8-bit code value in UTF-8 format. UnicodeScalarValues
                                0-0x7F are expressed in UTF-8 format using one UTF8Char
                                with the same value. UnicodeScalarValues above 0x7F are
                                expressed in UTF-8 format using 2-4 UTF8Chars, all with
                                values in the range 0x80-0xF4 (UnicodeScalarValues
                                0x100-0xFFFF use two or three UTF8Chars,
                                UnicodeScalarValues 0x10000-0x10FFFF use four UTF8Chars).

        UniCharCount            A count of UTF-16 code values in an array or buffer.

        StrNNN                  Pascal string holding up to NNN bytes
        StringPtr               Pointer to a pascal string
        StringHandle            Pointer to a StringPtr
        ConstStringPtr          Pointer to a read-only pascal string
        ConstStrNNNParam        For function parameters only - means string is const
        
        CStringPtr              Pointer to a C string           (in C:  char*)
        ConstCStringPtr         Pointer to a read-only C string (in C:  const char*)
        
    Note: The length of a pascal string is stored as the first byte.
          A pascal string does not have a termination byte.
          A pascal string can hold at most 255 bytes of data.
          The first character in a pascal string is offset one byte from the start of the string. 
          
          A C string is terminated with a byte of value zero.  
          A C string has no length limitation.
          The first character in a C string is the zeroth byte of the string. 
          
        
*********************************************************************************/
typedef UInt32                          UnicodeScalarValue;
typedef UInt32                          UTF32Char;
typedef UInt16                          UniChar;
typedef UInt16                          UTF16Char;
typedef UInt8                           UTF8Char;
typedef UniChar *                       UniCharPtr;
typedef unsigned long                   UniCharCount;
typedef UniCharCount *                  UniCharCountPtr;
typedef unsigned char                   Str255[256];
typedef unsigned char                   Str63[64];
typedef unsigned char                   Str32[33];
typedef unsigned char                   Str31[32];
typedef unsigned char                   Str27[28];
typedef unsigned char                   Str15[16];
/*
    The type Str32 is used in many AppleTalk based data structures.
    It holds up to 32 one byte chars.  The problem is that with the
    length byte it is 33 bytes long.  This can cause weird alignment
    problems in structures.  To fix this the type "Str32Field" has
    been created.  It should only be used to hold 32 chars, but
    it is 34 bytes long so that there are no alignment problems.
*/
typedef unsigned char                   Str32Field[34];
/*
    QuickTime 3.0:
    The type StrFileName is used to make MacOS structs work 
    cross-platform.  For example FSSpec or SFReply previously
    contained a Str63 field.  They now contain a StrFileName
    field which is the same when targeting the MacOS but is
    a 256 char buffer for Win32 and unix, allowing them to
    contain long file names.
*/
typedef Str63                           StrFileName;
typedef unsigned char *                 StringPtr;
typedef StringPtr *                     StringHandle;
typedef const unsigned char *           ConstStringPtr;
typedef const unsigned char *           ConstStr255Param;
typedef const unsigned char *           ConstStr63Param;
typedef const unsigned char *           ConstStr32Param;
typedef const unsigned char *           ConstStr31Param;
typedef const unsigned char *           ConstStr27Param;
typedef const unsigned char *           ConstStr15Param;
typedef ConstStr63Param                 ConstStrFileNameParam;
#ifdef __cplusplus
inline unsigned char StrLength(ConstStr255Param string) { return (*string); }
#else
#define StrLength(string) (*(const unsigned char *)(string))
#endif  /* defined(__cplusplus) */

#if OLDROUTINENAMES
#define Length(string) StrLength(string)
#endif  /* OLDROUTINENAMES */

/********************************************************************************

    Process Manager type ProcessSerialNumber (previously in Processes.h)

*********************************************************************************/
/* type for unique process identifier */
struct ProcessSerialNumber {
  UInt32              highLongOfPSN;
  UInt32              lowLongOfPSN;
};
typedef struct ProcessSerialNumber      ProcessSerialNumber;
typedef ProcessSerialNumber *           ProcessSerialNumberPtr;
/********************************************************************************

    Quickdraw Types
    
        Point               2D Quickdraw coordinate, range: -32K to +32K
        Rect                Rectangular Quickdraw area
        Style               Quickdraw font rendering styles
        StyleParameter      Style when used as a parameter (historical 68K convention)
        StyleField          Style when used as a field (historical 68K convention)
        CharParameter       Char when used as a parameter (historical 68K convention)
        
    Note:   The original Macintosh toolbox in 68K Pascal defined Style as a SET.  
            Both Style and CHAR occupy 8-bits in packed records or 16-bits when 
            used as fields in non-packed records or as parameters. 
        
*********************************************************************************/
struct Point {
  short               v;
  short               h;
};
typedef struct Point                    Point;
typedef Point *                         PointPtr;
struct Rect {
  short               top;
  short               left;
  short               bottom;
  short               right;
};
typedef struct Rect                     Rect;
typedef Rect *                          RectPtr;
struct FixedPoint {
  Fixed               x;
  Fixed               y;
};
typedef struct FixedPoint               FixedPoint;
struct FixedRect {
  Fixed               left;
  Fixed               top;
  Fixed               right;
  Fixed               bottom;
};
typedef struct FixedRect                FixedRect;

typedef short                           CharParameter;
enum {
  normal                        = 0,
  bold                          = 1,
  italic                        = 2,
  underline                     = 4,
  outline                       = 8,
  shadow                        = 0x10,
  condense                      = 0x20,
  extend                        = 0x40
};

typedef unsigned char                   Style;
typedef short                           StyleParameter;
typedef Style                           StyleField;


/********************************************************************************

    QuickTime TimeBase types (previously in Movies.h)
    
        TimeValue           Count of units
        TimeScale           Units per second
        CompTimeValue       64-bit count of units (always a struct) 
        TimeValue64         64-bit count of units (long long or struct) 
        TimeBase            An opaque reference to a time base
        TimeRecord          Package of TimeBase, duration, and scale
        
*********************************************************************************/
typedef SInt32                          TimeValue;
typedef SInt32                          TimeScale;
typedef wide                            CompTimeValue;
typedef SInt64                          TimeValue64;
typedef struct TimeBaseRecord*          TimeBase;
struct TimeRecord {
  CompTimeValue       value;                  /* units (duration or absolute) */
  TimeScale           scale;                  /* units per second */
  TimeBase            base;                   /* refernce to the time base */
};
typedef struct TimeRecord               TimeRecord;

/********************************************************************************

    THINK C base objects

        HandleObject        Root class for handle based THINK C++ objects
        PascalObject        Root class for pascal style objects in THINK C++ 

*********************************************************************************/
#if defined(__SC__) && !defined(__STDC__) && defined(__cplusplus)
        class __machdl HandleObject {};
        #if TARGET_CPU_68K
            class __pasobj PascalObject {};
        #endif
#endif


/********************************************************************************

    MacOS versioning structures
    
        VersRec                 Contents of a 'vers' resource
        VersRecPtr              Pointer to a VersRecPtr
        VersRecHndl             Resource Handle containing a VersRec
        NumVersion              Packed BCD version representation (e.g. "4.2.1a3" is 0x04214003)
        UniversalProcPtr        Pointer to classic 68K code or a RoutineDescriptor
        
        ProcHandle              Pointer to a ProcPtr
        UniversalProcHandle     Pointer to a UniversalProcPtr
        
*********************************************************************************/
#if TARGET_RT_BIG_ENDIAN
struct NumVersion {
                                              /* Numeric version part of 'vers' resource */
  UInt8               majorRev;               /*1st part of version number in BCD*/
  UInt8               minorAndBugRev;         /*2nd & 3rd part of version number share a byte*/
  UInt8               stage;                  /*stage code: dev, alpha, beta, final*/
  UInt8               nonRelRev;              /*revision level of non-released version*/
};
typedef struct NumVersion               NumVersion;
#else
struct NumVersion {
                                              /* Numeric version part of 'vers' resource accessable in little endian format */
  UInt8               nonRelRev;              /*revision level of non-released version*/
  UInt8               stage;                  /*stage code: dev, alpha, beta, final*/
  UInt8               minorAndBugRev;         /*2nd & 3rd part of version number share a byte*/
  UInt8               majorRev;               /*1st part of version number in BCD*/
};
typedef struct NumVersion               NumVersion;
#endif  /* TARGET_RT_BIG_ENDIAN */

enum {
                                        /* Version Release Stage Codes */
  developStage                  = 0x20,
  alphaStage                    = 0x40,
  betaStage                     = 0x60,
  finalStage                    = 0x80
};

union NumVersionVariant {
                                              /* NumVersionVariant is a wrapper so NumVersion can be accessed as a 32-bit value */
  NumVersion          parts;
  UInt32              whole;
};
typedef union NumVersionVariant         NumVersionVariant;
typedef NumVersionVariant *             NumVersionVariantPtr;
typedef NumVersionVariantPtr *          NumVersionVariantHandle;
struct VersRec {
                                              /* 'vers' resource format */
  NumVersion          numericVersion;         /*encoded version number*/
  short               countryCode;            /*country code from intl utilities*/
  Str255              shortVersion;           /*version number string - worst case*/
  Str255              reserved;               /*longMessage string packed after shortVersion*/
};
typedef struct VersRec                  VersRec;
typedef VersRec *                       VersRecPtr;
typedef VersRecPtr *                    VersRecHndl;
/*********************************************************************************

    Old names for types
        
*********************************************************************************/
typedef UInt8                           Byte;
typedef SInt8                           SignedByte;
typedef wide *                          WidePtr;
typedef UnsignedWide *                  UnsignedWidePtr;
typedef Float80                         extended80;
typedef Float96                         extended96;
typedef SInt8                           VHSelect;
/*********************************************************************************

    Debugger functions
    
*********************************************************************************/
/*
 *  Debugger()
 *  
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 */
extern void 
Debugger(void)                                                __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA);


/*
 *  DebugStr()
 *  
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 */
extern void 
DebugStr(ConstStr255Param debuggerMsg)                        __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA);


/*
 *  debugstr()
 *  
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 */


#if TARGET_CPU_PPC
/* Only for Mac OS native drivers */
/*
 *  SysDebug()
 *  
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   in DriverServicesLib 1.0 and later
 */


/*
 *  SysDebugStr()
 *  
 *  Availability:
 *    Mac OS X:         not available
 *    CarbonLib:        not available
 *    Non-Carbon CFM:   in DriverServicesLib 1.0 and later
 */


#endif  /* TARGET_CPU_PPC */

/* SADE break points */
/*
 *  SysBreak()
 *  
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 */
extern void 
SysBreak(void)                                                __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA);


/*
 *  SysBreakStr()
 *  
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 */
extern void 
SysBreakStr(ConstStr255Param debuggerMsg)                     __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA);


/*
 *  SysBreakFunc()
 *  
 *  Availability:
 *    Mac OS X:         in version 10.0 and later in CoreServices.framework
 *    CarbonLib:        in CarbonLib 1.0 and later
 *    Non-Carbon CFM:   in InterfaceLib 7.1 and later
 */
extern void 
SysBreakFunc(ConstStr255Param debuggerMsg)                    __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_0, __MAC_10_8, __IPHONE_NA, __IPHONE_NA);


/* old names for Debugger and DebugStr */
#if OLDROUTINENAMES && TARGET_CPU_68K
    #define Debugger68k()   Debugger()
    #define DebugStr68k(s)  DebugStr(s)
#endif


#pragma pack(pop)

#ifdef __cplusplus
}
#endif

#endif /* __MACTYPES__ */

