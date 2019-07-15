/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#ifndef INCLUDING_ADOGUIDS
#error Include via adoguids.h header only
#endif

#define MAXAVAILABLEGUID 0x570
#define MAXAVAILABLEGUIDALL 0x57f

#define LIBID_ADO LIBID_ADO60
#define LIBID_ADOR LIBID_ADOR20
#define LIBID_CADO10 LIBID_ADO20
#define LIBID_CADOR10 LIBID_ADOR20

#define CLSID_ADO GUID_BUILDER (CLSID_ADO, 0000051a, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define CLSID_CADOCommand GUID_BUILDER (CLSID_CADOCommand, 00000507, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define CLSID_CADOConnection GUID_BUILDER (CLSID_CADOConnection, 00000514, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define CLSID_CADOError GUID_BUILDER (CLSID_CADOError, 00000541, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define CLSID_CADOErrorLookup GUID_BUILDER (CLSID_CADOErrorLookup, 00000542, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define CLSID_CADOField GUID_BUILDER (CLSID_CADOField, 0000053a, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define CLSID_CADOParameter GUID_BUILDER (CLSID_CADOParameter, 0000050b, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define CLSID_CADORecField GUID_BUILDER (CLSID_CADORecField, 00000561, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define CLSID_CADORecord GUID_BUILDER (CLSID_CADORecord, 00000560, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define CLSID_CADORecordset GUID_BUILDER (CLSID_CADORecordset, 00000535, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define CLSID_CADOStream GUID_BUILDER (CLSID_CADOStream, 00000566, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID__ADO GUID_BUILDER (IID__ADO, 00000534, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_ConnectionEvents GUID_BUILDER (IID_ConnectionEvents, 00000400, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_ConnectionEventsVt GUID_BUILDER (IID_ConnectionEventsVt, 00000402, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumAffect GUID_BUILDER (IID_EnumAffect, 00000543, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumCEResync GUID_BUILDER (IID_EnumCEResync, 00000553, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumCommandType GUID_BUILDER (IID_EnumCommandType, 0000052e, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumCompare GUID_BUILDER (IID_EnumCompare, 00000545, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumConnectMode GUID_BUILDER (IID_EnumConnectMode, 00000521, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumConnectOption GUID_BUILDER (IID_EnumConnectOption, 00000541, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumConnectPrompt GUID_BUILDER (IID_EnumConnectPrompt, 00000520, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumCopyRecordOptions GUID_BUILDER (IID_EnumCopyRecordOptions, 00000574, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumCursorLocation GUID_BUILDER (IID_EnumCursorLocation, 0000052f, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumCursorOption GUID_BUILDER (IID_EnumCursorOption, 0000051c, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumCursorType GUID_BUILDER (IID_EnumCursorType, 0000051b, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumDataType GUID_BUILDER (IID_EnumDataType, 0000051f, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumEditMode GUID_BUILDER (IID_EnumEditMode, 00000526, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumErrorValue GUID_BUILDER (IID_EnumErrorValue, 0000052a, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumEventReason GUID_BUILDER (IID_EnumEventReason, 00000531, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumEventStatus GUID_BUILDER (IID_EnumEventStatus, 00000530, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumExecuteOption GUID_BUILDER (IID_EnumExecuteOption, 0000051e, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumFieldAttribute GUID_BUILDER (IID_EnumFieldAttribute, 00000525, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumFieldStatus GUID_BUILDER (IID_EnumFieldStatus, 0000057e, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumFilterCriteria GUID_BUILDER (IID_EnumFilterCriteria, 0000052d, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumFilterGroup GUID_BUILDER (IID_EnumFilterGroup, 00000546, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumGetRowsOption GUID_BUILDER (IID_EnumGetRowsOption, 00000542, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumIsolationLevel GUID_BUILDER (IID_EnumIsolationLevel, 00000523, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumLineSeparator GUID_BUILDER (IID_EnumLineSeparator, 00000577, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumLockType GUID_BUILDER (IID_EnumLockType, 0000051d, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumMarshalOptions GUID_BUILDER (IID_EnumMarshalOptions, 00000540, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumMode GUID_BUILDER (IID_EnumMode, 00000575, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumMoveRecordOptions GUID_BUILDER (IID_EnumMoveRecordOptions, 00000573, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumObjectState GUID_BUILDER (IID_EnumObjectState, 00000532, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumParameterAttributes GUID_BUILDER (IID_EnumParameterAttributes, 0000052b, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumParameterDirection GUID_BUILDER (IID_EnumParameterDirection, 0000052c, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumPersistFormat GUID_BUILDER (IID_EnumPersistFormat, 00000548, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumPosition GUID_BUILDER (IID_EnumPosition, 00000528, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumPrepareOption GUID_BUILDER (IID_EnumPrepareOption, 00000522, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumPropertyAttributes GUID_BUILDER (IID_EnumPropertyAttributes, 00000529, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumRDSAsyncThreadPriority GUID_BUILDER (IID_EnumRDSAsyncThreadPriority, 0000054b, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumRDSAutoRecalc GUID_BUILDER (IID_EnumRDSAutoRecalc, 00000554, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumRDSUpdateCriteria GUID_BUILDER (IID_EnumRDSUpdateCriteria, 0000054a, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumRecordCreateOptions GUID_BUILDER (IID_EnumRecordCreateOptions, 00000570, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumRecordOpenOptions GUID_BUILDER (IID_EnumRecordOpenOptions, 00000571, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumRecordStatus GUID_BUILDER (IID_EnumRecordStatus, 00000527, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumRecordType GUID_BUILDER (IID_EnumRecordType, 0000057d, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumResync GUID_BUILDER (IID_EnumResync, 00000544, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumSaveOptions GUID_BUILDER (IID_EnumSaveOptions, 0000057c, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumSchema GUID_BUILDER (IID_EnumSchema, 00000533, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumSearchDirection GUID_BUILDER (IID_EnumSearchDirection, 00000547, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumSeek GUID_BUILDER (IID_EnumSeek, 00000552, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumStreamOpenOptions GUID_BUILDER (IID_EnumStreamOpenOptions, 0000057a, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumStreamType GUID_BUILDER (IID_EnumStreamType, 00000576, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumStreamWrite GUID_BUILDER (IID_EnumStreamWrite, 0000057b, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumStringFormat GUID_BUILDER (IID_EnumStringFormat, 00000549, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_EnumXactAttribute GUID_BUILDER (IID_EnumXactAttribute, 00000524, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADO10StdObject GUID_BUILDER (IID_IADO10StdObject, 00000534, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOClass GUID_BUILDER (IID_IADOClass, 00000560, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOCollection GUID_BUILDER (IID_IADOCollection, 00000512, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOCommand GUID_BUILDER (IID_IADOCommand, B08400BD, F9D1, 4d02, B8, 56, 71, D5, DB, A1, 23, E9)
#define IID_IADOCommand15 GUID_BUILDER (IID_IADOCommand15, 00000508, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOCommand25 GUID_BUILDER (IID_IADOCommand25, 0000054e, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOCommandConstruction GUID_BUILDER (IID_IADOCommandConstruction, 00000517, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOCommands GUID_BUILDER (IID_IADOCommands, 00000509, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOConnection GUID_BUILDER (IID_IADOConnection, 00000550, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOConnection15 GUID_BUILDER (IID_IADOConnection15, 00000515, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOConnectionConstruction GUID_BUILDER (IID_IADOConnectionConstruction, 00000551, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOConnectionConstruction15 GUID_BUILDER (IID_IADOConnectionConstruction15, 00000516, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOConnectionEvents GUID_BUILDER (IID_IADOConnectionEvents, 00000400, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOConnectionEventsVt GUID_BUILDER (IID_IADOConnectionEventsVt, 00000402, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOConnections GUID_BUILDER (IID_IADOConnections, 00000518, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOCustomError GUID_BUILDER (IID_IADOCustomError, 00000519, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADODynaCollection GUID_BUILDER (IID_IADODynaCollection, 00000513, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOError GUID_BUILDER (IID_IADOError, 00000500, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOErrors GUID_BUILDER (IID_IADOErrors, 00000501, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOField GUID_BUILDER (IID_IADOField, 00000569, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOField15 GUID_BUILDER (IID_IADOField15, 00000505, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOField20 GUID_BUILDER (IID_IADOField20, 0000054c, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOFields GUID_BUILDER (IID_IADOFields, 00000564, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOFields15 GUID_BUILDER (IID_IADOFields15, 00000506, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOFields20 GUID_BUILDER (IID_IADOFields20, 0000054d, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOParameter GUID_BUILDER (IID_IADOParameter, 0000050c, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOParameters GUID_BUILDER (IID_IADOParameters, 0000050d, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOProperties GUID_BUILDER (IID_IADOProperties, 00000504, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOProperty GUID_BUILDER (IID_IADOProperty, 00000503, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADORecord GUID_BUILDER (IID_IADORecord, 00000562, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADORecord25 GUID_BUILDER (IID_IADORecord25, 00000562, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADORecord26 GUID_BUILDER (IID_IADORecord26, 00000563, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADORecordConstruction GUID_BUILDER (IID_IADORecordConstruction, 00000567, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADORecordGroup GUID_BUILDER (IID_IADORecordGroup, 00000511, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADORecordset GUID_BUILDER (IID_IADORecordset, 00000556, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADORecordset15 GUID_BUILDER (IID_IADORecordset15, 0000050e, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADORecordset20 GUID_BUILDER (IID_IADORecordset20, 0000054f, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADORecordset21 GUID_BUILDER (IID_IADORecordset21, 00000555, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADORecordset25 GUID_BUILDER (IID_IADORecordset25, 00000556, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADORecordsetConstruction GUID_BUILDER (IID_IADORecordsetConstruction, 00000283, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADORecordsetEvents GUID_BUILDER (IID_IADORecordsetEvents, 00000266, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADORecordsetEventsVt GUID_BUILDER (IID_IADORecordsetEventsVt, 00000403, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADORecordsets GUID_BUILDER (IID_IADORecordsets, 0000050f, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOStream GUID_BUILDER (IID_IADOStream, 00000565, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOStreamConstruction GUID_BUILDER (IID_IADOStreamConstruction, 00000568, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_ICMemStreamProperties GUID_BUILDER (IID_ICMemStreamProperties, FF184014, B5D3, 4310, AB, F0, 9b, 70, 45, A2, CF, 17)
#define IID_IPrivErrors GUID_BUILDER (IID_IPrivErrors, 00000502, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define LIBID_ADO20 GUID_BUILDER (LIBID_ADO20, 00000200, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define LIBID_ADO21 GUID_BUILDER (LIBID_ADO21, 00000201, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define LIBID_ADO25 GUID_BUILDER (LIBID_ADO25, 00000205, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define LIBID_ADO26 GUID_BUILDER (LIBID_ADO26, 00000206, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define LIBID_ADO27 GUID_BUILDER (LIBID_ADO27, EF53050B, 882e, 4776, B6, 43, ED, A4, 72, E8, E3, F2)
#define LIBID_ADO28 GUID_BUILDER (LIBID_ADO28, 2a75196c, D9EB, 4129, B8, 03, 93, 13, 27, F7, 2d, 5c)
#define LIBID_ADO60 GUID_BUILDER (LIBID_ADO60, B691E011, 1797, 432e, 90, 7a, 4d, 8c, 69, 33, 91, 29)
#define LIBID_ADOR20 GUID_BUILDER (LIBID_ADOR20, 00000300, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define LIBID_ADOR25 GUID_BUILDER (LIBID_ADOR25, 00000305, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)

