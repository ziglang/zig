/*
 * Copyright (c) 2000-2022 Apple Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */

#ifndef __CONSTRAINED_CTYPES__
#define __CONSTRAINED_CTYPES__

#include <sys/cdefs.h>

/*
 * Constraining pointer types based on contracts.
 *
 * 1. List of supported constrained pointers.
 *
 * 1.1. `Reference' pointers.
 *
 *      The `reference' pointers point to a single entity. The pointer
 *      arithmetics are not supported for the `reference' pointers.
 *
 *      The `reference' pointers are fully ABI compatible with
 *      the unconstrained C pointers.
 *
 *      The naming convention for the `reference' pointers uses
 *      the `ref' constraint tag. See `Naming conventions' below for furhter
 *      discussion.
 *
 *      Examples:
 *
 *      (1) `socket_ref_t' is `reference' pointer to `struct socket'.
 *      (2) `uint32_ref_t' is `reference' pointer to `uint32_t'.
 *
 *
 * 1.2. `Checked' pointers.
 *
 *      The `checked' pointers represent contigous data arrays, which
 *      can be traversed only in the direction of increasing memory addresses.
 *      The pointer arithmetics are partially supported: decrements (p--, --p)
 *      are disallowed.
 *
 *      The `checked' pointers are not ABI-compatible with plain C pointers,
 *      due to the boundary checks instrumentation. See `ABI
 *      Compatibility Considerations' below for further discussion.
 *
 *      The naming convention for the `checked' pointers uses the `ptr'
 *      constraint tag. See `Naming conventions' below for furhter discussion.
 *
 *      Examples:
 *
 *      (1) `socket_ptr_t' is `checked' pointer to `struct socket'.
 *      (2) `uint32_ptr_t' is `checked' pointer to `uint32_t'.
 *
 *
 * 1.3. `Bidirectional' pointers.
 *
 *      The `bidirectional' pointers represent contigous data arrays,
 *      which can be traversed in both directions. The pointer arithmetics are
 *      fully supported for the `array' pointers.
 *
 *      The `bidirectional' pointers are not ABI-compatible with plain C
 *      pointers, due to the boundary checks instrumentation. Additionally,
 *      passing `bidirectional' pointers to functions require the use of stack.
 *      See `ABI Compatibility Considerations' below for further discussion.
 *
 *      The naming convention for the `bidirectional' pointers uses
 *      the `bptr' constraint tag. See `Naming conventions' below for furhter
 *      discussion.
 *
 *      Examples:
 *
 *      (1) `socket_bptr_t' is `bidirectional' pointer to `struct socket'.
 *      (2) `uint32_bptr_t' is `bidirectional' pointer to `uint32_t'.
 *
 *
 * 1.4. Multidimensional constrained pointers.
 *
 *      Constraining multidimensional pointers is achieved by iteratively
 *      applying the constraints from the innermost type to the outermost type.
 *
 *      Pointer arithmetics are supported for the dimensions that
 *      are not constrained to a `reference' or `const reference'.
 *
 *      If any of the dimension constraints isn't ABI-compatible with its
 *      unconstrained counterpart, then the entire constrained multidimensional
 *      pointer is not ABI-compatible with the corresponding unconstrained
 *      multidimensional pointer. Otherwise, the two are ABI-compatible. See
 *      `ABI compatibility' below for further discussion.
 *
 *      The naming convention for the multidimensional constrained pointers
 *      combines the naming tags that correspond to the individual constraints.
 *      See `Naming conventions' below for furhter discussion.
 *
 *      Examples:
 *
 *      (1) `socket_ref_bptr_t' is a `bidirectional' pointer to a `reference'
 *          pointer to `struct socket'.
 *      (2) `socket_ptr_ref_t' is a `reference' pointer to a `checked'
 *          pointer to `struct socket'.
 *
 *
 * 1.5. Using `const', `volatile', and `restrict' type qualifiers with
 *      constrained types.
 *
 *      The use of the `const', `volatile', and `restrict' type qualifiers
 *      (a.k.a. "CRV qualifiers") follows the syntax of the C language.
 *
 *      As a special case, if a `const' qualifier is applied to inner
 *      dimensions of a multidimensional constrained pointer type, the
 *      constraint tag is prepended with letter `c'; thus `cref' can be used
 *      for const-qualified `reference' pointer. This abbreviation is only
 *      supported for the `const' qualifier, as use of `volatile' or `restrict'
 *      for inner constrained types is quite uncommon. See `Multidimensional
 *      constrained pointers' above and `Naming conventions' below for further
 *      discussion.
 *
 *      Examples:
 *
 *      (1) `socket_ref_t const' is the const-qualified `reference' pointer
 *          to `struct socket'.
 *      (2) `socket_ptr_t volatile' is the volatile-qualified `checked' pointer
 *          to `struct socket'.
 *      (3) `socket_ptr_ref_t const' is a const-qualified `reference' pointer
 *          to a `checked' pointer to `struct socket'.
 *      (4) `socket_cref_ptr_t const' is a `checked' pointer to a
 *          const-qualified `reference' pointer to `struct socket'.
 *
 *
 * 1.6. Combining constrained pointers and unconstrained pointers.
 *
 *      Unconstrained pointers to constrained pointers follow
 *      the standard C syntax. Defining constrained pointers to
 *      unconstrained pointers is possible via defining a constrained pointer
 *      to a typedef.
 *
 *      Examples:
 *
 *      (1) `socket_ref_t *' is an unconstrained pointer to `socket_ref_t', i.e.
 *          unconstrained pointer to a `reference' pointer to `struct socket'.
 *      (2) `socket_ref_t const *' is an unconstrained pointer to `socket_ref_t const',
 *          i.e. an unconstrained pointer to a const-qualified `reference'
 *          pointer to `struct socket'.
 *      (3) `socket_ref_t * const' is a const-qualified unconstrained pointer to
 *          `socket_ref_t', i.e. a const-qualified unconstrained pointer to a
 *          `reference' pointer to `struct socket'.
 *      (4) `intptr_ref_t' is a `reference' pointer to `intptr_t', i.e.
 *          a `reference' pointer to an unconstrained pointer to `int'. Note
 *          the use of `intptr_t' typedef, which is necessary at the moment.
 *
 *
 * 2. Defining constrained pointer types.
 *
 * 2.1. Declaring multiple constrained types simultaneously.
 *
 *      `__CCT_DECLARE_CONSTRAINED_PTR_TYPES(basetype, basetag)`
 *      is the suggested way to declare constrained pointer types.
 *
 *      Parameters:
 *
 *      `basetype`: the pointee type, including `struct' or `enum' keywords.
 *      `basetag`:  the prefix of the constrained type.
 *
 *      This macro acts differently in the user-space and the kernel-space
 *      code.
 *      When used in the user-space code, the macro will declare
 *      types which are ABI-safe. See `ABI Compatibility Considerations'
 *      below for more details on ABI-safety. In the user-space code,
 *      the macro is guarded by the `__CCT_ENABLE_USER_SPACE' compilation
 *      flag.
 *      When used in the kernel-space code, the macro will declare
 *      the common constrained types.
 *
 *      Examples:
 *
 *      (1) When used from the user space, and `__CCT_ENABLE_USER_SPACE'
 *          is defined, the expression
 *          `__CCT_DECLARE_CONSTRAINED_PTR_TYPES(struct socket, socket);'
 *           will declare types:
 *
 *          (a) `socket_ref_t': the `reference' to `struct socket'
 *          (b) `socket_ref_ref_t': the `reference to reference'
 *              to `struct socket'.
 *
 *      (2) When used from the kernel space,
 *          `__CCT_DECLARE_CONSTRAINED_PTR_TYPES(struct socket, socket);'
 *           will declare the above types, plus:
 *
 *          (c) `socket_ptr_t': `checked' pointer to `struct socket'.
 *          (d) `socket_bptr_t': `bidirectional' pointer to `struct socket'.
 *          (e) `socket_ref_ptr_t': `checked' pointer to a `reference'
 *              to `struct socket'.
 *          (f) `socket_ptr_ref_t': `reference' to a `checked' pointer
 *              to `struct socket'.
 *
 *      These additional types are not ABI-safe, and therefore are not exposed
 *      to the user space. See `ABI Compatibility Considerations' below.
 *
 *
 * 2.2. Declaring individual constrained types.
 *
 *      The above macro attempts to do many things at once, and under some
 *      circumstances can be not appropriate. For these circumstances, a
 *      finer-graned declarator can be used:
 *
 *      `__CCT_DECLARE_CONSTRAINED_PTR_TYPE(basetype, basetag, ...)'
 *
 *      Parameters:
 *
 *      `basetype`: the pointee type.
 *      `basetag`:  the prefix of the constrained type.
 *      `...`:      list of constraints:
 *                  - `__CCT_REF' for the "reference" contract;
 *                  - `__CCT_CREF' for the "const reference" contract;
 *                  - `__CCT_PTR' for the "checked pointer" contract; or
 *                  - `__CCT_BPTR' for the "bidirectional pointer" contract.
 *
 *      Examples:
 *
 *      (1) `__CCT_DECLARE_CONSTRAINED_PTR_TYPE(struct socket, socket, __CCT_REF)'
 *          will declare the type
 *              `reference' pointer to `struct socket'
 *          and call this type by `socket_ref_t'
 *
 *      (2) `__CCT_DECLARE_CONSTRAINED_PTR_TYPE(struct socket, socket, __CCT_REF, __CCT_PTR)'
 *          will declare the type
 *              `checked' pointer to `socket_ref_t'
 *          which in turn is equivalent to the type
 *              `checked' pointer to `reference' pointer to `struct socket'
 *
 *      (3) `__CCT_DECLARE_CONSTRAINED_PTR_TYPE(struct socket, socket, __CCT_REF, __CCT_PTR, __CCT_REF)'
 *          will declare the type
 *              `reference' pointer to `socket_ref_ptr_t'
 *          which is equivalent to the type
 *              `reference' pointer to `checked' pointer to `socket_ref_t'
 *          which in turn is equivalent to the type
 *              `reference' pointer to `checked' pointer to `reference' pointer to `struct socket'
 *
 *
 * 3. Using constrained pointer types.
 *
 * 3.1. Using constrained pointers for local variables.
 *
 *      Constraining the pointers on the stack reduces the risk of stack
 *      overflow. Therefore, it is highly suggested to use the constrained
 *      versions of the pointers for stack parameters. For local array
 *      variables, opt for the `bidirectional' pointers. If only a single value
 *      needs to be pointed, opt for the `reference' pointers.
 *
 *      There are two alternative approaches for using the `reference' pointers.
 *      One approach is to explicitly use `thing_ref_t ptr` instead of `thing *ptr`.
 *      The other approach is to surround the code with the directives
 *      `__ASSUME_PTR_ABI_SINGLE_BEGIN' and `__ASSUME_PTR_ABI_SINGLE_END', which
 *      will have the effect of turning every unconstrained pointer to its
 *      `reference' counterpart.
 *
 *
 * 3.2. Using constrained pointers for function parameters
 *
 * 3.2.1. Use `reference' pointers for scalar parameters.
 *
 *      Scalar parameters are safe to use across ABI boundaries.
 *
 *      Examples:
 *
 *      (1) Using `reference' pointers for scalar input:
 *
 *      errno_t thing_is_valid(const thing_ref_t t)
 *      {
 *              return t == NULL ? EINVAL : 0;
 *      }
 *
 *
 *      (2) Using `reference' pointers for scalar output, which is
 *          allocated by the caller:
 *
 *      errno_t thing_copy(const thing_ref_t src, thing_ref_t dst)
 *      {
 *              if (src == NULL || dst == NULL) {
 *                      return EINVAL;
 *              }
 *              bcopy(src, dst);
 *              return 0;
 *      }
 *
 *      (3) Using `reference to reference' for scalar output that is
 *          allocated by the callee:
 *
 *      errno_t thing_dup(const thing_ref_t src, thing_ref_ref_t dst)
 *      {
 *              *dst = malloc(sizeof(*dst));
 *              bcopy(src, *dst, sizeof(*src));
 *              return 0;
 *      }
 *
 *
 * 3.2.2. Use `checked' pointers for vector parameters.
 *
 *      When the ABI isn't a concern, use of `checked' pointers
 *      increases the code readability.
 *
 *      See `ABI Compatibility Considerations' below for vector parameters when
 *      ABI is a concern.
 *
 *      Examples:
 *
 *      (1) Using `checked' pointers for vector input:
 *
 *      errno_t thing_find_best(const thing_ref_ptr_t things,
 *                              thing_ref_ref_t best, size_t count)
 *      {
 *              for (int i = 0; i < count; i++) {
 *                      if (thing_is_the_best(things[i])) {
 *                              *best = things[i];
 *                              return 0;
 *                      }
 *              }
 *              return ENOENT; // no best thing
 *      }
 *
 *      (2) Using `checked' pointers for vector output parameters that
 *          are allocated by caller:
 *
 *      errno_t thing_copy_things(thing_ref_ptr_t src, thing_ref_ptr_t dst,
 *                                size_t count)
 *      {
 *              for (int i = 0; i < count; i++) {
 *                      dst[i] = malloc(sizeof(*dst[i]));
 *                      bcopy(src[i], dst[i], sizeof(*src[i]));
 *              }
 *              return 0;
 *      }
 *
 *      (3) Using `reference to checked' pointers for vector output
 *      parameters that are allocated by callee:
 *
 *      errno_t thing_dup_things(thing_ref_ptr_t src, thing_ref_ptr_ref_t dst,
 *                               size_t count)
 *      {
 *              *dst = malloc(sizeof(**src) * count);
 *              return thing_copy_things(src, *dst, count);
 *      }
 *
 *
 * 3.3. Using constrained pointers in struct definitions
 *
 *      Examples:
 *
 *      (1) Using a structure that points to array of things:
 *
 *      struct things_crate {
 *              size_t       tc_count;
 *              thing_bptr_t tc_things;
 *      };
 *
 *
 * 3.4. Variable-size structures
 *
 *      Constrained pointer instrumentation depends on knowing the size of the
 *      structures. If the structure contains a variable array, the array needs
 *      to be annotated by `__sized_by' or `__counted_by' attribute:
 *
 *      Example:
 *
 *      struct sockaddr {
 *              __uint8_t       sa_len;
 *              sa_family_t     sa_family;
 *              char            sa_data[__counted_by(sa_len - 2)];
 *      };
 *
 *
 * 4. ABI Compatibility Considerations
 *
 *      The pointer instrumentation process has ABI implications.
 *
 *      When the pointer insrumentation is enabled, the size of `bidirectional'
 *      and `checked' pointers exceeds the size of the machine word.
 *
 *      Thus, if there is a concern that the instrumentation is enabled only in
 *      some compilation units that use the function, these constrained
 *      pointers can not be used for function parameters.
 *
 *      Instead, one should rely on `__counted_by(count)' or `__sized_by(size)'
 *      attributes. These attributes accept as a parameter the name of a
 *      variable that contains the cont of items, or the byte size, of the
 *      pointed-to array. Use of these attributes does not change the size of
 *      the pointer.
 *
 *      The tradeoff is between maintaining code readabilty and ABI compatibility.
 *
 *      A common pattern is to split the function into the implementation,
 *      which is statically linked and therefore is ABI-safe, and the interface
 *      wrapper, which uses `__counted_by' or `__sized_by' to preserve ABI
 *      compatibility.
 *
 *
 * 4.1. When ABI is a concern, replace `bidirectional' and `checked'
 *        with  `__counted_by(count)` and `__sized_by(size)` for vector
 *        parameters.
 *
 *
 *      Examples:
 *
 *      (1) Using `const thing_ref_t __counted_by(count)' instead of `const
 *          thing_ref_ptr_t' for vector input in a wrapper:
 *
 *      errno_t thing_find_best_compat(const thing_ref_t __counted_by(count)things,
 *                                     thing_ref_ref_t best, size_t count)
 *      {
 *              // __counted_by implicitly upgraded to `checked'
 *              return thing_find_best(things, best, count);
 *      }
 *
 *      (2) Using `thing_ref_t __counted_by(count)' instead of `thing_ref_ptr_t'
 *          for vector output in a wrapper.
 *
 *      errno_t thing_copy_things_compat(thing_ref_t __counted_by(count)src,
 *                                       things_ref_t __counted_by(count)dst,
 *                                       size_t count)
 *      {
 *              // __counted_by implicitly upgraded to `checked'
 *              return thing_copy_things(src, dst, count);
 *      }
 *
 *
 * 4.2. When ABI is a concern, use `__counted_by(count)' and
 *        `__sized_by(size)' for struct members that point to arrays.
 *
 *      Examples:
 *
 *      (1) Using a structure that points to array of things:
 *
 *      struct things_crate {
 *              size_t                               tc_count;
 *              struct thing * __counted_by(tc_count)tc_things;
 *      };
 *
 * 5. Naming conventions
 *
 *      If `typename' is the name of a C type, and `tag' is a constraint tag
 *      (one of `ref', `ptr', or `bptr'), then the name of a pointer to
 *      `typename' constrained by `tag' is `basetag_tag_t', where `basename'
 *      is defined by:
 *
 *      (a) If `typename' is a name of an integral type, then `basetag' is same
 *          as `typename'.
 *      (b) If `typename' is a name of a function type, then `basetag' is same
 *          as `typename'.
 *      (c) If `typename' is a name of a structure, then `basetag' is formed by
 *          stripping the `struct' keyword from `typename'.
 *      (d) If `typename' is a name of an enumeration, then `basetag' is formed
 *          by stripping the `enum' keyword from `typename'.
 *      (e) If `typename' is a name of a typedef to a struct or an enum that ends
 *          with `_t', then `basetag' is formed by stripping the `_t' suffix
 *          from `typename'. See (h) below for when `typename' is a pointer typedef.
 *      (f) If `typename' is a name of constrained pointer type ending with `_t',
 *          then `basetag' is formed by stripping the `_t' suffix from `typename'.
 *
 *      Additionally, constrained pointers to constrained const pointers are a
 *      special case:
 *
 *      (g) If `typename' is a name of a constrained pointer type, ending with
 *          `_{innertag}_t', and `typename' has `const' qualifier, then `basetag'
 *          is formed by replacing `_{innertag}_t' with `_c{innertag}'
 *
 *      Finally, sometimes `name_t' represents not `struct name' but `struct name *'.
 *      This creates additional special case:
 *
 *      (h) If `typename' is a pointer typedef named `{struct}_t`, such as
 *          `mbuf_t',  then creating a constrained pointer to a `typename' would
 *           require creating a  constrained pointer to an unconstrained pointer,
 *           which is not supported at the moment. Instead, a constrained pointer to
 *           `typeof(*typename)` must be created first, and constrained again. Using
 *           the `mbuf_t` example, first one should create a constrained pointer to
 *           `struct mbuf`, e.g, `mbuf_bptr_t`, and then constrain it again with
 *           `tag`, leading to `mbuf_bptr_ref_t'.
 *
 *      Examples:
 *
 *      (1) `int_ref_t' is a `reference pointer' to `int', following the rule (a) above.
 *      (2) `so_pru_ref_t' is a `reference pointer' to function `so_pru',
 *          following the rule (b) above.
 *      (3) `socket_ref_t' is a `reference pointer' to `struct socket',
 *          following the rule (c) above.
 *      (4) `classq_pkt_type_ref_t' is a `reference pointer' to `enum classq_pkt_type'
 *          following the rule (d) above.
 *      (5) `classq_pkt_type_ref_t' is a also `reference pointer' to `classq_pkt_type_t'
 *          following the rule (e) above.
 *      (6) `socket_ref_ref_t' is a `reference pointer' to `socket_ref_t`,
 *          following the rule (f) above.
 *      (7) `socket_cref_ref_t' is a `reference pointer' to `socket_ref_t const`,
 *          following the rule (g) above.
 *      (8) `mbuf_ref_ref_t', is a `reference pointer' to `mbuf_ref_t`, and is one
 *          possible result of creating a `reference pointer' to `mbuf_t',
 *          following the rule (h) above.
 *      (9) `mbuf_bptr_ref_t', is a `reference pointer' to `mbuf_bptr_t`, and
 *          is another possible result of creating a `reference pointer' to
 *          `mbuf_t', following the rule (h) above.
 *
 */

