/*
 * Copyright (c) 2010 Apple Inc. All Rights Reserved.
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

#ifndef _CC_PBKDF_H_
#define _CC_PBKDF_H_

#include <string.h>
#include <limits.h>
#include <stdlib.h>
#include <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonHMAC.h>


#ifdef __cplusplus
extern "C" {
#endif

enum {
    kCCPBKDF2 = 2,
};


typedef uint32_t CCPBKDFAlgorithm;


enum {
    kCCPRFHmacAlgSHA1 = 1,
    kCCPRFHmacAlgSHA224 = 2,
    kCCPRFHmacAlgSHA256 = 3,
    kCCPRFHmacAlgSHA384 = 4,
    kCCPRFHmacAlgSHA512 = 5,
};


typedef uint32_t CCPseudoRandomAlgorithm;

/*

 @function  CCKeyDerivationPBKDF
 @abstract  Derive a key from a text password/passphrase

 @param algorithm       Currently only PBKDF2 is available via kCCPBKDF2
 @param password        The text password used as input to the derivation
                        function.  The actual octets present in this string
                        will be used with no additional processing.  It's
                        extremely important that the same encoding and
                        normalization be used each time this routine is
                        called if the same key is  expected to be derived.
 @param passwordLen     The length of the text password in bytes.
 @param salt            The salt byte values used as input to the derivation
                        function. The pointer can be NULL, only when saltLen is zero.
 @param saltLen         The length of the salt in bytes. It can be zero.
 @param prf             The Pseudo Random Algorithm to use for the derivation
                        iterations.
 @param rounds          The number of rounds of the Pseudo Random Algorithm
                        to use. It cannot be zero.
 @param derivedKey      The resulting derived key produced by the function.
                        The space for this must be provided by the caller.
 @param derivedKeyLen   The expected length of the derived key in bytes. It cannot be zero.

 @discussion The following values are used to designate the PRF:

 * kCCPRFHmacAlgSHA1
 * kCCPRFHmacAlgSHA224
 * kCCPRFHmacAlgSHA256
 * kCCPRFHmacAlgSHA384
 * kCCPRFHmacAlgSHA512

 @result     kCCParamError can result from bad values for the password, salt,
 	     and unwrapped key pointers as well as a bad value for the prf
	     function.

 */

int
CCKeyDerivationPBKDF( CCPBKDFAlgorithm algorithm, const char *password, size_t passwordLen,
                      const uint8_t *salt, size_t saltLen,
                      CCPseudoRandomAlgorithm prf, unsigned rounds,
                      uint8_t *derivedKey, size_t derivedKeyLen)
                      API_AVAILABLE(macos(10.7), ios(5.0));

/*
 * All lengths are in bytes - not bits.
 */

/*

 @function  CCCalibratePBKDF
 @abstract  Determine the number of PRF rounds to use for a specific delay on
            the current platform.
 @param algorithm       Currently only PBKDF2 is available via kCCPBKDF2
 @param passwordLen     The length of the text password in bytes.
 @param saltLen         The length of the salt in bytes. saltlen must be smaller than 133.
 @param prf             The Pseudo Random Algorithm to use for the derivation
                        iterations.
 @param derivedKeyLen   The expected length of the derived key in bytes.
 @param msec            The targetted duration we want to achieve for a key
                        derivation with these parameters.

 @result the number of iterations to use for the desired processing time.
        Returns a minimum of 10000 iterations (safety net, not a particularly recommended value)
            The number of iterations is a trade-off of usability and security. If there is an error
            the function returns (unsigned)(-1). The minimum return value is set to 10000.

 */

unsigned
CCCalibratePBKDF(CCPBKDFAlgorithm algorithm, size_t passwordLen, size_t saltLen,
                 CCPseudoRandomAlgorithm prf, size_t derivedKeyLen, uint32_t msec)
                 API_AVAILABLE(macos(10.7), ios(5.0));

#ifdef __cplusplus
}
#endif

#endif  /* _CC_PBKDF_H_ */
