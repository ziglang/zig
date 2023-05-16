/*
 * Copyright (c) 2008 Apple Inc. All rights reserved.
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

#ifndef _LIBKERN_OSKEXTLIB_H
#define _LIBKERN_OSKEXTLIB_H

#include <sys/cdefs.h>
__BEGIN_DECLS

#include <stdint.h>
#include <mach/kmod.h>
#include <mach/vm_types.h>
#include <uuid/uuid.h>

#include <CoreFoundation/CoreFoundation.h>
#include <libkern/OSReturn.h>

/*!
 * @header
 *
 * Declares functions, basic return values, and other constants
 * related to kernel extensions (kexts).
 */

#if PRAGMA_MARK
#pragma mark -
/********************************************************************/
#pragma mark OSReturn Values for Kernel Extensions
/********************************************************************/
#endif
/*!
 * @group OSReturn Values for Kernel Extensions
 * Many kext-related functions return these values,
 * as well as those defined under
 * <code>@link //apple_ref/c/tdef/OSReturn OSReturn@/link</code>
 * and other variants of <code>kern_return_t</code>.
 */


#define sub_libkern_kext           err_sub(2)
#define libkern_kext_err(code)     (sys_libkern|sub_libkern_kext|(code))


/*!
 * @define   kOSKextReturnInternalError
 * @abstract An internal error in the kext library.
 *           Contrast with <code>@link //apple_ref/c/econst/OSReturnError
 *           OSReturnError@/link</code>.
 */
#define kOSKextReturnInternalError                   libkern_kext_err(0x1)

/*!
 * @define   kOSKextReturnNoMemory
 * @abstract Memory allocation failed.
 */
#define kOSKextReturnNoMemory                        libkern_kext_err(0x2)

/*!
 * @define   kOSKextReturnNoResources
 * @abstract Some resource other than memory (such as available load tags)
 *           is exhausted.
 */
#define kOSKextReturnNoResources                     libkern_kext_err(0x3)

/*!
 * @define   kOSKextReturnNotPrivileged
 * @abstract The caller lacks privileges to perform the requested operation.
 */
#define kOSKextReturnNotPrivileged                   libkern_kext_err(0x4)

/*!
 * @define   kOSKextReturnInvalidArgument
 * @abstract Invalid argument.
 */
#define kOSKextReturnInvalidArgument                 libkern_kext_err(0x5)

/*!
 * @define   kOSKextReturnNotFound
 * @abstract Search item not found.
 */
#define kOSKextReturnNotFound                        libkern_kext_err(0x6)

/*!
 * @define   kOSKextReturnBadData
 * @abstract Malformed data (not used for XML).
 */
#define kOSKextReturnBadData                         libkern_kext_err(0x7)

/*!
 * @define   kOSKextReturnSerialization
 * @abstract Error converting or (un)serializing URL, string, or XML.
 */
#define kOSKextReturnSerialization                   libkern_kext_err(0x8)

/*!
 * @define   kOSKextReturnUnsupported
 * @abstract Operation is no longer or not yet supported.
 */
#define kOSKextReturnUnsupported                     libkern_kext_err(0x9)

/*!
 * @define   kOSKextReturnDisabled
 * @abstract Operation is currently disabled.
 */
#define kOSKextReturnDisabled                        libkern_kext_err(0xa)

/*!
 * @define   kOSKextReturnNotAKext
 * @abstract Bundle is not a kernel extension.
 */
#define kOSKextReturnNotAKext                        libkern_kext_err(0xb)

/*!
 * @define   kOSKextReturnValidation
 * @abstract Validation failures encountered; check diagnostics for details.
 */
#define kOSKextReturnValidation                      libkern_kext_err(0xc)

/*!
 * @define   kOSKextReturnAuthentication
 * @abstract Authetication failures encountered; check diagnostics for details.
 */
#define kOSKextReturnAuthentication                  libkern_kext_err(0xd)

