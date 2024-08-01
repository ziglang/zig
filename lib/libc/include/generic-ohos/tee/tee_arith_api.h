/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef TEE_ARITH_API_H
#define TEE_ARITH_API_H

/**
 * @addtogroup TeeTrusted
 * @{
 *
 * @brief TEE(Trusted Excution Environment) API.
 * Provides security capability APIs such as trusted storage, encryption and decryption,
 * and trusted time for trusted application development.
 *
 * @since 12
 */

/**
 * @file tee_arith_api.h
 *
 * @brief Provides APIs for operating big integers.
 *
 * @library NA
 * @kit TEE Kit
 * @syscap SystemCapability.Tee.TeeClient
 * @since 12
 * @version 1.0
 */

#include <tee_defines.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef uint32_t TEE_BigInt;
typedef uint32_t TEE_BigIntFMM;
typedef uint32_t TEE_BigIntFMMContext;

/**
 * @brief Obtains the size of the array of uint32_t values required to represent a <b>BigInt</b>.
 *
 * @param n Indicates the <b>TEE_BigInt</b> type.
 *
 * @return Returns the <b>BigInt</b> size obtained.
 *
 * @since 12
 * @version 1.0
 */
#define TEE_BigIntSizeInU32(n) ((((n) + 31) / 32) + 2)

/**
 * @brief Obtains the size of the array of uint32_t values.
 *
 * @param modulusSizeInBits Indicates the modulus size, in bits.
 *
 * @return Returns the number of bytes required to store a <b>TEE_BigIntFMM</b>,
 * given a modulus of length <b>modSizeInBits</b>.
 *
 * @since 12
 * @version 1.0
 */
size_t TEE_BigIntFMMSizeInU32(size_t modulusSizeInBits);

/**
 * @brief Obtains the size of an array of uint32_t values required to represent a fast modular context.
 *
 * @param modulusSizeInBits Indicates the modulus size, in bits.
 *
 * @return Returns the number of bytes required to store a <b>TEE_BigIntFMMContext</b>,
 * given a modulus of length <b>modSizeInBits</b>.
 *
 * @since 12
 * @version 1.0
 */
size_t TEE_BigIntFMMContextSizeInU32(size_t modulusSizeInBits);

/**
 * @brief Initializes a <b>TEE_BigInt</b>.
 *
 * @param bigInt Indicates the pointer to the <b>TEE_BigInt</b> to initialize.
 * @param len Indicates the size of the memory pointed to by <b>TEE_BigInt</b>, in uint32_t.
 *
 * @since 12
 * @version 1.0
 */
void TEE_BigIntInit(TEE_BigInt *bigInt, size_t len);

/**
 * @brief Calculates the necessary prerequisites for fast modular multiplication and stores them in a context.
 *
 * @param context Indicates the pointer to the <b>TEE_BigIntFMMContext</b> to initialize.
 * @param len Indicates the size of the memory pointed to by <b>context</b>, in uint32_t.
 * @param modulus Indicates the pointer to the modulus.
 *
 * @since 12
 * @version 1.0
 */
void TEE_BigIntInitFMMContext(TEE_BigIntFMMContext *context, size_t len, const TEE_BigInt *modulus);

/**
 * @brief Calculates the necessary prerequisites for fast modular multiplication and stores them in a context.
 *
 * @param context Indicates the pointer to the <b>TEE_BigIntFMMContext</b> to initialize.
 * @param len Indicates the size of the memory pointed to by <b>context</b>, in uint32_t.
 * @param modulus Indicates the pointer to the modulus.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns other values if the operation fails.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_BigIntInitFMMContext1(TEE_BigIntFMMContext *context, size_t len, const TEE_BigInt *modulus);

/**
 * @brief Initializes a <b>TEE_BigIntFMM</b> and sets its represented value to zero.
 *
 * @param bigIntFMM Indicates the pointer to the <b>TEE_BigIntFMM</b> to initialize.
 * @param len Indicates the size of the memory pointed to by <b>bigIntFMM</b>, in uint32_t.
 *
 * @since 12
 * @version 1.0
 */
void TEE_BigIntInitFMM(TEE_BigIntFMM *bigIntFMM, size_t len);

