# This file is dual licensed under the terms of the Apache License, Version
# 2.0, and the BSD License. See the LICENSE file in the root of this repository
# for complete details.

from __future__ import absolute_import, division, print_function

INCLUDES = """
#include <openssl/ocsp.h>
"""

TYPES = """
typedef ... OCSP_REQUEST;
typedef ... OCSP_ONEREQ;
typedef ... OCSP_RESPONSE;
typedef ... OCSP_BASICRESP;
typedef ... OCSP_SINGLERESP;
typedef ... OCSP_CERTID;
typedef ... OCSP_RESPDATA;
static const long OCSP_NOCERTS;
static const long OCSP_RESPID_KEY;
"""

FUNCTIONS = """
int OCSP_response_status(OCSP_RESPONSE *);
OCSP_BASICRESP *OCSP_response_get1_basic(OCSP_RESPONSE *);
int OCSP_BASICRESP_get_ext_count(OCSP_BASICRESP *);
const ASN1_OCTET_STRING *OCSP_resp_get0_signature(const OCSP_BASICRESP *);
const Cryptography_STACK_OF_X509 *OCSP_resp_get0_certs(const OCSP_BASICRESP *);
const ASN1_GENERALIZEDTIME *OCSP_resp_get0_produced_at(
    const OCSP_BASICRESP *);
const OCSP_CERTID *OCSP_SINGLERESP_get0_id(const OCSP_SINGLERESP *);
int OCSP_resp_get0_id(const OCSP_BASICRESP *, const ASN1_OCTET_STRING **,
                      const X509_NAME **);
const X509_ALGOR *OCSP_resp_get0_tbs_sigalg(const OCSP_BASICRESP *);
const OCSP_RESPDATA *OCSP_resp_get0_respdata(const OCSP_BASICRESP *);
X509_EXTENSION *OCSP_BASICRESP_get_ext(OCSP_BASICRESP *, int);
int OCSP_resp_count(OCSP_BASICRESP *);
OCSP_SINGLERESP *OCSP_resp_get0(OCSP_BASICRESP *, int);
int OCSP_SINGLERESP_get_ext_count(OCSP_SINGLERESP *);
X509_EXTENSION *OCSP_SINGLERESP_get_ext(OCSP_SINGLERESP *, int);

int OCSP_single_get0_status(OCSP_SINGLERESP *, int *, ASN1_GENERALIZEDTIME **,
                            ASN1_GENERALIZEDTIME **, ASN1_GENERALIZEDTIME **);

int OCSP_REQUEST_get_ext_count(OCSP_REQUEST *);
X509_EXTENSION *OCSP_REQUEST_get_ext(OCSP_REQUEST *, int);
int OCSP_request_onereq_count(OCSP_REQUEST *);
OCSP_ONEREQ *OCSP_request_onereq_get0(OCSP_REQUEST *, int);
int OCSP_ONEREQ_get_ext_count(OCSP_ONEREQ *);
X509_EXTENSION *OCSP_ONEREQ_get_ext(OCSP_ONEREQ *, int);
OCSP_CERTID *OCSP_onereq_get0_id(OCSP_ONEREQ *);
OCSP_ONEREQ *OCSP_request_add0_id(OCSP_REQUEST *, OCSP_CERTID *);
OCSP_CERTID *OCSP_cert_to_id(const EVP_MD *, const X509 *, const X509 *);
void OCSP_CERTID_free(OCSP_CERTID *);


OCSP_BASICRESP *OCSP_BASICRESP_new(void);
void OCSP_BASICRESP_free(OCSP_BASICRESP *);
OCSP_SINGLERESP *OCSP_basic_add1_status(OCSP_BASICRESP *, OCSP_CERTID *, int,
                                        int, ASN1_TIME *, ASN1_TIME *,
                                        ASN1_TIME *);
int OCSP_basic_add1_nonce(OCSP_BASICRESP *, unsigned char *, int);
int OCSP_basic_add1_cert(OCSP_BASICRESP *, X509 *);
int OCSP_BASICRESP_add_ext(OCSP_BASICRESP *, X509_EXTENSION *, int);
int OCSP_basic_sign(OCSP_BASICRESP *, X509 *, EVP_PKEY *, const EVP_MD *,
                    Cryptography_STACK_OF_X509 *, unsigned long);
OCSP_RESPONSE *OCSP_response_create(int, OCSP_BASICRESP *);
void OCSP_RESPONSE_free(OCSP_RESPONSE *);

OCSP_REQUEST *OCSP_REQUEST_new(void);
void OCSP_REQUEST_free(OCSP_REQUEST *);
int OCSP_request_add1_nonce(OCSP_REQUEST *, unsigned char *, int);
int OCSP_REQUEST_add_ext(OCSP_REQUEST *, X509_EXTENSION *, int);
int OCSP_id_get0_info(ASN1_OCTET_STRING **, ASN1_OBJECT **,
                      ASN1_OCTET_STRING **, ASN1_INTEGER **, OCSP_CERTID *);
OCSP_REQUEST *d2i_OCSP_REQUEST_bio(BIO *, OCSP_REQUEST **);
OCSP_RESPONSE *d2i_OCSP_RESPONSE_bio(BIO *, OCSP_RESPONSE **);
int i2d_OCSP_REQUEST_bio(BIO *, OCSP_REQUEST *);
int i2d_OCSP_RESPONSE_bio(BIO *, OCSP_RESPONSE *);
int i2d_OCSP_RESPDATA(OCSP_RESPDATA *, unsigned char **);
"""

