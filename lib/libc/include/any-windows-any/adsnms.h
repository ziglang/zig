/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
#ifdef __cplusplus
extern "C" {
#endif

#define NAMESPACE_CLASS_NAME TEXT ("Namespace")
#define COUNTRY_CLASS_NAME TEXT ("Country")
#define LOCALITY_CLASS_NAME TEXT ("Locality")
#define ORGANIZATION_CLASS_NAME TEXT ("Organization")
#define ORGANIZATIONUNIT_CLASS_NAME TEXT ("Organizational Unit")
#define DOMAIN_CLASS_NAME TEXT ("Domain")
#define COMPUTER_CLASS_NAME TEXT ("Computer")
#define USER_CLASS_NAME TEXT ("User")
#define GROUP_CLASS_NAME TEXT ("Group")
#define GLOBALGROUP_CLASS_NAME TEXT ("GlobalGroup")
#define LOCALGROUP_CLASS_NAME TEXT ("LocalGroup")
#define SERVICE_CLASS_NAME TEXT ("Service")
#define FILESERVICE_CLASS_NAME TEXT ("FileService")
#define SESSION_CLASS_NAME TEXT ("Session")
#define RESOURCE_CLASS_NAME TEXT ("Resource")
#define FILESHARE_CLASS_NAME TEXT ("FileShare")
#define PRINTER_CLASS_NAME TEXT ("PrintQueue")
#define PRINTJOB_CLASS_NAME TEXT ("PrintJob")
#define SCHEMA_CLASS_NAME TEXT ("Schema")
#define CLASS_CLASS_NAME TEXT ("Class")
#define PROPERTY_CLASS_NAME TEXT ("Property")
#define SYNTAX_CLASS_NAME TEXT ("Syntax")
#define ROOTDSE_CLASS_NAME TEXT ("RootDSE")

#define NO_SCHEMA TEXT ("")
#define DOMAIN_SCHEMA_NAME TEXT ("Domain")
#define COMPUTER_SCHEMA_NAME TEXT ("Computer")
#define USER_SCHEMA_NAME TEXT ("User")
#define GROUP_SCHEMA_NAME TEXT ("Group")
#define GLOBALGROUP_SCHEMA_NAME TEXT ("GlobalGroup")
#define LOCALGROUP_SCHEMA_NAME TEXT ("LocalGroup")
#define SERVICE_SCHEMA_NAME TEXT ("Service")
#define PRINTER_SCHEMA_NAME TEXT ("PrintQueue")
#define PRINTJOB_SCHEMA_NAME TEXT ("PrintJob")
#define FILESERVICE_SCHEMA_NAME TEXT ("FileService")
#define SESSION_SCHEMA_NAME TEXT ("Session")
#define RESOURCE_SCHEMA_NAME TEXT ("Resource")
#define FILESHARE_SCHEMA_NAME TEXT ("FileShare")
#define FPNW_FILESERVICE_SCHEMA_NAME TEXT ("FPNWFileService")
#define FPNW_SESSION_SCHEMA_NAME TEXT ("FPNWSession")
#define FPNW_RESOURCE_SCHEMA_NAME TEXT ("FPNWResource")
#define FPNW_FILESHARE_SCHEMA_NAME TEXT ("FPNWFileShare")

#ifdef __cplusplus
}
#endif
#endif