/**
 * @brief Converts an octet string buffer into the <b>TEE_BigInt</b> format.
 *
 * @param dest Indicates the pointer to the <b>TEE_BigInt</b> that holds the result.
 * @param buffer Indicates the pointer to the buffer that holds the octet string representation of the integer.
 * @param bufferLen Indicates the buffer length, in bytes.
 * @param sign Indicates the sign of <b>dest</b>, which is set to the sign of <b>sign</b>.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_OVERFLOW</b> if the memory allocated for <b>dest</b> is too small.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_BigIntConvertFromOctetString(TEE_BigInt *dest, const uint8_t *buffer, size_t bufferLen, int32_t sign);

/**
 * @brief Converts the absolute value of an integer in <b>TEE_BigInt</b> format into an octet string.
 *
 * @param buffer Indicates the pointer to the output buffer that holds the converted octet string representation
 * of the integer.
 * @param bufferLen Indicates the pointer to the buffer length, in bytes.
 * @param bigInt Indicates the pointer to the integer to convert.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_SHORT_BUFFER</b> if the output buffer is too small to hold the octet string.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_BigIntConvertToOctetString(void *buffer, size_t *bufferLen, const TEE_BigInt *bigInt);

/**
 * @brief Sets <b>dest</b> to the value <b>shortVal</b>.
 *
 * @param dest Indicates the pointer to the <b>TEE_BigInt</b> that holds the result.
 * @param shortVal Indicates the value to set.
 *
 * @since 12
 * @version 1.0
 */
void TEE_BigIntConvertFromS32(TEE_BigInt *dest, int32_t shortVal);

/**
 * @brief Sets <b>dest</b> to the value of <b>src</b>, including the sign of <b>src</b>.
 *
 * @param dest Indicates the pointer to the <b> int32_t</b> that holds the result.
 * @param src Indicates the pointer to the value to set.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_OVERFLOW</b> if <b>src</b> does not fit within an <b> int32_t</b>.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_BigIntConvertToS32(int32_t *dest, const TEE_BigInt *src);

/**
 * @brief Checks whether op1 > op2, op1 == op2, or op1 < op2.
 *
 * @param op1 Indicates the pointer to the first operand.
 * @param op2 Indicates the pointer to the second operand.
 *
 * @return Returns <b>0</b> if op1 == op2.
 *         Returns a positive number if op1 > op2.
 *
 * @since 12
 * @version 1.0
 */
int32_t TEE_BigIntCmp(const TEE_BigInt *op1, const TEE_BigInt *op2);

/**
 * @brief Checks whether op > shortVal, op == shortVal, or op < shortVal.
 *
 * @param op Indicates the pointer to the first operand.
 * @param shortVal Indicates the pointer to the second operand.
 *
 * @return Returns <b>0</b> if op1 == shortVal.
 *         Returns a positive number if op1 > shortVal.
 *
 * @since 12
 * @version 1.0
 */
int32_t TEE_BigIntCmpS32(const TEE_BigInt *op, int32_t shortVal);

/**
 * @brief Computes |dest| = |op| >> bits.
 *
 * @param dest Indicates the pointer to the <b>TEE_BigInt</b> that holds the shifted result.
 * @param op Indicates the pointer to the operand to be shifted.
 * @param bits Indicates the number of bits to shift.
 *
 * @since 12
 * @version 1.0
 */
void TEE_BigIntShiftRight(TEE_BigInt *dest, const TEE_BigInt *op, size_t bits);

/**
 * @brief Obtains the <b>bitIndex</b> bit of the natural binary representation of |src|.
 *
 * @param src Indicates the pointer to the integer.
 * @param bitIndex Indicates the offset of the bit to read, starting from offset <b>0</b> of the least significant bit.
 *
 * @return Returns the Boolean value of <b>bitIndexth</b> in |src|. The value <b>true</b> represents a <b>1</b>,
 * and <b>false</b> represents a <b>0</b>.
 *
 * @since 12
 * @version 1.0
 */
bool TEE_BigIntGetBit(const TEE_BigInt *src, uint32_t bitIndex);

/**
 * @brief Obtains the number of bits in the natural binary representation of |src|,
 * that is, the magnitude of <b>src</b>.
 *
 * @param src Indicates the pointer to the integer.
 *
 * @return Returns <b>0</b> if <b>src</b> is <b>0</b>.
 *         Returns the number of bits in the natural binary representation of <b>src</b>.
 *
 * @since 12
 * @version 1.0
 */
uint32_t TEE_BigIntGetBitCount(const TEE_BigInt *src);

