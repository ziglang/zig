/*
 * Copyright (c) 2002-2017 by Apple Inc.. All rights reserved.
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
	File:       AssertMacros.h
 
	Contains:   This file defines structured error handling and assertion macros for
				programming in C. Originally used in QuickDraw GX and later enhanced.
				These macros are used throughout Apple's software.
	
				New code may not want to begin adopting these macros and instead use
				existing language functionality.
	
				See "Living In an Exceptional World" by Sean Parent
				(develop, The Apple Technical Journal, Issue 11, August/September 1992)
				<http://developer.apple.com/dev/techsupport/develop/issue11toc.shtml> or
				<http://www.mactech.com/articles/develop/issue_11/Parent_final.html>
				for the methodology behind these error handling and assertion macros.
	
	Bugs?:      For bug reports, consult the following page on
				the World Wide Web:

	 http://developer.apple.com/bugreporter/ 
*/
#ifndef __ASSERTMACROS__
#define __ASSERTMACROS__

#ifdef DEBUG_ASSERT_CONFIG_INCLUDE
    #include DEBUG_ASSERT_CONFIG_INCLUDE
#endif

/*
 *  Macro overview:
 *  
 *      check(assertion)
 *         In production builds, pre-processed away  
 *         In debug builds, if assertion evaluates to false, calls DEBUG_ASSERT_MESSAGE
 *  
 *      verify(assertion)
 *         In production builds, evaluates assertion and does nothing
 *         In debug builds, if assertion evaluates to false, calls DEBUG_ASSERT_MESSAGE
 *  
 *      require(assertion, exceptionLabel)
 *         In production builds, if the assertion expression evaluates to false, goto exceptionLabel
 *         In debug builds, if the assertion expression evaluates to false, calls DEBUG_ASSERT_MESSAGE
 *                          and jumps to exceptionLabel
 *  
 *      In addition the following suffixes are available:
 * 
 *         _noerr     Adds "!= 0" to assertion.  Useful for asserting and OSStatus or OSErr is noErr (zero)
 *         _action    Adds statement to be executued if assertion fails
 *         _quiet     Suppress call to DEBUG_ASSERT_MESSAGE
 *         _string    Allows you to add explanitory message to DEBUG_ASSERT_MESSAGE
 *  
 *        For instance, require_noerr_string(resultCode, label, msg) will do nothing if 
 *        resultCode is zero, otherwise it will call DEBUG_ASSERT_MESSAGE with msg
 *        and jump to label.
 *
 *  Configuration:
 *
 *      By default all macros generate "production code" (i.e non-debug).  If  
 *      DEBUG_ASSERT_PRODUCTION_CODE is defined to zero or DEBUG is defined to non-zero
 *      while this header is included, the macros will generated debug code.
 *
 *      If DEBUG_ASSERT_COMPONENT_NAME_STRING is defined, all debug messages will
 *      be prefixed with it.
 *
 *      By default, all messages write to stderr.  If you would like to write a custom
 *      error message formater, defined DEBUG_ASSERT_MESSAGE to your function name.
 *
 *      Each individual macro will only be defined if it is not already defined, so
 *      you can redefine their behavior singly by providing your own definition before
 *      this file is included.
 *
 *      If you define __ASSERTMACROS__ before this file is included, then nothing in
 *      this file will take effect.
 *
 *      Prior to Mac OS X 10.6 the macro names used in this file conflicted with some
 *      user code, including libraries in boost and the proposed C++ standards efforts,
 *      and there was no way for a client of this header to resolve this conflict. Because
 *      of this, most of the macros have been changed so that they are prefixed with 
 *      __ and contain at least one capital letter, which should alleviate the current
 *      and future conflicts.  However, to allow current sources to continue to compile,
 *      compatibility macros are defined at the end with the old names.  A tops script 
 *      at the end of this file will convert all of the old macro names used in a directory
 *      to the new names.  Clients are recommended to migrate over to these new macros as
 *      they update their sources because a future release of Mac OS X will remove the
 *      old macro definitions ( without the double-underscore prefix ).  Clients who
 *      want to compile without the old macro definitions can define the macro
 *      __ASSERT_MACROS_DEFINE_VERSIONS_WITHOUT_UNDERSCORES to 0 before this file is
 *      included.
 */


/*
 *  Before including this file, #define DEBUG_ASSERT_COMPONENT_NAME_STRING to
 *  a C-string containing the name of your client. This string will be passed to
 *  the DEBUG_ASSERT_MESSAGE macro for inclusion in any assertion messages.
 *
 *  If you do not define DEBUG_ASSERT_COMPONENT_NAME_STRING, the default
 *  DEBUG_ASSERT_COMPONENT_NAME_STRING value, an empty string, will be used by
 *  the assertion macros.
 */
#ifndef DEBUG_ASSERT_COMPONENT_NAME_STRING
    #define DEBUG_ASSERT_COMPONENT_NAME_STRING ""
#endif


/*
 *  To activate the additional assertion code and messages for non-production builds,
 *  #define DEBUG_ASSERT_PRODUCTION_CODE to zero before including this file.
 *
 *  If you do not define DEBUG_ASSERT_PRODUCTION_CODE, the default value 1 will be used
 *  (production code = no assertion code and no messages).
 */
#ifndef DEBUG_ASSERT_PRODUCTION_CODE
   #define DEBUG_ASSERT_PRODUCTION_CODE !DEBUG
#endif


