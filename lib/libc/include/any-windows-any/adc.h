/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#include <winapifamily.h>

#ifndef ADC_INCLUDED
#define ADC_INCLUDED

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#undef ADCDECLSPEC
#define ADCDECLSPEC __declspec (selectany)

extern const ADCDECLSPEC CLSID CLSID_FoxRowset = { 0x3ff292b6, 0xb204, 0x11cf,{ 0x8d, 0x23, 0, 0xaa, 0, 0x5f, 0xfe, 0x58 } };
extern const ADCDECLSPEC GUID DBPROPSET_ADC = { 0xb68e3cc1, 0x6deb, 0x11d0,{ 0x8d, 0xf6, 0x00, 0xaa, 0x00, 0x5f, 0xfe, 0x58 } };
extern const ADCDECLSPEC GUID IID_IAsyncAllowed = { 0xf5f2893a, 0xba9e, 0x11d0,{ 0xab, 0xb9, 0x0, 0xc0, 0x4f, 0xc2, 0x9f, 0x8f } };
extern const ADCDECLSPEC IID IID_IRowsetADCExtensions = { 0xf17324c4, 0x68e0, 0x11d0,{ 0xad, 0x45, 0x00, 0xc0, 0x4f, 0xc2, 0x98, 0x63 } };
extern const ADCDECLSPEC IID IID_IUpdateInfo = { 0xa0385420, 0x62b8, 0x11d1,{ 0x9a, 0x6, 0x0, 0xa0, 0xc9, 0x3, 0xaa, 0x45 } };
extern const ADCDECLSPEC IID IID_IRowsetSynchronize = { 0x1be41e60, 0x807a, 0x11d1,{ 0x9a, 0x14, 0x0, 0xa0, 0xc9, 0x3, 0xaa, 0x45 } };
extern const ADCDECLSPEC IID IID_IRowsetProperties = { 0x1e837070, 0xbcfc, 0x11d1,{ 0x9a, 0x2c, 0x0, 0xa0, 0xc9, 0x3, 0xaa, 0x45 } };

enum ADCPROPENUM {
  DBPROP_ADC_ASYNCHFETCHSIZE = 3,
  DBPROP_ADC_BATCHSIZE = 4,
  DBPROP_ADC_UPDATECRITERIA = 5,
  DBPROP_ADC_ASYNCHPREFETCHSIZE = 7,
  DBPROP_ADC_ASYNCHTHREADPRIORITY = 8,
  DBPROP_ADC_CACHECHILDROWS = 9,
  DBPROP_ADC_MAINTAINCHANGESTATUS = 10,
  DBPROP_ADC_AUTORECALC = 11,
  DBPROP_ADC_UNIQUETABLE = 13,
  DBPROP_ADC_UNIQUESCHEMA = 14,
  DBPROP_ADC_UNIQUECATALOG = 15,
  DBPROP_ADC_CUSTOMRESYNCH = 16,
  DBPROP_ADC_CEVER = 17,
  DBPROP_ADC_RESHAPENAME = 18,
  DBPROP_ADC_UPDATERESYNC = 19,
  DBPROP_ADC_BACKINGSTORE = 21,
  DBPROP_ADC_RELEASESHAPEONDISCONNECT = 22
};

#ifndef _COMMON_ADC_AND_ADO_PROPS_
#define _COMMON_ADC_AND_ADO_PROPS_

enum ADCPROP_UPDATECRITERIA_ENUM {
  adCriteriaKey = 0,
  adCriteriaAllCols = 1,
  adCriteriaUpdCols = 2,
  adCriteriaTimeStamp = 3
};

enum ADCPROP_ASYNCTHREADPRIORITY_ENUM {
  adPriorityLowest = 1,
  adPriorityBelowNormal = 2,
  adPriorityNormal = 3,
  adPriorityAboveNormal = 4,
  adPriorityHighest = 5
};

enum ADCPROP_UPDATERESYNC_ENUM {
  adResyncNone = 0,
  adResyncAutoIncrement = 0x1,
  adResyncConflicts = 0x2,
  adResyncUpdates = 0x4,
  adResyncInserts = 0x8,
  adResyncAll = 0x0f
};

enum ADCPROP_AUTORECALC_ENUM {
  adRecalcUpFront = 0,
  adRecalcAlways = 1
};
#endif

enum FOXROWSETPROPENUM {
  DBPROP_FOXTABLENAME = 0xeeff
};
#endif

#endif