#ifdef IMMEDIATE_GUID_USE
CLSID_ADO;
CLSID_CADOCommand;
CLSID_CADOConnection;
CLSID_CADOError;
CLSID_CADOErrorLookup;
CLSID_CADOField;
CLSID_CADOParameter;
CLSID_CADORecField;
CLSID_CADORecord;
CLSID_CADORecordset;
CLSID_CADOStream;
IID__ADO;
IID_ConnectionEvents;
IID_ConnectionEventsVt;
IID_EnumAffect;
IID_EnumCEResync;
IID_EnumCommandType;
IID_EnumCompare;
IID_EnumConnectMode;
IID_EnumConnectOption;
IID_EnumConnectPrompt;
IID_EnumCopyRecordOptions;
IID_EnumCursorLocation;
IID_EnumCursorOption;
IID_EnumCursorType;
IID_EnumDataType;
IID_EnumEditMode;
IID_EnumErrorValue;
IID_EnumEventReason;
IID_EnumEventStatus;
IID_EnumExecuteOption;
IID_EnumFieldAttribute;
IID_EnumFieldStatus;
IID_EnumFilterCriteria;
IID_EnumFilterGroup;
IID_EnumGetRowsOption;
IID_EnumIsolationLevel;
IID_EnumLineSeparator;
IID_EnumLockType;
IID_EnumMarshalOptions;
IID_EnumMode;
IID_EnumMoveRecordOptions;
IID_EnumObjectState;
IID_EnumParameterAttributes;
IID_EnumParameterDirection;
IID_EnumPersistFormat;
IID_EnumPosition;
IID_EnumPrepareOption;
IID_EnumPropertyAttributes;
IID_EnumRDSAsyncThreadPriority;
IID_EnumRDSAutoRecalc;
IID_EnumRDSUpdateCriteria;
IID_EnumRecordCreateOptions;
IID_EnumRecordOpenOptions;
IID_EnumRecordStatus;
IID_EnumRecordType;
IID_EnumResync;
IID_EnumSaveOptions;
IID_EnumSchema;
IID_EnumSearchDirection;
IID_EnumSeek;
IID_EnumStreamOpenOptions;
IID_EnumStreamType;
IID_EnumStreamWrite;
IID_EnumStringFormat;
IID_EnumXactAttribute;
IID_IADO10StdObject;
IID_IADOClass;
IID_IADOCollection;
IID_IADOCommand;
IID_IADOCommand15;
IID_IADOCommand25;
IID_IADOCommandConstruction;
IID_IADOCommands;
IID_IADOConnection;
IID_IADOConnection15;
IID_IADOConnectionConstruction;
IID_IADOConnectionConstruction15;
IID_IADOConnectionEvents;
IID_IADOConnectionEventsVt;
IID_IADOConnections;
IID_IADOCustomError;
IID_IADODynaCollection;
IID_IADOError;
IID_IADOErrors;
IID_IADOField;
IID_IADOField15;
IID_IADOField20;
IID_IADOFields;
IID_IADOFields15;
IID_IADOFields20;
IID_IADOParameter;
IID_IADOParameters;
IID_IADOProperties;
IID_IADOProperty;
IID_IADORecord;
IID_IADORecord25;
IID_IADORecord26;
IID_IADORecordConstruction;
IID_IADORecordGroup;
IID_IADORecordset;
IID_IADORecordset15;
IID_IADORecordset20;
IID_IADORecordset21;
IID_IADORecordset25;
IID_IADORecordsetConstruction;
IID_IADORecordsetEvents;
IID_IADORecordsetEventsVt;
IID_IADORecordsets;
IID_IADOStream;
IID_IADOStreamConstruction;
IID_ICMemStreamProperties;
IID_IPrivErrors;
LIBID_ADO20;
LIBID_ADO21;
LIBID_ADO25;
LIBID_ADO26;
LIBID_ADO27;
LIBID_ADO28;
LIBID_ADO60;
LIBID_ADOR20;
LIBID_ADOR25;

#undef CLSID_ADO
#undef CLSID_CADOCommand
#undef CLSID_CADOConnection
#undef CLSID_CADOError
#undef CLSID_CADOErrorLookup
#undef CLSID_CADOField
#undef CLSID_CADOParameter
#undef CLSID_CADORecField
#undef CLSID_CADORecord
#undef CLSID_CADORecordset
#undef CLSID_CADOStream
#undef IID__ADO
#undef IID_ConnectionEvents
#undef IID_ConnectionEventsVt
#undef IID_EnumAffect
#undef IID_EnumCEResync
#undef IID_EnumCommandType
#undef IID_EnumCompare
#undef IID_EnumConnectMode
#undef IID_EnumConnectOption
#undef IID_EnumConnectPrompt
#undef IID_EnumCopyRecordOptions
#undef IID_EnumCursorLocation
#undef IID_EnumCursorOption
#undef IID_EnumCursorType
#undef IID_EnumDataType
#undef IID_EnumEditMode
#undef IID_EnumErrorValue
#undef IID_EnumEventReason
#undef IID_EnumEventStatus
#undef IID_EnumExecuteOption
#undef IID_EnumFieldAttribute
#undef IID_EnumFieldStatus
#undef IID_EnumFilterCriteria
#undef IID_EnumFilterGroup
#undef IID_EnumGetRowsOption
#undef IID_EnumIsolationLevel
#undef IID_EnumLineSeparator
#undef IID_EnumLockType
#undef IID_EnumMarshalOptions
#undef IID_EnumMode
#undef IID_EnumMoveRecordOptions
#undef IID_EnumObjectState
#undef IID_EnumParameterAttributes
#undef IID_EnumParameterDirection
#undef IID_EnumPersistFormat
#undef IID_EnumPosition
#undef IID_EnumPrepareOption
#undef IID_EnumPropertyAttributes
#undef IID_EnumRDSAsyncThreadPriority
#undef IID_EnumRDSAutoRecalc
#undef IID_EnumRDSUpdateCriteria
#undef IID_EnumRecordCreateOptions
#undef IID_EnumRecordOpenOptions
#undef IID_EnumRecordStatus
#undef IID_EnumRecordType
#undef IID_EnumResync
#undef IID_EnumSaveOptions
#undef IID_EnumSchema
#undef IID_EnumSearchDirection
#undef IID_EnumSeek
#undef IID_EnumStreamOpenOptions
#undef IID_EnumStreamType
#undef IID_EnumStreamWrite
#undef IID_EnumStringFormat
#undef IID_EnumXactAttribute
#undef IID_IADO10StdObject
#undef IID_IADOClass
#undef IID_IADOCollection
#undef IID_IADOCommand
#undef IID_IADOCommand15
#undef IID_IADOCommand25
#undef IID_IADOCommandConstruction
#undef IID_IADOCommands
#undef IID_IADOConnection
#undef IID_IADOConnection15
#undef IID_IADOConnectionConstruction
#undef IID_IADOConnectionConstruction15
#undef IID_IADOConnectionEvents
#undef IID_IADOConnectionEventsVt
#undef IID_IADOConnections
#undef IID_IADOCustomError
#undef IID_IADODynaCollection
#undef IID_IADOError
#undef IID_IADOErrors
#undef IID_IADOField
#undef IID_IADOField15
#undef IID_IADOField20
#undef IID_IADOFields
#undef IID_IADOFields15
#undef IID_IADOFields20
#undef IID_IADOParameter
#undef IID_IADOParameters
#undef IID_IADOProperties
#undef IID_IADOProperty
#undef IID_IADORecord
#undef IID_IADORecord25
#undef IID_IADORecord26
#undef IID_IADORecordConstruction
#undef IID_IADORecordGroup
#undef IID_IADORecordset
#undef IID_IADORecordset15
#undef IID_IADORecordset20
#undef IID_IADORecordset21
#undef IID_IADORecordset25
#undef IID_IADORecordsetConstruction
#undef IID_IADORecordsetEvents
#undef IID_IADORecordsetEventsVt
#undef IID_IADORecordsets
#undef IID_IADOStream
#undef IID_IADOStreamConstruction
#undef IID_ICMemStreamProperties
#undef IID_IPrivErrors
#undef LIBID_ADO20
#undef LIBID_ADO21
#undef LIBID_ADO25
#undef LIBID_ADO26
#undef LIBID_ADO27
#undef LIBID_ADO28
#undef LIBID_ADO60
#undef LIBID_ADOR20
#undef LIBID_ADOR25
#endif

#ifdef _LOCKBYTESUPPORT_

#define IID_IADOField25 GUID_BUILDER (IID_IADOField25, 00000569, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)
#define IID_IADOField26 GUID_BUILDER (IID_IADOField26, 00000557, 0000, 0010, 80, 00, 00, AA, 00, 6d, 2e, A4)

#ifdef IMMEDIATE_GUID_USE
IID_IADOField25;
IID_IADOField26;

#undef IID_IADOField25
#undef IID_IADOField26
#endif

#endif

#ifdef RESERVED_GUIDS_BEYOND_THIS_POINT