/*
 *  DEBUG_ASSERT_MESSAGE(component, assertion, label, error, file, line, errorCode)
 *
 *  Summary:
 *    All assertion messages are routed through this macro. If you wish to use your
 *    own routine to display assertion messages, you can override DEBUG_ASSERT_MESSAGE
 *    by #defining DEBUG_ASSERT_MESSAGE before including this file.
 *
 *  Parameters:
 *
 *    componentNameString:
 *      A pointer to a string constant containing the name of the
 *      component this code is part of. This must be a string constant
 *      (and not a string variable or NULL) because the preprocessor
 *      concatenates it with other string constants.
 *
 *    assertionString:
 *      A pointer to a string constant containing the assertion.
 *      This must be a string constant (and not a string variable or
 *      NULL) because the Preprocessor concatenates it with other
 *      string constants.
 *    
 *    exceptionLabelString:
 *      A pointer to a string containing the exceptionLabel, or NULL.
 *    
 *    errorString:
 *      A pointer to the error string, or NULL. DEBUG_ASSERT_MESSAGE macros
 *      must not attempt to concatenate this string with constant
 *      character strings.
 *    
 *    fileName:
 *      A pointer to the fileName or pathname (generated by the
 *      preprocessor __FILE__ identifier), or NULL.
 *    
 *    lineNumber:
 *      The line number in the file (generated by the preprocessor
 *      __LINE__ identifier), or 0 (zero).
 *    
 *    errorCode:
 *      A value associated with the assertion, or 0.
 *
 *  Here is an example of a DEBUG_ASSERT_MESSAGE macro and a routine which displays
 *  assertion messsages:
 *
 *      #define DEBUG_ASSERT_COMPONENT_NAME_STRING "MyCoolProgram"
 *
 *      #define DEBUG_ASSERT_MESSAGE(componentNameString, assertionString,                           \
 *                                   exceptionLabelString, errorString, fileName, lineNumber, errorCode) \
 *              MyProgramDebugAssert(componentNameString, assertionString,                           \
 *                                   exceptionLabelString, errorString, fileName, lineNumber, errorCode)
 *
 *      static void
 *      MyProgramDebugAssert(const char *componentNameString, const char *assertionString, 
 *                           const char *exceptionLabelString, const char *errorString, 
 *                           const char *fileName, long lineNumber, int errorCode)
 *      {
 *          if ( (assertionString != NULL) && (*assertionString != '\0') )
 *              fprintf(stderr, "Assertion failed: %s: %s\n", componentNameString, assertionString);
 *          else
 *              fprintf(stderr, "Check failed: %s:\n", componentNameString);
 *          if ( exceptionLabelString != NULL )
 *              fprintf(stderr, "    %s\n", exceptionLabelString);
 *          if ( errorString != NULL )
 *              fprintf(stderr, "    %s\n", errorString);
 *          if ( fileName != NULL )
 *              fprintf(stderr, "    file: %s\n", fileName);
 *          if ( lineNumber != 0 )
 *              fprintf(stderr, "    line: %ld\n", lineNumber);
 *          if ( errorCode != 0 )
 *              fprintf(stderr, "    error: %d\n", errorCode);
 *      }
 *
 *  If you do not define DEBUG_ASSERT_MESSAGE, a simple printf to stderr will be used.
 */
#ifndef DEBUG_ASSERT_MESSAGE
#include <TargetConditionals.h>
   #ifdef KERNEL
      #include <libkern/libkern.h>
      #define DEBUG_ASSERT_MESSAGE(name, assertion, label, message, file, line, value) \
                                  printf( "AssertMacros: %s, %s file: %s, line: %d, value: %ld\n", assertion, (message!=0) ? message : "", file, line, (long) (value));
   #elif TARGET_OS_DRIVERKIT
      #include <os/log.h>
      #define DEBUG_ASSERT_MESSAGE(name, assertion, label, message, file, line, value) \
                                  os_log(OS_LOG_DEFAULT, "AssertMacros: %s, %s file: %s, line: %d, value: %ld\n", assertion, (message!=0) ? message : "", file, line, (long) (value));
   #else
      #include <stdio.h>
      #define DEBUG_ASSERT_MESSAGE(name, assertion, label, message, file, line, value) \
                                  fprintf(stderr, "AssertMacros: %s, %s file: %s, line: %d, value: %ld\n", assertion, (message!=0) ? message : "", file, line, (long) (value));
   #endif
#endif





/*
 *  __Debug_String(message)
 *
 *  Summary:
 *    Production builds: does nothing and produces no code.
 *
 *    Non-production builds: call DEBUG_ASSERT_MESSAGE.
 *
 *  Parameters:
 *
 *    message:
 *      The C string to display.
 *
 */
#ifndef __Debug_String
	#if DEBUG_ASSERT_PRODUCTION_CODE
	   #define __Debug_String(message)
	#else
	   #define __Debug_String(message)                                             \
		  do                                                                      \
		  {                                                                       \
			  DEBUG_ASSERT_MESSAGE(                                               \
				  DEBUG_ASSERT_COMPONENT_NAME_STRING,                             \
				  "",                                                             \
				  0,                                                              \
				  message,                                                        \
				  __FILE__,                                                       \
				  __LINE__,                                                       \
				  0);                                                             \
		  } while ( 0 )
	#endif
#endif

/*
 *  __Check(assertion)
 *
 *  Summary:
 *    Production builds: does nothing and produces no code.
 *
 *    Non-production builds: if the assertion expression evaluates to false,
 *    call DEBUG_ASSERT_MESSAGE.
 *
 *  Parameters:
 *
 *    assertion:
 *      The assertion expression.
 */
