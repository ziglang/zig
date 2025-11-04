//
//  CommonCryptoError.h
//  CommonCrypto
//
//  Copyright (c) 2014 Platform Security. All rights reserved.
//

#ifndef CommonCrypto_CommonCryptoError_h
#define CommonCrypto_CommonCryptoError_h

/*
 * Copyright (c) 2014 Apple Inc. All Rights Reserved.
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

#include <stdint.h>

#if defined(__cplusplus)
extern "C" {
#endif	
    
/*!
    @enum       CCCryptorStatus
    @abstract   Return values from CommonCryptor operations.
    
    @constant   kCCSuccess          Operation completed normally.
    @constant   kCCParamError       Illegal parameter value.
    @constant   kCCBufferTooSmall   Insufficent buffer provided for specified 
                                    operation.
    @constant   kCCMemoryFailure    Memory allocation failure. 
    @constant   kCCAlignmentError   Input size was not aligned properly. 
    @constant   kCCDecodeError      Input data did not decode or decrypt 
                                    properly.
    @constant   kCCUnimplemented    Function not implemented for the current 
                                    algorithm.
    @constant   kCCInvalidKey       Key is not valid.
 */
enum {
    kCCSuccess          = 0,
    kCCParamError       = -4300,
    kCCBufferTooSmall   = -4301,
    kCCMemoryFailure    = -4302,
    kCCAlignmentError   = -4303,
    kCCDecodeError      = -4304,
    kCCUnimplemented    = -4305,
    kCCOverflow         = -4306,
    kCCRNGFailure       = -4307,
    kCCUnspecifiedError = -4308,
    kCCCallSequenceError= -4309,
    kCCKeySizeError     = -4310,
    kCCInvalidKey       = -4311,
};
typedef int32_t CCStatus;
typedef int32_t CCCryptorStatus;
    
#if defined(__cplusplus)
}
#endif

#endif