/*!
 * @define   kOSKextReturnDependencies
 * @abstract Dependency resolution failures encountered; check diagnostics for details.
 */
#define kOSKextReturnDependencies                    libkern_kext_err(0xe)

/*!
 * @define   kOSKextReturnArchNotFound
 * @abstract Kext does not contain code for the requested architecture.
 */
#define kOSKextReturnArchNotFound                    libkern_kext_err(0xf)

/*!
 * @define   kOSKextReturnCache
 * @abstract An error occurred processing a system kext cache.
 */
#define kOSKextReturnCache                           libkern_kext_err(0x10)

/*!
 * @define   kOSKextReturnDeferred
 * @abstract Operation has been posted asynchronously to user space (kernel only).
 */
#define kOSKextReturnDeferred                        libkern_kext_err(0x11)

/*!
 * @define   kOSKextReturnBootLevel
 * @abstract Kext not loadable or operation not allowed at current boot level.
 */
#define kOSKextReturnBootLevel                       libkern_kext_err(0x12)

/*!
 * @define   kOSKextReturnNotLoadable
 * @abstract Kext cannot be loaded; check diagnostics for details.
 */
#define kOSKextReturnNotLoadable                     libkern_kext_err(0x13)

/*!
 * @define   kOSKextReturnLoadedVersionDiffers
 * @abstract A different version (or executable UUID, or executable by checksum)
 *           of the requested kext is already loaded.
 */
#define kOSKextReturnLoadedVersionDiffers            libkern_kext_err(0x14)

/*!
 * @define   kOSKextReturnDependencyLoadError
 * @abstract A load error occurred on a dependency of the kext being loaded.
 */
#define kOSKextReturnDependencyLoadError             libkern_kext_err(0x15)

/*!
 * @define   kOSKextReturnLinkError
 * @abstract A link failure occured with this kext or a dependency.
 */
#define kOSKextReturnLinkError                       libkern_kext_err(0x16)

/*!
 * @define   kOSKextReturnStartStopError
 * @abstract The kext start or stop routine returned an error.
 */
#define kOSKextReturnStartStopError                  libkern_kext_err(0x17)

/*!
 * @define   kOSKextReturnInUse
 * @abstract The kext is currently in use or has outstanding references,
 *           and cannot be unloaded.
 */
#define kOSKextReturnInUse                           libkern_kext_err(0x18)

/*!
 * @define   kOSKextReturnTimeout
 * @abstract A kext request has timed out.
 */
#define kOSKextReturnTimeout                         libkern_kext_err(0x19)

/*!
 * @define   kOSKextReturnStopping
 * @abstract The kext is in the process of stopping; requests cannot be made.
 */
#define kOSKextReturnStopping                        libkern_kext_err(0x1a)

/*!
 * @define   kOSKextReturnSystemPolicy
 * @abstract The kext was prevented from loading due to system policy.
 */
#define kOSKextReturnSystemPolicy                    libkern_kext_err(0x1b)

/*!
 * @define   kOSKextReturnKCLoadFailure
 * @abstract Loading of the System KC failed
 */
#define kOSKextReturnKCLoadFailure                  libkern_kext_err(0x1c)

/*!
 * @define   kOSKextReturnKCLoadFailureSystemKC
 * @abstract Loading of the System KC failed
 *
 * This a sub-code of kOSKextReturnKCLoadFailure. It can be OR'd together
 * with: kOSKextReturnKCLoadFailureAuxKC
 *
 * If both the System and Aux KCs fail to load, then the error code will be:
 * libkern_kext_err(0x1f)
 */
#define kOSKextReturnKCLoadFailureSystemKC          libkern_kext_err(0x1d)

/*!
 * @define   kOSKextReturnKCLoadFailureAuxKC
 * @abstract Loading of the Aux KC failed
 *
 * This a sub-code of kOSKextReturnKCLoadFailure. It can be OR'd together
 * with: kOSKextReturnKCLoadFailureSystemKC
 *
 * If both the System and Aux KCs fail to load, then the error code will be:
 * libkern_kext_err(0x1f)
 */
