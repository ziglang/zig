/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _MQMAIL_H
#define _MQMAIL_H

#ifdef __cplusplus
extern "C" {
#endif

#include <windows.h>
#include <windowsx.h>
#include <ole2.h>

  DEFINE_GUID(CLSID_MQMailQueueType,0x5eadc0d0,0x7182,0x11cf,0xa8,0xff,0x00,0x20,0xaf,0xb8,0xfb,0x50);

  typedef enum MQMailRecipType_enum {
    MQMailRecip_TO,MQMailRecip_CC,MQMailRecip_BCC
  } MQMailRecipType;

  typedef struct MQMailRecip_tag {
    LPSTR szName;
    LPSTR szQueueLabel;
    LPSTR szAddress;
    MQMailRecipType iType;
    LPFILETIME pftDeliveryTime;
    LPSTR szNonDeliveryReason;
  } MQMailRecip,*LPMQMailRecip;

  typedef struct MQMailRecipList_tag {
    ULONG cRecips;
    LPMQMailRecip *apRecip;
  } MQMailRecipList,*LPMQMailRecipList;

  typedef enum MQMailFormFieldType_enum {
    MQMailFormField_BOOL,MQMailFormField_STRING,MQMailFormField_LONG,MQMailFormField_CURRENCY,MQMailFormField_DOUBLE
  } MQMailFormFieldType;

  typedef union MQMailFormFieldData_tag {
    WINBOOL b;
    LPSTR lpsz;
    LONG l;
    CY cy;
    double dbl;
  } MQMailFormFieldData,*LPMQMailFormFieldData;

  typedef struct MQMailFormField_tag {
    LPSTR szName;
    MQMailFormFieldType iType;
    MQMailFormFieldData Value;
  } MQMailFormField,*LPMQMailFormField;

  typedef struct MQMailFormFieldList_tag {
    ULONG cFields;
    LPMQMailFormField *apField;
  } MQMailFormFieldList,*LPMQMailFormFieldList;

  typedef enum MQMailEMailType_enum {
    MQMailEMail_MESSAGE,MQMailEMail_FORM,MQMailEMail_TNEF,MQMailEMail_DELIVERY_REPORT,MQMailEMail_NON_DELIVERY_REPORT
  } MQMailEMailType;

  typedef struct MQMailMessageData_tag {
    LPSTR szText;
  } MQMailMessageData,*LPMQMailMessageData;

  typedef struct MQMailFormData_tag {
    LPSTR szName;
    LPMQMailFormFieldList pFields;
  } MQMailFormData,*LPMQMailFormData;

  typedef struct MQMailTnefData_tag {
    ULONG cbData;
    LPBYTE lpbData;
  } MQMailTnefData,*LPMQMailTnefData;

  typedef struct MQMailDeliveryReportData_tag {
    LPMQMailRecipList pDeliveredRecips;
    LPSTR szOriginalSubject;
    LPFILETIME pftOriginalDate;
  } MQMailDeliveryReportData,*LPMQMailDeliveryReportData;

  typedef struct MQMailEMail_tag MQMailEMail,*LPMQMailEMail;
  typedef struct MQMailNonDeliveryReportData_tag {
    LPMQMailRecipList pNonDeliveredRecips;
    LPMQMailEMail pOriginalEMail;
  } MQMailNonDeliveryReportData,*LPMQMailNonDeliveryReportData;

  typedef struct MQMailEMail_tag {
    LPMQMailRecip pFrom;
    LPSTR szSubject;
    WINBOOL fRequestDeliveryReport;
    WINBOOL fRequestNonDeliveryReport;
    LPFILETIME pftDate;
    LPMQMailRecipList pRecips;
    MQMailEMailType iType;
    __C89_NAMELESS union {
      MQMailFormData form;
      MQMailMessageData message;
      MQMailTnefData tnef;
      MQMailDeliveryReportData DeliveryReport;
      MQMailNonDeliveryReportData NonDeliveryReport;
    };
    LPVOID pReserved;
  } MQMailEMail,*LPMQMailEMail;

  STDAPI MQMailComposeBody(LPMQMailEMail pEMail,ULONG *pcbBuffer,LPBYTE *ppbBuffer);
  STDAPI MQMailParseBody(ULONG cbBuffer,LPBYTE pbBuffer,LPMQMailEMail *ppEMail);
  STDAPI_(void) MQMailFreeMemory(LPVOID lpBuffer);

#ifdef __cplusplus
}
#endif
#endif
