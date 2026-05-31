/*
 * Copyright (c) 2006-2010 Apple, Inc. All Rights Reserved.
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

/*!
    @header     CommonCryptor.h
    @abstract   Generic interface for symmetric encryption.

    @discussion This interface provides access to a number of symmetric
                encryption algorithms. Symmetric encryption algorithms come
                in two "flavors" -  block ciphers, and stream ciphers. Block
                ciphers process data (while both encrypting and decrypting)
                in discrete chunks of  data called blocks; stream ciphers
                operate on arbitrary sized data.

                The object declared in this interface, CCCryptor, provides
                access to both block ciphers and stream ciphers with the same
                API; however some options are available for block ciphers that
                do not apply to stream ciphers.

                The general operation of a CCCryptor is: initialize it
                with raw key data and other optional fields with
                CCCryptorCreate(); process input data via one or more calls to
                CCCryptorUpdate(), each of which may result in output data
                being written to caller-supplied memory; and obtain possible
                remaining output data with CCCryptorFinal(). The CCCryptor is
                disposed of via CCCryptorRelease(), or it can be reused (with
                the same key data as provided to CCCryptorCreate()) by calling
                CCCryptorReset(). The CCCryptorReset() function only works for
                the CBC and CTR modes. In other block cipher modes, it returns error.


                CCCryptors can be dynamically allocated by this module, or
                their memory can be allocated by the caller. See discussion for
                CCCryptorCreate() and CCCryptorCreateFromData() for information
                on CCCryptor allocation.

                One option for block ciphers is padding, as defined in PKCS7;
                when padding is enabled, the total amount of data encrypted
                does not have to be an even multiple of the block size, and
                the actual length of plaintext is calculated during decryption.

                Another option for block ciphers is Cipher Block Chaining, known
                as CBC mode. When using CBC mode, an Initialization Vector (IV)
                is provided along with the key when starting an encrypt
                or decrypt operation. If CBC mode is selected and no IV is
                provided, an IV of all zeroes will be used.

                CCCryptor also implements block bufferring, so that individual
                calls to CCCryptorUpdate() do not have to provide data whose
                length is aligned to the block size. (If padding is disabled,
                encrypting with block ciphers does require that the *total*
                length of data input to CCCryptorUpdate() call(s) be aligned
                to the block size.)

                A given CCCryptor can only be used by one thread at a time;
                multiple threads can use safely different CCCryptors at the
                same time.
*/

#include <CommonCrypto/CommonCryptoError.h>

#ifndef _CC_COMMON_CRYPTOR_
#define _CC_COMMON_CRYPTOR_

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

#if defined(_MSC_VER)
#include <availability.h>
#else
#include <os/availability.h>
#endif