#define ADO_Reserved_4 GUID_BUILDER (ADO_Reserved_4, 567747f1, 658b, 4906, 82, C4, E9, CD, A1, 46, 26, 15)
#define ADO_Reserved_5 GUID_BUILDER (ADO_Reserved_5, 986761e8, 7269, 4890, AA, 65, AD, 7c, 03, 69, 7a, 6d)
#define ADO_Reserved_6 GUID_BUILDER (ADO_Reserved_6, ED5A4589, 7a9d, 41df, 89, 86, CC, A9, 25, 01, A5, DA)
#define ADO_Reserved_7 GUID_BUILDER (ADO_Reserved_7, C029178A, F16B, 4a06, 82, 93, A8, 08, B7, F8, 78, 92)
#define ADO_Reserved_8 GUID_BUILDER (ADO_Reserved_8, FD6974FD, 21fb, 409c, 96, 56, A5, 68, FE, C0, AC, 01)
#define ADO_Reserved_9 GUID_BUILDER (ADO_Reserved_9, F23FCB5E, 7159, 4cba, A3, 41, 0e, 7a, A5, 15, 18, 70)
#define ADO_Reserved_10 GUID_BUILDER (ADO_Reserved_10, E724D5C9, 327c, 43f7, 86, 4c, 68, 2f, FF, 5c, 99, 93)
#define ADO_Reserved_12 GUID_BUILDER (ADO_Reserved_12, 8831ebb5, 2c09, 4ddd, 9a, 7a, AC, 13, 6d, 58, D7, 21)
#define ADO_Reserved_13 GUID_BUILDER (ADO_Reserved_13, 447b1221, 64fa, 44e9, B1, 46, B1, 1f, 16, E3, 14, B2)
#define ADO_Reserved_14 GUID_BUILDER (ADO_Reserved_14, FC528DC2, A992, 44d3, 97, 9f, 07, F7, F4, 45, 5f, 23)
#define ADO_Reserved_15 GUID_BUILDER (ADO_Reserved_15, C2CC7BC0, 9f8b, 46c8, 83, 6b, BC, 46, 70, 28, F4, 54)
#define ADO_Reserved_16 GUID_BUILDER (ADO_Reserved_16, 4687ee6c, 12ce, 4a31, 97, E9, E6, 49, 6d, E7, 2c, 71)
#define ADO_Reserved_17 GUID_BUILDER (ADO_Reserved_17, 4b56fc5d, 992f, 4339, 95, 81, C5, 40, 7a, B2, BF, FD)
#define ADO_Reserved_18 GUID_BUILDER (ADO_Reserved_18, 1f13bfb3, 8ba8, 46ca, 91, 78, 74, 28, EF, 9a, 85, C0)
#define ADO_Reserved_19 GUID_BUILDER (ADO_Reserved_19, 0b410060, 4d75, 4f77, 96, A1, 68, 4c, 38, 15, E1, B1)
#define ADO_Reserved_20 GUID_BUILDER (ADO_Reserved_20, 5593f2e0, 436b, 40b8, 81, A8, 1b, 7e, F4, E6, 25, 2c)
#define ADO_Reserved_21 GUID_BUILDER (ADO_Reserved_21, 88447b2f, E1C9, 413e, BE, E7, A7, D2, B9, 0e, D1, 96)
#define ADO_Reserved_22 GUID_BUILDER (ADO_Reserved_22, 89bfee1b, 8cb5, 4a90, 89, AF, E8, 29, 93, 4e, 6c, 48)
#define ADO_Reserved_23 GUID_BUILDER (ADO_Reserved_23, 28d7f9fc, F485, 4bdb, 9c, C4, 6f, AE, 44, F9, 9f, D9)
#define ADO_Reserved_24 GUID_BUILDER (ADO_Reserved_24, 1bb4223f, B0E8, 4540, 96, FD, B8, FE, D9, A7, C0, 8b)
#define ADO_Reserved_25 GUID_BUILDER (ADO_Reserved_25, AD1A1568, 8b4a, 403f, 84, 76, D8, F6, 33, 4d, BD, 9f)
#define ADO_Reserved_26 GUID_BUILDER (ADO_Reserved_26, 1326b4d8, EE0B, 4054, 8f, 4c, 86, 35, 9f, 00, 24, AD)
#define ADO_Reserved_27 GUID_BUILDER (ADO_Reserved_27, 98b7eb70, 7aed, 401a, AF, 6d, A6, B8, DB, A0, AF, A6)
#define ADO_Reserved_28 GUID_BUILDER (ADO_Reserved_28, FD46F2C2, 7fda, 4dc9, A2, DB, D9, BE, 4f, 59, 98, C2)
#define ADO_Reserved_29 GUID_BUILDER (ADO_Reserved_29, FAA37542, B471, 4183, A6, 56, 99, C8, FD, 80, FF, 73)
#define ADO_Reserved_30 GUID_BUILDER (ADO_Reserved_30, 56ce86f1, 3116, 4104, A5, 28, 17, D1, 1e, DC, 68, 2a)
#define ADO_Reserved_31 GUID_BUILDER (ADO_Reserved_31, 83e8cf0e, 176f, 4908, 86, 3a, 2a, 77, 4d, 76, 9b, EF)
#define ADO_Reserved_32 GUID_BUILDER (ADO_Reserved_32, 0494d18d, 98f7, 4a38, 80, DF, 35, F8, 80, 98, BD, DF)
#define ADO_Reserved_33 GUID_BUILDER (ADO_Reserved_33, 00c61f59, 4e7f, 4093, BF, FD, 03, 53, B4, 5d, E5, 8b)
#define ADO_Reserved_34 GUID_BUILDER (ADO_Reserved_34, 732a172f, 384d, 4c4a, A6, AF, D2, 28, 20, D3, 34, 26)
#define ADO_Reserved_35 GUID_BUILDER (ADO_Reserved_35, 104e1f7e, 8993, 455c, B7, D8, 58, CD, 88, 74, 80, 75)
#define ADO_Reserved_36 GUID_BUILDER (ADO_Reserved_36, C12B8DFD, 42f7, 408e, AE, FB, A7, C2, FB, 43, 49, A7)
#define ADO_Reserved_37 GUID_BUILDER (ADO_Reserved_37, EE881FC9, 6c2f, 45a2, BA, 17, 24, 95, BC, 72, 4e, 55)
#define ADO_Reserved_38 GUID_BUILDER (ADO_Reserved_38, 7381c764, 646b, 4f11, A6, 73, 13, 50, 98, 9d, 62, 3a)
#define ADO_Reserved_39 GUID_BUILDER (ADO_Reserved_39, D8E4965C, F571, 4771, 8a, 74, 63, 95, 05, 16, B0, 88)
#define ADO_Reserved_40 GUID_BUILDER (ADO_Reserved_40, 2be262e5, 3a8c, 4b07, A3, C3, 3b, B7, 40, EF, 40, 95)
#define ADO_Reserved_41 GUID_BUILDER (ADO_Reserved_41, 3e90a199, 4f86, 445c, 84, 8e, A6, 17, 86, B9, 67, D1)
#define ADO_Reserved_42 GUID_BUILDER (ADO_Reserved_42, DCD025E0, DA44, 47e4, 82, 65, E4, A7, 6b, 85, 29, 0c)
#define ADO_Reserved_43 GUID_BUILDER (ADO_Reserved_43, 31eff562, FB6B, 41d6, 81, AD, 30, 1b, B0, 53, 9c, 61)
#define ADO_Reserved_44 GUID_BUILDER (ADO_Reserved_44, BD3ECD6B, F4A7, 42fc, 90, F1, 75, D5, 37, 2a, F2, 8f)
#define ADO_Reserved_45 GUID_BUILDER (ADO_Reserved_45, 6efbc56f, 67e4, 4f7d, BE, 59, C5, D6, FA, 21, B7, 77)
#define ADO_Reserved_46 GUID_BUILDER (ADO_Reserved_46, 3bf5e1fc, B960, 4564, 86, 54, 07, B0, 7a, AF, 6e, 4f)
#define ADO_Reserved_47 GUID_BUILDER (ADO_Reserved_47, 2430f883, 1462, 4899, 9a, DE, F7, 24, 27, FD, 5e, E4)
#define ADO_Reserved_48 GUID_BUILDER (ADO_Reserved_48, AB663F07, BA4D, 42cc, 93, C6, F2, EA, 9f, C8, BA, 74)
#define ADO_Reserved_49 GUID_BUILDER (ADO_Reserved_49, D808C6F7, 36c0, 4302, 80, EE, C4, B7, 00, F8, D2, 38)
#define ADO_Reserved_50 GUID_BUILDER (ADO_Reserved_50, AB146E06, E493, 4df0, A1, CD, 07, D4, B0, 74, 46, C3)
#define ADO_Reserved_51 GUID_BUILDER (ADO_Reserved_51, 74f1fd51, 9cb8, 4186, 8c, 3d, DD, F3, 55, 2a, 99, 9b)
#define ADO_Reserved_52 GUID_BUILDER (ADO_Reserved_52, 71701a97, 5386, 43b0, 95, 8d, 3c, EE, 40, 57, B1, 99)
#define ADO_Reserved_53 GUID_BUILDER (ADO_Reserved_53, 63cc6087, A6C6, 4ccf, 8e, D4, 17, 5b, 91, A6, 32, C5)
#define ADO_Reserved_54 GUID_BUILDER (ADO_Reserved_54, 7323fd37, B7D8, 4f8a, 80, F4, E8, 3d, 0b, 2a, 73, B5)
#define ADO_Reserved_55 GUID_BUILDER (ADO_Reserved_55, 5c666403, 2a0a, 4b12, 8e, 1d, 41, 19, 88, DD, E0, 0a)
#define ADO_Reserved_56 GUID_BUILDER (ADO_Reserved_56, ECA4C14C, 5529, 49df, B1, 3c, 17, F0, 22, DB, 1b, A6)
#define ADO_Reserved_57 GUID_BUILDER (ADO_Reserved_57, 304ade1d, 4458, 4a6a, 93, 48, 1f, 7c, 2e, 64, D6, FA)
#define ADO_Reserved_58 GUID_BUILDER (ADO_Reserved_58, D87A7AF2, FB3C, 49bc, B2, 69, F3, 57, 36, E7, 23, 2e)
#define ADO_Reserved_59 GUID_BUILDER (ADO_Reserved_59, 542d6d77, AECB, 4aff, B1, C6, 54, EF, 79, 8f, 61, ED)
#define ADO_Reserved_60 GUID_BUILDER (ADO_Reserved_60, 46359618, 34ae, 410e, AE, 20, F3, D4, E1, BD, A6, BE)
#define ADO_Reserved_61 GUID_BUILDER (ADO_Reserved_61, F98DF79B, 2935, 464b, AA, 08, CC, EF, F1, 5f, 71, 32)
#define ADO_Reserved_62 GUID_BUILDER (ADO_Reserved_62, 214887fb, 4867, 4dd8, 83, 9d, 4c, F0, BB, 83, E1, 95)
#define ADO_Reserved_63 GUID_BUILDER (ADO_Reserved_63, C9B68C08, F663, 4386, 8f, 5b, FA, BA, E0, 27, 43, 6d)
#define ADO_Reserved_64 GUID_BUILDER (ADO_Reserved_64, F46511DD, 10b6, 49cf, AA, 75, 5e, E2, 7c, FD, 9e, A4)
#define ADO_Reserved_65 GUID_BUILDER (ADO_Reserved_65, C057EF87, F3A8, 4890, A9, 56, 57, 8c, 07, CD, 2e, F8)
#define ADO_Reserved_66 GUID_BUILDER (ADO_Reserved_66, 1c9e0666, 1405, 4dc5, BD, A7, 65, F4, B4, 16, 1d, 7b)
#define ADO_Reserved_67 GUID_BUILDER (ADO_Reserved_67, B91484C2, 5e48, 438c, 91, CD, B9, D6, 99, 32, 30, E4)
#define ADO_Reserved_68 GUID_BUILDER (ADO_Reserved_68, 17d12bfe, 6c9f, 4229, 87, 95, 60, 20, 6f, D1, 45, 35)
#define ADO_Reserved_69 GUID_BUILDER (ADO_Reserved_69, 5a816ea3, EE82, 4f65, BC, 76, 74, 07, E9, E5, 43, 58)
#define ADO_Reserved_70 GUID_BUILDER (ADO_Reserved_70, 3ad0de2b, AA3E, 4508, BE, 9e, 1e, AA, DF, 1c, 4d, 8b)
#define ADO_Reserved_71 GUID_BUILDER (ADO_Reserved_71, 54dc8b80, 7869, 4d90, AB, 5c, 8c, 54, 1a, 74, EE, F8)
#define ADO_Reserved_72 GUID_BUILDER (ADO_Reserved_72, 80a200b0, 5783, 48e7, 81, 25, B9, E4, BF, 59, F7, 22)
#define ADO_Reserved_73 GUID_BUILDER (ADO_Reserved_73, 1502cb61, 8c42, 4c4b, B9, 0c, 3a, 9e, 4e, 46, D1, BE)
#define ADO_Reserved_74 GUID_BUILDER (ADO_Reserved_74, 70eb3f53, 91a0, 42f5, BE, 50, F1, 02, DE, C8, 92, 27)
#define ADO_Reserved_75 GUID_BUILDER (ADO_Reserved_75, 4680aa81, B27C, 4a8f, 83, F9, 6f, B7, E1, 8e, D2, 3c)
#define ADO_Reserved_76 GUID_BUILDER (ADO_Reserved_76, EF31F9EB, 4541, 4fcb, 8d, 67, 59, 2c, 85, 50, 93, 05)
#define ADO_Reserved_77 GUID_BUILDER (ADO_Reserved_77, 88b77d15, 997e, 4e3a, 83, 20, 3b, 37, 83, 52, 86, D5)
#define ADO_Reserved_78 GUID_BUILDER (ADO_Reserved_78, D03A3AA8, 1aac, 4867, 93, C9, 5f, 51, D8, 7d, 6a, 74)
#define ADO_Reserved_79 GUID_BUILDER (ADO_Reserved_79, 47022458, 17e7, 4bd7, 90, 81, 85, B4, 0b, 03, 6d, 5b)
#define ADO_Reserved_80 GUID_BUILDER (ADO_Reserved_80, 9e5bee82, F410, 44c7, 9d, 6d, 3f, 7d, D2, 8b, A7, CC)
#define ADO_Reserved_81 GUID_BUILDER (ADO_Reserved_81, 278a1c47, 3c39, 41c7, A3, FB, 7c, 2e, 62, 0b, E4, 44)
#define ADO_Reserved_82 GUID_BUILDER (ADO_Reserved_82, 964cbf05, 8084, 4c15, 9c, F5, 8c, 4b, 81, 41, B4, AE)
#define ADO_Reserved_83 GUID_BUILDER (ADO_Reserved_83, A86296A0, F272, 4acd, 83, 06, FF, CA, FF, 89, 14, A9)
#define ADO_Reserved_84 GUID_BUILDER (ADO_Reserved_84, F805FC7C, 7c4a, 43a1, B0, 14, 71, EA, 0e, EB, EA, 5f)
#define ADO_Reserved_85 GUID_BUILDER (ADO_Reserved_85, 33e6e9b6, 0bea, 4549, 90, CB, 3b, 64, 12, DB, 8c, F5)
#define ADO_Reserved_86 GUID_BUILDER (ADO_Reserved_86, 7337e3dc, 219f, 4d9e, 82, 5b, 0a, 2c, 18, 4e, C0, DE)
#define ADO_Reserved_87 GUID_BUILDER (ADO_Reserved_87, 7397bafc, 354e, 4f18, 9f, 76, C3, 3a, 4e, EF, 6d, 20)
#define ADO_Reserved_88 GUID_BUILDER (ADO_Reserved_88, 5ec2d163, E671, 4186, BE, 72, BF, FF, 72, D5, 7a, 5c)
#define ADO_Reserved_89 GUID_BUILDER (ADO_Reserved_89, 8b37b801, 0a35, 4f97, A3, 43, 82, 57, B3, E7, 6c, 79)
#define ADO_Reserved_90 GUID_BUILDER (ADO_Reserved_90, FAD396B6, EE4E, 4f70, 85, 54, E8, 23, 9e, 47, 05, 29)
#define ADO_Reserved_91 GUID_BUILDER (ADO_Reserved_91, 6063972c, 395b, 4fef, A0, 04, ED, 95, E7, D8, 72, 0d)
#define ADO_Reserved_92 GUID_BUILDER (ADO_Reserved_92, 85aeed72, A1F8, 4597, 82, 32, F8, 40, EF, C9, 21, 09)
#define ADO_Reserved_93 GUID_BUILDER (ADO_Reserved_93, CE4FD8FF, 553a, 4424, B1, EA, 3e, DF, 11, 42, AD, 8b)
#define ADO_Reserved_94 GUID_BUILDER (ADO_Reserved_94, 1a856a0f, 0844, 4de4, AC, 7b, 75, 30, 62, 56, 39, 86)
#define ADO_Reserved_95 GUID_BUILDER (ADO_Reserved_95, 09a742a1, 19ed, 43bb, 85, E9, 99, 23, DE, C4, 17, F7)
#define ADO_Reserved_96 GUID_BUILDER (ADO_Reserved_96, 3695bd0c, 9de6, 4895, 84, E6, B2, 4c, E7, 55, 47, 02)
#define ADO_Reserved_97 GUID_BUILDER (ADO_Reserved_97, 8802531f, 6ea8, 4a55, 8a, 18, 05, 97, 86, 3c, DA, 38)
#define ADO_Reserved_98 GUID_BUILDER (ADO_Reserved_98, 498e70f0, B13F, 4804, AD, D5, 72, E8, 0e, 28, 05, E7)
#define ADO_Reserved_99 GUID_BUILDER (ADO_Reserved_99, 50d0e90f, E3A4, 4a93, 8b, 48, 71, 21, 66, E8, 87, CD)
#define ADO_Reserved_100 GUID_BUILDER (ADO_Reserved_100, F1D30550, 8515, 4f8b, 93, E1, 1e, F0, 12, 1b, 4b, D0)
#define ADO_Reserved_101 GUID_BUILDER (ADO_Reserved_101, 901cda31, 8cdb, 4a5b, 91, 6b, 63, EA, 90, 1d, 8c, E0)
#define ADO_Reserved_102 GUID_BUILDER (ADO_Reserved_102, 00bda239, 1094, 4aef, 93, AD, 7c, E2, 73, 6c, 42, 25)
#define ADO_Reserved_103 GUID_BUILDER (ADO_Reserved_103, DCA4E51E, 250e, 4ab3, B4, 90, F2, CB, 9e, 8f, 6c, C4)
#define ADO_Reserved_104 GUID_BUILDER (ADO_Reserved_104, 24679ebd, 8535, 4494, A9, 1c, 18, 91, F0, 75, 5b, 6f)
#define ADO_Reserved_105 GUID_BUILDER (ADO_Reserved_105, F041739E, F37E, 4925, 94, 25, FB, 51, 5e, 56, 0f, 54)
#define ADO_Reserved_106 GUID_BUILDER (ADO_Reserved_106, FECACBBF, A73C, 4616, 84, 2f, FE, F5, 72, 85, 70, AB)
#define ADO_Reserved_107 GUID_BUILDER (ADO_Reserved_107, DBAD7368, 1ded, 4a77, B8, 0a, 1a, EB, 12, 99, BD, B3)
#define ADO_Reserved_108 GUID_BUILDER (ADO_Reserved_108, CFDE81B8, 66ef, 4503, 84, A8, 7e, 8f, C8, AB, 0b, 31)
#define ADO_Reserved_109 GUID_BUILDER (ADO_Reserved_109, 9b7484fa, 023a, 4ffb, A2, 94, 11, A6, E5, 97, AB, 35)
#define ADO_Reserved_110 GUID_BUILDER (ADO_Reserved_110, 54f0f09c, 1201, 49a9, B4, 65, 6b, 02, 9b, 5f, E3, 12)
#define ADO_Reserved_111 GUID_BUILDER (ADO_Reserved_111, BFFA01F8, EAE7, 4fa1, BF, 74, 37, 73, 3f, BF, 36, 4c)
#define ADO_Reserved_112 GUID_BUILDER (ADO_Reserved_112, 12fad291, 4aab, 4038, 9d, D1, 04, E4, E7, A9, E0, F4)
#define ADO_Reserved_113 GUID_BUILDER (ADO_Reserved_113, 8d2af964, C489, 4d77, A8, 17, A0, 4d, B1, DB, 26, A5)
#define ADO_Reserved_114 GUID_BUILDER (ADO_Reserved_114, 79f89dd7, BE86, 4b36, BE, 9b, FA, 75, 24, 18, 55, 68)
#define ADO_Reserved_115 GUID_BUILDER (ADO_Reserved_115, 4387d7fa, 7a52, 4f67, BF, B6, 7e, 7d, 7a, B7, C9, DE)
#define ADO_Reserved_116 GUID_BUILDER (ADO_Reserved_116, 7571252f, 0e49, 4f4b, A3, 87, 9e, D9, 70, 54, 68, D8)
#define ADO_Reserved_117 GUID_BUILDER (ADO_Reserved_117, 0dab016b, 6ba4, 470f, 98, 1a, 2b, A7, 65, D4, 60, 4b)
#define ADO_Reserved_118 GUID_BUILDER (ADO_Reserved_118, E97D87A3, 8a95, 4080, 8c, A9, ED, 9f, 05, 1a, B7, B2)
#define ADO_Reserved_119 GUID_BUILDER (ADO_Reserved_119, C9EA1598, 2d23, 4978, 9b, 33, 3d, 2c, C4, 0a, B7, A1)
#define ADO_Reserved_120 GUID_BUILDER (ADO_Reserved_120, E41CA9FC, 7fc9, 4831, 90, CE, F5, 33, 96, CE, 42, C3)
#define ADO_Reserved_121 GUID_BUILDER (ADO_Reserved_121, 15df0905, 4acc, 44f7, A0, 1e, 0f, EF, 56, 3c, C4, E5)
#define ADO_Reserved_122 GUID_BUILDER (ADO_Reserved_122, D2879A0E, D0B3, 42a2, A1, 16, D1, 5e, 13, C7, 51, 77)
#define ADO_Reserved_123 GUID_BUILDER (ADO_Reserved_123, A999A8D2, 5e83, 4c0e, 83, 97, 18, 33, 19, 32, 79, CD)
#define ADO_Reserved_124 GUID_BUILDER (ADO_Reserved_124, C6AFAE72, B3FF, 48ab, B1, EE, F5, EE, F9, 05, DF, 47)
#define ADO_Reserved_125 GUID_BUILDER (ADO_Reserved_125, 0deadf50, 0940, 4f0e, AC, 3b, 94, 80, B7, 32, 2b, 1b)
#define ADO_Reserved_126 GUID_BUILDER (ADO_Reserved_126, 61278818, 2fe6, 4892, 8b, 95, A7, 5c, AC, 6e, 21, BB)
#define ADO_Reserved_127 GUID_BUILDER (ADO_Reserved_127, 3ac2bed7, 1111, 4e55, B2, 06, 1f, 54, 18, 94, 4c, BA)
#define ADO_Reserved_128 GUID_BUILDER (ADO_Reserved_128, 3d4751e2, 04b8, 4593, A0, 0d, 3a, 4b, 94, 67, 4b, E9)
#define ADO_Reserved_129 GUID_BUILDER (ADO_Reserved_129, 69bc6751, FE10, 4b3f, 89, 35, 40, 2f, A5, FD, 04, 82)
#define ADO_Reserved_130 GUID_BUILDER (ADO_Reserved_130, 5867af81, 995a, 4686, 8b, CB, 13, B6, 8b, 10, 26, 8a)
#define ADO_Reserved_131 GUID_BUILDER (ADO_Reserved_131, DA46C62F, BDCD, 4745, A3, CA, 4e, C9, FA, AB, E1, 10)
#define ADO_Reserved_132 GUID_BUILDER (ADO_Reserved_132, 93028aa6, EECC, 482f, B3, A4, 2f, D4, 13, 04, 96, 5e)
#define ADO_Reserved_133 GUID_BUILDER (ADO_Reserved_133, AB14F604, D05E, 4e50, A4, 5b, A8, 10, 48, E3, A4, 75)
#define ADO_Reserved_134 GUID_BUILDER (ADO_Reserved_134, 35267875, 8420, 4226, 87, C0, 25, 00, 58, 56, 0f, D2)
#define ADO_Reserved_135 GUID_BUILDER (ADO_Reserved_135, 16e34932, EEFA, 440e, A7, 86, 6a, 36, D2, C6, 21, 69)
#define ADO_Reserved_136 GUID_BUILDER (ADO_Reserved_136, 2710a15a, B2B0, 46ec, BD, EC, E2, 2e, A8, A6, 28, FA)
#define ADO_Reserved_137 GUID_BUILDER (ADO_Reserved_137, 2777696f, CB34, 4cc4, A0, A9, 02, EA, 15, 16, 63, DD)
#define ADO_Reserved_138 GUID_BUILDER (ADO_Reserved_138, D11CA1A0, A261, 4ba2, 81, 68, 46, 52, 32, 9a, 60, 77)
#define ADO_Reserved_139 GUID_BUILDER (ADO_Reserved_139, C33509A8, 883f, 4bea, AF, B5, 35, 26, CF, 0b, 8b, E1)
#define ADO_Reserved_140 GUID_BUILDER (ADO_Reserved_140, DEBDC8E1, 4f02, 43e1, 8c, 88, 0b, A8, E1, 50, 6b, F5)
#define ADO_Reserved_141 GUID_BUILDER (ADO_Reserved_141, 552f8531, 3f79, 4db3, 87, 7b, 8e, 54, C3, 5b, 38, 54)
#define ADO_Reserved_142 GUID_BUILDER (ADO_Reserved_142, 1e6a2bf4, 241c, 48a1, 90, 66, C6, E1, E5, 2b, 0a, 4b)
#define ADO_Reserved_143 GUID_BUILDER (ADO_Reserved_143, 8e5b2a8d, 1f0d, 429d, 94, 95, 16, F8, E9, 58, 06, 80)
#define ADO_Reserved_144 GUID_BUILDER (ADO_Reserved_144, 57faec9d, 5cde, 4ebe, 84, A1, 5a, CB, 75, 7c, D4, 51)
#define ADO_Reserved_145 GUID_BUILDER (ADO_Reserved_145, 707b03c3, A3B0, 4f00, 81, 61, 6e, 3f, 02, 7f, F0, B3)
#define ADO_Reserved_146 GUID_BUILDER (ADO_Reserved_146, 5dd552f4, 0718, 4bdd, 82, 6c, 7c, C3, 5c, DA, 1d, 93)
#define ADO_Reserved_147 GUID_BUILDER (ADO_Reserved_147, F3247F33, E377, 4a44, A9, 37, AC, E6, 36, F6, 58, 1f)
#define ADO_Reserved_148 GUID_BUILDER (ADO_Reserved_148, E7C324C4, 38a5, 42a8, 99, FF, 34, 5d, AD, 8c, D2, 29)
#define ADO_Reserved_149 GUID_BUILDER (ADO_Reserved_149, D14FCA70, 390d, 4158, B5, C3, 9a, 02, D1, F7, 85, 87)
#define ADO_Reserved_150 GUID_BUILDER (ADO_Reserved_150, 58d30b5f, 92a5, 4ef4, 8e, 45, A0, 24, A9, CD, F9, FE)
#define ADO_Reserved_151 GUID_BUILDER (ADO_Reserved_151, 9673df76, 73e4, 4c66, 89, 14, 7f, A4, 17, 43, 6c, 4a)
#define ADO_Reserved_152 GUID_BUILDER (ADO_Reserved_152, 9fa8a7e1, CF3C, 4a61, BE, 10, 1d, 85, 5f, A0, D5, 08)
#define ADO_Reserved_153 GUID_BUILDER (ADO_Reserved_153, B657729F, 6cc7, 4392, BD, 56, DC, ED, 6e, 53, F6, 4c)
#define ADO_Reserved_154 GUID_BUILDER (ADO_Reserved_154, 06e5224b, 8c27, 4f41, 8f, B7, C6, 41, E4, C5, 04, 2d)
#define ADO_Reserved_155 GUID_BUILDER (ADO_Reserved_155, 2268a619, CC1D, 4f72, B8, 3f, 79, 63, C0, 13, B1, 3d)
#define ADO_Reserved_156 GUID_BUILDER (ADO_Reserved_156, FB4810F3, 3a65, 4c33, B3, 99, B5, C9, 33, 11, 11, D7)
#define ADO_Reserved_157 GUID_BUILDER (ADO_Reserved_157, 9011be74, 6c9d, 44f7, BE, 2c, 8a, 2a, BB, 62, 51, AC)
#define ADO_Reserved_158 GUID_BUILDER (ADO_Reserved_158, 3145c182, 82c6, 4082, BB, E7, 79, 1a, 2f, 49, 6c, B1)
#define ADO_Reserved_159 GUID_BUILDER (ADO_Reserved_159, D8865377, 8799, 4c08, 97, E5, D6, 7e, 88, 6f, F5, 49)
#define ADO_Reserved_160 GUID_BUILDER (ADO_Reserved_160, 8993232e, 8afa, 4552, A7, 8c, C6, 6c, 9d, 3a, E6, D0)
#define ADO_Reserved_161 GUID_BUILDER (ADO_Reserved_161, 40af1931, 8721, 427b, 83, 5e, 50, 87, 79, BD, 1e, B2)
#define ADO_Reserved_162 GUID_BUILDER (ADO_Reserved_162, 9c6e2b26, 4468, 427c, 8c, F5, 01, 14, 7d, B8, DF, 22)
#define ADO_Reserved_163 GUID_BUILDER (ADO_Reserved_163, 3537fa93, 7e92, 4ce0, 80, 96, EF, DC, 1a, 80, A8, 95)
#define ADO_Reserved_164 GUID_BUILDER (ADO_Reserved_164, 36992492, 3e17, 47c1, AB, 98, 5f, 0c, 49, B4, 6a, 25)
#define ADO_Reserved_165 GUID_BUILDER (ADO_Reserved_165, 01662edb, CE23, 4215, AE, 9d, 51, 51, E6, DA, 36, 3c)
#define ADO_Reserved_166 GUID_BUILDER (ADO_Reserved_166, 80b4a97b, 5256, 4397, 89, CD, 4e, F9, 91, 0f, 1d, E6)
#define ADO_Reserved_167 GUID_BUILDER (ADO_Reserved_167, C2341A38, 2c6b, 414e, 96, A8, 8b, 5e, 47, F8, 14, DA)
#define ADO_Reserved_168 GUID_BUILDER (ADO_Reserved_168, 5c2b7578, 53fa, 4ace, 8e, 6c, 39, 18, 2f, 68, D2, 67)
#define ADO_Reserved_169 GUID_BUILDER (ADO_Reserved_169, B80C1E36, 611b, 49d4, 97, 19, 4e, 0c, 59, 0e, 2e, E1)
#define ADO_Reserved_170 GUID_BUILDER (ADO_Reserved_170, BA269EB4, B741, 4fb2, A9, C9, 52, 4c, 9d, BE, 7c, 16)
#define ADO_Reserved_171 GUID_BUILDER (ADO_Reserved_171, EE49769D, 1028, 4429, A9, 66, 2f, A8, 1d, 70, EE, 19)
#define ADO_Reserved_172 GUID_BUILDER (ADO_Reserved_172, 541fc621, D6E6, 4cc4, B4, 98, 8e, 4f, AA, A0, 65, BF)
#define ADO_Reserved_173 GUID_BUILDER (ADO_Reserved_173, AA8B544C, 4067, 4e00, 96, 09, 95, EE, 21, 68, AF, CE)
#define ADO_Reserved_174 GUID_BUILDER (ADO_Reserved_174, 5b161b2b, D02C, 4300, A1, 54, CF, DC, 25, 3b, 13, 0d)
#define ADO_Reserved_175 GUID_BUILDER (ADO_Reserved_175, 81f62203, 182e, 42de, B1, B7, 63, 5f, C6, 6f, 6e, 9e)
#define ADO_Reserved_176 GUID_BUILDER (ADO_Reserved_176, 04934bdd, A530, 48ec, 91, CE, 11, 83, 42, 5b, DB, 61)
#define ADO_Reserved_177 GUID_BUILDER (ADO_Reserved_177, F6997841, 9a99, 48aa, B0, 56, 8c, 75, 17, 06, 41, 7f)
#define ADO_Reserved_178 GUID_BUILDER (ADO_Reserved_178, 353fe3f1, DE50, 45ee, 91, E9, 3e, 62, E3, C7, 86, 04)
#define ADO_Reserved_179 GUID_BUILDER (ADO_Reserved_179, F142C8C6, 9e24, 422e, 81, BD, D2, 94, 7f, 93, 94, D4)
#define ADO_Reserved_180 GUID_BUILDER (ADO_Reserved_180, 95951773, 9566, 46c9, 86, B0, 40, ED, 25, 46, 02, 93)
#define ADO_Reserved_181 GUID_BUILDER (ADO_Reserved_181, 54140563, 0f25, 4f56, 9d, 8f, B6, DE, CB, 96, DC, E4)
#define ADO_Reserved_182 GUID_BUILDER (ADO_Reserved_182, 91a48243, AE16, 48cf, 82, 29, 00, 00, F8, 3c, 5e, FC)
#define ADO_Reserved_183 GUID_BUILDER (ADO_Reserved_183, E0FA1A1F, 3967, 4392, AB, 1a, E2, 8b, 85, 04, 68, CA)
#define ADO_Reserved_184 GUID_BUILDER (ADO_Reserved_184, 5582d772, ABAC, 4a85, A0, B3, 2e, 65, E1, 71, 10, 53)
#define ADO_Reserved_185 GUID_BUILDER (ADO_Reserved_185, 1cd1f347, 8fb4, 49a2, B5, 65, A6, 74, A0, C1, 45, 0e)
#define ADO_Reserved_186 GUID_BUILDER (ADO_Reserved_186, 0ec3aa4e, FEF5, 4a5c, BD, 0a, E9, CD, B7, 6a, 5f, 30)
#define ADO_Reserved_187 GUID_BUILDER (ADO_Reserved_187, 4118414d, 4a21, 46da, 88, C1, EF, A7, 01, 8c, 45, 27)
#define ADO_Reserved_188 GUID_BUILDER (ADO_Reserved_188, D5C1CC0D, E38E, 4cb6, 89, D9, 99, 27, 7f, 12, D1, 9e)
#define ADO_Reserved_189 GUID_BUILDER (ADO_Reserved_189, 0956b82a, 94a7, 474e, A5, 05, 1a, 76, 26, 36, AF, 08)
#define ADO_Reserved_190 GUID_BUILDER (ADO_Reserved_190, 2cbf62ab, B8E4, 48d0, B5, 01, 69, CF, 63, 3c, AA, E6)
#define ADO_Reserved_191 GUID_BUILDER (ADO_Reserved_191, C02B8113, AECF, 4a34, B3, E9, 5b, 52, 4e, 51, 44, B5)
#define ADO_Reserved_192 GUID_BUILDER (ADO_Reserved_192, 1c90947b, 4a3a, 4ecd, 8c, 70, F4, 3f, E5, 2d, 46, 45)
#define ADO_Reserved_193 GUID_BUILDER (ADO_Reserved_193, 48175e98, 6672, 4db4, B5, 74, 8c, 93, 25, 8d, BF, 14)
#define ADO_Reserved_194 GUID_BUILDER (ADO_Reserved_194, 99cb88bf, E5C1, 4af0, 85, 00, 72, 36, 47, DC, D2, 05)
#define ADO_Reserved_195 GUID_BUILDER (ADO_Reserved_195, 6a2cc3cc, 7855, 4b27, 86, F7, 98, 6b, AA, F9, 5f, 0f)
#define ADO_Reserved_196 GUID_BUILDER (ADO_Reserved_196, 7640b336, 9ebb, 4017, 9e, EE, 54, 01, F4, EC, B1, 70)
#define ADO_Reserved_197 GUID_BUILDER (ADO_Reserved_197, 507b39e1, 2965, 42ea, 92, 66, 55, 8d, E4, 31, 53, 73)
#define ADO_Reserved_198 GUID_BUILDER (ADO_Reserved_198, 58c591fa, 37ff, 4428, A0, 4a, 46, 71, 98, 17, 74, 8c)
#define ADO_Reserved_199 GUID_BUILDER (ADO_Reserved_199, 24be98e9, B43D, 49b5, 9c, 41, 20, AF, C2, FE, 1d, 8d)
#define ADO_Reserved_200 GUID_BUILDER (ADO_Reserved_200, 041956c5, B951, 4c8f, 8c, 61, 8e, 12, 34, E1, E9, 61)
#define ADO_Reserved_201 GUID_BUILDER (ADO_Reserved_201, 6c98d05c, D366, 48b4, 80, E3, 8f, A1, CC, 06, 1d, B7)
#define ADO_Reserved_202 GUID_BUILDER (ADO_Reserved_202, 09570783, A1E8, 4a52, BA, 74, 6c, AC, 02, C0, 14, 8c)
#define ADO_Reserved_203 GUID_BUILDER (ADO_Reserved_203, 96c8c205, FD0D, 4b56, 9a, 12, 39, B3, 7e, 9d, 07, 4d)
#define ADO_Reserved_204 GUID_BUILDER (ADO_Reserved_204, 136c40e1, 366e, 4ba6, AF, 71, C4, 9a, EF, 17, 3f, C0)
#define ADO_Reserved_205 GUID_BUILDER (ADO_Reserved_205, A298C799, 06fb, 466e, B5, 6d, 3e, CC, 6d, 0c, D6, 75)
#define ADO_Reserved_206 GUID_BUILDER (ADO_Reserved_206, 41a96542, 08f2, 4609, B7, 6a, ED, 93, E5, 5b, 8c, 60)
#define ADO_Reserved_207 GUID_BUILDER (ADO_Reserved_207, 65a3b57e, 06f9, 4572, 80, 91, 17, 3f, C4, A6, 5a, 16)
#define ADO_Reserved_208 GUID_BUILDER (ADO_Reserved_208, 114f3e9d, 5431, 4dc1, 95, 42, 9b, 85, 44, CF, 83, B2)
#define ADO_Reserved_209 GUID_BUILDER (ADO_Reserved_209, 41de92d4, 9f2a, 4085, 8c, C1, C1, 04, 3e, 5b, 11, 12)
#define ADO_Reserved_210 GUID_BUILDER (ADO_Reserved_210, E32A7A98, FF1E, 45c9, AA, 51, 5f, 86, 9a, 9a, 48, 57)
#define ADO_Reserved_211 GUID_BUILDER (ADO_Reserved_211, 5e5a209f, 3efc, 48bc, A7, 1e, F4, CE, BE, 4c, A6, 25)
#define ADO_Reserved_212 GUID_BUILDER (ADO_Reserved_212, C556C1CC, 8b2e, 482b, B7, 8c, E2, F6, FD, A0, 4f, 4d)
#define ADO_Reserved_213 GUID_BUILDER (ADO_Reserved_213, 39c54fd9, A22A, 43d4, A4, 36, D9, CB, C5, 53, D5, 5a)
#define ADO_Reserved_214 GUID_BUILDER (ADO_Reserved_214, 750e0ba2, E25C, 479f, B0, C1, 58, 44, A1, 4d, 08, 77)
#define ADO_Reserved_215 GUID_BUILDER (ADO_Reserved_215, 7ecbdb2c, C5C2, 48fb, 8a, 3a, 30, B7, E7, BD, 17, 25)
#define ADO_Reserved_216 GUID_BUILDER (ADO_Reserved_216, 0bf18ac7, 8be1, 49e6, A8, 57, EA, 89, 3a, 83, 58, F5)
#define ADO_Reserved_217 GUID_BUILDER (ADO_Reserved_217, DA74EAB6, AAFE, 42ad, 8a, 0d, B2, 73, 35, 0c, 82, E3)
#define ADO_Reserved_218 GUID_BUILDER (ADO_Reserved_218, F6A3D173, E366, 424a, AD, 0c, 25, 5c, 32, 2d, 09, 80)
#define ADO_Reserved_219 GUID_BUILDER (ADO_Reserved_219, 7cd83ba3, 0516, 4366, BB, 85, DE, 53, 03, F7, 75, 08)
#define ADO_Reserved_220 GUID_BUILDER (ADO_Reserved_220, 42edfc05, 3a70, 4f5c, 8c, 32, 06, 5e, 61, 45, 3c, BE)
#define ADO_Reserved_221 GUID_BUILDER (ADO_Reserved_221, 624bc037, 05b0, 44e1, 85, A7, 73, C4, 7f, A0, CC, 04)
#define ADO_Reserved_222 GUID_BUILDER (ADO_Reserved_222, 8811f8dd, FA15, 4fa6, A7, 6e, 7e, DA, E7, 0d, EC, D4)
#define ADO_Reserved_223 GUID_BUILDER (ADO_Reserved_223, DD310D89, 9f22, 4f49, 89, 8c, AF, A2, 7f, AF, 11, 1c)
#define ADO_Reserved_224 GUID_BUILDER (ADO_Reserved_224, 321e3a7d, DF0E, 4ff7, 98, 5d, F6, E6, 73, FD, E2, 9f)
#define ADO_Reserved_225 GUID_BUILDER (ADO_Reserved_225, 036d1b77, 3737, 47cb, 9e, 75, 31, 13, 13, 2d, 32, B8)
#define ADO_Reserved_226 GUID_BUILDER (ADO_Reserved_226, A46B9E8C, 4740, 4919, 86, 34, A3, 57, 73, F6, 53, 2f)
#define ADO_Reserved_227 GUID_BUILDER (ADO_Reserved_227, 7c064e3a, 014e, 4733, 9d, 00, 5d, 03, 13, F7, B7, F5)
#define ADO_Reserved_228 GUID_BUILDER (ADO_Reserved_228, 7cbff995, A041, 4b0a, B7, 9b, 16, 3a, 74, 2c, DC, CF)
#define ADO_Reserved_229 GUID_BUILDER (ADO_Reserved_229, C3271965, BA03, 4abc, 8f, D8, 98, 97, 7e, 4c, B3, 9a)
#define ADO_Reserved_230 GUID_BUILDER (ADO_Reserved_230, 565dc4b1, 8d7a, 41c6, AE, 01, 6c, EF, 63, 46, 4d, 5e)
#define ADO_Reserved_231 GUID_BUILDER (ADO_Reserved_231, 3331e567, EB74, 45d2, 86, 32, 20, 43, 47, DB, BE, 04)
#define ADO_Reserved_232 GUID_BUILDER (ADO_Reserved_232, 3cee44a8, 6fc5, 4cd5, AA, 9d, 1b, 67, 4c, B6, 2e, EC)
#define ADO_Reserved_233 GUID_BUILDER (ADO_Reserved_233, CD1BE145, 71b9, 4ccd, A7, AF, 5b, BA, A0, 2a, 51, E6)
#define ADO_Reserved_234 GUID_BUILDER (ADO_Reserved_234, 4203c429, F3F0, 4dd7, 91, 24, 51, E0, 13, 95, 5e, 7a)
#define ADO_Reserved_235 GUID_BUILDER (ADO_Reserved_235, BB256836, 2804, 492f, 9c, B2, CF, 83, CB, 82, 63, 8a)
#define ADO_Reserved_236 GUID_BUILDER (ADO_Reserved_236, 8b247756, 34aa, 45ef, B1, 24, A9, 60, 66, AC, E8, D6)
#define ADO_Reserved_237 GUID_BUILDER (ADO_Reserved_237, EF1CF73C, 4915, 4289, AD, C4, DD, DA, 62, 70, 70, A6)
#define ADO_Reserved_238 GUID_BUILDER (ADO_Reserved_238, D0EB0A94, 91a0, 49d3, 97, 26, 94, 52, 66, 5a, FE, 53)
#define ADO_Reserved_239 GUID_BUILDER (ADO_Reserved_239, D6F5003E, 4c06, 47b1, 89, E9, D6, 3c, 3d, 7d, 41, B6)
#define ADO_Reserved_240 GUID_BUILDER (ADO_Reserved_240, AA803151, F4AE, 4ce3, BC, 92, 97, 1c, 84, 2e, F5, BC)
#define ADO_Reserved_241 GUID_BUILDER (ADO_Reserved_241, C4BB086F, 5b11, 4c67, 98, 6c, 8c, D4, 8c, 5c, E3, 8b)
#define ADO_Reserved_242 GUID_BUILDER (ADO_Reserved_242, F1C4A502, 4744, 478f, 87, 71, C6, 94, CC, 2d, F7, B6)
#define ADO_Reserved_243 GUID_BUILDER (ADO_Reserved_243, 2cd39761, F389, 4f5e, BE, 91, A6, B9, 1b, 18, AD, 12)
#define ADO_Reserved_244 GUID_BUILDER (ADO_Reserved_244, 8895ba8f, 0cb7, 4354, A8, EA, CD, 9d, F4, 1b, F8, 88)
#define ADO_Reserved_245 GUID_BUILDER (ADO_Reserved_245, 71e0b0dc, 1245, 441d, 92, 92, 32, 71, 3f, 57, 97, 7a)
#define ADO_Reserved_246 GUID_BUILDER (ADO_Reserved_246, 7604d0cb, F137, 472d, 8b, 4c, 85, 66, 72, 9a, CF, 03)
#define ADO_Reserved_247 GUID_BUILDER (ADO_Reserved_247, 94c9b5ac, 8309, 4f4b, 8e, 68, C4, 37, 7e, C2, B7, 91)
#define ADO_Reserved_248 GUID_BUILDER (ADO_Reserved_248, 0e555180, 5e2c, 4bf6, 90, A0, 1b, 36, 3d, 4b, B9, 99)
#define ADO_Reserved_249 GUID_BUILDER (ADO_Reserved_249, C077D666, 6988, 4eac, A5, 52, 61, 61, 55, F9, 6a, 12)