/*
 * Constraint contract constants.
 *
 * At the moment only clang (when compiled with `ptrcheck' feature) supports
 * pointer tagging via `__single', `__indexable' and `__bidi_indexable' attributes.
 *
 * During the transitional period, the `__indexable__' and `__bidi_indexable'
 * constraints will decay to raw pointers if the `ptrcheck' feature is not enabled.
 * Once the transitional period is over, the `__CCT_CONTRACT_ATTR_{B}PTR' constraints
 * will stop decaying to raw pointers when built by sufficiently recent version
 * of clang.
 *
 * Support for other compilers will be added after the introduction of support
 * for pointer tagging on those compilers.
 */
#if defined(KERNEL) || defined(__CCT_ENABLE_USER_SPACE)
#if defined(__clang__)
#define __CCT_CONTRACT_ATTR___CCT_REF         __single
#define __CCT_CONTRACT_ATTR___CCT_CREF        const __single
#if  __has_ptrcheck
#define __CCT_CONTRACT_ATTR___CCT_BPTR        __bidi_indexable
#define __CCT_CONTRACT_ATTR___CCT_PTR         __indexable
#else /* __clang__ + __has_ptrcheck */
#define __CCT_CONTRACT_ATTR___CCT_BPTR
#define __CCT_CONTRACT_ATTR___CCT_PTR
#endif /* __clang__ + !__has_ptrcheck */
#else /* !__clang__ */
#define __CCT_CONTRACT_ATTR___CCT_REF
#define __CCT_CONTRACT_ATTR___CCT_CREF        const
#define __CCT_CONTRACT_ATTR___CCT_BPTR
#define __CCT_CONTRACT_ATTR___CCT_PTR
#endif /* __clang__ */

