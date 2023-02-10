/*
 * Copyright (c) 2008-2020 Apple Inc. All rights reserved.
 *
 * @APPLE_APACHE_LICENSE_HEADER_START@
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * @APPLE_APACHE_LICENSE_HEADER_END@
 */

#ifndef __OS_BASE__
#define __OS_BASE__

#include <sys/cdefs.h>


#ifndef __has_builtin
#define __has_builtin(x) 0
#endif
#ifndef __has_include
#define __has_include(x) 0
#endif
#ifndef __has_feature
#define __has_feature(x) 0
#endif
#ifndef __has_attribute
#define __has_attribute(x) 0
#endif
#ifndef __has_extension
#define __has_extension(x) 0
#endif

#undef OS_INLINE // <sys/_types/_os_inline.h>
#if __GNUC__
#define OS_NORETURN __attribute__((__noreturn__))
#define OS_NOTHROW __attribute__((__nothrow__))
#define OS_NONNULL1 __attribute__((__nonnull__(1)))
#define OS_NONNULL2 __attribute__((__nonnull__(2)))
#define OS_NONNULL3 __attribute__((__nonnull__(3)))
#define OS_NONNULL4 __attribute__((__nonnull__(4)))
#define OS_NONNULL5 __attribute__((__nonnull__(5)))
#define OS_NONNULL6 __attribute__((__nonnull__(6)))
#define OS_NONNULL7 __attribute__((__nonnull__(7)))
#define OS_NONNULL8 __attribute__((__nonnull__(8)))
#define OS_NONNULL9 __attribute__((__nonnull__(9)))
#define OS_NONNULL10 __attribute__((__nonnull__(10)))
#define OS_NONNULL11 __attribute__((__nonnull__(11)))
#define OS_NONNULL12 __attribute__((__nonnull__(12)))
#define OS_NONNULL13 __attribute__((__nonnull__(13)))
#define OS_NONNULL14 __attribute__((__nonnull__(14)))
#define OS_NONNULL15 __attribute__((__nonnull__(15)))
#define OS_NONNULL_ALL __attribute__((__nonnull__))
#define OS_SENTINEL __attribute__((__sentinel__))
#define OS_PURE __attribute__((__pure__))
#define OS_CONST __attribute__((__const__))
#define OS_WARN_RESULT __attribute__((__warn_unused_result__))
#define OS_MALLOC __attribute__((__malloc__))
#define OS_USED __attribute__((__used__))
#define OS_UNUSED __attribute__((__unused__))
#define OS_COLD __attribute__((__cold__))
#define OS_WEAK __attribute__((__weak__))
#define OS_WEAK_IMPORT __attribute__((__weak_import__))
#define OS_NOINLINE __attribute__((__noinline__))
#define OS_ALWAYS_INLINE __attribute__((__always_inline__))
#define OS_TRANSPARENT_UNION __attribute__((__transparent_union__))
#define OS_ALIGNED(n) __attribute__((__aligned__((n))))
#define OS_FORMAT_PRINTF(x, y) __attribute__((__format__(printf,x,y)))
#define OS_EXPORT extern __attribute__((__visibility__("default")))
#define OS_INLINE static __inline__
#define OS_EXPECT(x, v) __builtin_expect((x), (v))
#else
#define OS_NORETURN
#define OS_NOTHROW
#define OS_NONNULL1
#define OS_NONNULL2
#define OS_NONNULL3
#define OS_NONNULL4
#define OS_NONNULL5
#define OS_NONNULL6
#define OS_NONNULL7
#define OS_NONNULL8
#define OS_NONNULL9
#define OS_NONNULL10
#define OS_NONNULL11
#define OS_NONNULL12
#define OS_NONNULL13
#define OS_NONNULL14
#define OS_NONNULL15
#define OS_NONNULL_ALL
#define OS_SENTINEL
#define OS_PURE
#define OS_CONST
#define OS_WARN_RESULT
#define OS_MALLOC
#define OS_USED
#define OS_UNUSED
#define OS_COLD
#define OS_WEAK
#define OS_WEAK_IMPORT
#define OS_NOINLINE
#define OS_ALWAYS_INLINE
#define OS_TRANSPARENT_UNION
#define OS_ALIGNED(n)
#define OS_FORMAT_PRINTF(x, y)
#define OS_EXPORT extern
#define OS_INLINE static inline
#define OS_EXPECT(x, v) (x)
#endif