#if defined(API_LEVEL) && (API_LEVEL >= API_LEVEL1_2)
/**
 * @brief Sets the first bit of <b>bitIndex</b> in the natural binary representation of <b>op</b> to
 * <b>1</b> or <b>0</b>.
 *
 * @param op Indicates the pointer to the integer.
 * @param bitIndex Indicates the offset of the bit to set, starting from offset <b>0</b> of the least significant bit.
 * @param value Indicates the bit value to set. The value <b>true</b> represents a <b>1</b>, and the value <b>false</b>
 * represents a <b>0</b>.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_OVERFLOW bitIndexth</b> if the <b>bitIndexth</b> bit is larger than the allocated bit
 * length of <b>op</b>.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_BigIntSetBit(TEE_BigInt *op, uint32_t bitIndex, bool value);

/**
 * @brief Assigns the value of <b>src</b> to <b>dest</b>.
 *
 * @param dest Indicates the pointer to the <b>TEE_BigInt</b> to be assigned.
 * @param src Indicates the pointer to the source operand.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_OVERFLOW</b> if the <b>dest</b> operand cannot hold the value of <b>src</b>.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_BigIntAssign(TEE_BigInt *dest, const TEE_BigInt *src);

/**
 * @brief Assigns the value of <b>src</b> to <b>dest</b>.
 *
 * @param dest Indicates the pointer to the <b>TEE_BigInt</b> to be assigned.
 * @param src Indicates the pointer to the source operand.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_OVERFLOW</b> if the <b>dest</b> operand cannot hold the value of <b>src</b>.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_BigIntAbs(TEE_BigInt *dest, const TEE_BigInt *src);
#endif /* API_LEVEL */

/**
 * @brief Computes dest = op1 + op2.
 *
 * @param dest Indicates the pointer to the <b>TEE_BigInt</b> that holds the sum of <b>op1</b> and <b>op2</b>.
 * @param op1 Indicates the pointer to the first operand.
 * @param op2 Indicates the pointer to the second operand.
 *
 * @since 12
 * @version 1.0
 */
void TEE_BigIntAdd(TEE_BigInt *dest, const TEE_BigInt *op1, const TEE_BigInt *op2);

/**
 * @brief Computes dest = op1 – op2.
 *
 * @param dest Indicates the pointer to the <b>TEE_BigInt</b> that holds the difference between <b>op1</b>
 * and <b>op2</b>.
 * @param op1 Indicates the pointer to the first operand.
 * @param op2 Indicates the pointer to the second operand.
 *
 * @since 12
 * @version 1.0
 */
void TEE_BigIntSub(TEE_BigInt *dest, const TEE_BigInt *op1, const TEE_BigInt *op2);

/**
 * @brief Negates an operand: dest = –op.
 *
 * @param dest Indicates the pointer to the <b>TEE_BigInt</b> that holds the result –op.
 * @param op Indicates the pointer to the operand to be negated.
 *
 * @since 12
 * @version 1.0
 */
void TEE_BigIntNeg(TEE_BigInt *dest, const TEE_BigInt *op);

/**
 * @brief Computes dest = op1 * op2.
 *
 * @param dest Indicates the pointer to the <b>TEE_BigInt</b> that holds the product of <b>op1</b> and <b>op2</b>.
 * @param op1 Indicates the pointer to the first operand.
 * @param op2 Indicates the pointer to the second operand.
 *
 * @since 12
 * @version 1.0
 */
void TEE_BigIntMul(TEE_BigInt *dest, const TEE_BigInt *op1, const TEE_BigInt *op2);

/**
 * @brief Computes dest = op * op.
 *
 * @param dest Indicates the pointer to the <b>TEE_BigInt</b> that holds the result op * op.
 * @param op Indicates the pointer to the operand to be squared.
 *
 * @since 12
 * @version 1.0
 */
void TEE_BigIntSquare(TEE_BigInt *dest, const TEE_BigInt *op);

/**
 * @brief Computes <b>dest_r</b> and <b>dest_q</b> to make op1 = dest_q* op2 + dest_r.
 *
 * @param dest_q Indicates the pointer to the <b>TEE_BigInt</b> that holds the quotient.
 * @param dest_r Indicates the pointer to the <b>TEE_BigInt</b> that holds the remainder.
 * @param op1 Indicates the pointer to the first operand, which is the dividend.
 * @param op2 Indicates the pointer to the second operand, which is the divisor.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_BAD_PARAMETERS</b> if at least one parameter is null.
 *
 * @since 12
 * @version 1.0
 */