#ifndef __Check
	#if DEBUG_ASSERT_PRODUCTION_CODE
	   #define __Check(assertion)
	#else
	   #define __Check(assertion)                                                 \
		  do                                                                      \
		  {                                                                       \
			  if ( __builtin_expect(!(assertion), 0) )                            \
			  {                                                                   \
				  DEBUG_ASSERT_MESSAGE(                                           \
					  DEBUG_ASSERT_COMPONENT_NAME_STRING,                         \
					  #assertion, 0, 0, __FILE__, __LINE__, 0 );                  \
			  }                                                                   \
		  } while ( 0 )
	#endif
#endif

#ifndef __nCheck
	#define __nCheck(assertion)  __Check(!(assertion))
#endif

/*
 *  __Check_String(assertion, message)
 *
 *  Summary:
 *    Production builds: does nothing and produces no code.
 *
 *    Non-production builds: if the assertion expression evaluates to false,
 *    call DEBUG_ASSERT_MESSAGE.
 *
 *  Parameters:
 *
 *    assertion:
 *      The assertion expression.
 *
 *    message:
 *      The C string to display.
 */
#ifndef __Check_String
	#if DEBUG_ASSERT_PRODUCTION_CODE
	   #define __Check_String(assertion, message)
	#else
	   #define __Check_String(assertion, message)                                 \
		  do                                                                      \
		  {                                                                       \
			  if ( __builtin_expect(!(assertion), 0) )                            \
			  {                                                                   \
				  DEBUG_ASSERT_MESSAGE(                                           \
					  DEBUG_ASSERT_COMPONENT_NAME_STRING,                         \
					  #assertion, 0, message, __FILE__, __LINE__, 0 );            \
			  }                                                                   \
		  } while ( 0 )
	#endif
#endif

#ifndef __nCheck_String
	#define __nCheck_String(assertion, message)  __Check_String(!(assertion), message)
#endif

/*
 *  __Check_noErr(errorCode)
 *
 *  Summary:
 *    Production builds: does nothing and produces no code.
 *
 *    Non-production builds: if the errorCode expression does not equal 0 (noErr),
 *    call DEBUG_ASSERT_MESSAGE.
 *
 *  Parameters:
 *
 *    errorCode:
 *      The errorCode expression to compare with 0.
 */
#ifndef __Check_noErr
	#if DEBUG_ASSERT_PRODUCTION_CODE
	   #define __Check_noErr(errorCode)
	#else
	   #define __Check_noErr(errorCode)                                           \
		  do                                                                      \
		  {                                                                       \
			  long evalOnceErrorCode = (errorCode);                               \
			  if ( __builtin_expect(0 != evalOnceErrorCode, 0) )                  \
			  {                                                                   \
				  DEBUG_ASSERT_MESSAGE(                                           \
					  DEBUG_ASSERT_COMPONENT_NAME_STRING,                         \
					  #errorCode " == 0 ", 0, 0, __FILE__, __LINE__, evalOnceErrorCode ); \
			  }                                                                   \
		  } while ( 0 )
	#endif
#endif

/*
 *  __Check_noErr_String(errorCode, message)
 *
 *  Summary:
 *    Production builds: check_noerr_string() does nothing and produces
 *    no code.
 *
 *    Non-production builds: if the errorCode expression does not equal 0 (noErr),
 *    call DEBUG_ASSERT_MESSAGE.
 *
 *  Parameters:
 *
 *    errorCode:
 *      The errorCode expression to compare to 0.
 *
 *    message:
 *      The C string to display.
 */
#ifndef __Check_noErr_String
	#if DEBUG_ASSERT_PRODUCTION_CODE
	   #define __Check_noErr_String(errorCode, message)
	#else
	   #define __Check_noErr_String(errorCode, message)                           \
		  do                                                                      \
		  {                                                                       \
			  long evalOnceErrorCode = (errorCode);                               \
			  if ( __builtin_expect(0 != evalOnceErrorCode, 0) )                  \
			  {                                                                   \
				  DEBUG_ASSERT_MESSAGE(                                           \
					  DEBUG_ASSERT_COMPONENT_NAME_STRING,                         \
					  #errorCode " == 0 ", 0, message, __FILE__, __LINE__, evalOnceErrorCode ); \
			  }                                                                   \
		  } while ( 0 )
	#endif
#endif

/*
 *  __Verify(assertion)
 *
 *  Summary:
 *    Production builds: evaluate the assertion expression, but ignore
 *    the result.
 *
 *    Non-production builds: if the assertion expression evaluates to false,
 *    call DEBUG_ASSERT_MESSAGE.
 *
 *  Parameters:
 *
 *    assertion:
 *      The assertion expression.
 */
#ifndef __Verify
	#if DEBUG_ASSERT_PRODUCTION_CODE
	   #define __Verify(assertion)                                                \
		  do                                                                      \
		  {                                                                       \
			  if ( !(assertion) )                                                 \
			  {                                                                   \
			  }                                                                   \
		  } while ( 0 )
	#else
	   #define __Verify(assertion)                                                \
		  do                                                                      \
		  {                                                                       \
			  if ( __builtin_expect(!(assertion), 0) )                            \
			  {                                                                   \
				  DEBUG_ASSERT_MESSAGE(                                           \
					  DEBUG_ASSERT_COMPONENT_NAME_STRING,                         \
					  #assertion, 0, 0, __FILE__, __LINE__, 0 );                  \
			  }                                                                   \
		  } while ( 0 )
	#endif
#endif

#ifndef __nVerify
	#define __nVerify(assertion)	__Verify(!(assertion))
#endif

/*
 *  __Verify_String(assertion, message)
 *
 *  Summary:
 *    Production builds: evaluate the assertion expression, but ignore
 *    the result.
 *
 *    Non-production builds: if the assertion expression evaluates to false,
 *    call DEBUG_ASSERT_MESSAGE.
 *
 *  Parameters:
 *
 *    assertion:
 *      The assertion expression.
 *
 *    message:
 *      The C string to display.
 */
#ifndef __Verify_String
	#if DEBUG_ASSERT_PRODUCTION_CODE
	   #define __Verify_String(assertion, message)                                \
		  do                                                                      \
		  {                                                                       \
			  if ( !(assertion) )                                                 \
			  {                                                                   \
			  }                                                                   \
		  } while ( 0 )
	#else
	   #define __Verify_String(assertion, message)                                \
		  do                                                                      \
		  {                                                                       \
			  if ( __builtin_expect(!(assertion), 0) )                            \
			  {                                                                   \
				  DEBUG_ASSERT_MESSAGE(                                           \
					  DEBUG_ASSERT_COMPONENT_NAME_STRING,                         \
					  #assertion, 0, message, __FILE__, __LINE__, 0 );            \
			  }                                                                   \
		  } while ( 0 )
	#endif
#endif

#ifndef __nVerify_String
	#define __nVerify_String(assertion, message)  __Verify_String(!(assertion), message)
#endif

/*
 *  __Verify_noErr(errorCode)
 *
 *  Summary:
 *    Production builds: evaluate the errorCode expression, but ignore
 *    the result.
 *
 *    Non-production builds: if the errorCode expression does not equal 0 (noErr),
 *    call DEBUG_ASSERT_MESSAGE.
 *
 *  Parameters:
 *
 *    errorCode:
 *      The expression to compare to 0.
 */
#ifndef __Verify_noErr
	#if DEBUG_ASSERT_PRODUCTION_CODE
	   #define __Verify_noErr(errorCode)                                          \
		  do                                                                      \
		  {                                                                       \
			  if ( 0 != (errorCode) )                                             \
			  {                                                                   \
			  }                                                                   \
		  } while ( 0 )
	#else
	   #define __Verify_noErr(errorCode)                                          \
		  do                                                                      \
		  {                                                                       \
			  long evalOnceErrorCode = (errorCode);                               \
			  if ( __builtin_expect(0 != evalOnceErrorCode, 0) )                  \
			  {                                                                   \
				  DEBUG_ASSERT_MESSAGE(                                           \
					  DEBUG_ASSERT_COMPONENT_NAME_STRING,                         \
					  #errorCode " == 0 ", 0, 0, __FILE__, __LINE__, evalOnceErrorCode ); \
			  }                                                                   \
		  } while ( 0 )
	#endif
#endif

/*
 *  __Verify_noErr_String(errorCode, message)
 *
 *  Summary:
 *    Production builds: evaluate the errorCode expression, but ignore
 *    the result.
 *
 *    Non-production builds: if the errorCode expression does not equal 0 (noErr),
 *    call DEBUG_ASSERT_MESSAGE.
 *
 *  Parameters:
 *
 *    errorCode:
 *      The expression to compare to 0.
 *
 *    message:
 *      The C string to display.
 */
#ifndef __Verify_noErr_String
	#if DEBUG_ASSERT_PRODUCTION_CODE
	   #define __Verify_noErr_String(errorCode, message)                          \
		  do                                                                      \
		  {                                                                       \
			  if ( 0 != (errorCode) )                                             \
			  {                                                                   \
			  }                                                                   \
		  } while ( 0 )
	#else
	   #define __Verify_noErr_String(errorCode, message)                          \
		  do                                                                      \
		  {                                                                       \
			  long evalOnceErrorCode = (errorCode);                               \
			  if ( __builtin_expect(0 != evalOnceErrorCode, 0) )                  \
			  {                                                                   \
				  DEBUG_ASSERT_MESSAGE(                                           \
					  DEBUG_ASSERT_COMPONENT_NAME_STRING,                         \
					  #errorCode " == 0 ", 0, message, __FILE__, __LINE__, evalOnceErrorCode ); \
			  }                                                                   \
		  } while ( 0 )
	#endif
#endif

/*
 *  __Verify_noErr_Action(errorCode, action)
 *
 *  Summary:
 *    Production builds: if the errorCode expression does not equal 0 (noErr),
 *    execute the action statement or compound statement (block).
 *
 *    Non-production builds: if the errorCode expression does not equal 0 (noErr),
 *    call DEBUG_ASSERT_MESSAGE and then execute the action statement or compound
 *    statement (block).
 *
 *  Parameters:
 *
 *    errorCode:
 *      The expression to compare to 0.
 *
 *    action:
 *      The statement or compound statement (block).
 */
#ifndef __Verify_noErr_Action
	#if DEBUG_ASSERT_PRODUCTION_CODE
	   #define __Verify_noErr_Action(errorCode, action)                          \
		  if ( 0 != (errorCode) ) {                                              \
			  action;                                                            \
		  }                                                                      \
		  else do {} while (0)
	#else
	   #define __Verify_noErr_Action(errorCode, action)                          \
               do {                                                                   \
		  long evalOnceErrorCode = (errorCode);                                  \
		  if ( __builtin_expect(0 != evalOnceErrorCode, 0) ) {                   \
			  DEBUG_ASSERT_MESSAGE(                                              \
				  DEBUG_ASSERT_COMPONENT_NAME_STRING,                            \
				  #errorCode " == 0 ", 0, 0, __FILE__, __LINE__, evalOnceErrorCode );            \
			  action;                                                            \
		  }                                                                      \
	       } while (0)
	#endif
#endif

/*
 *  __Verify_Action(assertion, action)
 *
 *  Summary:
 *    Production builds: if the assertion expression evaluates to false,
 *    then execute the action statement or compound statement (block).
 *
 *    Non-production builds: if the assertion expression evaluates to false,
 *    call DEBUG_ASSERT_MESSAGE and then execute the action statement or compound
 *    statement (block).
 *
 *  Parameters:
 *
 *    assertion:
 *      The assertion expression.
 *
 *    action:
 *      The statement or compound statement (block).
 */
#ifndef __Verify_Action
	#if DEBUG_ASSERT_PRODUCTION_CODE
	   #define __Verify_Action(assertion, action)                                \
		  if ( __builtin_expect(!(assertion), 0) ) {                             \
			action;                                                              \
		  }                                                                      \
		  else do {} while (0)
	#else
	   #define __Verify_Action(assertion, action)                                \
		  if ( __builtin_expect(!(assertion), 0) ) {                             \
			  DEBUG_ASSERT_MESSAGE(                                              \
					  DEBUG_ASSERT_COMPONENT_NAME_STRING,                        \
					  #assertion, 0, 0, __FILE__, __LINE__, 0 );                 \
			  action;                                                            \
		  }                                                                      \
		  else do {} while (0)
	#endif
#endif

/*
 *  __Require(assertion, exceptionLabel)
 *
 *  Summary:
 *    Production builds: if the assertion expression evaluates to false,
 *    goto exceptionLabel.
 *
 *    Non-production builds: if the assertion expression evaluates to false,
 *    call DEBUG_ASSERT_MESSAGE and then goto exceptionLabel.
 *
 *  Parameters:
 *
 *    assertion:
 *      The assertion expression.
 *
 *    exceptionLabel:
 *      The label.
 */
#ifndef __Require
	#if DEBUG_ASSERT_PRODUCTION_CODE
	   #define __Require(assertion, exceptionLabel)                               \
		  do                                                                      \
		  {                                                                       \
			  if ( __builtin_expect(!(assertion), 0) )                            \
			  {                                                                   \
				  goto exceptionLabel;                                            \
			  }                                                                   \
		  } while ( 0 )
	#else
	   #define __Require(assertion, exceptionLabel)                               \
		  do                                                                      \
		  {                                                                       \
			  if ( __builtin_expect(!(assertion), 0) ) {                          \
				  DEBUG_ASSERT_MESSAGE(                                           \
					  DEBUG_ASSERT_COMPONENT_NAME_STRING,                         \
					  #assertion, #exceptionLabel, 0, __FILE__, __LINE__,  0);    \
				  goto exceptionLabel;                                            \
			  }                                                                   \
		  } while ( 0 )
	#endif
#endif

#ifndef __nRequire
	#define __nRequire(assertion, exceptionLabel)  __Require(!(assertion), exceptionLabel)
#endif

/*
 *  __Require_Action(assertion, exceptionLabel, action)
 *
 *  Summary:
 *    Production builds: if the assertion expression evaluates to false,
 *    execute the action statement or compound statement (block) and then
 *    goto exceptionLabel.
 *
 *    Non-production builds: if the assertion expression evaluates to false,
 *    call DEBUG_ASSERT_MESSAGE, execute the action statement or compound
 *    statement (block), and then goto exceptionLabel.
 *
 *  Parameters:
 *
 *    assertion:
 *      The assertion expression.
 *
 *    exceptionLabel:
 *      The label.
 *
 *    action:
 *      The statement or compound statement (block).
 */
#ifndef __Require_Action
	#if DEBUG_ASSERT_PRODUCTION_CODE
	   #define __Require_Action(assertion, exceptionLabel, action)                \
		  do                                                                      \
		  {                                                                       \
			  if ( __builtin_expect(!(assertion), 0) )                            \
			  {                                                                   \
				  {                                                               \
					  action;                                                     \
				  }                                                               \
				  goto exceptionLabel;                                            \
			  }                                                                   \
		  } while ( 0 )
	#else
	   #define __Require_Action(assertion, exceptionLabel, action)                \
		  do                                                                      \
		  {                                                                       \
			  if ( __builtin_expect(!(assertion), 0) )                            \
			  {                                                                   \
				  DEBUG_ASSERT_MESSAGE(                                           \
					  DEBUG_ASSERT_COMPONENT_NAME_STRING,                         \
					  #assertion, #exceptionLabel, 0,   __FILE__, __LINE__, 0);   \
				  {                                                               \
					  action;                                                     \
				  }                                                               \
				  goto exceptionLabel;                                            \
			  }                                                                   \
		  } while ( 0 )
	#endif
#endif

#ifndef __nRequire_Action
	#define __nRequire_Action(assertion, exceptionLabel, action)                  \
	__Require_Action(!(assertion), exceptionLabel, action)
#endif

/*
 *  __Require_Quiet(assertion, exceptionLabel)
 *
 *  Summary:
 *    If the assertion expression evaluates to false, goto exceptionLabel.
 *
 *  Parameters:
 *
 *    assertion:
 *      The assertion expression.
 *
 *    exceptionLabel:
 *      The label.
 */
#ifndef __Require_Quiet
	#define __Require_Quiet(assertion, exceptionLabel)                            \
	  do                                                                          \
	  {                                                                           \
		  if ( __builtin_expect(!(assertion), 0) )                                \
		  {                                                                       \
			  goto exceptionLabel;                                                \
		  }                                                                       \
	  } while ( 0 )
#endif

#ifndef __nRequire_Quiet
	#define __nRequire_Quiet(assertion, exceptionLabel)  __Require_Quiet(!(assertion), exceptionLabel)
#endif

/*
 *  __Require_Action_Quiet(assertion, exceptionLabel, action)
 *
 *  Summary:
 *    If the assertion expression evaluates to false, execute the action
 *    statement or compound statement (block), and goto exceptionLabel.
 *
 *  Parameters:
 *
 *    assertion:
 *      The assertion expression.
 *
 *    exceptionLabel:
 *      The label.
 *
 *    action:
 *      The statement or compound statement (block).
 */
#ifndef __Require_Action_Quiet
	#define __Require_Action_Quiet(assertion, exceptionLabel, action)             \
	  do                                                                          \
	  {                                                                           \
		  if ( __builtin_expect(!(assertion), 0) )                                \
		  {                                                                       \
			  {                                                                   \
				  action;                                                         \
			  }                                                                   \
			  goto exceptionLabel;                                                \
		  }                                                                       \
	  } while ( 0 )
#endif

#ifndef __nRequire_Action_Quiet
	#define __nRequire_Action_Quiet(assertion, exceptionLabel, action)              \
		__Require_Action_Quiet(!(assertion), exceptionLabel, action)
#endif

/*
 *  __Require_String(assertion, exceptionLabel, message)
 *
 *  Summary:
 *    Production builds: if the assertion expression evaluates to false,
 *    goto exceptionLabel.
 *
 *    Non-production builds: if the assertion expression evaluates to false,
 *    call DEBUG_ASSERT_MESSAGE, and then goto exceptionLabel.
 *
 *  Parameters:
 *
 *    assertion:
 *      The assertion expression.
 *
 *    exceptionLabel:
 *      The label.
 *
 *    message:
 *      The C string to display.
 */
#ifndef __Require_String
	#if DEBUG_ASSERT_PRODUCTION_CODE
	   #define __Require_String(assertion, exceptionLabel, message)               \
		  do                                                                      \
		  {                                                                       \
			  if ( __builtin_expect(!(assertion), 0) )                            \
			  {                                                                   \
				  goto exceptionLabel;                                            \
			  }                                                                   \
		  } while ( 0 )
	#else
	   #define __Require_String(assertion, exceptionLabel, message)               \
		  do                                                                      \
		  {                                                                       \
			  if ( __builtin_expect(!(assertion), 0) )                            \
			  {                                                                   \
				  DEBUG_ASSERT_MESSAGE(                                           \
					  DEBUG_ASSERT_COMPONENT_NAME_STRING,                         \
					  #assertion, #exceptionLabel,  message,  __FILE__, __LINE__, 0); \
				  goto exceptionLabel;                                            \
			  }                                                                   \
		  } while ( 0 )
	#endif
#endif

#ifndef __nRequire_String
	#define __nRequire_String(assertion, exceptionLabel, string)                  \
		__Require_String(!(assertion), exceptionLabel, string)
#endif

/*
 *  __Require_Action_String(assertion, exceptionLabel, action, message)
 *
 *  Summary:
 *    Production builds: if the assertion expression evaluates to false,
 *    execute the action statement or compound statement (block), and then
 *    goto exceptionLabel.
 *
 *    Non-production builds: if the assertion expression evaluates to false,
 *    call DEBUG_ASSERT_MESSAGE, execute the action statement or compound
 *    statement (block), and then goto exceptionLabel.
 *
 *  Parameters:
 *
 *    assertion:
 *      The assertion expression.
 *
 *    exceptionLabel:
 *      The label.
 *
 *    action:
 *      The statement or compound statement (block).
 *
 *    message:
 *      The C string to display.
 */
#ifndef __Require_Action_String
	#if DEBUG_ASSERT_PRODUCTION_CODE
	   #define __Require_Action_String(assertion, exceptionLabel, action, message)  \
		  do                                                                      \
		  {                                                                       \
			  if ( __builtin_expect(!(assertion), 0) )                            \
			  {                                                                   \
				  {                                                               \
					  action;                                                     \
				  }                                                               \
				  goto exceptionLabel;                                            \
			  }                                                                   \
		  } while ( 0 )
	#else
	   #define __Require_Action_String(assertion, exceptionLabel, action, message)  \
		  do                                                                      \
		  {                                                                       \
			  if ( __builtin_expect(!(assertion), 0) )                            \
			  {                                                                   \
				  DEBUG_ASSERT_MESSAGE(                                           \
					  DEBUG_ASSERT_COMPONENT_NAME_STRING,                         \
					  #assertion, #exceptionLabel,  message,  __FILE__,  __LINE__, 0); \
				  {                                                               \
					  action;                                                     \
				  }                                                               \
				  goto exceptionLabel;                                            \
			  }                                                                   \
		  } while ( 0 )
	#endif
#endif

#ifndef __nRequire_Action_String
	#define __nRequire_Action_String(assertion, exceptionLabel, action, message)    \
		__Require_Action_String(!(assertion), exceptionLabel, action, message)
#endif

/*
 *  __Require_noErr(errorCode, exceptionLabel)
 *
 *  Summary:
 *    Production builds: if the errorCode expression does not equal 0 (noErr),
 *    goto exceptionLabel.
 *
 *    Non-production builds: if the errorCode expression does not equal 0 (noErr),
 *    call DEBUG_ASSERT_MESSAGE and then goto exceptionLabel.
 *
 *  Parameters:
 *
 *    errorCode:
 *      The expression to compare to 0.
 *
 *    exceptionLabel:
 *      The label.
 */
#ifndef __Require_noErr
	#if DEBUG_ASSERT_PRODUCTION_CODE
	   #define __Require_noErr(errorCode, exceptionLabel)                         \
		  do                                                                      \
		  {                                                                       \
			  if ( __builtin_expect(0 != (errorCode), 0) )                        \
			  {                                                                   \
				  goto exceptionLabel;                                            \
			  }                                                                   \
		  } while ( 0 )
	#else
	   #define __Require_noErr(errorCode, exceptionLabel)                         \
		  do                                                                      \
		  {                                                                       \
			  long evalOnceErrorCode = (errorCode);                               \
			  if ( __builtin_expect(0 != evalOnceErrorCode, 0) )                  \
			  {                                                                   \
				  DEBUG_ASSERT_MESSAGE(                                           \
					  DEBUG_ASSERT_COMPONENT_NAME_STRING,                         \
					  #errorCode " == 0 ",  #exceptionLabel,  0,  __FILE__, __LINE__, evalOnceErrorCode); \
				  goto exceptionLabel;                                            \
			  }                                                                   \
		  } while ( 0 )
	#endif
#endif

/*
 *  __Require_noErr_Action(errorCode, exceptionLabel, action)
 *
 *  Summary:
 *    Production builds: if the errorCode expression does not equal 0 (noErr),
 *    execute the action statement or compound statement (block) and
 *    goto exceptionLabel.
 *
 *    Non-production builds: if the errorCode expression does not equal 0 (noErr),
 *    call DEBUG_ASSERT_MESSAGE, execute the action statement or
 *    compound statement (block), and then goto exceptionLabel.
 *
 *  Parameters:
 *
 *    errorCode:
 *      The expression to compare to 0.
 *
 *    exceptionLabel:
 *      The label.
 *
 *    action:
 *      The statement or compound statement (block).
 */
#ifndef __Require_noErr_Action
	#if DEBUG_ASSERT_PRODUCTION_CODE
	   #define __Require_noErr_Action(errorCode, exceptionLabel, action)          \
		  do                                                                      \
		  {                                                                       \
			  if ( __builtin_expect(0 != (errorCode), 0) )                        \
			  {                                                                   \
				  {                                                               \
					  action;                                                     \
				  }                                                               \
				  goto exceptionLabel;                                            \
			  }                                                                   \
		  } while ( 0 )
	#else
	   #define __Require_noErr_Action(errorCode, exceptionLabel, action)          \
		  do                                                                      \
		  {                                                                       \
			  long evalOnceErrorCode = (errorCode);                               \
			  if ( __builtin_expect(0 != evalOnceErrorCode, 0) )                  \
			  {                                                                   \
				  DEBUG_ASSERT_MESSAGE(                                           \
					  DEBUG_ASSERT_COMPONENT_NAME_STRING,                         \
					  #errorCode " == 0 ", #exceptionLabel,  0,  __FILE__, __LINE__,  evalOnceErrorCode); \
				  {                                                               \
					  action;                                                     \
				  }                                                               \
				  goto exceptionLabel;                                            \
			  }                                                                   \
		  } while ( 0 )
	#endif
#endif

/*
 *  __Require_noErr_Quiet(errorCode, exceptionLabel)
 *
 *  Summary:
 *    If the errorCode expression does not equal 0 (noErr),
 *    goto exceptionLabel.
 *
 *  Parameters:
 *
 *    errorCode:
 *      The expression to compare to 0.
 *
 *    exceptionLabel:
 *      The label.
 */
#ifndef __Require_noErr_Quiet
	#define __Require_noErr_Quiet(errorCode, exceptionLabel)                      \
	  do                                                                          \
	  {                                                                           \
		  if ( __builtin_expect(0 != (errorCode), 0) )                            \
		  {                                                                       \
			  goto exceptionLabel;                                                \
		  }                                                                       \
	  } while ( 0 )
#endif

/*
 *  __Require_noErr_Action_Quiet(errorCode, exceptionLabel, action)
 *
 *  Summary:
 *    If the errorCode expression does not equal 0 (noErr),
 *    execute the action statement or compound statement (block) and
 *    goto exceptionLabel.
 *
 *  Parameters:
 *
 *    errorCode:
 *      The expression to compare to 0.
 *
 *    exceptionLabel:
 *      The label.
 *
 *    action:
 *      The statement or compound statement (block).
 */
#ifndef __Require_noErr_Action_Quiet
	#define __Require_noErr_Action_Quiet(errorCode, exceptionLabel, action)       \
	  do                                                                          \
	  {                                                                           \
		  if ( __builtin_expect(0 != (errorCode), 0) )                            \
		  {                                                                       \
			  {                                                                   \
				  action;                                                         \
			  }                                                                   \
			  goto exceptionLabel;                                                \
		  }                                                                       \
	  } while ( 0 )
#endif

/*
 *  __Require_noErr_String(errorCode, exceptionLabel, message)
 *
 *  Summary:
 *    Production builds: if the errorCode expression does not equal 0 (noErr),
 *    goto exceptionLabel.
 *
 *    Non-production builds: if the errorCode expression does not equal 0 (noErr),
 *    call DEBUG_ASSERT_MESSAGE, and then goto exceptionLabel.
 *
 *  Parameters:
 *
 *    errorCode:
 *      The expression to compare to 0.
 *
 *    exceptionLabel:
 *      The label.
 *
 *    message:
 *      The C string to display.
 */
#ifndef __Require_noErr_String
	#if DEBUG_ASSERT_PRODUCTION_CODE
	   #define __Require_noErr_String(errorCode, exceptionLabel, message)         \
		  do                                                                      \
		  {                                                                       \
			  if ( __builtin_expect(0 != (errorCode), 0) )                        \
			  {                                                                   \
				  goto exceptionLabel;                                            \
			  }                                                                   \
		  } while ( 0 )
	#else
	   #define __Require_noErr_String(errorCode, exceptionLabel, message)         \
		  do                                                                      \
		  {                                                                       \
			  long evalOnceErrorCode = (errorCode);                               \
			  if ( __builtin_expect(0 != evalOnceErrorCode, 0) )                  \
			  {                                                                   \
				  DEBUG_ASSERT_MESSAGE(                                           \
					  DEBUG_ASSERT_COMPONENT_NAME_STRING,                         \
					  #errorCode " == 0 ",  #exceptionLabel, message, __FILE__,  __LINE__,  evalOnceErrorCode); \
				  goto exceptionLabel;                                            \
			  }                                                                   \
		  } while ( 0 )
	#endif
#endif

/*
 *  __Require_noErr_Action_String(errorCode, exceptionLabel, action, message)
 *
 *  Summary:
 *    Production builds: if the errorCode expression does not equal 0 (noErr),
 *    execute the action statement or compound statement (block) and
 *    goto exceptionLabel.
 *
 *    Non-production builds: if the errorCode expression does not equal 0 (noErr),
 *    call DEBUG_ASSERT_MESSAGE, execute the action statement or compound
 *    statement (block), and then goto exceptionLabel.
 *
 *  Parameters:
 *
 *    errorCode:
 *      The expression to compare to 0.
 *
 *    exceptionLabel:
 *      The label.
 *
 *    action:
 *      The statement or compound statement (block).
 *
 *    message:
 *      The C string to display.
 */
#ifndef __Require_noErr_Action_String
	#if DEBUG_ASSERT_PRODUCTION_CODE
	   #define __Require_noErr_Action_String(errorCode, exceptionLabel, action, message) \
		  do                                                                      \
		  {                                                                       \
			  if ( __builtin_expect(0 != (errorCode), 0) )                        \
			  {                                                                   \
				  {                                                               \
					  action;                                                     \
				  }                                                               \
				  goto exceptionLabel;                                            \
			  }                                                                   \
		  } while ( 0 )
	#else
	   #define __Require_noErr_Action_String(errorCode, exceptionLabel, action, message) \
		  do                                                                      \
		  {                                                                       \
			  long evalOnceErrorCode = (errorCode);                               \
			  if ( __builtin_expect(0 != evalOnceErrorCode, 0) )                  \
			  {                                                                   \
				  DEBUG_ASSERT_MESSAGE(                                           \
					  DEBUG_ASSERT_COMPONENT_NAME_STRING,                         \
					  #errorCode " == 0 ", #exceptionLabel, message, __FILE__, __LINE__, evalOnceErrorCode); \
				  {                                                               \
					  action;                                                     \
				  }                                                               \
				  goto exceptionLabel;                                            \
			  }                                                                   \
		  } while ( 0 )
	#endif
#endif

/*
 *  __Check_Compile_Time(expr)
 *
 *  Summary:
 *    any build: if the expression is not true, generated a compile time error.
 *
 *  Parameters:
 *
 *    expr:
 *      The compile time expression that should evaluate to non-zero.
 *
 *  Discussion:
 *     This declares an array with a size that is determined by a compile-time expression.
 *     If false, it declares a negatively sized array, which generates a compile-time error.
 *
 * Examples:
 *     __Check_Compile_Time( sizeof( int ) == 4 );
 *     __Check_Compile_Time( offsetof( MyStruct, myField ) == 4 );
 *     __Check_Compile_Time( ( kMyBufferSize % 512 ) == 0 );
 *
 *  Note: This only works with compile-time expressions.
 *  Note: This only works in places where extern declarations are allowed (e.g. global scope).
 */
#ifndef __Check_Compile_Time
    #ifdef __GNUC__ 
     #if (__cplusplus >= 201103L)
        #define __Check_Compile_Time( expr )    static_assert( expr , "__Check_Compile_Time")        
     #elif (__STDC_VERSION__ >= 201112L)
        #define __Check_Compile_Time( expr )    _Static_assert( expr , "__Check_Compile_Time")
     #else
        #define __Check_Compile_Time( expr )    \
            extern int compile_time_assert_failed[ ( expr ) ? 1 : -1 ] __attribute__( ( unused ) )
     #endif
    #else
        #define __Check_Compile_Time( expr )    \
            extern int compile_time_assert_failed[ ( expr ) ? 1 : -1 ]
    #endif
#endif

/*
 *	For time immemorial, Mac OS X has defined version of most of these macros without the __ prefix, which
 *	could collide with similarly named functions or macros in user code, including new functionality in
 *	Boost and the C++ standard library.
 *
 *  macOS High Sierra and iOS 11 will now require that clients move to the new macros as defined above.
 *
 *  If you would like to enable the macros for use within your own project, you can define the
 *  __ASSERT_MACROS_DEFINE_VERSIONS_WITHOUT_UNDERSCORES macro via an Xcode Build Configuration.
 *  See "Add a build configuration (xcconfig) file" in Xcode Help. 
 *
 *  To aid users of these macros in converting their sources, the following tops script will convert usages
 *  of the old macros into the new equivalents.  To do so, in Terminal go into the directory containing the
 *  sources to be converted and run this command.
 *
    find -E . -regex '.*\.(c|cc|cp|cpp|m|mm|h)' -print0 |  xargs -0 tops -verbose \
      replace "check(<b args>)" with "__Check(<args>)" \
      replace "check_noerr(<b args>)" with "__Check_noErr(<args>)" \
      replace "check_noerr_string(<b args>)" with "__Check_noErr_String(<args>)" \
      replace "check_string(<b args>)" with "__Check_String(<args>)" \
      replace "require(<b args>)" with "__Require(<args>)" \
      replace "require_action(<b args>)" with "__Require_Action(<args>)" \
      replace "require_action_string(<b args>)" with "__Require_Action_String(<args>)" \
      replace "require_noerr(<b args>)" with "__Require_noErr(<args>)" \
      replace "require_noerr_action(<b args>)" with "__Require_noErr_Action(<args>)" \
      replace "require_noerr_action_string(<b args>)" with "__Require_noErr_Action_String(<args>)" \
      replace "require_noerr_string(<b args>)" with "__Require_noErr_String(<args>)" \
      replace "require_string(<b args>)" with "__Require_String(<args>)" \
      replace "verify(<b args>)" with "__Verify(<args>)" \
      replace "verify_action(<b args>)" with "__Verify_Action(<args>)" \
      replace "verify_noerr(<b args>)" with "__Verify_noErr(<args>)" \
      replace "verify_noerr_action(<b args>)" with "__Verify_noErr_Action(<args>)" \
      replace "verify_noerr_string(<b args>)" with "__Verify_noErr_String(<args>)" \
      replace "verify_string(<b args>)" with "__Verify_String(<args>)" \
      replace "ncheck(<b args>)" with "__nCheck(<args>)" \
      replace "ncheck_string(<b args>)" with "__nCheck_String(<args>)" \
      replace "nrequire(<b args>)" with "__nRequire(<args>)" \
      replace "nrequire_action(<b args>)" with "__nRequire_Action(<args>)" \
      replace "nrequire_action_quiet(<b args>)" with "__nRequire_Action_Quiet(<args>)" \
      replace "nrequire_action_string(<b args>)" with "__nRequire_Action_String(<args>)" \
      replace "nrequire_quiet(<b args>)" with "__nRequire_Quiet(<args>)" \
      replace "nrequire_string(<b args>)" with "__nRequire_String(<args>)" \
      replace "nverify(<b args>)" with "__nVerify(<args>)" \
      replace "nverify_string(<b args>)" with "__nVerify_String(<args>)" \
      replace "require_action_quiet(<b args>)" with "__Require_Action_Quiet(<args>)" \
      replace "require_noerr_action_quiet(<b args>)" with "__Require_noErr_Action_Quiet(<args>)" \
      replace "require_noerr_quiet(<b args>)" with "__Require_noErr_Quiet(<args>)" \
      replace "require_quiet(<b args>)" with "__Require_Quiet(<args>)" \
      replace "check_compile_time(<b args>)" with "__Check_Compile_Time(<args>)" \
      replace "debug_string(<b args>)" with "__Debug_String(<args>)"
 *
 */

#ifndef __ASSERT_MACROS_DEFINE_VERSIONS_WITHOUT_UNDERSCORES
    #if __has_include(<AssertMacrosInternal.h>)
        #include <AssertMacrosInternal.h>
    #else 
        /* In  macOS High Sierra and iOS 11, if we haven't set this yet, it now defaults to off. */
        #define	__ASSERT_MACROS_DEFINE_VERSIONS_WITHOUT_UNDERSCORES	0
    #endif
#endif

#if	__ASSERT_MACROS_DEFINE_VERSIONS_WITHOUT_UNDERSCORES

	#ifndef check
	#define check(assertion)  __Check(assertion)
	#endif

	#ifndef check_noerr
	#define check_noerr(errorCode)  __Check_noErr(errorCode)
	#endif

	#ifndef check_noerr_string
		#define check_noerr_string(errorCode, message)  __Check_noErr_String(errorCode, message)
	#endif

	#ifndef check_string
		#define check_string(assertion, message)  __Check_String(assertion, message)
	#endif

	#ifndef require
		#define require(assertion, exceptionLabel)  __Require(assertion, exceptionLabel)
	#endif

	#ifndef require_action
		#define require_action(assertion, exceptionLabel, action)  __Require_Action(assertion, exceptionLabel, action)
	#endif

	#ifndef require_action_string
		#define require_action_string(assertion, exceptionLabel, action, message)  __Require_Action_String(assertion, exceptionLabel, action, message)
	#endif

	#ifndef require_noerr
		#define require_noerr(errorCode, exceptionLabel)  __Require_noErr(errorCode, exceptionLabel)
	#endif

	#ifndef require_noerr_action
		#define require_noerr_action(errorCode, exceptionLabel, action)  __Require_noErr_Action(errorCode, exceptionLabel, action)
	#endif

	#ifndef require_noerr_action_string
		#define require_noerr_action_string(errorCode, exceptionLabel, action, message)  __Require_noErr_Action_String(errorCode, exceptionLabel, action, message)
	#endif

	#ifndef require_noerr_string
		#define require_noerr_string(errorCode, exceptionLabel, message)  __Require_noErr_String(errorCode, exceptionLabel, message)
	#endif

	#ifndef require_string
		#define require_string(assertion, exceptionLabel, message)  __Require_String(assertion, exceptionLabel, message)
	#endif

	#ifndef verify
		#define verify(assertion) __Verify(assertion)
	#endif

	#ifndef verify_action
		#define verify_action(assertion, action)  __Verify_Action(assertion, action)
	#endif

	#ifndef verify_noerr
		#define verify_noerr(errorCode)  __Verify_noErr(errorCode)
	#endif

	#ifndef verify_noerr_action
		#define verify_noerr_action(errorCode, action)  __Verify_noErr_Action(errorCode, action)
	#endif

	#ifndef verify_noerr_string
		#define verify_noerr_string(errorCode, message)  __Verify_noErr_String(errorCode, message)
	#endif

	#ifndef verify_string
		#define verify_string(assertion, message)  __Verify_String(assertion, message)
	#endif

	#ifndef ncheck
		#define ncheck(assertion)  __nCheck(assertion)
	#endif

	#ifndef ncheck_string
		#define ncheck_string(assertion, message)  __nCheck_String(assertion, message)
	#endif

	#ifndef nrequire
		#define nrequire(assertion, exceptionLabel)  __nRequire(assertion, exceptionLabel)
	#endif

	#ifndef nrequire_action
		#define nrequire_action(assertion, exceptionLabel, action)  __nRequire_Action(assertion, exceptionLabel, action)
	#endif

	#ifndef nrequire_action_quiet
		#define nrequire_action_quiet(assertion, exceptionLabel, action)  __nRequire_Action_Quiet(assertion, exceptionLabel, action)
	#endif

	#ifndef nrequire_action_string
		#define nrequire_action_string(assertion, exceptionLabel, action, message)  __nRequire_Action_String(assertion, exceptionLabel, action, message)
	#endif

	#ifndef nrequire_quiet
		#define nrequire_quiet(assertion, exceptionLabel)  __nRequire_Quiet(assertion, exceptionLabel)
	#endif

	#ifndef nrequire_string
		#define nrequire_string(assertion, exceptionLabel, string)  __nRequire_String(assertion, exceptionLabel, string)
	#endif

	#ifndef nverify
		#define nverify(assertion)  __nVerify(assertion)
	#endif

	#ifndef nverify_string
		#define nverify_string(assertion, message)  __nVerify_String(assertion, message)
	#endif

	#ifndef require_action_quiet
		#define require_action_quiet(assertion, exceptionLabel, action)  __Require_Action_Quiet(assertion, exceptionLabel, action)
	#endif

	#ifndef require_noerr_action_quiet
		#define require_noerr_action_quiet(errorCode, exceptionLabel, action)  __Require_noErr_Action_Quiet(errorCode, exceptionLabel, action)
	#endif

	#ifndef require_noerr_quiet
		#define require_noerr_quiet(errorCode, exceptionLabel)  __Require_noErr_Quiet(errorCode, exceptionLabel)
	#endif

	#ifndef require_quiet
		#define require_quiet(assertion, exceptionLabel)  __Require_Quiet(assertion, exceptionLabel)
	#endif

	#ifndef check_compile_time
		#define check_compile_time( expr )  __Check_Compile_Time( expr )
	#endif

	#ifndef debug_string
		#define debug_string(message)  __Debug_String(message)
	#endif
	
#endif	/* ASSERT_MACROS_DEFINE_VERSIONS_WITHOUT_UNDERSCORES */


#endif /* __ASSERTMACROS__ */