#ifdef IMMEDIATE_GUID_USE
ADO_Reserved_4;
ADO_Reserved_5; ADO_Reserved_6; ADO_Reserved_7; ADO_Reserved_8; ADO_Reserved_9;
ADO_Reserved_10; ADO_Reserved_12; ADO_Reserved_13; ADO_Reserved_14;
ADO_Reserved_15; ADO_Reserved_16; ADO_Reserved_17; ADO_Reserved_18; ADO_Reserved_19;
ADO_Reserved_20; ADO_Reserved_21; ADO_Reserved_22; ADO_Reserved_23; ADO_Reserved_24;
ADO_Reserved_25; ADO_Reserved_26; ADO_Reserved_27; ADO_Reserved_28; ADO_Reserved_29;
ADO_Reserved_30; ADO_Reserved_31; ADO_Reserved_32; ADO_Reserved_33; ADO_Reserved_34;
ADO_Reserved_35; ADO_Reserved_36; ADO_Reserved_37; ADO_Reserved_38; ADO_Reserved_39;
ADO_Reserved_40; ADO_Reserved_41; ADO_Reserved_42; ADO_Reserved_43; ADO_Reserved_44;
ADO_Reserved_45; ADO_Reserved_46; ADO_Reserved_47; ADO_Reserved_48; ADO_Reserved_49;
ADO_Reserved_50; ADO_Reserved_51; ADO_Reserved_52; ADO_Reserved_53; ADO_Reserved_54;
ADO_Reserved_55; ADO_Reserved_56; ADO_Reserved_57; ADO_Reserved_58; ADO_Reserved_59;
ADO_Reserved_60; ADO_Reserved_61; ADO_Reserved_62; ADO_Reserved_63; ADO_Reserved_64;
ADO_Reserved_65; ADO_Reserved_66; ADO_Reserved_67; ADO_Reserved_68; ADO_Reserved_69;
ADO_Reserved_70; ADO_Reserved_71; ADO_Reserved_72; ADO_Reserved_73; ADO_Reserved_74;
ADO_Reserved_75; ADO_Reserved_76; ADO_Reserved_77; ADO_Reserved_78; ADO_Reserved_79;
ADO_Reserved_80; ADO_Reserved_81; ADO_Reserved_82; ADO_Reserved_83; ADO_Reserved_84;
ADO_Reserved_85; ADO_Reserved_86; ADO_Reserved_87; ADO_Reserved_88; ADO_Reserved_89;
ADO_Reserved_90; ADO_Reserved_91; ADO_Reserved_92; ADO_Reserved_93; ADO_Reserved_94;
ADO_Reserved_95; ADO_Reserved_96; ADO_Reserved_97; ADO_Reserved_98; ADO_Reserved_99;
ADO_Reserved_100; ADO_Reserved_101; ADO_Reserved_102; ADO_Reserved_103; ADO_Reserved_104;
ADO_Reserved_105; ADO_Reserved_106; ADO_Reserved_107; ADO_Reserved_108; ADO_Reserved_109;
ADO_Reserved_110; ADO_Reserved_111; ADO_Reserved_112; ADO_Reserved_113; ADO_Reserved_114;
ADO_Reserved_115; ADO_Reserved_116; ADO_Reserved_117; ADO_Reserved_118; ADO_Reserved_119;
ADO_Reserved_120; ADO_Reserved_121; ADO_Reserved_122; ADO_Reserved_123; ADO_Reserved_124;
ADO_Reserved_125; ADO_Reserved_126; ADO_Reserved_127; ADO_Reserved_128; ADO_Reserved_129;
ADO_Reserved_130; ADO_Reserved_131; ADO_Reserved_132; ADO_Reserved_133; ADO_Reserved_134;
ADO_Reserved_135; ADO_Reserved_136; ADO_Reserved_137; ADO_Reserved_138; ADO_Reserved_139;
ADO_Reserved_140; ADO_Reserved_141; ADO_Reserved_142; ADO_Reserved_143; ADO_Reserved_144;
ADO_Reserved_145; ADO_Reserved_146; ADO_Reserved_147; ADO_Reserved_148; ADO_Reserved_149;
ADO_Reserved_150; ADO_Reserved_151; ADO_Reserved_152; ADO_Reserved_153; ADO_Reserved_154;
ADO_Reserved_155; ADO_Reserved_156; ADO_Reserved_157; ADO_Reserved_158; ADO_Reserved_159;
ADO_Reserved_160; ADO_Reserved_161; ADO_Reserved_162; ADO_Reserved_163; ADO_Reserved_164;
ADO_Reserved_165; ADO_Reserved_166; ADO_Reserved_167; ADO_Reserved_168; ADO_Reserved_169;
ADO_Reserved_170; ADO_Reserved_171; ADO_Reserved_172; ADO_Reserved_173; ADO_Reserved_174;
ADO_Reserved_175; ADO_Reserved_176; ADO_Reserved_177; ADO_Reserved_178; ADO_Reserved_179;
ADO_Reserved_180; ADO_Reserved_181; ADO_Reserved_182; ADO_Reserved_183; ADO_Reserved_184;
ADO_Reserved_185; ADO_Reserved_186; ADO_Reserved_187; ADO_Reserved_188; ADO_Reserved_189;
ADO_Reserved_190; ADO_Reserved_191; ADO_Reserved_192; ADO_Reserved_193; ADO_Reserved_194;
ADO_Reserved_195; ADO_Reserved_196; ADO_Reserved_197; ADO_Reserved_198; ADO_Reserved_199;
ADO_Reserved_200; ADO_Reserved_201; ADO_Reserved_202; ADO_Reserved_203; ADO_Reserved_204;
ADO_Reserved_205; ADO_Reserved_206; ADO_Reserved_207; ADO_Reserved_208; ADO_Reserved_209;
ADO_Reserved_210; ADO_Reserved_211; ADO_Reserved_212; ADO_Reserved_213; ADO_Reserved_214;
ADO_Reserved_215; ADO_Reserved_216; ADO_Reserved_217; ADO_Reserved_218; ADO_Reserved_219;
ADO_Reserved_220; ADO_Reserved_221; ADO_Reserved_222; ADO_Reserved_223; ADO_Reserved_224;
ADO_Reserved_225; ADO_Reserved_226; ADO_Reserved_227; ADO_Reserved_228; ADO_Reserved_229;
ADO_Reserved_230; ADO_Reserved_231; ADO_Reserved_232; ADO_Reserved_233; ADO_Reserved_234;
ADO_Reserved_235; ADO_Reserved_236; ADO_Reserved_237; ADO_Reserved_238; ADO_Reserved_239;
ADO_Reserved_240; ADO_Reserved_241; ADO_Reserved_242; ADO_Reserved_243; ADO_Reserved_244;
ADO_Reserved_245; ADO_Reserved_246; ADO_Reserved_247; ADO_Reserved_248; ADO_Reserved_249;