#if __has_attribute(noescape)
#define OS_NOESCAPE __attribute__((__noescape__))
#else
#define OS_NOESCAPE
#endif

#if defined(__cplusplus) && defined(__clang__)
#define OS_FALLTHROUGH [[clang::fallthrough]]
#elif __has_attribute(fallthrough)
#define OS_FALLTHROUGH __attribute__((__fallthrough__))
#else
#define OS_FALLTHROUGH
#endif

#if __has_feature(assume_nonnull)
#define OS_ASSUME_NONNULL_BEGIN _Pragma("clang assume_nonnull begin")
#define OS_ASSUME_NONNULL_END   _Pragma("clang assume_nonnull end")
#else
#define OS_ASSUME_NONNULL_BEGIN
#define OS_ASSUME_NONNULL_END
#endif

#if __has_builtin(__builtin_assume)
#define OS_COMPILER_CAN_ASSUME(expr) __builtin_assume(expr)
#else
#define OS_COMPILER_CAN_ASSUME(expr) ((void)(expr))
#endif

#if __has_extension(attribute_overloadable)
#define OS_OVERLOADABLE __attribute__((__overloadable__))
#else
#define OS_OVERLOADABLE
#endif

#if __has_attribute(analyzer_suppress)
#define OS_ANALYZER_SUPPRESS(RADAR) __attribute__((analyzer_suppress))
#else
#define OS_ANALYZER_SUPPRESS(RADAR)
#endif

#if __has_attribute(enum_extensibility)
#define __OS_ENUM_ATTR __attribute__((enum_extensibility(open)))
#define __OS_ENUM_ATTR_CLOSED __attribute__((enum_extensibility(closed)))
#else
#define __OS_ENUM_ATTR
#define __OS_ENUM_ATTR_CLOSED
#endif // __has_attribute(enum_extensibility)

#if __has_attribute(flag_enum)
/*!
 * Compile with -Wflag-enum and -Wassign-enum to enforce at definition and
 * assignment, respectively, i.e. -Wflag-enum prevents you from creating new
 * enumeration values from illegal values within the enum definition, and
 * -Wassign-enum prevents you from assigning illegal values to a variable of the
 * enum type.
 */
#define __OS_OPTIONS_ATTR __attribute__((flag_enum))
#else
#define __OS_OPTIONS_ATTR
#endif // __has_attribute(flag_enum)

#if __has_feature(objc_fixed_enum) || __has_extension(cxx_fixed_enum) || \
        __has_extension(cxx_strong_enums)
#define OS_ENUM(_name, _type, ...) \
	typedef enum : _type { __VA_ARGS__ } _name##_t
#define OS_CLOSED_ENUM(_name, _type, ...) \
	typedef enum : _type { __VA_ARGS__ } __OS_ENUM_ATTR_CLOSED _name##_t
#define OS_OPTIONS(_name, _type, ...) \
	typedef enum : _type { __VA_ARGS__ } __OS_ENUM_ATTR __OS_OPTIONS_ATTR _name##_t
#define OS_CLOSED_OPTIONS(_name, _type, ...) \
	typedef enum : _type { __VA_ARGS__ } __OS_ENUM_ATTR_CLOSED __OS_OPTIONS_ATTR _name##_t
#else
/*!
 * There is unfortunately no good way in plain C to have both fixed-type enums
 * and enforcement for clang's enum_extensibility extensions. The primary goal
 * of these macros is to allow you to define an enum and specify its width in a
 * single statement, and for plain C that is accomplished by defining an
 * anonymous enum and then separately typedef'ing the requested type name to the
 * requested underlying integer type. So the type emitted actually has no
 * relationship at all to the enum, and therefore while the compiler could
 * enforce enum extensibility if you used the enum type, it cannot do so if you
 * use the "_t" type resulting from this expression.
 *
 * But we still define a named enum type and decorate it appropriately for you,
 * so if you really want the enum extensibility enforcement, you can use the
 * enum type yourself, i.e. when compiling with a C compiler:
 *
 *     OS_CLOSED_ENUM(my_type, uint64_t,
 *         FOO,
 *         BAR,
 *         BAZ,
 *     );
 *
 *     my_type_t mt = 98; // legal
 *     enum my_type emt = 98; // illegal
 *
 * But be aware that the underlying enum type's width is subject only to the C
 * language's guarantees -- namely that it will be compatible with int, char,
 * and unsigned char. It is not safe to rely on the size of this type.
 *
 * When compiling in ObjC or C++, both of the above assignments are illegal.
 */