#define __CCT_CONTRACT_TAG___CCT_REF          _ref
#define __CCT_CONTRACT_TAG___CCT_CREF         _cref
#define __CCT_CONTRACT_TAG___CCT_BPTR         _bptr
#define __CCT_CONTRACT_TAG___CCT_PTR          _ptr

/* Helper macros */
#define __CCT_DEFER(F, ...) F(__VA_ARGS__)
#define __CCT_CONTRACT_TO_ATTR(kind) __CONCAT(__CCT_CONTRACT_ATTR_, kind)
#define __CCT_CONTRACT_TO_TAG(kind)  __CCT_DEFER(__CONCAT, __CCT_CONTRACT_TAG_, kind)

#define __CCT_COUNT_ARGS1(a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, N, ...) N
#define __CCT_COUNT_ARGS(...) \
	__CCT_COUNT_ARGS1(, __VA_ARGS__, _9, _8, _7, _6, _5, _4, _3, _2, _1, _0)
#define __CCT_DISPATCH1(base, N, ...) __CONCAT(base, N)(__VA_ARGS__)
#define __CCT_DISPATCH(base, ...) \
	__CCT_DISPATCH1(base, __CCT_COUNT_ARGS(__VA_ARGS__), __VA_ARGS__)

/* Covert a contract list to a type suffix */
#define __CCT_CONTRACT_LIST_TO_TAGGED_SUFFIX_1(kind)                                                \
	__CCT_DEFER(__CONCAT, __CCT_CONTRACT_TO_TAG(kind), _t)