#ifdef __cplusplus
extern "C" {
#endif

/*!
    @typedef    CCCryptorRef
    @abstract   Opaque reference to a CCCryptor object.
 */
typedef struct _CCCryptor *CCCryptorRef;


/*!
    @enum       CCOperation
    @abstract   Operations that an CCCryptor can perform.

    @constant   kCCEncrypt  Symmetric encryption.
    @constant   kCCDecrypt  Symmetric decryption.
*/
enum {
    kCCEncrypt = 0,
    kCCDecrypt,
};
typedef uint32_t CCOperation;

/*!
    @enum       CCAlgorithm
    @abstract   Encryption algorithms implemented by this module.
    @constant   kCCAlgorithmAES     Advanced Encryption Standard, 128-bit block
    @constant   kCCAlgorithmAES128  Deprecated, name phased out due to ambiguity with key size
    @constant   kCCAlgorithmDES     Data Encryption Standard
    @constant   kCCAlgorithm3DES    Triple-DES, three key, EDE configuration
    @constant   kCCAlgorithmCAST    CAST
 	@constant   kCCAlgorithmRC4     RC4 stream cipher
 	@constant   kCCAlgorithmBlowfish    Blowfish block cipher
*/
enum {
    kCCAlgorithmAES128 = 0, /* Deprecated, name phased out due to ambiguity with key size */
    kCCAlgorithmAES = 0,
    kCCAlgorithmDES,
    kCCAlgorithm3DES,
    kCCAlgorithmCAST,
    kCCAlgorithmRC4,
    kCCAlgorithmRC2,
    kCCAlgorithmBlowfish
};
typedef uint32_t CCAlgorithm;

/*!
    @enum       CCOptions
    @abstract   Options flags, passed to CCCryptorCreate().

    @constant   kCCOptionPKCS7Padding   Perform PKCS7 padding.
    @constant   kCCOptionECBMode        Electronic Code Book Mode.
                                        Default is CBC.
*/
enum {
    /* options for block ciphers */
    kCCOptionPKCS7Padding   = 0x0001,
    kCCOptionECBMode        = 0x0002
    /* stream ciphers currently have no options */
};
typedef uint32_t CCOptions;

/*!
    @enum           Key sizes

    @discussion     Key sizes, in bytes, for supported algorithms.  Use these
                    constants to select any keysize variants you wish to use
                    for algorithms that support them (ie AES-128, AES-192, AES-256)

    @constant kCCKeySizeAES128      128 bit AES key size.
    @constant kCCKeySizeAES192      192 bit AES key size.
    @constant kCCKeySizeAES256      256 bit AES key size.
    @constant kCCKeySizeDES         DES key size.
    @constant kCCKeySize3DES        Triple DES key size.
    @constant kCCKeySizeMinCAST     CAST minimum key size.
    @constant kCCKeySizeMaxCAST     CAST maximum key size.
    @constant kCCKeySizeMinRC4      RC4 minimum key size.
    @constant kCCKeySizeMaxRC4      RC4 maximum key size.

    @discussion     DES and TripleDES have fixed key sizes.
                    AES has three discrete key sizes.
                    CAST and RC4 have variable key sizes.
*/
enum {
    kCCKeySizeAES128          = 16,
    kCCKeySizeAES192          = 24,
    kCCKeySizeAES256          = 32,
    kCCKeySizeDES             = 8,
    kCCKeySize3DES            = 24,
    kCCKeySizeMinCAST         = 5,
    kCCKeySizeMaxCAST         = 16,
    kCCKeySizeMinRC4          = 1,
    kCCKeySizeMaxRC4          = 512,
    kCCKeySizeMinRC2          = 1,
    kCCKeySizeMaxRC2          = 128,
    kCCKeySizeMinBlowfish     = 8,
    kCCKeySizeMaxBlowfish     = 56,
};

/*!
    @enum           Block sizes

    @discussion     Block sizes, in bytes, for supported algorithms.

    @constant kCCBlockSizeAES128    AES block size (currently, only 128-bit
                                    blocks are supported).
    @constant kCCBlockSizeDES       DES block size.
    @constant kCCBlockSize3DES      Triple DES block size.
    @constant kCCBlockSizeCAST      CAST block size.
*/
enum {
    /* AES */
    kCCBlockSizeAES128        = 16,
    /* DES */
    kCCBlockSizeDES           = 8,
    /* 3DES */
    kCCBlockSize3DES          = 8,
    /* CAST */
    kCCBlockSizeCAST          = 8,
    kCCBlockSizeRC2           = 8,
    kCCBlockSizeBlowfish      = 8,
};

/*!
    @enum       Minimum context sizes
    @discussion Minimum context sizes, for caller-allocated CCCryptorRefs.
                To minimize dynamic allocation memory, a caller can create
                a CCCryptorRef by passing caller-supplied memory to the
                CCCryptorCreateFromData() function.

                These constants define the minimum amount of memory, in
                bytes, needed for CCCryptorRefs for each supported algorithm.

                Note: these constants are valid for the current version of
                this library; they may change in subsequent releases, so
                applications wishing to allocate their own memory for use
                in creating CCCryptorRefs must be prepared to deal with
                a kCCBufferTooSmall return from CCCryptorCreateFromData().
                See discussion for the CCCryptorCreateFromData() function.

    @constant kCCContextSizeAES128 - Minimum context size for kCCAlgorithmAES128.
    @constant kCCContextSizeDES    - Minimum context size for kCCAlgorithmDES.
    @constant kCCContextSize3DES   - Minimum context size for kCCAlgorithm3DES.
    @constant kCCContextSizeCAST   - Minimum context size for kCCAlgorithmCAST.
    @constant kCCContextSizeRC4    - Minimum context size for kCCAlgorithmRC4.
*/

enum {
    kCCContextSizeAES128	= 404,
    kCCContextSizeDES		= 240,
    kCCContextSize3DES		= 496,
    kCCContextSizeCAST		= 240,
    kCCContextSizeRC4		= 1072
};



/*!
    @function   CCCryptorCreate
    @abstract   Create a cryptographic context.

    @param      op          Defines the basic operation: kCCEncrypt or
                            kCCDecrypt.

    @param      alg         Defines the algorithm.

    @param      options     A word of flags defining options. See discussion
                            for the CCOptions type.

    @param      key         Raw key material, length keyLength bytes.

    @param      keyLength   Length of key material. Must be appropriate
                            for the selected operation and algorithm. Some
                            algorithms  provide for varying key lengths.

    @param      iv          Initialization vector, optional. Used by
                            block ciphers when Cipher Block Chaining (CBC)
                            mode is enabled. If present, must be the same
                            length as the selected algorithm's block size.
                            If CBC mode is selected (by the absence of the
                            kCCOptionECBMode bit in the options flags) and no
                            IV is present, a NULL (all zeroes) IV will be used.
                            This parameter is ignored if ECB mode is used or
                            if a stream cipher algorithm is selected. For sound
                            encryption, always initialize iv with random data.

    @param      cryptorRef  A (required) pointer to the returned CCCryptorRef.

    @result     Possible error returns are kCCParamError and kCCMemoryFailure.
*/
CCCryptorStatus CCCryptorCreate(
    CCOperation op,             /* kCCEncrypt, etc. */
    CCAlgorithm alg,            /* kCCAlgorithmDES, etc. */
    CCOptions options,          /* kCCOptionPKCS7Padding, etc. */
    const void *key,            /* raw key material */
    size_t keyLength,
    const void *iv,             /* optional initialization vector */
    CCCryptorRef *cryptorRef)  /* RETURNED */
API_AVAILABLE(macos(10.4), ios(2.0));

/*!
    @function   CCCryptorCreateFromData
    @abstract   Create a cryptographic context using caller-supplied memory.

    @param      op          Defines the basic operation: kCCEncrypt or
                            kCCDecrypt.

    @param      alg         Defines the algorithm.

    @param      options     A word of flags defining options. See discussion
                            for the CCOptions type.

    @param      key         Raw key material, length keyLength bytes.

    @param      keyLength   Length of key material. Must be appropriate
                            for the selected operation and algorithm. Some
                            algorithms  provide for varying key lengths.

    @param      iv          Initialization vector, optional. Used by
                            block ciphers when Cipher Block Chaining (CBC)
                            mode is enabled. If present, must be the same
                            length as the selected algorithm's block size.
                            If CBC mode is selected (by the absence of the
                            kCCOptionECBMode bit in the options flags) and no
                            IV is present, a NULL (all zeroes) IV will be used.
                            This parameter is ignored if ECB mode is used or
                            if a stream cipher algorithm is selected. For sound
                            encryption, always initialize iv with random data.

    @param      data        A pointer to caller-supplied memory from which the
                            CCCryptorRef will be created.

    @param      dataLength  The size of the caller-supplied memory in bytes.

    @param      cryptorRef  A (required) pointer to the returned CCCryptorRef.

    @param      dataUsed    Optional. If present, the actual number of bytes of
                            the caller-supplied memory which was consumed by
                            creation of the CCCryptorRef is returned here. Also,
                            if the supplied memory is of insufficent size to create
                            a CCCryptorRef, kCCBufferTooSmall is returned, and
                            the minimum required buffer size is returned via this
                            parameter if present.

    @result     Possible error returns are kCCParamError and kCCBufferTooSmall.

    @discussion The CCCryptorRef created by this function must be disposed of
                via CCCRyptorRelease which clears sensitive data and deallocates memory
                when the caller is finished using the CCCryptorRef.
*/
CCCryptorStatus CCCryptorCreateFromData(
    CCOperation op,             /* kCCEncrypt, etc. */
    CCAlgorithm alg,            /* kCCAlgorithmDES, etc. */
    CCOptions options,          /* kCCOptionPKCS7Padding, etc. */
    const void *key,            /* raw key material */
    size_t keyLength,
    const void *iv,             /* optional initialization vector */
    const void *data,           /* caller-supplied memory */
    size_t dataLength,          /* length of data in bytes */
    CCCryptorRef *cryptorRef,   /* RETURNED */
    size_t *dataUsed)           /* optional, RETURNED */
API_AVAILABLE(macos(10.4), ios(2.0));

/*!
    @function   CCCryptorRelease
    @abstract   Free a context created by CCCryptorCreate or
                CCCryptorCreateFromData().

    @param      cryptorRef  The CCCryptorRef to release.

    @result     The only possible error return is kCCParamError resulting
                from passing in a null CCCryptorRef.
*/
CCCryptorStatus CCCryptorRelease(
    CCCryptorRef cryptorRef)
API_AVAILABLE(macos(10.4), ios(2.0));

/*!
    @function   CCCryptorUpdate
    @abstract   Process (encrypt, decrypt) some data. The result, if any,
                is written to a caller-provided buffer.

    @param      cryptorRef      A CCCryptorRef created via CCCryptorCreate() or
                                CCCryptorCreateFromData().
    @param      dataIn          Data to process, length dataInLength bytes.
    @param      dataInLength    Length of data to process.
    @param      dataOut         Result is written here. Allocated by caller.
                                Encryption and decryption can be performed
                                "in-place", with the same buffer used for
                                input and output. The in-place operation is not
                                suported for ciphers modes that work with blocks
                                of data such as CBC and ECB.

    @param      dataOutAvailable The size of the dataOut buffer in bytes.
    @param      dataOutMoved    On successful return, the number of bytes
    				written to dataOut.

    @result     kCCBufferTooSmall indicates insufficent space in the dataOut
                                buffer. The caller can use
				CCCryptorGetOutputLength() to determine the
				required output buffer size in this case. The
				operation can be retried; no state is lost
                                when this is returned.

    @discussion This routine can be called multiple times. The caller does
                not need to align input data lengths to block sizes; input is
                bufferred as necessary for block ciphers.

                When performing symmetric encryption with block ciphers,
                and padding is enabled via kCCOptionPKCS7Padding, the total
                number of bytes provided by all the calls to this function
                when encrypting can be arbitrary (i.e., the total number
                of bytes does not have to be block aligned). However if
                padding is disabled, or when decrypting, the total number
                of bytes does have to be aligned to the block size; otherwise
                CCCryptFinal() will return kCCAlignmentError.

                A general rule for the size of the output buffer which must be
                provided by the caller is that for block ciphers, the output
                length is never larger than the input length plus the block size.
                For stream ciphers, the output length is always exactly the same
                as the input length. See the discussion for
		CCCryptorGetOutputLength() for more information on this topic.

                Generally, when all data has been processed, call
		CCCryptorFinal().

                In the following cases, the CCCryptorFinal() is superfluous as
                it will not yield any data nor return an error:
                1. Encrypting or decrypting with a block cipher with padding
                   disabled, when the total amount of data provided to
                   CCCryptorUpdate() is an integral multiple of the block size.
                2. Encrypting or decrypting with a stream cipher.
 */
CCCryptorStatus CCCryptorUpdate(
    CCCryptorRef cryptorRef,
    const void *dataIn,
    size_t dataInLength,
    void *dataOut,              /* data RETURNED here */
    size_t dataOutAvailable,
    size_t *dataOutMoved)       /* number of bytes written */
API_AVAILABLE(macos(10.4), ios(2.0));

/*!
    @function   CCCryptorFinal
    @abstract   Finish an encrypt or decrypt operation, and obtain the (possible)
                final data output.

    @param      cryptorRef      A CCCryptorRef created via CCCryptorCreate() or
                                CCCryptorCreateFromData().
    @param      dataOut         Result is written here. Allocated by caller.
    @param      dataOutAvailable The size of the dataOut buffer in bytes.
    @param      dataOutMoved    On successful return, the number of bytes
    				written to dataOut.

    @result     kCCBufferTooSmall indicates insufficent space in the dataOut
                                buffer. The caller can use
				CCCryptorGetOutputLength() to determine the
				required output buffer size in this case. The
				operation can be retried; no state is lost
                                when this is returned.
                kCCAlignmentError When decrypting, or when encrypting with a
                                block cipher with padding disabled,
                                kCCAlignmentError will be returned if the total
                                number of bytes provided to CCCryptUpdate() is
                                not an integral multiple of the current
                                algorithm's block size.
                kCCDecodeError  Indicates garbled ciphertext or the
                                wrong key during decryption. This can only
                                be returned while decrypting with padding
                                enabled.

    @discussion Except when kCCBufferTooSmall is returned, the CCCryptorRef
                can no longer be used for subsequent operations unless
                CCCryptorReset() is called on it.

                It is not necessary to call CCCryptorFinal() when performing
                symmetric encryption or decryption if padding is disabled, or
                when using a stream cipher.

                It is not necessary to call CCCryptorFinal() prior to
                CCCryptorRelease() when aborting an operation.
 */
CCCryptorStatus CCCryptorFinal(
    CCCryptorRef cryptorRef,
    void *dataOut,
    size_t dataOutAvailable,
    size_t *dataOutMoved)       /* number of bytes written */
API_AVAILABLE(macos(10.4), ios(2.0));

/*!
    @function   CCCryptorGetOutputLength
    @abstract   Determine output buffer size required to process a given input
    		size.

    @param      cryptorRef  A CCCryptorRef created via CCCryptorCreate() or
                            CCCryptorCreateFromData().
    @param      inputLength The length of data which will be provided to
                            CCCryptorUpdate().
    @param      final       If false, the returned value will indicate the
    			    output buffer space needed when 'inputLength'
			    bytes are provided to CCCryptorUpdate(). When
			    'final' is true, the returned value will indicate
			    the total combined buffer space needed when
			    'inputLength' bytes are provided to
			    CCCryptorUpdate() and then CCCryptorFinal() is
			    called.

    @result The maximum buffer space need to perform CCCryptorUpdate() and
    	    optionally CCCryptorFinal().

    @discussion Some general rules apply that allow clients of this module to
                know a priori how much output buffer space will be required
                in a given situation. For stream ciphers, the output size is
                always equal to the input size, and CCCryptorFinal() never
                produces any data. For block ciphers, the output size will
                always be less than or equal to the input size plus the size
                of one block. For block ciphers, if the input size provided
                to each call to CCCryptorUpdate() is is an integral multiple
                of the block size, then the output size for each call to
                CCCryptorUpdate() is less than or equal to the input size
                for that call to CCCryptorUpdate(). CCCryptorFinal() only
                produces output when using a block cipher with padding enabled.
*/
size_t CCCryptorGetOutputLength(
    CCCryptorRef cryptorRef,
    size_t inputLength,
    bool final)
API_AVAILABLE(macos(10.4), ios(2.0));


/*!
    @function   CCCryptorReset
    @abstract   Reinitializes an existing CCCryptorRef with a (possibly)
                new initialization vector. The CCCryptorRef's key is
                unchanged. Use only for CBC and CTR modes.

    @param      cryptorRef  A CCCryptorRef created via CCCryptorCreate() or
                            CCCryptorCreateFromData().
    @param      iv          Optional initialization vector; if present, must
                            be the same size as the current algorithm's block
                            size. For sound encryption, always initialize iv with
                            random data.

    @result     The only possible errors are kCCParamError and
                kCCUnimplemented. On macOS 10.13, iOS 11, watchOS 4 and tvOS 11 returns kCCUnimplemented
                for modes other than CBC. On prior SDKs, returns kCCSuccess to preserve compatibility

    @discussion This can be called on a CCCryptorRef with data pending (i.e.
                in a padded mode operation before CCCryptFinal is called);
                however any pending data will be lost in that case.
*/
CCCryptorStatus CCCryptorReset(
    CCCryptorRef cryptorRef,
    const void *iv)
    API_AVAILABLE(macos(10.4), ios(2.0));


/*!
    @function   CCCrypt
    @abstract   Stateless, one-shot encrypt or decrypt operation.
                This basically performs a sequence of CCCrytorCreate(),
                CCCryptorUpdate(), CCCryptorFinal(), and CCCryptorRelease().

    @param      alg             Defines the encryption algorithm.


    @param      op              Defines the basic operation: kCCEncrypt or
    				kCCDecrypt.

    @param      options         A word of flags defining options. See discussion
                                for the CCOptions type.

    @param      key             Raw key material, length keyLength bytes.

    @param      keyLength       Length of key material. Must be appropriate
                                for the select algorithm. Some algorithms may
                                provide for varying key lengths.

    @param      iv              Initialization vector, optional. Used for
                                Cipher Block Chaining (CBC) mode. If present,
                                must be the same length as the selected
                                algorithm's block size. If CBC mode is
                                selected (by the absence of any mode bits in
                                the options flags) and no IV is present, a
                                NULL (all zeroes) IV will be used. This is
                                ignored if ECB mode is used or if a stream
                                cipher algorithm is selected. For sound encryption,
                                always initialize IV with random data.

    @param      dataIn          Data to encrypt or decrypt, length dataInLength
                                bytes.

    @param      dataInLength    Length of data to encrypt or decrypt.

    @param      dataOut         Result is written here. Allocated by caller.
                                Encryption and decryption can be performed
                                "in-place", with the same buffer used for
                                input and output.

    @param      dataOutAvailable The size of the dataOut buffer in bytes.

    @param      dataOutMoved    On successful return, the number of bytes
    				written to dataOut. If kCCBufferTooSmall is
				returned as a result of insufficient buffer
				space being provided, the required buffer space
				is returned here.

    @result     kCCBufferTooSmall indicates insufficent space in the dataOut
                                buffer. In this case, the *dataOutMoved
                                parameter will indicate the size of the buffer
                                needed to complete the operation. The
                                operation can be retried with minimal runtime
                                penalty.
                kCCAlignmentError indicates that dataInLength was not properly
                                aligned. This can only be returned for block
                                ciphers, and then only when decrypting or when
                                encrypting with block with padding disabled.
                kCCDecodeError  Indicates improperly formatted ciphertext or
                                a "wrong key" error; occurs only during decrypt
                                operations.
 */

CCCryptorStatus CCCrypt(
    CCOperation op,         /* kCCEncrypt, etc. */
    CCAlgorithm alg,        /* kCCAlgorithmAES128, etc. */
    CCOptions options,      /* kCCOptionPKCS7Padding, etc. */
    const void *key,
    size_t keyLength,
    const void *iv,         /* optional initialization vector */
    const void *dataIn,     /* optional per op and alg */
    size_t dataInLength,
    void *dataOut,          /* data RETURNED here */
    size_t dataOutAvailable,
    size_t *dataOutMoved)
    API_AVAILABLE(macos(10.4), ios(2.0));


/*!
    @enum       Cipher Modes
    @discussion These are the selections available for modes of operation for
				use with block ciphers.  If RC4 is selected as the cipher (a stream
				cipher) the only correct mode is kCCModeRC4.

    @constant kCCModeECB - Electronic Code Book Mode.
    @constant kCCModeCBC - Cipher Block Chaining Mode.
    @constant kCCModeCFB - Cipher Feedback Mode.
    @constant kCCModeOFB - Output Feedback Mode.
    @constant kCCModeRC4 - RC4 as a streaming cipher is handled internally as a mode.
    @constant kCCModeCFB8 - Cipher Feedback Mode producing 8 bits per round.
*/


enum {
	kCCModeECB		= 1,
	kCCModeCBC		= 2,
	kCCModeCFB		= 3,
	kCCModeCTR		= 4,
	kCCModeOFB		= 7,
	kCCModeRC4		= 9,
	kCCModeCFB8		= 10,
};
typedef uint32_t CCMode;

/*!
    @enum       Padding for Block Ciphers
    @discussion These are the padding options available for block modes.

    @constant ccNoPadding -  No padding.
    @constant ccPKCS7Padding - PKCS7 Padding.
*/

enum {
	ccNoPadding			= 0,
	ccPKCS7Padding		= 1,
};
typedef uint32_t CCPadding;

/*!
    @enum       Mode options - Not currently in use.

    @discussion Values used to specify options for modes. This was used for counter
    mode operations in 10.8, now only Big Endian mode is supported.

    @constant kCCModeOptionCTR_BE - CTR Mode Big Endian.
*/

enum {
    kCCModeOptionCTR_BE = 2
};

typedef uint32_t CCModeOptions;

/*!
     @function   CCCryptorCreateWithMode
     @abstract   Create a cryptographic context.

     @param      op         Defines the basic operation: kCCEncrypt or
                            kCCDecrypt.

     @param     mode		Specifies the cipher mode to use for operations.

     @param      alg        Defines the algorithm.

     @param		padding		Specifies the padding to use.

     @param      iv         Initialization vector, optional. Used by
                            block ciphers with the following modes:

                            Cipher Block Chaining (CBC)
                            Cipher Feedback (CFB and CFB8)
                            Output Feedback (OFB)
                            Counter (CTR)

                            If present, must be the same length as the selected
                            algorithm's block size.  If no IV is present, a NULL
                            (all zeroes) IV will be used. For sound encryption,
                            always initialize iv with random data.

                            This parameter is ignored if ECB mode is used or
                            if a stream cipher algorithm is selected.

     @param      key         Raw key material, length keyLength bytes.

     @param      keyLength   Length of key material. Must be appropriate
                            for the selected operation and algorithm. Some
                            algorithms  provide for varying key lengths.

     @param      tweak      Raw key material, length keyLength bytes. Used for the
                            tweak key in XEX-based Tweaked CodeBook (XTS) mode.

     @param      tweakLength   Length of tweak key material. Must be appropriate
                            for the selected operation and algorithm. Some
                            algorithms  provide for varying key lengths.  For XTS
                            this is the same length as the encryption key.

     @param		numRounds	The number of rounds of the cipher to use.  0 uses the default.

     @param      options    A word of flags defining options. See discussion
                            for the CCModeOptions type.

     @param      cryptorRef  A (required) pointer to the returned CCCryptorRef.

     @result     Possible error returns are kCCParamError and kCCMemoryFailure.
 */


CCCryptorStatus CCCryptorCreateWithMode(
    CCOperation 	op,				/* kCCEncrypt, kCCDecrypt */
    CCMode			mode,
    CCAlgorithm		alg,
    CCPadding		padding,
    const void 		*iv,			/* optional initialization vector */
    const void 		*key,			/* raw key material */
    size_t 			keyLength,
    const void 		*tweak,			/* raw tweak material */
    size_t 			tweakLength,
    int				numRounds,		/* 0 == default */
    CCModeOptions 	options,
    CCCryptorRef	*cryptorRef)	/* RETURNED */
API_AVAILABLE(macos(10.7), ios(5.0));

#ifdef __cplusplus
}
#endif

#endif  /* _CC_COMMON_CRYPTOR_ */