void TEE_BigIntDiv(TEE_BigInt *dest_q, TEE_BigInt *dest_r, const TEE_BigInt *op1, const TEE_BigInt *op2);

/**
 * @brief Computes dest = op (mod n) to make 0 <= dest < n.
 *
 * @param dest Indicates the pointer to the <b>TEE_BigInt</b> that holds the result op (mod n).
 * @param op Indicates the pointer to the operand to be reduced mod n.
 * @param n [IN] Indicates the pointer to the modulus, which must be greater than 1.
 *
 * @since 12
 * @version 1.0
 */
void TEE_BigIntMod(TEE_BigInt *dest, const TEE_BigInt *op, const TEE_BigInt *n);

/**
 * @brief Computes dest = (op1 + op2) (mod n).
 *
 * @param dest Indicates the pointer to the <b>TEE_BigInt</b> that holds the result op (op1 + op2)(mod n).
 * @param op1 Indicates the pointer to the first operand.
 * @param op2 Indicates the pointer to the second operand.
 * @param n Indicates the pointer to the modulus, which must be greater than 1.
 *
 * @since 12
 * @version 1.0
 */
void TEE_BigIntAddMod(TEE_BigInt *dest, const TEE_BigInt *op1, const TEE_BigInt *op2, const TEE_BigInt *n);

/**
 * @brief Computes dest = (op1 – op2) (mod n).
 *
 * @param dest Indicates the pointer to the <b>TEE_BigInt</b> that holds the result op (op1 – op2)(mod n).
 * @param op1 Indicates the pointer to the first operand.
 * @param op2 Indicates the pointer to the second operand.
 * @param n Indicates the pointer to the modulus, which must be greater than 1.
 *
 * @since 12
 * @version 1.0
 */
void TEE_BigIntSubMod(TEE_BigInt *dest, const TEE_BigInt *op1, const TEE_BigInt *op2, const TEE_BigInt *n);

/**
 * @brief Computes dest = (op1* op2)(mod n).
 *
 * @param dest Indicates the pointer to the <b>TEE_BigInt</b> that holds the result op (op1 * op2)(mod n).
 * @param op1 Indicates the pointer to the first operand.
 * @param op2 Indicates the pointer to the second operand.
 * @param n Indicates the pointer to the modulus, which must be greater than 1.
 *
 * @since 12
 * @version 1.0
 */
void TEE_BigIntMulMod(TEE_BigInt *dest, const TEE_BigInt *op1, const TEE_BigInt *op2, const TEE_BigInt *n);

/**
 * @brief Computes dest = (op * op) (mod n).
 *
 * @param dest Indicates the pointer to the <b>TEE_BigInt</b> that holds the result op (op * op)(mod n).
 * @param op Indicates the pointer to the operand.
 * @param n [IN] Indicates the pointer to the modulus, which must be greater than 1.
 *
 * @since 12
 * @version 1.0
 */
void TEE_BigIntSquareMod(TEE_BigInt *dest, const TEE_BigInt *op, const TEE_BigInt *n);

/**
 * @brief Computes <b>dest</b> to make dest* op = 1 (mod n).
 *
 * @param dest Indicates the pointer to the <b>TEE_BigInt</b> that holds the result (op^–1)(mod n).
 * @param op Indicates the pointer to the operand.
 * @param n [IN] Indicates the pointer to the modulus, which must be greater than 1.
 *
 * @since 12
 * @version 1.0
 */
void TEE_BigIntInvMod(TEE_BigInt *dest, const TEE_BigInt *op, const TEE_BigInt *n);

/**
 * @brief Checks whether gcd(op1, op2) == 1.
 *
 * @param op1 Indicates the pointer to the first operand.
 * @param op2 Indicates the pointer to the second operand.
 *
 * @return Returns <b>true</b> if gcd(op1, op2) == 1.
 *         Returns <b>false</b> if gcd(op1, op2) != 1.
 *
 * @since 12
 * @version 1.0
 */
bool TEE_BigIntRelativePrime(const TEE_BigInt *op1, const TEE_BigInt *op2);

/**
 * @brief Computes the greatest common divisor of <b>op1</b> and <b>op2</b>.
 *
 * @param gcd Indicates the pointer to the <b>TEE_BigInt</b> that holds the greatest common divisor of <b>op1</b>
 * and <b>op2</b>.
 * @param u Indicates the pointer to the <b>TEE_BigInt</b> that holds the first coefficient.
 * @param v Indicates the pointer to the <b>TEE_BigInt</b> that holds the second coefficient.
 * @param op1 Indicates the pointer to the first operand.
 * @param op2 Indicates the pointer to the second operand.
 *
 * @since 12
 * @version 1.0
 */