#define __CCT_CONTRACT_LIST_TO_TAGGED_SUFFIX_2(kind1, kind2)                                        \
	__CCT_DEFER(__CONCAT, __CCT_CONTRACT_TO_TAG(kind1),                                             \
	         __CCT_CONTRACT_LIST_TO_TAGGED_SUFFIX_1(kind2))
#define __CCT_CONTRACT_LIST_TO_TAGGED_SUFFIX_3(kind1, kind2, kind3)                                 \
	__CCT_DEFER(__CONCAT, __CCT_CONTRACT_TO_TAG(kind1),                                             \
	         __CCT_CONTRACT_LIST_TO_TAGGED_SUFFIX_2(kind2, kind3))

/* Create typedefs for the constrained pointer type */
#define __CCT_DECLARE_CONSTRAINED_PTR_TYPE_3(basetype, basetag, kind)                               \
typedef basetype * __CCT_CONTRACT_TO_ATTR(kind)                                                     \
	__CCT_DEFER(__CONCAT, basetag,  __CCT_CONTRACT_LIST_TO_TAGGED_SUFFIX_1(kind))

#define __CCT_DECLARE_CONSTRAINED_PTR_TYPE_4(basetype, basetag, kind1, kind2)                       \
typedef basetype * __CCT_CONTRACT_TO_ATTR(kind1)                                                    \
	         * __CCT_CONTRACT_TO_ATTR(kind2)                                                        \
	__CCT_DEFER(__CONCAT, basetag,  __CCT_CONTRACT_LIST_TO_TAGGED_SUFFIX_2(kind1, kind2))