#define __OS_ENUM_C_FALLBACK(_name, _type, ...) \
	typedef _type _name##_t; enum _name { __VA_ARGS__ }

#define OS_ENUM(_name, _type, ...) \
	typedef _type _name##_t; enum { __VA_ARGS__ }
#define OS_CLOSED_ENUM(_name, _type, ...) \
	__OS_ENUM_C_FALLBACK(_name, _type, ## __VA_ARGS__) \
	__OS_ENUM_ATTR_CLOSED
#define OS_OPTIONS(_name, _type, ...) \
	__OS_ENUM_C_FALLBACK(_name, _type, ## __VA_ARGS__) \
	__OS_ENUM_ATTR __OS_OPTIONS_ATTR
#define OS_CLOSED_OPTIONS(_name, _type, ...) \
	__OS_ENUM_C_FALLBACK(_name, _type, ## __VA_ARGS__) \
	__OS_ENUM_ATTR_CLOSED __OS_OPTIONS_ATTR
#endif // __has_feature(objc_fixed_enum) || __has_extension(cxx_strong_enums)

#if __has_feature(attribute_availability_swift)
// equivalent to __SWIFT_UNAVAILABLE from Availability.h
#define OS_SWIFT_UNAVAILABLE(_msg) \
	__attribute__((__availability__(swift, unavailable, message=_msg)))
#else
#define OS_SWIFT_UNAVAILABLE(_msg)
#endif

#if __has_attribute(swift_private)
# define OS_REFINED_FOR_SWIFT __attribute__((__swift_private__))
#else
# define OS_REFINED_FOR_SWIFT
#endif

#if __has_attribute(swift_name)
# define OS_SWIFT_NAME(_name) __attribute__((__swift_name__(#_name)))
#else
# define OS_SWIFT_NAME(_name)
#endif

#define __OS_STRINGIFY(s) #s
#define OS_STRINGIFY(s) __OS_STRINGIFY(s)
#define __OS_CONCAT(x, y) x ## y
#define OS_CONCAT(x, y) __OS_CONCAT(x, y)

#ifdef __GNUC__
#define os_prevent_tail_call_optimization()  __asm__("")
#define os_is_compile_time_constant(expr)    __builtin_constant_p(expr)
#define os_compiler_barrier()                __asm__ __volatile__("" ::: "memory")
#else
#define os_prevent_tail_call_optimization()  do { } while (0)
#define os_is_compile_time_constant(expr)    0
#define os_compiler_barrier()                do { } while (0)
#endif

#if __has_attribute(not_tail_called)
#define OS_NOT_TAIL_CALLED __attribute__((__not_tail_called__))
#else
#define OS_NOT_TAIL_CALLED
#endif


typedef void (*os_function_t)(void *_Nullable);

#ifdef __BLOCKS__
/*!
 * @typedef os_block_t
 *
 * @abstract
 * Generic type for a block taking no arguments and returning no value.
 *
 * @discussion
 * When not building with Objective-C ARC, a block object allocated on or
 * copied to the heap must be released with a -[release] message or the
 * Block_release() function.
 *
 * The declaration of a block literal allocates storage on the stack.
 * Therefore, this is an invalid construct:
 * <code>
 * os_block_t block;
 * if (x) {
 *     block = ^{ printf("true\n"); };
 * } else {
 *     block = ^{ printf("false\n"); };
 * }
 * block(); // unsafe!!!
 * </code>
 *
 * What is happening behind the scenes:
 * <code>
 * if (x) {
 *     struct Block __tmp_1 = ...; // setup details
 *     block = &__tmp_1;
 * } else {
 *     struct Block __tmp_2 = ...; // setup details
 *     block = &__tmp_2;
 * }
 * </code>
 *
 * As the example demonstrates, the address of a stack variable is escaping the
 * scope in which it is allocated. That is a classic C bug.
 *
 * Instead, the block literal must be copied to the heap with the Block_copy()
 * function or by sending it a -[copy] message.
 */
typedef void (^os_block_t)(void);
#endif



#endif // __OS_BASE__