CUSTOMIZATIONS = """
#if ( \
    CRYPTOGRAPHY_OPENSSL_110_OR_GREATER && \
    CRYPTOGRAPHY_OPENSSL_LESS_THAN_110J \
    )
/* These structs come from ocsp_lcl.h and are needed to de-opaque the struct
   for the getters in OpenSSL 1.1.0 through 1.1.0i */
struct ocsp_responder_id_st {
    int type;
    union {
        X509_NAME *byName;
        ASN1_OCTET_STRING *byKey;
    } value;
};
struct ocsp_response_data_st {
    ASN1_INTEGER *version;
    OCSP_RESPID responderId;
    ASN1_GENERALIZEDTIME *producedAt;
    STACK_OF(OCSP_SINGLERESP) *responses;
    STACK_OF(X509_EXTENSION) *responseExtensions;
};
struct ocsp_basic_response_st {
    OCSP_RESPDATA tbsResponseData;
    X509_ALGOR signatureAlgorithm;
    ASN1_BIT_STRING *signature;
    STACK_OF(X509) *certs;
};
#endif

#if CRYPTOGRAPHY_OPENSSL_LESS_THAN_110
/* These functions are all taken from ocsp_cl.c in OpenSSL 1.1.0 */
const OCSP_CERTID *OCSP_SINGLERESP_get0_id(const OCSP_SINGLERESP *single)
{
    return single->certId;
}
const Cryptography_STACK_OF_X509 *OCSP_resp_get0_certs(
    const OCSP_BASICRESP *bs)
{
    return bs->certs;
}
int OCSP_resp_get0_id(const OCSP_BASICRESP *bs,
                      const ASN1_OCTET_STRING **pid,
                      const X509_NAME **pname)
{
    const OCSP_RESPID *rid = bs->tbsResponseData->responderId;

    if (rid->type == V_OCSP_RESPID_NAME) {
        *pname = rid->value.byName;
        *pid = NULL;
    } else if (rid->type == V_OCSP_RESPID_KEY) {
        *pid = rid->value.byKey;
        *pname = NULL;
    } else {
        return 0;
    }
    return 1;
}
const ASN1_GENERALIZEDTIME *OCSP_resp_get0_produced_at(
    const OCSP_BASICRESP* bs)
{
    return bs->tbsResponseData->producedAt;
}
const ASN1_OCTET_STRING *OCSP_resp_get0_signature(const OCSP_BASICRESP *bs)
{
    return bs->signature;
}
#endif

#if CRYPTOGRAPHY_OPENSSL_LESS_THAN_110J
const X509_ALGOR *OCSP_resp_get0_tbs_sigalg(const OCSP_BASICRESP *bs)
{
#if CRYPTOGRAPHY_OPENSSL_LESS_THAN_110
    return bs->signatureAlgorithm;
#else
    return &bs->signatureAlgorithm;
#endif
}

const OCSP_RESPDATA *OCSP_resp_get0_respdata(const OCSP_BASICRESP *bs)
{
#if CRYPTOGRAPHY_OPENSSL_LESS_THAN_110
    return bs->tbsResponseData;
#else
    return &bs->tbsResponseData;
#endif
}
#endif
"""