#define kOSKextReturnKCLoadFailureAuxKC             libkern_kext_err(0x1e)

/* next available error is: libkern_kext_err(0x20) */

#if PRAGMA_MARK
#pragma mark -
/********************************************************************/
#pragma mark Kext/OSBundle Property List Keys
/********************************************************************/
#endif
/*!
 * @group Kext Property List Keys
 * These constants cover CFBundle properties defined for kernel extensions.
 * Because they are used in the kernel, if you want to use one with
 * CFBundle APIs you'll need to wrap it in a <code>CFSTR()</code> macro.
 */


/*!
 * @define   kOSBundleCompatibleVersionKey
 * @abstract A string giving the backwards-compatible version of a library kext
 *           in extended Mac OS 'vers' format (####.##.##s{1-255} where 's'
 *           is a build stage 'd', 'a', 'b', 'f' or 'fc').
 */
#define kOSBundleCompatibleVersionKey           "OSBundleCompatibleVersion"

/*!
 * @define   kOSBundleEnableKextLoggingKey
 * @abstract Set to true to have the kernel kext logging spec applied
 *           to the kext.
 *           See <code>@link //apple_ref/c/econst/OSKextLogSpec
 *           OSKextLogSpec@/link</code>.
 */
#define kOSBundleEnableKextLoggingKey           "OSBundleEnableKextLogging"

/*!
 * @define   kOSBundleIsInterfaceKey
 * @abstract A boolean value indicating whether the kext executable
 *           contains only symbol references.
 */
#define kOSBundleIsInterfaceKey                 "OSBundleIsInterface"

/*!
 * @define   kOSBundleLibrariesKey
 * @abstract A dictionary listing link dependencies for this kext.
 *           Keys are bundle identifiers, values are version strings.
 */
#define kOSBundleLibrariesKey                   "OSBundleLibraries"

/*!
 * @define   kOSBundleRequiredKey
 * @abstract A string indicating in which kinds of startup this kext
 *           may need to load during early startup (before
 *           <code>@link //apple_ref/doc/man/8/kextd kextcache(8)@/link</code>).
 * @discussion
 * The value is one of:
 * <ul>
 * <li>@link kOSBundleRequiredRoot "OSBundleRequiredRoot"@/link</li>
 * <li>@link kOSBundleRequiredLocalRoot "OSBundleRequiredLocalRoot"@/link</li>
 * <li>@link kOSBundleRequiredNetworkRoot "OSBundleRequiredNetworkRoot"@/link</li>
 * <li>@link kOSBundleRequiredSafeBoot "OSBundleRequiredSafeBoot"@/link</li>
 * <li>@link kOSBundleRequiredConsole "OSBundleRequiredConsole"@/link</li>
 * </ul>
 *
 * Use this property judiciously.
 * Every kext that declares a value other than "OSBundleRequiredSafeBoot"
 * increases startup time, as the booter must read it into memory,
 * or startup kext caches must include it.
 */
#define kOSBundleRequiredKey                    "OSBundleRequired"

/*!
 * @define   kOSBundleRequireExplicitLoadKey
 * @abstract A boolean value indicating whether the kext requires an
 *           explicit kextload in order to start/match.
 */
#define kOSBundleRequireExplicitLoadKey         "OSBundleRequireExplicitLoad"

/*!
 * @define   kOSBundleAllowUserLoadKey
 * @abstract A boolean value indicating whether
 *           <code>@link //apple_ref/doc/man/8/kextd kextcache(8)@/link</code>
 *           will honor a non-root process's request to load a kext.
 * @discussion
 * See <code>@link //apple_ref/doc/compositePage/c/func/KextManagerLoadKextWithURL
 * KextManagerLoadKextWithURL@/link</code>
 * and <code>@link //apple_ref/doc/compositePage/c/func/KextManagerLoadKextWithIdentifier
 * KextManagerLoadKextWithIdentifier@/link</code>.
 */
