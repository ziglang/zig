/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_CERTENROLL
#define _INC_CERTENROLL

#if (_WIN32_WINNT >= 0x0600)
#ifdef __cplusplus
extern "C" {
#endif

  typedef enum AlgorithmFlags {
    AlgorithmFlagsNone   = 0x00000000,
    AlgorithmFlagsWrap   = 0x00000001 
  } AlgorithmFlags;

  typedef enum AlgorithmOperationFlags {
    XCN_NCRYPT_NO_OPERATION                      = 0,
    XCN_NCRYPT_CIPHER_OPERATION                  = 0x1,
    XCN_NCRYPT_HASH_OPERATION                    = 0x2,
    XCN_NCRYPT_ASYMMETRIC_ENCRYPTION_OPERATION   = 0x4,
    XCN_NCRYPT_SECRET_AGREEMENT_OPERATION        = 0x8,
    XCN_NCRYPT_SIGNATURE_OPERATION               = 0x10,
    XCN_NCRYPT_RNG_OPERATION                     = 0x20,
    XCN_NCRYPT_ANY_ASYMMETRIC_OPERATION          = ( ( 0x4 | 0x8 )  | 0x10 ),
    XCN_NCRYPT_PREFER_SIGNATURE_ONLY_OPERATION   = 0x00200000,
    XCN_NCRYPT_PREFER_NON_SIGNATURE_OPERATION    = 0x00400000,
    XCN_NCRYPT_EXACT_MATCH_OPERATION             = 0x00800000,
    XCN_NCRYPT_PREFERENCE_MASK_OPERATION         = 0x00e00000 
  } AlgorithmOperationFlags;

  typedef enum AlgorithmType {
    XCN_BCRYPT_UNKNOWN_INTERFACE                 = 0,
    XCN_BCRYPT_SIGNATURE_INTERFACE               = 0x5,
    XCN_BCRYPT_ASYMMETRIC_ENCRYPTION_INTERFACE   = 0x3,
    XCN_BCRYPT_CIPHER_INTERFACE                  = 0x1,
    XCN_BCRYPT_HASH_INTERFACE                    = 0x2,
    XCN_BCRYPT_SECRET_AGREEMENT_INTERFACE        = 0x4,
    XCN_BCRYPT_RNG_INTERFACE                     = 0x6 
  } AlgorithmType;

  typedef enum AlternativeNameType {
    XCN_CERT_ALT_NAME_UNKNOWN               = 0,
    XCN_CERT_ALT_NAME_OTHER_NAME            = 1,
    XCN_CERT_ALT_NAME_RFC822_NAME           = 2,
    XCN_CERT_ALT_NAME_DNS_NAME              = 3,
    XCN_CERT_ALT_NAME_DIRECTORY_NAME        = 5,
    XCN_CERT_ALT_NAME_URL                   = 7,
    XCN_CERT_ALT_NAME_IP_ADDRESS            = 8,
    XCN_CERT_ALT_NAME_REGISTERED_ID         = 9,
    XCN_CERT_ALT_NAME_GUID                  = 10,
    XCN_CERT_ALT_NAME_USER_PRINCIPLE_NAME   = 11 
  } AlternativeNameType;

  typedef enum CERTENROLL_PROPERTYID {
    XCN_PROPERTYID_NONE                              = 0,
    XCN_CERT_KEY_PROV_HANDLE_PROP_ID                 = 1,
    XCN_CERT_KEY_PROV_INFO_PROP_ID                   = 2,
    XCN_CERT_SHA1_HASH_PROP_ID                       = 3,
    XCN_CERT_MD5_HASH_PROP_ID                        = 4,
    XCN_CERT_HASH_PROP_ID                            = 3,
    XCN_CERT_KEY_CONTEXT_PROP_ID                     = 5,
    XCN_CERT_KEY_SPEC_PROP_ID                        = 6,
    XCN_CERT_IE30_RESERVED_PROP_ID                   = 7,
    XCN_CERT_PUBKEY_HASH_RESERVED_PROP_ID            = 8,
    XCN_CERT_ENHKEY_USAGE_PROP_ID                    = 9,
    XCN_CERT_CTL_USAGE_PROP_ID                       = 9,
    XCN_CERT_NEXT_UPDATE_LOCATION_PROP_ID            = 10,
    XCN_CERT_FRIENDLY_NAME_PROP_ID                   = 11,
    XCN_CERT_PVK_FILE_PROP_ID                        = 12,
    XCN_CERT_DESCRIPTION_PROP_ID                     = 13,
    XCN_CERT_ACCESS_STATE_PROP_ID                    = 14,
    XCN_CERT_SIGNATURE_HASH_PROP_ID                  = 15,
    XCN_CERT_SMART_CARD_DATA_PROP_ID                 = 16,
    XCN_CERT_EFS_PROP_ID                             = 17,
    XCN_CERT_FORTEZZA_DATA_PROP_ID                   = 18,
    XCN_CERT_ARCHIVED_PROP_ID                        = 19,
    XCN_CERT_KEY_IDENTIFIER_PROP_ID                  = 20,
    XCN_CERT_AUTO_ENROLL_PROP_ID                     = 21,
    XCN_CERT_PUBKEY_ALG_PARA_PROP_ID                 = 22,
    XCN_CERT_CROSS_CERT_DIST_POINTS_PROP_ID          = 23,
    XCN_CERT_ISSUER_PUBLIC_KEY_MD5_HASH_PROP_ID      = 24,
    XCN_CERT_SUBJECT_PUBLIC_KEY_MD5_HASH_PROP_ID     = 25,
    XCN_CERT_ENROLLMENT_PROP_ID                      = 26,
    XCN_CERT_DATE_STAMP_PROP_ID                      = 27,
    XCN_CERT_ISSUER_SERIAL_NUMBER_MD5_HASH_PROP_ID   = 28,
    XCN_CERT_SUBJECT_NAME_MD5_HASH_PROP_ID           = 29,
    XCN_CERT_EXTENDED_ERROR_INFO_PROP_ID             = 30,
    XCN_CERT_RENEWAL_PROP_ID                         = 64,
    XCN_CERT_ARCHIVED_KEY_HASH_PROP_ID               = 65,
    XCN_CERT_AUTO_ENROLL_RETRY_PROP_ID               = 66,
    XCN_CERT_AIA_URL_RETRIEVED_PROP_ID               = 67,
    XCN_CERT_AUTHORITY_INFO_ACCESS_PROP_ID           = 68,
    XCN_CERT_BACKED_UP_PROP_ID                       = 69,
    XCN_CERT_OCSP_RESPONSE_PROP_ID                   = 70,
    XCN_CERT_REQUEST_ORIGINATOR_PROP_ID              = 71,
    XCN_CERT_SOURCE_LOCATION_PROP_ID                 = 72,
    XCN_CERT_SOURCE_URL_PROP_ID                      = 73,
    XCN_CERT_NEW_KEY_PROP_ID                         = 74,
    XCN_CERT_FIRST_RESERVED_PROP_ID                  = 87,
    XCN_CERT_LAST_RESERVED_PROP_ID                   = 0x7fff,
    XCN_CERT_FIRST_USER_PROP_ID                      = 0x8000,
    XCN_CERT_LAST_USER_PROP_ID                       = 0xffff,
    XCN_CERT_STORE_LOCALIZED_NAME_PROP_ID            = 0x1000,
    XCN_CERT_CEP_PROP_ID                             = 87 
  } CERTENROLL_PROPERTYID;

  typedef enum CERTENROLL_OBJECTID {
    XCN_OID_NONE                                         = 0,
    XCN_OID_RSA                                          = 1,
    XCN_OID_PKCS                                         = 2,
    XCN_OID_RSA_HASH                                     = 3,
    XCN_OID_RSA_ENCRYPT                                  = 4,
    XCN_OID_PKCS_1                                       = 5,
    XCN_OID_PKCS_2                                       = 6,
    XCN_OID_PKCS_3                                       = 7,
    XCN_OID_PKCS_4                                       = 8,
    XCN_OID_PKCS_5                                       = 9,
    XCN_OID_PKCS_6                                       = 10,
    XCN_OID_PKCS_7                                       = 11,
    XCN_OID_PKCS_8                                       = 12,
    XCN_OID_PKCS_9                                       = 13,
    XCN_OID_PKCS_10                                      = 14,
    XCN_OID_PKCS_12                                      = 15,
    XCN_OID_RSA_RSA                                      = 16,
    XCN_OID_RSA_MD2RSA                                   = 17,
    XCN_OID_RSA_MD4RSA                                   = 18,
    XCN_OID_RSA_MD5RSA                                   = 19,
    XCN_OID_RSA_SHA1RSA                                  = 20,
    XCN_OID_RSA_SETOAEP_RSA                              = 21,
    XCN_OID_RSA_DH                                       = 22,
    XCN_OID_RSA_data                                     = 23,
    XCN_OID_RSA_signedData                               = 24,
    XCN_OID_RSA_envelopedData                            = 25,
    XCN_OID_RSA_signEnvData                              = 26,
    XCN_OID_RSA_digestedData                             = 27,
    XCN_OID_RSA_hashedData                               = 28,
    XCN_OID_RSA_encryptedData                            = 29,
    XCN_OID_RSA_emailAddr                                = 30,
    XCN_OID_RSA_unstructName                             = 31,
    XCN_OID_RSA_contentType                              = 32,
    XCN_OID_RSA_messageDigest                            = 33,
    XCN_OID_RSA_signingTime                              = 34,
    XCN_OID_RSA_counterSign                              = 35,
    XCN_OID_RSA_challengePwd                             = 36,
    XCN_OID_RSA_unstructAddr                             = 37,
    XCN_OID_RSA_extCertAttrs                             = 38,
    XCN_OID_RSA_certExtensions                           = 39,
    XCN_OID_RSA_SMIMECapabilities                        = 40,
    XCN_OID_RSA_preferSignedData                         = 41,
    XCN_OID_RSA_SMIMEalg                                 = 42,
    XCN_OID_RSA_SMIMEalgESDH                             = 43,
    XCN_OID_RSA_SMIMEalgCMS3DESwrap                      = 44,
    XCN_OID_RSA_SMIMEalgCMSRC2wrap                       = 45,
    XCN_OID_RSA_MD2                                      = 46,
    XCN_OID_RSA_MD4                                      = 47,
    XCN_OID_RSA_MD5                                      = 48,
    XCN_OID_RSA_RC2CBC                                   = 49,
    XCN_OID_RSA_RC4                                      = 50,
    XCN_OID_RSA_DES_EDE3_CBC                             = 51,
    XCN_OID_RSA_RC5_CBCPad                               = 52,
    XCN_OID_ANSI_X942                                    = 53,
    XCN_OID_ANSI_X942_DH                                 = 54,
    XCN_OID_X957                                         = 55,
    XCN_OID_X957_DSA                                     = 56,
    XCN_OID_X957_SHA1DSA                                 = 57,
    XCN_OID_DS                                           = 58,
    XCN_OID_DSALG                                        = 59,
    XCN_OID_DSALG_CRPT                                   = 60,
    XCN_OID_DSALG_HASH                                   = 61,
    XCN_OID_DSALG_SIGN                                   = 62,
    XCN_OID_DSALG_RSA                                    = 63,
    XCN_OID_OIW                                          = 64,
    XCN_OID_OIWSEC                                       = 65,
    XCN_OID_OIWSEC_md4RSA                                = 66,
    XCN_OID_OIWSEC_md5RSA                                = 67,
    XCN_OID_OIWSEC_md4RSA2                               = 68,
    XCN_OID_OIWSEC_desECB                                = 69,
    XCN_OID_OIWSEC_desCBC                                = 70,
    XCN_OID_OIWSEC_desOFB                                = 71,
    XCN_OID_OIWSEC_desCFB                                = 72,
    XCN_OID_OIWSEC_desMAC                                = 73,
    XCN_OID_OIWSEC_rsaSign                               = 74,
    XCN_OID_OIWSEC_dsa                                   = 75,
    XCN_OID_OIWSEC_shaDSA                                = 76,
    XCN_OID_OIWSEC_mdc2RSA                               = 77,
    XCN_OID_OIWSEC_shaRSA                                = 78,
    XCN_OID_OIWSEC_dhCommMod                             = 79,
    XCN_OID_OIWSEC_desEDE                                = 80,
    XCN_OID_OIWSEC_sha                                   = 81,
    XCN_OID_OIWSEC_mdc2                                  = 82,
    XCN_OID_OIWSEC_dsaComm                               = 83,
    XCN_OID_OIWSEC_dsaCommSHA                            = 84,
    XCN_OID_OIWSEC_rsaXchg                               = 85,
    XCN_OID_OIWSEC_keyHashSeal                           = 86,
    XCN_OID_OIWSEC_md2RSASign                            = 87,
    XCN_OID_OIWSEC_md5RSASign                            = 88,
    XCN_OID_OIWSEC_sha1                                  = 89,
    XCN_OID_OIWSEC_dsaSHA1                               = 90,
    XCN_OID_OIWSEC_dsaCommSHA1                           = 91,
    XCN_OID_OIWSEC_sha1RSASign                           = 92,
    XCN_OID_OIWDIR                                       = 93,
    XCN_OID_OIWDIR_CRPT                                  = 94,
    XCN_OID_OIWDIR_HASH                                  = 95,
    XCN_OID_OIWDIR_SIGN                                  = 96,
    XCN_OID_OIWDIR_md2                                   = 97,
    XCN_OID_OIWDIR_md2RSA                                = 98,
    XCN_OID_INFOSEC                                      = 99,
    XCN_OID_INFOSEC_sdnsSignature                        = 100,
    XCN_OID_INFOSEC_mosaicSignature                      = 101,
    XCN_OID_INFOSEC_sdnsConfidentiality                  = 102,
    XCN_OID_INFOSEC_mosaicConfidentiality                = 103,
    XCN_OID_INFOSEC_sdnsIntegrity                        = 104,
    XCN_OID_INFOSEC_mosaicIntegrity                      = 105,
    XCN_OID_INFOSEC_sdnsTokenProtection                  = 106,
    XCN_OID_INFOSEC_mosaicTokenProtection                = 107,
    XCN_OID_INFOSEC_sdnsKeyManagement                    = 108,
    XCN_OID_INFOSEC_mosaicKeyManagement                  = 109,
    XCN_OID_INFOSEC_sdnsKMandSig                         = 110,
    XCN_OID_INFOSEC_mosaicKMandSig                       = 111,
    XCN_OID_INFOSEC_SuiteASignature                      = 112,
    XCN_OID_INFOSEC_SuiteAConfidentiality                = 113,
    XCN_OID_INFOSEC_SuiteAIntegrity                      = 114,
    XCN_OID_INFOSEC_SuiteATokenProtection                = 115,
    XCN_OID_INFOSEC_SuiteAKeyManagement                  = 116,
    XCN_OID_INFOSEC_SuiteAKMandSig                       = 117,
    XCN_OID_INFOSEC_mosaicUpdatedSig                     = 118,
    XCN_OID_INFOSEC_mosaicKMandUpdSig                    = 119,
    XCN_OID_INFOSEC_mosaicUpdatedInteg                   = 120,
    XCN_OID_COMMON_NAME                                  = 121,
    XCN_OID_SUR_NAME                                     = 122,
    XCN_OID_DEVICE_SERIAL_NUMBER                         = 123,
    XCN_OID_COUNTRY_NAME                                 = 124,
    XCN_OID_LOCALITY_NAME                                = 125,
    XCN_OID_STATE_OR_PROVINCE_NAME                       = 126,
    XCN_OID_STREET_ADDRESS                               = 127,
    XCN_OID_ORGANIZATION_NAME                            = 128,
    XCN_OID_ORGANIZATIONAL_UNIT_NAME                     = 129,
    XCN_OID_TITLE                                        = 130,
    XCN_OID_DESCRIPTION                                  = 131,
    XCN_OID_SEARCH_GUIDE                                 = 132,
    XCN_OID_BUSINESS_CATEGORY                            = 133,
    XCN_OID_POSTAL_ADDRESS                               = 134,
    XCN_OID_POSTAL_CODE                                  = 135,
    XCN_OID_POST_OFFICE_BOX                              = 136,
    XCN_OID_PHYSICAL_DELIVERY_OFFICE_NAME                = 137,
    XCN_OID_TELEPHONE_NUMBER                             = 138,
    XCN_OID_TELEX_NUMBER                                 = 139,
    XCN_OID_TELETEXT_TERMINAL_IDENTIFIER                 = 140,
    XCN_OID_FACSIMILE_TELEPHONE_NUMBER                   = 141,
    XCN_OID_X21_ADDRESS                                  = 142,
    XCN_OID_INTERNATIONAL_ISDN_NUMBER                    = 143,
    XCN_OID_REGISTERED_ADDRESS                           = 144,
    XCN_OID_DESTINATION_INDICATOR                        = 145,
    XCN_OID_PREFERRED_DELIVERY_METHOD                    = 146,
    XCN_OID_PRESENTATION_ADDRESS                         = 147,
    XCN_OID_SUPPORTED_APPLICATION_CONTEXT                = 148,
    XCN_OID_MEMBER                                       = 149,
    XCN_OID_OWNER                                        = 150,
    XCN_OID_ROLE_OCCUPANT                                = 151,
    XCN_OID_SEE_ALSO                                     = 152,
    XCN_OID_USER_PASSWORD                                = 153,
    XCN_OID_USER_CERTIFICATE                             = 154,
    XCN_OID_CA_CERTIFICATE                               = 155,
    XCN_OID_AUTHORITY_REVOCATION_LIST                    = 156,
    XCN_OID_CERTIFICATE_REVOCATION_LIST                  = 157,
    XCN_OID_CROSS_CERTIFICATE_PAIR                       = 158,
    XCN_OID_GIVEN_NAME                                   = 159,
    XCN_OID_INITIALS                                     = 160,
    XCN_OID_DN_QUALIFIER                                 = 161,
    XCN_OID_DOMAIN_COMPONENT                             = 162,
    XCN_OID_PKCS_12_FRIENDLY_NAME_ATTR                   = 163,
    XCN_OID_PKCS_12_LOCAL_KEY_ID                         = 164,
    XCN_OID_PKCS_12_KEY_PROVIDER_NAME_ATTR               = 165,
    XCN_OID_LOCAL_MACHINE_KEYSET                         = 166,
    XCN_OID_PKCS_12_EXTENDED_ATTRIBUTES                  = 167,
    XCN_OID_KEYID_RDN                                    = 168,
    XCN_OID_AUTHORITY_KEY_IDENTIFIER                     = 169,
    XCN_OID_KEY_ATTRIBUTES                               = 170,
    XCN_OID_CERT_POLICIES_95                             = 171,
    XCN_OID_KEY_USAGE_RESTRICTION                        = 172,
    XCN_OID_SUBJECT_ALT_NAME                             = 173,
    XCN_OID_ISSUER_ALT_NAME                              = 174,
    XCN_OID_BASIC_CONSTRAINTS                            = 175,
    XCN_OID_KEY_USAGE                                    = 176,
    XCN_OID_PRIVATEKEY_USAGE_PERIOD                      = 177,
    XCN_OID_BASIC_CONSTRAINTS2                           = 178,
    XCN_OID_CERT_POLICIES                                = 179,
    XCN_OID_ANY_CERT_POLICY                              = 180,
    XCN_OID_AUTHORITY_KEY_IDENTIFIER2                    = 181,
    XCN_OID_SUBJECT_KEY_IDENTIFIER                       = 182,
    XCN_OID_SUBJECT_ALT_NAME2                            = 183,
    XCN_OID_ISSUER_ALT_NAME2                             = 184,
    XCN_OID_CRL_REASON_CODE                              = 185,
    XCN_OID_REASON_CODE_HOLD                             = 186,
    XCN_OID_CRL_DIST_POINTS                              = 187,
    XCN_OID_ENHANCED_KEY_USAGE                           = 188,
    XCN_OID_CRL_NUMBER                                   = 189,
    XCN_OID_DELTA_CRL_INDICATOR                          = 190,
    XCN_OID_ISSUING_DIST_POINT                           = 191,
    XCN_OID_FRESHEST_CRL                                 = 192,
    XCN_OID_NAME_CONSTRAINTS                             = 193,
    XCN_OID_POLICY_MAPPINGS                              = 194,
    XCN_OID_LEGACY_POLICY_MAPPINGS                       = 195,
    XCN_OID_POLICY_CONSTRAINTS                           = 196,
    XCN_OID_RENEWAL_CERTIFICATE                          = 197,
    XCN_OID_ENROLLMENT_NAME_VALUE_PAIR                   = 198,
    XCN_OID_ENROLLMENT_CSP_PROVIDER                      = 199,
    XCN_OID_OS_VERSION                                   = 200,
    XCN_OID_ENROLLMENT_AGENT                             = 201,
    XCN_OID_PKIX                                         = 202,
    XCN_OID_PKIX_PE                                      = 203,
    XCN_OID_AUTHORITY_INFO_ACCESS                        = 204,
    XCN_OID_BIOMETRIC_EXT                                = 205,
    XCN_OID_LOGOTYPE_EXT                                 = 206,
    XCN_OID_CERT_EXTENSIONS                              = 207,
    XCN_OID_NEXT_UPDATE_LOCATION                         = 208,
    XCN_OID_REMOVE_CERTIFICATE                           = 209,
    XCN_OID_CROSS_CERT_DIST_POINTS                       = 210,
    XCN_OID_CTL                                          = 211,
    XCN_OID_SORTED_CTL                                   = 212,
    XCN_OID_SERIALIZED                                   = 213,
    XCN_OID_NT_PRINCIPAL_NAME                            = 214,
    XCN_OID_PRODUCT_UPDATE                               = 215,
    XCN_OID_ANY_APPLICATION_POLICY                       = 216,
    XCN_OID_AUTO_ENROLL_CTL_USAGE                        = 217,
    XCN_OID_ENROLL_CERTTYPE_EXTENSION                    = 218,
    XCN_OID_CERT_MANIFOLD                                = 219,
    XCN_OID_CERTSRV_CA_VERSION                           = 220,
    XCN_OID_CERTSRV_PREVIOUS_CERT_HASH                   = 221,
    XCN_OID_CRL_VIRTUAL_BASE                             = 222,
    XCN_OID_CRL_NEXT_PUBLISH                             = 223,
    XCN_OID_KP_CA_EXCHANGE                               = 224,
    XCN_OID_KP_KEY_RECOVERY_AGENT                        = 225,
    XCN_OID_CERTIFICATE_TEMPLATE                         = 226,
    XCN_OID_ENTERPRISE_OID_ROOT                          = 227,
    XCN_OID_RDN_DUMMY_SIGNER                             = 228,
    XCN_OID_APPLICATION_CERT_POLICIES                    = 229,
    XCN_OID_APPLICATION_POLICY_MAPPINGS                  = 230,
    XCN_OID_APPLICATION_POLICY_CONSTRAINTS               = 231,
    XCN_OID_ARCHIVED_KEY_ATTR                            = 232,
    XCN_OID_CRL_SELF_CDP                                 = 233,
    XCN_OID_REQUIRE_CERT_CHAIN_POLICY                    = 234,
    XCN_OID_ARCHIVED_KEY_CERT_HASH                       = 235,
    XCN_OID_ISSUED_CERT_HASH                             = 236,
    XCN_OID_DS_EMAIL_REPLICATION                         = 237,
    XCN_OID_REQUEST_CLIENT_INFO                          = 238,
    XCN_OID_ENCRYPTED_KEY_HASH                           = 239,
    XCN_OID_CERTSRV_CROSSCA_VERSION                      = 240,
    XCN_OID_NTDS_REPLICATION                             = 241,
    XCN_OID_SUBJECT_DIR_ATTRS                            = 242,
    XCN_OID_PKIX_KP                                      = 243,
    XCN_OID_PKIX_KP_SERVER_AUTH                          = 244,
    XCN_OID_PKIX_KP_CLIENT_AUTH                          = 245,
    XCN_OID_PKIX_KP_CODE_SIGNING                         = 246,
    XCN_OID_PKIX_KP_EMAIL_PROTECTION                     = 247,
    XCN_OID_PKIX_KP_IPSEC_END_SYSTEM                     = 248,
    XCN_OID_PKIX_KP_IPSEC_TUNNEL                         = 249,
    XCN_OID_PKIX_KP_IPSEC_USER                           = 250,
    XCN_OID_PKIX_KP_TIMESTAMP_SIGNING                    = 251,
    XCN_OID_PKIX_KP_OCSP_SIGNING                         = 252,
    XCN_OID_PKIX_OCSP_NOCHECK                            = 253,
    XCN_OID_IPSEC_KP_IKE_INTERMEDIATE                    = 254,
    XCN_OID_KP_CTL_USAGE_SIGNING                         = 255,
    XCN_OID_KP_TIME_STAMP_SIGNING                        = 256,
    XCN_OID_SERVER_GATED_CRYPTO                          = 257,
    XCN_OID_SGC_NETSCAPE                                 = 258,
    XCN_OID_KP_EFS                                       = 259,
    XCN_OID_EFS_RECOVERY                                 = 260,
    XCN_OID_WHQL_CRYPTO                                  = 261,
    XCN_OID_NT5_CRYPTO                                   = 262,
    XCN_OID_OEM_WHQL_CRYPTO                              = 263,
    XCN_OID_EMBEDDED_NT_CRYPTO                           = 264,
    XCN_OID_ROOT_LIST_SIGNER                             = 265,
    XCN_OID_KP_QUALIFIED_SUBORDINATION                   = 266,
    XCN_OID_KP_KEY_RECOVERY                              = 267,
    XCN_OID_KP_DOCUMENT_SIGNING                          = 268,
    XCN_OID_KP_LIFETIME_SIGNING                          = 269,
    XCN_OID_KP_MOBILE_DEVICE_SOFTWARE                    = 270,
    XCN_OID_KP_SMART_DISPLAY                             = 271,
    XCN_OID_KP_CSP_SIGNATURE                             = 272,
    XCN_OID_DRM                                          = 273,
    XCN_OID_DRM_INDIVIDUALIZATION                        = 274,
    XCN_OID_LICENSES                                     = 275,
    XCN_OID_LICENSE_SERVER                               = 276,
    XCN_OID_KP_SMARTCARD_LOGON                           = 277,
    XCN_OID_YESNO_TRUST_ATTR                             = 278,
    XCN_OID_PKIX_POLICY_QUALIFIER_CPS                    = 279,
    XCN_OID_PKIX_POLICY_QUALIFIER_USERNOTICE             = 280,
    XCN_OID_CERT_POLICIES_95_QUALIFIER1                  = 281,
    XCN_OID_PKIX_ACC_DESCR                               = 282,
    XCN_OID_PKIX_OCSP                                    = 283,
    XCN_OID_PKIX_CA_ISSUERS                              = 284,
    XCN_OID_VERISIGN_PRIVATE_6_9                         = 285,
    XCN_OID_VERISIGN_ONSITE_JURISDICTION_HASH            = 286,
    XCN_OID_VERISIGN_BITSTRING_6_13                      = 287,
    XCN_OID_VERISIGN_ISS_STRONG_CRYPTO                   = 288,
    XCN_OID_NETSCAPE                                     = 289,
    XCN_OID_NETSCAPE_CERT_EXTENSION                      = 290,
    XCN_OID_NETSCAPE_CERT_TYPE                           = 291,
    XCN_OID_NETSCAPE_BASE_URL                            = 292,
    XCN_OID_NETSCAPE_REVOCATION_URL                      = 293,
    XCN_OID_NETSCAPE_CA_REVOCATION_URL                   = 294,
    XCN_OID_NETSCAPE_CERT_RENEWAL_URL                    = 295,
    XCN_OID_NETSCAPE_CA_POLICY_URL                       = 296,
    XCN_OID_NETSCAPE_SSL_SERVER_NAME                     = 297,
    XCN_OID_NETSCAPE_COMMENT                             = 298,
    XCN_OID_NETSCAPE_DATA_TYPE                           = 299,
    XCN_OID_NETSCAPE_CERT_SEQUENCE                       = 300,
    XCN_OID_CT_PKI_DATA                                  = 301,
    XCN_OID_CT_PKI_RESPONSE                              = 302,
    XCN_OID_PKIX_NO_SIGNATURE                            = 303,
    XCN_OID_CMC                                          = 304,
    XCN_OID_CMC_STATUS_INFO                              = 305,
    XCN_OID_CMC_IDENTIFICATION                           = 306,
    XCN_OID_CMC_IDENTITY_PROOF                           = 307,
    XCN_OID_CMC_DATA_RETURN                              = 308,
    XCN_OID_CMC_TRANSACTION_ID                           = 309,
    XCN_OID_CMC_SENDER_NONCE                             = 310,
    XCN_OID_CMC_RECIPIENT_NONCE                          = 311,
    XCN_OID_CMC_ADD_EXTENSIONS                           = 312,
    XCN_OID_CMC_ENCRYPTED_POP                            = 313,
    XCN_OID_CMC_DECRYPTED_POP                            = 314,
    XCN_OID_CMC_LRA_POP_WITNESS                          = 315,
    XCN_OID_CMC_GET_CERT                                 = 316,
    XCN_OID_CMC_GET_CRL                                  = 317,
    XCN_OID_CMC_REVOKE_REQUEST                           = 318,
    XCN_OID_CMC_REG_INFO                                 = 319,
    XCN_OID_CMC_RESPONSE_INFO                            = 320,
    XCN_OID_CMC_QUERY_PENDING                            = 321,
    XCN_OID_CMC_ID_POP_LINK_RANDOM                       = 322,
    XCN_OID_CMC_ID_POP_LINK_WITNESS                      = 323,
    XCN_OID_CMC_ID_CONFIRM_CERT_ACCEPTANCE               = 324,
    XCN_OID_CMC_ADD_ATTRIBUTES                           = 325,
    XCN_OID_LOYALTY_OTHER_LOGOTYPE                       = 326,
    XCN_OID_BACKGROUND_OTHER_LOGOTYPE                    = 327,
    XCN_OID_PKIX_OCSP_BASIC_SIGNED_RESPONSE              = 328,
    XCN_OID_PKCS_7_DATA                                  = 329,
    XCN_OID_PKCS_7_SIGNED                                = 330,
    XCN_OID_PKCS_7_ENVELOPED                             = 331,
    XCN_OID_PKCS_7_SIGNEDANDENVELOPED                    = 332,
    XCN_OID_PKCS_7_DIGESTED                              = 333,
    XCN_OID_PKCS_7_ENCRYPTED                             = 334,
    XCN_OID_PKCS_9_CONTENT_TYPE                          = 335,
    XCN_OID_PKCS_9_MESSAGE_DIGEST                        = 336,
    XCN_OID_CERT_PROP_ID_PREFIX                          = 337,
    XCN_OID_CERT_KEY_IDENTIFIER_PROP_ID                  = 338,
    XCN_OID_CERT_ISSUER_SERIAL_NUMBER_MD5_HASH_PROP_ID   = 339,
    XCN_OID_CERT_SUBJECT_NAME_MD5_HASH_PROP_ID           = 340,
    XCN_OID_CERT_MD5_HASH_PROP_ID                        = 341,
    XCN_OID_RSA_SHA256RSA                                = 342,
    XCN_OID_RSA_SHA384RSA                                = 343,
    XCN_OID_RSA_SHA512RSA                                = 344,
    XCN_OID_NIST_sha256                                  = 345,
    XCN_OID_NIST_sha384                                  = 346,
    XCN_OID_NIST_sha512                                  = 347,
    XCN_OID_RSA_MGF1                                     = 348,
    XCN_OID_ECC_PUBLIC_KEY                               = 349,
    XCN_OID_RSA_SSA_PSS                                  = 353,
    XCN_OID_ECDSA_SHA1                                   = 354,
    XCN_OID_ECDSA_SPECIFIED                              = 354 
  } CERTENROLL_OBJECTID;

  typedef enum EnrollmentCAProperty {
    CAPropCommonName           = 1,
    CAPropDistinguishedName    = 2,
    CAPropSanitizedName        = 3,
    CAPropSanitizedShortName   = 4,
    CAPropDNSName              = 5,
    CAPropCertificateTypes     = 6,
    CAPropCertificate          = 7,
    CAPropDescription          = 8,
    CAPropWebServers           = 9,
    CAPropSiteName             = 10,
    CAPropSecurity             = 11,
    CAPropRenewalOnly          = 12 
  } EnrollmentCAProperty;

  typedef enum EncodingType {
    XCN_CRYPT_STRING_BASE64HEADER          = 0,
    XCN_CRYPT_STRING_BASE64                = 0x1,
    XCN_CRYPT_STRING_BINARY                = 0x2,
    XCN_CRYPT_STRING_BASE64REQUESTHEADER   = 0x3,
    XCN_CRYPT_STRING_HEX                   = 0x4,
    XCN_CRYPT_STRING_HEXASCII              = 0x5,
    XCN_CRYPT_STRING_BASE64_ANY            = 0x6,
    XCN_CRYPT_STRING_ANY                   = 0x7,
    XCN_CRYPT_STRING_HEX_ANY               = 0x8,
    XCN_CRYPT_STRING_BASE64X509CRLHEADER   = 0x9,
    XCN_CRYPT_STRING_HEXADDR               = 0xa,
    XCN_CRYPT_STRING_HEXASCIIADDR          = 0xb,
    XCN_CRYPT_STRING_HEXRAW                = 0xc,
    XCN_CRYPT_STRING_NOCRLF                = 0x40000000,
    XCN_CRYPT_STRING_NOCR                  = 0x80000000 
  } EncodingType;

  typedef enum CommitTemplateFlags {
    CommitFlagSaveTemplateGenerateOID     = 1,
    CommitFlagSaveTemplateUseCurrentOID   = 2,
    CommitFlagSaveTemplateOverwrite       = 3,
    CommitFlagDeleteTemplate              = 4 
  } CommitTemplateFlags;

  typedef enum EnrollmentDisplayStatus {
    DisplayNo    = 0,
    DisplayYes   = 1 
  } EnrollmentDisplayStatus;

  typedef enum EnrollmentEnrollStatus {
    Enrolled                             = 0x00000001,
    EnrollPended                         = 0x00000002,
    EnrollUIDeferredEnrollmentRequired   = 0x00000004,
    EnrollError                          = 0x00000010,
    EnrollUnknown                        = 0x00000020,
    EnrollSkipped                        = 0x00000040,
    EnrollDenied                         = 0x00000100 
  } EnrollmentEnrollStatus;

#if (_WIN32_WINNT >= 0x0601)
  enum EnrollmentPolicyFlags {
    DisableGroupPolicyList   = 0x2,
    DisableUserServerList    = 0x4 
  };

  typedef enum EnrollmentPolicyServerPropertyFlags {
    DefaultNone           = 0x00000000,
    DefaultPolicyServer   = 0x00000001 
  } EnrollmentPolicyServerPropertyFlags;

#endif /*(_WIN32_WINNT >= 0x0601)*/

  typedef enum EnrollmentSelectionStatus {
    SelectedNo    = 0,
    SelectedYes   = 1 
  } EnrollmentSelectionStatus;

#if (_WIN32_WINNT >= 0x0601)

  typedef enum EnrollmentTemplateProperty {
    TemplatePropCommonName              = 1,
    TemplatePropFriendlyName            = 2,
    TemplatePropEKUs                    = 3,
    TemplatePropCryptoProviders         = 4,
    TemplatePropMajorRevision           = 5,
    TemplatePropDescription             = 6,
    TemplatePropKeySpec                 = 7,
    TemplatePropSchemaVersion           = 8,
    TemplatePropMinorRevision           = 9,
    TemplatePropRASignatureCount        = 10,
    TemplatePropMinimumKeySize          = 11,
    TemplatePropOID                     = 12,
    TemplatePropSupersede               = 13,
    TemplatePropRACertificatePolicies   = 14,
    TemplatePropRAEKUs                  = 15,
    TemplatePropCertificatePolicies     = 16,
    TemplatePropV1ApplicationPolicy     = 17,
    TemplatePropAsymmetricAlgorithm     = 18,
    TemplatePropKeySecurityDescriptor   = 19,
    TemplatePropSymmetricAlgorithm      = 20,
    TemplatePropSymmetricKeyLength      = 21,
    TemplatePropHashAlgorithm           = 22,
    TemplatePropEnrollmentFlags         = 23,
    TemplatePropSubjectNameFlags        = 24,
    TemplatePropPrivateKeyFlags         = 25,
    TemplatePropGeneralFlags            = 26,
    TemplatePropSecurityDescriptor      = 27,
    TemplatePropExtensions              = 28,
    TemplatePropValidityPeriod          = 29,
    TemplatePropRenewalPeriod           = 30 
  } EnrollmentTemplateProperty;
#endif /*(_WIN32_WINNT >= 0x0601)*/

  typedef enum InnerRequestLevel {
    LevelInnermost   = 0,
    LevelNext        = 1 
  } InnerRequestLevel;

  typedef enum InstallResponseRestrictionFlags {
    AllowNone                   = 0x00000000,
    AllowNoOutstandingRequest   = 0x00000001,
    AllowUntrustedCertificate   = 0x00000002,
    AllowUntrustedRoot          = 0x00000004 
  } InstallResponseRestrictionFlags;

  typedef enum KeyIdentifierHashAlgorithm {
    SKIHashDefault    = 0,
    SKIHashSha1       = 1,
    SKIHashCapiSha1   = 2 
  } KeyIdentifierHashAlgorithm;

  typedef enum ObjectIdGroupId {
    XCN_CRYPT_ANY_GROUP_ID                 = 0,
    XCN_CRYPT_HASH_ALG_OID_GROUP_ID        = 1,
    XCN_CRYPT_ENCRYPT_ALG_OID_GROUP_ID     = 2,
    XCN_CRYPT_PUBKEY_ALG_OID_GROUP_ID      = 3,
    XCN_CRYPT_SIGN_ALG_OID_GROUP_ID        = 4,
    XCN_CRYPT_RDN_ATTR_OID_GROUP_ID        = 5,
    XCN_CRYPT_EXT_OR_ATTR_OID_GROUP_ID     = 6,
    XCN_CRYPT_ENHKEY_USAGE_OID_GROUP_ID    = 7,
    XCN_CRYPT_POLICY_OID_GROUP_ID          = 8,
    XCN_CRYPT_TEMPLATE_OID_GROUP_ID        = 9,
    XCN_CRYPT_LAST_OID_GROUP_ID            = 9,
    XCN_CRYPT_FIRST_ALG_OID_GROUP_ID       = 1,
    XCN_CRYPT_LAST_ALG_OID_GROUP_ID        = 4,
    XCN_CRYPT_OID_DISABLE_SEARCH_DS_FLAG   = 0x80000000,
    XCN_CRYPT_KEY_LENGTH_MASK              = 0xffff0000 
  } ObjectIdGroupId;

  typedef enum ObjectIdPublicKeyFlags {
    XCN_CRYPT_OID_INFO_PUBKEY_ANY                = 0,
    XCN_CRYPT_OID_INFO_PUBKEY_SIGN_KEY_FLAG      = 0x80000000,
    XCN_CRYPT_OID_INFO_PUBKEY_ENCRYPT_KEY_FLAG   = 0x40000000 
  } ObjectIdPublicKeyFlags;

  typedef enum PFXExportOptions {
    PFXExportEEOnly          = 0,
    PFXExportChainNoRoot     = 1,
    PFXExportChainWithRoot   = 2 
  } PFXExportOptions;

  typedef enum Pkcs10AllowedSignatureTypes {
    AllowedKeySignature    = 0x1,
    AllowedNullSignature   = 0x2 
  } Pkcs10AllowedSignatureTypes;

  typedef enum PolicyQualifierType {
    PolicyQualifierTypeUnknown      = 0,
    PolicyQualifierTypeUrl          = 1,
    PolicyQualifierTypeUserNotice   = 2 
  } PolicyQualifierType;

  typedef enum PolicyServerUrlFlags {
    PsfNone                    = 0,
    PsfLocationGroupPolicy     = 1,
    PsfLocationRegistry        = 2,
    PsfUseClientId             = 4,
    PsfAutoEnrollmentEnabled   = 16,
    PsfAllowUnTrustedCA        = 32 
  } PolicyServerUrlFlags;

#if (_WIN32_WINNT >= 0x0601)

  typedef enum PolicyServerUrlPropertyID {
    PsPolicyID       = 0,
    PsFriendlyName   = 1 
  } PolicyServerUrlPropertyID;

#endif /*(_WIN32_WINNT >= 0x0601)*/

  typedef enum RequestClientInfoClientId {
    ClientIdNone             = 0,
    ClientIdXEnroll2003      = 1,
    ClientIdAutoEnroll2003   = 2,
    ClientIdWizard2003       = 3,
    ClientIdCertReq2003      = 4,
    ClientIdDefaultRequest   = 5,
    ClientIdAutoEnroll       = 6,
    ClientIdRequestWizard    = 7,
    ClientIdEOBO             = 8,
    ClientIdCertReq          = 9,
    ClientIdTest             = 10,
    ClientIdUserStart        = 1000 
  } RequestClientInfoClientId;

#if (_WIN32_WINNT >= 0x0601)

  typedef enum WebEnrollmentFlags {
    EnrollPrompt   = 0x00000001 
  } WebEnrollmentFlags;

#endif /*(_WIN32_WINNT >= 0x0601)*/

  typedef enum WebSecurityLevel {
    LevelUnsafe   = 0,
    LevelSafe     = 1 
  } WebSecurityLevel;

  typedef enum X500NameFlags {
    XCN_CERT_NAME_STR_NONE                        = 0,
    XCN_CERT_SIMPLE_NAME_STR                      = 1,
    XCN_CERT_OID_NAME_STR                         = 2,
    XCN_CERT_X500_NAME_STR                        = 3,
    XCN_CERT_XML_NAME_STR                         = 4,
    XCN_CERT_NAME_STR_SEMICOLON_FLAG              = 0x40000000,
    XCN_CERT_NAME_STR_NO_PLUS_FLAG                = 0x20000000,
    XCN_CERT_NAME_STR_NO_QUOTING_FLAG             = 0x10000000,
    XCN_CERT_NAME_STR_CRLF_FLAG                   = 0x8000000,
    XCN_CERT_NAME_STR_COMMA_FLAG                  = 0x4000000,
    XCN_CERT_NAME_STR_REVERSE_FLAG                = 0x2000000,
    XCN_CERT_NAME_STR_DISABLE_IE4_UTF8_FLAG       = 0x10000,
    XCN_CERT_NAME_STR_ENABLE_T61_UNICODE_FLAG     = 0x20000,
    XCN_CERT_NAME_STR_ENABLE_UTF8_UNICODE_FLAG    = 0x40000,
    XCN_CERT_NAME_STR_FORCE_UTF8_DIR_STR_FLAG     = 0x80000,
    XCN_CERT_NAME_STR_DISABLE_UTF8_DIR_STR_FLAG   = 0x100000 
  } X500NameFlags;

  typedef enum X509CertificateEnrollmentContext {
    ContextUser                        = 0x1,
    ContextMachine                     = 0x2,
    ContextAdministratorForceMachine   = 0x3 
  } X509CertificateEnrollmentContext;

#if (_WIN32_WINNT >= 0x0601)

  typedef enum X509CertificateTemplateEnrollmentFlag {
    EnrollmentIncludeSymmetricAlgorithms                  = CT_FLAG_INCLUDE_SYMMETRIC_ALGORITHMS,
    EnrollmentPendAllRequests                             = CT_FLAG_PEND_ALL_REQUESTS,
    EnrollmentPublishToKRAContainer                       = CT_FLAG_PUBLISH_TO_KRA_CONTAINER,
    EnrollmentPublishToDS                                 = CT_FLAG_PUBLISH_TO_DS,
    EnrollmentAutoEnrollmentCheckUserDSCertificate        = CT_FLAG_AUTO_ENROLLMENT_CHECK_USER_DS_CERTIFICATE,
    EnrollmentAutoEnrollment                              = CT_FLAG_AUTO_ENROLLMENT,
    EnrollmentDomainAuthenticationNotRequired             = CT_FLAG_DOMAIN_AUTHENTICATION_NOT_REQUIRED,
    EnrollmentPreviousApprovalValidateReenrollment        = CT_FLAG_PREVIOUS_APPROVAL_VALIDATE_REENROLLMENT,
    EnrollmentUserInteractionRequired                     = CT_FLAG_USER_INTERACTION_REQUIRED,
    EnrollmentAddTemplateName                             = CT_FLAG_ADD_TEMPLATE_NAME,
    EnrollmentRemoveInvalidCertificateFromPersonalStore   = CT_FLAG_REMOVE_INVALID_CERTIFICATE_FROM_PERSONAL_STORE,
    EnrollmentAllowEnrollOnBehalfOf                       = CT_FLAG_ALLOW_ENROLL_ON_BEHALF_OF,
    EnrollmentAddOCSPNoCheck                              = CT_FLAG_ADD_OCSP_NOCHECK,
    EnrollmentReuseKeyOnFullSmartCard                     = CT_FLAG_ENABLE_KEY_REUSE_ON_NT_TOKEN_KEYSET_STORAGE_FULL,
    EnrollmentNoRevocationInfoInCerts                     = CT_FLAG_NOREVOCATIONINFOINISSUEDCERTS,
    EnrollmentIncludeBasicConstraintsForEECerts           = CT_FLAG_INCLUDE_BASIC_CONSTRAINTS_FOR_EE_CERTS 
  } X509CertificateTemplateEnrollmentFlag;

  typedef enum X509CertificateTemplateGeneralFlag {
    GeneralMachineType    = CT_FLAG_MACHINE_TYPE,
    GeneralCA             = CT_FLAG_IS_CA,
    GeneralCrossCA        = CT_FLAG_IS_CROSS_CA,
    GeneralDefault        = CT_FLAG_IS_DEFAULT,
    GeneralModified       = CT_FLAG_IS_MODIFIED,
    GeneralDonotPersist   = CT_FLAG_DONOTPERSISTINDB 
  } X509CertificateTemplateGeneralFlag;

  typedef enum X509CertificateTemplatePrivateKeyFlag {
    PrivateKeyRequireArchival                      = CT_FLAG_REQUIRE_PRIVATE_KEY_ARCHIVAL,
    PrivateKeyExportable                           = CT_FLAG_EXPORTABLE_KEY,
    PrivateKeyRequireStrongKeyProtection           = CT_FLAG_STRONG_KEY_PROTECTION_REQUIRED,
    PrivateKeyRequireAlternateSignatureAlgorithm   = CT_FLAG_REQUIRE_ALTERNATE_SIGNATURE_ALGORITHM 
  } X509CertificateTemplatePrivateKeyFlag;

  typedef enum X509CertificateTemplateSubjectNameFlag {
    SubjectNameEnrolleeSupplies                    = CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT,
    SubjectNameRequireDirectoryPath                = CT_FLAG_SUBJECT_REQUIRE_DIRECTORY_PATH,
    SubjectNameRequireCommonName                   = CT_FLAG_SUBJECT_REQUIRE_COMMON_NAME,
    SubjectNameRequireEmail                        = CT_FLAG_SUBJECT_REQUIRE_EMAIL,
    SubjectNameRequireDNS                          = CT_FLAG_SUBJECT_REQUIRE_DNS_AS_CN,
    SubjectNameAndAlternativeNameOldCertSupplies   = CT_FLAG_OLD_CERT_SUPPLIES_SUBJECT_AND_ALT_NAME,
    SubjectAlternativeNameEnrolleeSupplies         = CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT_ALT_NAME,
    SubjectAlternativeNameRequireDirectoryGUID     = CT_FLAG_SUBJECT_ALT_REQUIRE_DIRECTORY_GUID,
    SubjectAlternativeNameRequireUPN               = CT_FLAG_SUBJECT_ALT_REQUIRE_UPN,
    SubjectAlternativeNameRequireEmail             = CT_FLAG_SUBJECT_ALT_REQUIRE_EMAIL,
    SubjectAlternativeNameRequireSPN               = CT_FLAG_SUBJECT_ALT_REQUIRE_SPN,
    SubjectAlternativeNameRequireDNS               = CT_FLAG_SUBJECT_ALT_REQUIRE_DNS,
    SubjectAlternativeNameRequireDomainDNS         = CT_FLAG_SUBJECT_ALT_REQUIRE_DOMAIN_DNS 
  } X509CertificateTemplateSubjectNameFlag;

  typedef enum X509EnrollmentPolicyExportFlags {
    ExportTemplates   = 0x1,
    ExportOIDs        = 0x2,
    ExportCAs         = 0x4 
  } X509EnrollmentPolicyExportFlags;

  typedef enum X509EnrollmentPolicyLoadOption {
    LoadOptionDefault                = 0,
    LoadOptionCacheOnly              = 1,
    LoadOptionReload                 = 2,
    LoadOptionRegisterForADChanges   = 4 
  } X509EnrollmentPolicyLoadOption;


#endif /*(_WIN32_WINNT >= 0x0601)*/

  typedef enum X509KeySpec {
    XCN_AT_NONE          = 0,
    XCN_AT_KEYEXCHANGE   = 1,
    XCN_AT_SIGNATURE     = 2 
  } X509KeySpec;

  typedef enum X509KeyUsageFlags {
    XCN_CERT_NO_KEY_USAGE                  = 0,
    XCN_CERT_DIGITAL_SIGNATURE_KEY_USAGE   = 0x80,
    XCN_CERT_NON_REPUDIATION_KEY_USAGE     = 0x40,
    XCN_CERT_KEY_ENCIPHERMENT_KEY_USAGE    = 0x20,
    XCN_CERT_DATA_ENCIPHERMENT_KEY_USAGE   = 0x10,
    XCN_CERT_KEY_AGREEMENT_KEY_USAGE       = 0x8,
    XCN_CERT_KEY_CERT_SIGN_KEY_USAGE       = 0x4,
    XCN_CERT_OFFLINE_CRL_SIGN_KEY_USAGE    = 0x2,
    XCN_CERT_CRL_SIGN_KEY_USAGE            = 0x2,
    XCN_CERT_ENCIPHER_ONLY_KEY_USAGE       = 0x1,
    XCN_CERT_DECIPHER_ONLY_KEY_USAGE       = ( 0x80 << 8 ) 
  } X509KeyUsageFlags;

  typedef enum X509PrivateKeyExportFlags {
    XCN_NCRYPT_ALLOW_EXPORT_NONE                = 0,
    XCN_NCRYPT_ALLOW_EXPORT_FLAG                = 0x1,
    XCN_NCRYPT_ALLOW_PLAINTEXT_EXPORT_FLAG      = 0x2,
    XCN_NCRYPT_ALLOW_ARCHIVING_FLAG             = 0x4,
    XCN_NCRYPT_ALLOW_PLAINTEXT_ARCHIVING_FLAG   = 0x8 
  } X509PrivateKeyExportFlags;

  typedef enum X509PrivateKeyProtection {
    XCN_NCRYPT_UI_NO_PROTECTION_FLAG           = 0,
    XCN_NCRYPT_UI_PROTECT_KEY_FLAG             = 0x1,
    XCN_NCRYPT_UI_FORCE_HIGH_PROTECTION_FLAG   = 0x2 
  } X509PrivateKeyProtection;

  typedef enum X509RequestType {
    TypeAny           = 0,
    TypePkcs10        = 1,
    TypePkcs7         = 2,
    TypeCmc           = 3,
    TypeCertificate   = 4 
  } X509RequestType;

  typedef enum X509RequestInheritOptions {
    InheritDefault                  = 0x00000000,
    InheritNewDefaultKey            = 0x00000001,
    InheritNewSimilarKey            = 0x00000002,
    InheritPrivateKey               = 0x00000003,
    InheritPublicKey                = 0x00000004,
    InheritKeyMask                  = 0x0000000f,
    InheritNone                     = 0x00000010,
    InheritRenewalCertificateFlag   = 0x00000020,
    InheritTemplateFlag             = 0x00000040,
    InheritSubjectFlag              = 0x00000080,
    InheritExtensionsFlag           = 0x00000100,
    InheritSubjectAltNameFlag       = 0x00000200,
    InheritValidityPeriodFlag       = 0x00000400 
  } X509RequestInheritOptions;

  typedef enum X509ProviderType {
    XCN_PROV_NONE            = 0,
    XCN_PROV_RSA_FULL        = 1,
    XCN_PROV_RSA_SIG         = 2,
    XCN_PROV_DSS             = 3,
    XCN_PROV_FORTEZZA        = 4,
    XCN_PROV_MS_EXCHANGE     = 5,
    XCN_PROV_SSL             = 6,
    XCN_PROV_RSA_SCHANNEL    = 12,
    XCN_PROV_DSS_DH          = 13,
    XCN_PROV_EC_ECDSA_SIG    = 14,
    XCN_PROV_EC_ECNRA_SIG    = 15,
    XCN_PROV_EC_ECDSA_FULL   = 16,
    XCN_PROV_EC_ECNRA_FULL   = 17,
    XCN_PROV_DH_SCHANNEL     = 18,
    XCN_PROV_SPYRUS_LYNKS    = 20,
    XCN_PROV_RNG             = 21,
    XCN_PROV_INTEL_SEC       = 22,
    XCN_PROV_REPLACE_OWF     = 23,
    XCN_PROV_RSA_AES         = 24 
  } X509ProviderType;

  typedef enum X509PrivateKeyVerify {
    VerifyNone              = 0,
    VerifySilent            = 1,
    VerifySmartCardNone     = 2,
    VerifySmartCardSilent   = 3,
    VerifyAllowUI           = 4 
  } X509PrivateKeyVerify;

  typedef enum X509PrivateKeyUsageFlags {
    XCN_NCRYPT_ALLOW_USAGES_NONE          = 0,
    XCN_NCRYPT_ALLOW_DECRYPT_FLAG         = 0x1,
    XCN_NCRYPT_ALLOW_SIGNING_FLAG         = 0x2,
    XCN_NCRYPT_ALLOW_KEY_AGREEMENT_FLAG   = 0x4,
    XCN_NCRYPT_ALLOW_ALL_USAGES           = 0xffffff 
  } X509PrivateKeyUsageFlags;
  
  typedef enum EncodingType {
  XCN_CRYPT_STRING_BASE64HEADER          = 0,
  XCN_CRYPT_STRING_BASE64                = 0x1,
  XCN_CRYPT_STRING_BINARY                = 0x2,
  XCN_CRYPT_STRING_BASE64REQUESTHEADER   = 0x3,
  XCN_CRYPT_STRING_HEX                   = 0x4,
  XCN_CRYPT_STRING_HEXASCII              = 0x5,
  XCN_CRYPT_STRING_BASE64_ANY            = 0x6,
  XCN_CRYPT_STRING_ANY                   = 0x7,
  XCN_CRYPT_STRING_HEX_ANY               = 0x8,
  XCN_CRYPT_STRING_BASE64X509CRLHEADER   = 0x9,
  XCN_CRYPT_STRING_HEXADDR               = 0xa,
  XCN_CRYPT_STRING_HEXASCIIADDR          = 0xb,
  XCN_CRYPT_STRING_HEXRAW                = 0xc,
  XCN_CRYPT_STRING_NOCRLF                = 0x40000000,
  XCN_CRYPT_STRING_NOCR                  = 0x80000000 
} EncodingType;

typedef enum EnrollmentDisplayStatus {
  DisplayNo    = 0,
  DisplayYes   = 1 
} EnrollmentDisplayStatus;

typedef enum EnrollmentEnrollStatus {
  Enrolled                             = 0x00000001,
  EnrollPended                         = 0x00000002,
  EnrollUIDeferredEnrollmentRequired   = 0x00000004,
  EnrollError                          = 0x00000010,
  EnrollUnknown                        = 0x00000020,
  EnrollSkipped                        = 0x00000040,
  EnrollDenied                         = 0x00000100 
} EnrollmentEnrollStatus;

typedef enum EnrollmentSelectionStatus {
  SelectedNo    = 0,
  SelectedYes   = 1 
} EnrollmentSelectionStatus;

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_CERTENROLL*/