#define __CCT_DECLARE_CONSTRAINED_PTR_TYPE_5(basetype, basetag, kind1, kind2, kind3)                \
typedef basetype * __CCT_CONTRACT_TO_ATTR(kind1)                                                    \
	         * __CCT_CONTRACT_TO_ATTR(kind2)                                                        \
	         * __CCT_CONTRACT_TO_ATTR(kind3)                                                        \
	__CCT_DEFER(__CONCAT, basetag,  __CCT_CONTRACT_LIST_TO_TAGGED_SUFFIX_3(kind1, kind2, kind3))
#endif /* defined(KERNEL) || defined(__CCT_ENABLE_USER_SPACE) */

/*
 * Lower level type constructor.
 */
#if defined(KERNEL) || defined(__CCT_ENABLE_USER_SPACE)
#define __CCT_DECLARE_CONSTRAINED_PTR_TYPE(basetype, basetag, ...)                                  \
	__CCT_DISPATCH(__CCT_DECLARE_CONSTRAINED_PTR_TYPE, basetype, basetag, __VA_ARGS__)
#else /* !defined(KERNEL) && !defined(__CCT_ENABLE_USER_SPACE) */
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra-semi"
#endif /* defined(__clang__) */
#define __CCT_DECLARE_CONSTRAINED_PTR_TYPE(basetype, basetag, ...)
#if defined(__clang__)
#pragma clang diagnostic pop
#endif /* defined(__clang__) */
#endif /* !defined(KERNEL) && !defined(__CCT_ENABLE_USER_SPACE) */

/*
 * Higher level type constructors.
 */
#if defined(__CCT_ENABLE_USER_SPACE)
/* Limiting the higher-level constructor to the ABI-preserving constructs. */
#define __CCT_DECLARE_CONSTRAINED_PTR_TYPES(basetype, basetag)                                      \
	__CCT_DECLARE_CONSTRAINED_PTR_TYPE(basetype, basetag, __CCT_REF);                               \
	__CCT_DECLARE_CONSTRAINED_PTR_TYPE(basetype, basetag, __CCT_REF, __CCT_REF)
#else /* !defined(__CCT_ENABLE_USER_SPACE) */
/* Disabling the higher-level constructor */
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra-semi"
#endif /* defined(__clang__) */
#define __CCT_DECLARE_CONSTRAINED_PTR_TYPES(basetype, basetag)
#if defined(__clang__)
#pragma clang diagnostic pop
#endif /* defined(__clang__) */
#endif /* !defined(__CCT_ENABLE_USER_SPACE) */

#endif /* __CONSTRAINED_CTYPES__ */