#define kOSBundleAllowUserLoadKey               "OSBundleAllowUserLoad"

/*!
 * @define   kOSBundleAllowUserTerminateKey
 * @abstract A boolean value indicating whether the kextunload tool
 *           is allowed to issue IOService terminate to classes defined in this kext.
 * @discussion A boolean value indicating whether the kextunload tool
 *           is allowed to issue IOService terminate to classes defined in this kext.
 */
#define kOSBundleAllowUserTerminateKey          "OSBundleAllowUserTerminate"

/*!
 * @define   kOSKernelResourceKey
 * @abstract A boolean value indicating whether the kext represents a built-in
 *           component of the kernel.
 */
#define kOSKernelResourceKey                    "OSKernelResource"

/*!
 * @define   kOSKextVariantOverrideKey
 * @abstract A dictionary with target names as key and a target-specific variant
 *           name as value.
 */
#define kOSKextVariantOverrideKey               "OSKextVariantOverride"

/*!
 * @define   kIOKitPersonalitiesKey
 * @abstract A dictionary of dictionaries used in matching for I/O Kit drivers.
 */
#define kIOKitPersonalitiesKey                  "IOKitPersonalities"

/*
 * @define   kIOPersonalityPublisherKey
 * @abstract Used in personalities sent to the I/O Kit,
 *           contains the CFBundleIdentifier of the kext
 *           that the personality originated in.
 */
#define kIOPersonalityPublisherKey              "IOPersonalityPublisher"

#if CONFIG_KEC_FIPS
/*
 * @define   kAppleTextHashesKey
 * @abstract A dictionary conataining hashes for corecrypto kext.
 */
#define kAppleTextHashesKey                     "AppleTextHashes"
#endif

/*!
 * @define   kOSMutableSegmentCopy
 * @abstract A boolean value indicating whether the kext requires a copy of
 *           its mutable segments to be kept in memory, and then reset when the kext
 *           unloads. This should be used with caution as it will increase the
 *           amount of memory used by the kext.
 */
#define kOSMutableSegmentCopy                   "OSMutableSegmentCopy"


#if PRAGMA_MARK
/********************************************************************/
#pragma mark Kext/OSBundle Property Deprecated Keys
/********************************************************************/
#endif
/*
 * @define   kOSBundleDebugLevelKey
 * @abstract
 * Deprecated (used on some releases of Mac OS X prior to 10.6 Snow Leopard).
 * Value is an integer from 1-6, corresponding to the verbose levels
 * of kext tools on those releases.
 * On 10.6 Snow Leopard, use <code>@link OSKextEnableKextLogging
 * OSKextEnableKextLogging@/link</code>.
 */
#define kOSBundleDebugLevelKey                  "OSBundleDebugLevel"

/*!
 * @define   kOSBundleSharedExecutableIdentifierKey
 * @abstract Deprecated (used on some releases of Mac OS X
 *           prior to 10.6 Snow Leopard).
 *           Value is the bundle identifier of the pseudokext
 *           that contains an executable shared by this kext.
 */
#define kOSBundleSharedExecutableIdentifierKey  "OSBundleSharedExecutableIdentifier"


#if PRAGMA_MARK
/********************************************************************/
#pragma mark Kext/OSBundle Property List Values
/********************************************************************/
#endif

/*!
 * @group Kext Property List Values
 * These constants encompass established values
 * for kernel extension bundle properties.
 */

/*!
 * @define   kOSKextKernelIdentifier
 * @abstract
 * This is the CFBundleIdentifier user for the kernel itself.
 */
#define kOSKextKernelIdentifier                 "__kernel__"

/*!
 * @define  kOSKextBundlePackageTypeKext
 * @abstract
 * The bundle type value for Kernel Extensions.
 */