#undef ADO_Reserved_4
#undef ADO_Reserved_5
#undef ADO_Reserved_6
#undef ADO_Reserved_7
#undef ADO_Reserved_8
#undef ADO_Reserved_9
#undef ADO_Reserved_10
#undef ADO_Reserved_12
#undef ADO_Reserved_13
#undef ADO_Reserved_14
#undef ADO_Reserved_15
#undef ADO_Reserved_16
#undef ADO_Reserved_17
#undef ADO_Reserved_18
#undef ADO_Reserved_19
#undef ADO_Reserved_20
#undef ADO_Reserved_21
#undef ADO_Reserved_22
#undef ADO_Reserved_23
#undef ADO_Reserved_24
#undef ADO_Reserved_25
#undef ADO_Reserved_26
#undef ADO_Reserved_27
#undef ADO_Reserved_28
#undef ADO_Reserved_29
#undef ADO_Reserved_30
#undef ADO_Reserved_31
#undef ADO_Reserved_32
#undef ADO_Reserved_33
#undef ADO_Reserved_34
#undef ADO_Reserved_35
#undef ADO_Reserved_36
#undef ADO_Reserved_37
#undef ADO_Reserved_38
#undef ADO_Reserved_39
#undef ADO_Reserved_40
#undef ADO_Reserved_41
#undef ADO_Reserved_42
#undef ADO_Reserved_43
#undef ADO_Reserved_44
#undef ADO_Reserved_45
#undef ADO_Reserved_46
#undef ADO_Reserved_47
#undef ADO_Reserved_48
#undef ADO_Reserved_49
#undef ADO_Reserved_50
#undef ADO_Reserved_51
#undef ADO_Reserved_52
#undef ADO_Reserved_53
#undef ADO_Reserved_54
#undef ADO_Reserved_55
#undef ADO_Reserved_56
#undef ADO_Reserved_57
#undef ADO_Reserved_58
#undef ADO_Reserved_59
#undef ADO_Reserved_60
#undef ADO_Reserved_61
#undef ADO_Reserved_62
#undef ADO_Reserved_63
#undef ADO_Reserved_64
#undef ADO_Reserved_65
#undef ADO_Reserved_66
#undef ADO_Reserved_67
#undef ADO_Reserved_68
#undef ADO_Reserved_69
#undef ADO_Reserved_70
#undef ADO_Reserved_71
#undef ADO_Reserved_72
#undef ADO_Reserved_73
#undef ADO_Reserved_74
#undef ADO_Reserved_75
#undef ADO_Reserved_76
#undef ADO_Reserved_77
#undef ADO_Reserved_78
#undef ADO_Reserved_79
#undef ADO_Reserved_80
#undef ADO_Reserved_81
#undef ADO_Reserved_82
#undef ADO_Reserved_83
#undef ADO_Reserved_84
#undef ADO_Reserved_85
#undef ADO_Reserved_86
#undef ADO_Reserved_87
#undef ADO_Reserved_88
#undef ADO_Reserved_89
#undef ADO_Reserved_90
#undef ADO_Reserved_91
#undef ADO_Reserved_92
#undef ADO_Reserved_93
#undef ADO_Reserved_94
#undef ADO_Reserved_95
#undef ADO_Reserved_96
#undef ADO_Reserved_97
#undef ADO_Reserved_98
#undef ADO_Reserved_99
#undef ADO_Reserved_100
#undef ADO_Reserved_101
#undef ADO_Reserved_102
#undef ADO_Reserved_103
#undef ADO_Reserved_104
#undef ADO_Reserved_105
#undef ADO_Reserved_106
#undef ADO_Reserved_107
#undef ADO_Reserved_108
#undef ADO_Reserved_109
#undef ADO_Reserved_110
#undef ADO_Reserved_111
#undef ADO_Reserved_112
#undef ADO_Reserved_113
#undef ADO_Reserved_114
#undef ADO_Reserved_115
#undef ADO_Reserved_116
#undef ADO_Reserved_117
#undef ADO_Reserved_118
#undef ADO_Reserved_119
#undef ADO_Reserved_120
#undef ADO_Reserved_121
#undef ADO_Reserved_122
#undef ADO_Reserved_123
#undef ADO_Reserved_124
#undef ADO_Reserved_125
#undef ADO_Reserved_126
#undef ADO_Reserved_127
#undef ADO_Reserved_128
#undef ADO_Reserved_129
#undef ADO_Reserved_130
#undef ADO_Reserved_131
#undef ADO_Reserved_132
#undef ADO_Reserved_133
#undef ADO_Reserved_134
#undef ADO_Reserved_135
#undef ADO_Reserved_136
#undef ADO_Reserved_137
#undef ADO_Reserved_138
#undef ADO_Reserved_139
#undef ADO_Reserved_140
#undef ADO_Reserved_141
#undef ADO_Reserved_142
#undef ADO_Reserved_143
#undef ADO_Reserved_144
#undef ADO_Reserved_145
#undef ADO_Reserved_146
#undef ADO_Reserved_147
#undef ADO_Reserved_148
#undef ADO_Reserved_149
#undef ADO_Reserved_150
#undef ADO_Reserved_151
#undef ADO_Reserved_152
#undef ADO_Reserved_153
#undef ADO_Reserved_154
#undef ADO_Reserved_155
#undef ADO_Reserved_156
#undef ADO_Reserved_157
#undef ADO_Reserved_158
#undef ADO_Reserved_159
#undef ADO_Reserved_160
#undef ADO_Reserved_161
#undef ADO_Reserved_162
#undef ADO_Reserved_163
#undef ADO_Reserved_164
#undef ADO_Reserved_165
#undef ADO_Reserved_166
#undef ADO_Reserved_167
#undef ADO_Reserved_168
#undef ADO_Reserved_169
#undef ADO_Reserved_170
#undef ADO_Reserved_171
#undef ADO_Reserved_172
#undef ADO_Reserved_173
#undef ADO_Reserved_174
#undef ADO_Reserved_175
#undef ADO_Reserved_176
#undef ADO_Reserved_177
#undef ADO_Reserved_178
#undef ADO_Reserved_179
#undef ADO_Reserved_180
#undef ADO_Reserved_181
#undef ADO_Reserved_182
#undef ADO_Reserved_183
#undef ADO_Reserved_184
#undef ADO_Reserved_185
#undef ADO_Reserved_186
#undef ADO_Reserved_187
#undef ADO_Reserved_188
#undef ADO_Reserved_189
#undef ADO_Reserved_190
#undef ADO_Reserved_191
#undef ADO_Reserved_192
#undef ADO_Reserved_193
#undef ADO_Reserved_194
#undef ADO_Reserved_195
#undef ADO_Reserved_196
#undef ADO_Reserved_197
#undef ADO_Reserved_198
#undef ADO_Reserved_199
#undef ADO_Reserved_200
#undef ADO_Reserved_201
#undef ADO_Reserved_202
#undef ADO_Reserved_203
#undef ADO_Reserved_204
#undef ADO_Reserved_205
#undef ADO_Reserved_206
#undef ADO_Reserved_207
#undef ADO_Reserved_208
#undef ADO_Reserved_209
#undef ADO_Reserved_210
#undef ADO_Reserved_211
#undef ADO_Reserved_212
#undef ADO_Reserved_213
#undef ADO_Reserved_214
#undef ADO_Reserved_215
#undef ADO_Reserved_216
#undef ADO_Reserved_217
#undef ADO_Reserved_218
#undef ADO_Reserved_219
#undef ADO_Reserved_220
#undef ADO_Reserved_221
#undef ADO_Reserved_222
#undef ADO_Reserved_223
#undef ADO_Reserved_224
#undef ADO_Reserved_225
#undef ADO_Reserved_226
#undef ADO_Reserved_227
#undef ADO_Reserved_228
#undef ADO_Reserved_229
#undef ADO_Reserved_230
#undef ADO_Reserved_231
#undef ADO_Reserved_232
#undef ADO_Reserved_233
#undef ADO_Reserved_234
#undef ADO_Reserved_235
#undef ADO_Reserved_236
#undef ADO_Reserved_237
#undef ADO_Reserved_238
#undef ADO_Reserved_239
#undef ADO_Reserved_240
#undef ADO_Reserved_241
#undef ADO_Reserved_242
#undef ADO_Reserved_243
#undef ADO_Reserved_244
#undef ADO_Reserved_245
#undef ADO_Reserved_246
#undef ADO_Reserved_247
#undef ADO_Reserved_248
#undef ADO_Reserved_249
#endif

#endif

#endif