void TEE_BigIntComputeExtendedGcd(TEE_BigInt *gcd, TEE_BigInt *u, TEE_BigInt *v, const TEE_BigInt *op1,
                                  const TEE_BigInt *op2);
/**
 * @brief Performs a probabilistic primality test on <b>op</b>.
 *
 * @param op Indicates the pointer to the candidate number that is tested for primality.
 * @param confidenceLevel Indicates the expected confidence level for a non-conclusive test.
 *
 * @return Returns <b>0</b> if <b>op</b> is a composite number.
 *         Returns <b>1</b> if <b>op</b> is a prime number.
 *         Returns <b>–1</b> if the test is non-conclusive but the probability that <b>op</b> is composite is
 * less than 2^(-confidenceLevel).
 *
 * @since 12
 * @version 1.0
 */
int32_t TEE_BigIntIsProbablePrime(const TEE_BigInt *op, uint32_t confidenceLevel);

/**
 * @brief Converts <b>src</b> into a representation suitable for doing fast modular multiplication.
 *
 * @param dest Indicates the pointer to an initialized <b>TEE_BigIntFMM</b> memory area.
 * @param src Indicates the pointer to the <b>TEE_BigInt</b> to convert.
 * @param n Indicates the pointer to the modulus.
 * @param context Indicates the pointer to the context that is previously initialized using
 * {@link TEE_BigIntInitFMMContext1}.
 *
 * @since 12
 * @version 1.0
 */
void TEE_BigIntConvertToFMM(TEE_BigIntFMM *dest, const TEE_BigInt *src, const TEE_BigInt *n,
                            const TEE_BigIntFMMContext *context);

/**
 * @brief Converts <b>src</b> in the fast modular multiplication representation back to a
 * <b>TEE_BigInt</b> representation.
 *
 * @param dest Indicates the pointer to an initialized <b>TEE_BigIntFMM</b> memory area to store the converted result.
 * @param src Indicates the pointer to a <b>TEE_BigIntFMM</b> holding the value in the fast modular multiplication
 * representation.
 * @param n Indicates the pointer to the modulus.
 * @param context Indicates the pointer to the context that is previously initialized using
 * {@link TEE_BigIntInitFMMContext1}.
 *
 * @since 12
 * @version 1.0
 */
void TEE_BigIntConvertFromFMM(TEE_BigInt *dest, const TEE_BigIntFMM *src, const TEE_BigInt *n,
                              const TEE_BigIntFMMContext *context);

/**
 * @brief Computes dest = op1* op2 in the fast modular multiplication representation.
 *
 * @param dest Indicates the pointer to the <b>TEE_BigIntFMM</b> that holds the result op1* op2.
 * @param op1 Indicates the pointer to the first operand.
 * @param op2 Indicates the pointer to the second operand.
 * @param n Indicates the pointer to the modulus.
 * @param context Indicates the pointer to the context that is previously initialized using
 * {@link TEE_BigIntInitFMMContext1}.
 *
 * @since 12
 * @version 1.0
 */
void TEE_BigIntComputeFMM(TEE_BigIntFMM *dest, const TEE_BigIntFMM *op1, const TEE_BigIntFMM *op2, const TEE_BigInt *n,
                          const TEE_BigIntFMMContext *context);

/**
 * @brief Computes dest = (op1 ^ op2)(mod n).
 *
 * @param des Indicates the pointer to the <b>TEE_BigInt</b> that holds the result (op1 ^ op2)(mod n).
 * @param op1 Indicates the pointer to the first operand.
 * @param op2 Indicates the pointer to the second operand.
 * @param n Indicates the pointer to the modulus.
 * @param context Indicates the pointer to the context that is previously initialized using
 * {@link TEE_BigIntInitFMMContext1} or initialized to null.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_NOT_SUPPORTED</b> if the value of <b>n</b> is not supported.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_BigIntExpMod(TEE_BigInt *des, TEE_BigInt *op1, const TEE_BigInt *op2, const TEE_BigInt *n,
                            TEE_BigIntFMMContext *context);

#ifdef __cplusplus
}
#endif
/** @} */
#endif