#define kOSKextBundlePackageTypeKext        "KEXT"

/*!
 * @define  kOSKextBundlePackageTypeDriverKit
 * @abstract
 * The bundle type value for Driver Extensions.
 */
#define kOSKextBundlePackageTypeDriverKit   "DEXT"

/*!
 * @define   kOSBundleRequiredRoot
 * @abstract
 * This <code>@link kOSBundleRequiredKey OSBundleRequired@/link</code>
 * value indicates that the kext may be needed to mount the root filesystem
 * whether starting from a local or a network volume.
 */
#define kOSBundleRequiredRoot                   "Root"

/*!
 * @define   kOSBundleRequiredLocalRoot
 * @abstract
 * This <code>@link kOSBundleRequiredKey OSBundleRequired@/link</code>
 * value indicates that the kext may be needed to mount the root filesystem
 * when starting from a local disk.
 */
#define kOSBundleRequiredLocalRoot              "Local-Root"

/*!
 * @define   kOSBundleRequiredNetworkRoot
 * @abstract
 * This <code>@link kOSBundleRequiredKey OSBundleRequired@/link</code>
 * value indicates that the kext may be needed to mount the root filesystem
 * when starting over a network connection.
 */
#define kOSBundleRequiredNetworkRoot            "Network-Root"

/*!
 * @define   kOSBundleRequiredSafeBoot
 * @abstract
 * This <code>@link kOSBundleRequiredKey OSBundleRequired@/link</code>
 * value indicates that the kext can be loaded during a safe startup.
 * This value does not normally cause the kext to be read by the booter
 * or included in startup kext caches.
 */
#define kOSBundleRequiredSafeBoot               "Safe Boot"

/*!
 * @define   kOSBundleRequiredConsole
 * @abstract
 * This <code>@link kOSBundleRequiredKey OSBundleRequired@/link</code>
 * value indicates that the kext may be needed for console access
 * (specifically in a single-user startup when
 * <code>@link //apple_ref/doc/man/8/kextd kextd(8)@/link</code>.
 * does not run)
 * and should be loaded during early startup.
 */
#define kOSBundleRequiredConsole                "Console"

/*!
 * @define   kOSBundleRequiredDriverKit
 * @abstract
 * This <code>@link kOSBundleRequiredKey OSBundleRequired@/link</code>
 * value indicates that the driver extension's (DriverKit driver's)
 * personalities must be present in the kernel at early boot (specifically
 * before <code>@link //apple_ref/doc/man/8/kextd kextd(8)@/link</code> starts)
 * in order to compete with kexts built into the prelinkedkernel. Note that
 * kextd is still required to launch the user space driver binary. The IOKit
 * matching will happen during early boot, and the actual driver launch
 * will happen after kextd starts.
 */
#define kOSBundleRequiredDriverKit              "DriverKit"

#if PRAGMA_MARK
#pragma mark -
/********************************************************************/
#pragma mark Kext Information
/********************************************************************/
#endif
/*!
 * @group Kext Information
 * Types, constants, and macros providing a kext with information
 * about itself.
 */

/*!
 * @typedef OSKextLoadTag
 *
 * @abstract
 * A unique identifier assigned to a loaded instanace of a kext.
 *
 * @discussion
 * If a kext is unloaded and later reloaded, the new instance
 * has a different load tag.
 *
 * A kext can get its own load tag in the <code>kmod_info_t</code>
 * structure passed into its module start routine, as the
 * <code>id</code> field (cast to this type).
 */
typedef uint32_t  OSKextLoadTag;

/*!
 * @define kOSKextInvalidLoadTag
 *
 * @abstract
 * A load tag value that will never be used for a loaded kext;
 * indicates kext not found.
 */
#define  kOSKextInvalidLoadTag  ((OSKextLoadTag)(-1))


__END_DECLS

#endif /* _LIBKERN_OSKEXTLIB_H */