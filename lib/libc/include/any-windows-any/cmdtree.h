/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 440
#endif

#include "rpc.h"
#include "rpcndr.h"

#ifndef __RPCNDR_H_VERSION__
#error this stub requires an updated version of <rpcndr.h>
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __cmdtree_h__
#define __cmdtree_h__

#ifndef __ICommandTree_FWD_DEFINED__
#define __ICommandTree_FWD_DEFINED__
typedef struct ICommandTree ICommandTree;
#endif

#ifndef __IQuery_FWD_DEFINED__
#define __IQuery_FWD_DEFINED__
typedef struct IQuery IQuery;
#endif

#include "oledb.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifdef _WIN64
#include <pshpack8.h>
#else
#include <pshpack2.h>
#endif

  extern RPC_IF_HANDLE __MIDL_itf_cmdtree_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_cmdtree_0000_v0_0_s_ifspec;

#ifndef __CommandTreeStructureDefinitions_INTERFACE_DEFINED__
#define __CommandTreeStructureDefinitions_INTERFACE_DEFINED__

  typedef WORD DBCOMMANDOP;

  enum DBCOMMANDOPENUM {
    DBOP_scalar_constant = 0,DBOP_DEFAULT,DBOP_NULL,DBOP_bookmark_name,
    DBOP_catalog_name,DBOP_column_name,DBOP_schema_name,
    DBOP_outall_name,DBOP_qualifier_name,DBOP_qualified_column_name,
    DBOP_table_name,DBOP_nested_table_name,DBOP_nested_column_name,
    DBOP_row,DBOP_table,DBOP_sort,DBOP_distinct,DBOP_distinct_order_preserving,
    DBOP_alias,DBOP_cross_join,DBOP_union_join,DBOP_inner_join,DBOP_left_semi_join,
    DBOP_right_semi_join,DBOP_left_anti_semi_join,DBOP_right_anti_semi_join,
    DBOP_left_outer_join,DBOP_right_outer_join,DBOP_full_outer_join,DBOP_natural_join,
    DBOP_natural_left_outer_join,DBOP_natural_right_outer_join,
    DBOP_natural_full_outer_join,DBOP_set_intersection,
    DBOP_set_union,DBOP_set_left_difference,DBOP_set_right_difference,
    DBOP_set_anti_difference,DBOP_bag_intersection,
    DBOP_bag_union,DBOP_bag_left_difference,DBOP_bag_right_difference,
    DBOP_bag_anti_difference,DBOP_division,DBOP_relative_sampling,
    DBOP_absolute_sampling,DBOP_transitive_closure,
    DBOP_recursive_union,DBOP_aggregate,DBOP_remote_table,
    DBOP_select,DBOP_order_preserving_select,DBOP_project,
    DBOP_project_order_preserving,DBOP_top,DBOP_top_percent,
    DBOP_top_plus_ties,DBOP_top_percent_plus_ties,DBOP_rank,
    DBOP_rank_ties_equally,DBOP_rank_ties_equally_and_skip,
    DBOP_navigate,DBOP_nesting,DBOP_unnesting,
    DBOP_nested_apply,DBOP_cross_tab,DBOP_is_NULL,DBOP_is_NOT_NULL,
    DBOP_equal,DBOP_not_equal,DBOP_less,DBOP_less_equal,
    DBOP_greater,DBOP_greater_equal,DBOP_equal_all,
    DBOP_not_equal_all,DBOP_less_all,DBOP_less_equal_all,
    DBOP_greater_all,DBOP_greater_equal_all,DBOP_equal_any,
    DBOP_not_equal_any,DBOP_less_any,DBOP_less_equal_any,
    DBOP_greater_any,DBOP_greater_equal_any,DBOP_anybits,
    DBOP_allbits,DBOP_anybits_any,DBOP_allbits_any,
    DBOP_anybits_all,DBOP_allbits_all,DBOP_between,
    DBOP_between_unordered,DBOP_match,DBOP_match_unique,
    DBOP_match_partial,DBOP_match_partial_unique,DBOP_match_full,
    DBOP_match_full_unique,DBOP_scalar_parameter,DBOP_scalar_function,
    DBOP_plus,DBOP_minus,DBOP_times,DBOP_over,DBOP_div,
    DBOP_modulo,DBOP_power,DBOP_like,DBOP_sounds_like,
    DBOP_like_any,DBOP_like_all,DBOP_is_INVALID,DBOP_is_TRUE,
    DBOP_is_FALSE,DBOP_and,DBOP_or,DBOP_xor,DBOP_equivalent,
    DBOP_not,DBOP_implies,DBOP_overlaps,DBOP_case_condition,
    DBOP_case_value,DBOP_nullif,DBOP_cast,DBOP_coalesce,
    DBOP_position,DBOP_extract,DBOP_char_length,DBOP_octet_length,
    DBOP_bit_length,DBOP_substring,DBOP_upper,DBOP_lower,
    DBOP_trim,DBOP_translate,DBOP_convert,DBOP_string_concat,
    DBOP_current_date,DBOP_current_time,DBOP_current_timestamp,
    DBOP_content_select,DBOP_content,DBOP_content_freetext,
    DBOP_content_proximity,DBOP_content_vector_or,DBOP_delete,
    DBOP_update,DBOP_insert,DBOP_min,DBOP_max,DBOP_count,
    DBOP_sum,DBOP_avg,DBOP_any_sample,DBOP_stddev,DBOP_stddev_pop,
    DBOP_var,DBOP_var_pop,DBOP_first,DBOP_last,DBOP_in,
    DBOP_exists,DBOP_unique,DBOP_subset,DBOP_proper_subset,
    DBOP_superset,DBOP_proper_superset,DBOP_disjoint,
    DBOP_pass_through,DBOP_defined_by_GUID,DBOP_text_command,
    DBOP_SQL_select,DBOP_prior_command_tree,DBOP_add_columns,
    DBOP_column_list_anchor,DBOP_column_list_element,
    DBOP_command_list_anchor,DBOP_command_list_element,
    DBOP_from_list_anchor,DBOP_from_list_element,
    DBOP_project_list_anchor,DBOP_project_list_element,
    DBOP_row_list_anchor,DBOP_row_list_element,
    DBOP_scalar_list_anchor,DBOP_scalar_list_element,
    DBOP_set_list_anchor,DBOP_set_list_element,
    DBOP_sort_list_anchor,DBOP_sort_list_element,
    DBOP_alter_character_set,DBOP_alter_collation,
    DBOP_alter_domain,DBOP_alter_index,DBOP_alter_procedure,
    DBOP_alter_schema,DBOP_alter_table,DBOP_alter_trigger,
    DBOP_alter_view,DBOP_coldef_list_anchor,DBOP_coldef_list_element,
    DBOP_create_assertion,DBOP_create_character_set,
    DBOP_create_collation,DBOP_create_domain,DBOP_create_index,
    DBOP_create_procedure,DBOP_create_schema,DBOP_create_synonym,
    DBOP_create_table,DBOP_create_temporary_table,
    DBOP_create_translation,DBOP_create_trigger,
    DBOP_create_view,DBOP_drop_assertion,DBOP_drop_character_set,
    DBOP_drop_collation,DBOP_drop_domain,DBOP_drop_index,
    DBOP_drop_procedure,DBOP_drop_schema,DBOP_drop_synonym,
    DBOP_drop_table,DBOP_drop_translation,DBOP_drop_trigger,
    DBOP_drop_view,DBOP_foreign_key,DBOP_grant_privileges,
    DBOP_index_list_anchor,DBOP_index_list_element,
    DBOP_primary_key,DBOP_property_list_anchor,
    DBOP_property_list_element,DBOP_referenced_table,
    DBOP_rename_object,DBOP_revoke_privileges,
    DBOP_schema_authorization,DBOP_unique_key,DBOP_scope_list_anchor,
    DBOP_scope_list_element,DBOP_content_table
  };
#ifdef DBINITCONSTANTS
  extern const OLEDBDECLSPEC GUID DBGUID_LIKE_SQL = {0xc8b521f6,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBGUID_LIKE_DOS = {0xc8b521f7,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBGUID_LIKE_OFS = {0xc8b521f8,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
  extern const OLEDBDECLSPEC GUID DBGUID_LIKE_MAPI = {0xc8b521f9,0x5cf3,0x11ce,{0xad,0xe5,0x00,0xaa,0x00,0x44,0x77,0x3d}};
#else
  extern const GUID DBGUID_LIKE_SQL;
  extern const GUID DBGUID_LIKE_DOS;
  extern const GUID DBGUID_LIKE_OFS;
  extern const GUID DBGUID_LIKE_MAPI;
#endif

  extern RPC_IF_HANDLE CommandTreeStructureDefinitions_v0_0_c_ifspec;
  extern RPC_IF_HANDLE CommandTreeStructureDefinitions_v0_0_s_ifspec;
#endif

#ifndef __ICommandTree_INTERFACE_DEFINED__
#define __ICommandTree_INTERFACE_DEFINED__

  typedef DWORD DBCOMMANDREUSE;
  enum DBCOMMANDREUSEENUM {
    DBCOMMANDREUSE_NONE = 0,DBCOMMANDREUSE_PROPERTIES = 0x1,DBCOMMANDREUSE_PARAMETERS = 0x2
  };
  typedef DWORD DBVALUEKIND;
  enum DBVALUEKINDENUM {
    DBVALUEKIND_BYGUID = 256,DBVALUEKIND_COLDESC,DBVALUEKIND_ID,
    DBVALUEKIND_CONTENT,DBVALUEKIND_CONTENTVECTOR,DBVALUEKIND_GROUPINFO,
    DBVALUEKIND_PARAMETER,DBVALUEKIND_PROPERTY,DBVALUEKIND_SETFUNC,
    DBVALUEKIND_SORTINFO,DBVALUEKIND_TEXT,DBVALUEKIND_COMMAND,
    DBVALUEKIND_MONIKER,DBVALUEKIND_ROWSET,DBVALUEKIND_LIKE,
    DBVALUEKIND_CONTENTPROXIMITY,DBVALUEKIND_CONTENTSCOPE,
    DBVALUEKIND_CONTENTTABLE,
    DBVALUEKIND_IDISPATCH = 9,DBVALUEKIND_IUNKNOWN = 13,DBVALUEKIND_EMPTY = 0,
    DBVALUEKIND_NULL = 1,DBVALUEKIND_I2 = 2,DBVALUEKIND_I4 = 3,DBVALUEKIND_R4 = 4,
    DBVALUEKIND_R8 = 5,DBVALUEKIND_CY = 6,DBVALUEKIND_DATE = 7,
    DBVALUEKIND_BSTR = 8,DBVALUEKIND_ERROR = 10,DBVALUEKIND_BOOL = 11,
    DBVALUEKIND_VARIANT = 12,DBVALUEKIND_VECTOR = 0x1000,DBVALUEKIND_ARRAY = 0x2000, DBVALUEKIND_BYREF = 0x4000,
    DBVALUEKIND_I1 = 16,DBVALUEKIND_UI1 = 17,DBVALUEKIND_UI2 = 18,
    DBVALUEKIND_UI4 = 19,DBVALUEKIND_I8 = 20,DBVALUEKIND_UI8 = 21,
    DBVALUEKIND_GUID = 72,DBVALUEKIND_BYTES = 128,DBVALUEKIND_STR = 129,
    DBVALUEKIND_WSTR = 130,DBVALUEKIND_NUMERIC = 131,DBVALUEKIND_DBDATE = 133,
    DBVALUEKIND_DBTIME = 134,DBVALUEKIND_DBTIMESTAMP = 135,
    DBVALUEKIND_PROBABILISTIC = 136,DBVALUEKIND_RELEVANTDOCUMENT = 137
  };
  typedef struct tagDBBYGUID {
    BYTE *pbInfo;
    DBLENGTH cbInfo;
    GUID guid;
  } DBBYGUID;

#define GENERATE_METHOD_EXACT (0)
#define GENERATE_METHOD_PREFIX (1)
#define GENERATE_METHOD_INFLECT (2)

  typedef struct tagDBCONTENT {
    LPOLESTR pwszPhrase;
    DWORD dwGenerateMethod;
    LONG lWeight;
    LCID lcid;
  } DBCONTENT;

#define SCOPE_FLAG_MASK (0x000000ff)
#define SCOPE_FLAG_INCLUDE (0x00000001)
#define SCOPE_FLAG_DEEP (0x00000002)
#define SCOPE_TYPE_MASK (0xffffff00)
#define SCOPE_TYPE_WINPATH (0x00000100)
#define SCOPE_TYPE_VPATH (0x00000200)

  typedef struct tagDBCONTENTSCOPE {
    DWORD dwFlags;
    LPOLESTR *rgpwszTagName;
    LPOLESTR pwszElementValue;
  } DBCONTENTSCOPE;

  typedef struct tagDBCONTENTTABLE {
    LPOLESTR pwszMachine;
    LPOLESTR pwszCatalog;
  } DBCONTENTTABLE;

#define PROPID_QUERY_RANKVECTOR (0x2)
#define PROPID_QUERY_RANK (0x3)
#define PROPID_QUERY_HITCOUNT (0x4)
#define PROPID_QUERY_ALL (0x6)
#define PROPID_STG_CONTENTS (0x13)
#define VECTOR_RANK_MIN (0)
#define VECTOR_RANK_MAX (1)
#define VECTOR_RANK_INNER (2)
#define VECTOR_RANK_DICE (3)
#define VECTOR_RANK_JACCARD (4)

  typedef struct tagDBCONTENTVECTOR {
    LONG lWeight;
    DWORD dwRankingMethod;
  } DBCONTENTVECTOR;

  typedef struct tagDBGROUPINFO {
    LCID lcid;
  } DBGROUPINFO;

  typedef struct tagDBPARAMETER {
    LPOLESTR pwszName;
    ITypeInfo *pTypeInfo;
    DB_NUMERIC *pNum;
    DBLENGTH cbMaxLength;
    DBPARAMFLAGS dwFlags;
    DBTYPE wType;
  } DBPARAMETER;

#define DBSETFUNC_NONE 0x0
#define DBSETFUNC_ALL 0x1
#define DBSETFUNC_DISTINCT 0x2

  typedef struct tagDBSETFUNC {
    DWORD dwSetQuantifier;
  } DBSETFUNC;

  typedef struct tagDBSORTINFO {
    WINBOOL fDesc;
    LCID lcid;
  } DBSORTINFO;

  typedef struct tagDBTEXT {
    LPOLESTR pwszText;
    ULONG ulErrorLocator;
    ULONG ulTokenLength;
    GUID guidDialect;
  } DBTEXT;

  typedef struct tagDBLIKE {
    LONG lWeight;
    GUID guidDialect;
  } DBLIKE;

#define PROXIMITY_UNIT_WORD (0)
#define PROXIMITY_UNIT_SENTENCE (1)
#define PROXIMITY_UNIT_PARAGRAPH (2)
#define PROXIMITY_UNIT_CHAPTER (3)

  typedef struct tagDBCONTENTPROXIMITY {
    DWORD dwProximityUnit;
    ULONG ulProximityDistance;
    LONG lWeight;
  } DBCONTENTPROXIMITY;

  typedef struct tagDBPROBABILISTIC {
    LONG lWeight;
    float flK1;
    float flK2;
    float flK3;
    float flB;
  } DBPROBABILISTIC;

  typedef struct tagDBRELEVANTDOCUMENT {
    LONG lWeight;
    VARIANT vDocument;
  } DBRELEVANTDOCUMENT;

  typedef struct tagDBCOMMANDTREE {
    DBCOMMANDOP op;
    WORD wKind;
    struct tagDBCOMMANDTREE *pctFirstChild;
    struct tagDBCOMMANDTREE *pctNextSibling;
    union {
      __MINGW_EXTENSION __int64 llValue;
      __MINGW_EXTENSION unsigned __int64 ullValue;
      WINBOOL fValue;
      unsigned char uchValue;
      signed char schValue;
      unsigned short usValue;
      short sValue;
      LPOLESTR pwszValue;
      LONG lValue;
      ULONG ulValue;
      float flValue;
      double dblValue;
      CY cyValue;
      DATE dateValue;
      DBDATE dbdateValue;
      DBTIME dbtimeValue;
      SCODE scodeValue;
      BSTR *pbstrValue;
      ICommand *pCommand;
      IDispatch *pDispatch;
      IMoniker *pMoniker;
      IRowset *pRowset;
      IUnknown *pUnknown;
      DBBYGUID *pdbbygdValue;
      DBCOLUMNDESC *pcoldescValue;
      DBID *pdbidValue;
      DBLIKE *pdblikeValue;
      DBCONTENT *pdbcntntValue;
      DBCONTENTSCOPE *pdbcntntscpValue;
      DBCONTENTTABLE *pdbcntnttblValue;
      DBCONTENTVECTOR *pdbcntntvcValue;
      DBCONTENTPROXIMITY *pdbcntntproxValue;
      DBGROUPINFO *pdbgrpinfValue;
      DBPARAMETER *pdbparamValue;
      DBPROPSET *pdbpropValue;
      DBSETFUNC *pdbstfncValue;
      DBSORTINFO *pdbsrtinfValue;
      DBTEXT *pdbtxtValue;
      DBVECTOR *pdbvectorValue;
      SAFEARRAY *parrayValue;
      VARIANT *pvarValue;
      GUID *pGuid;
      BYTE *pbValue;
      char *pzValue;
      DB_NUMERIC *pdbnValue;
      DBTIMESTAMP *pdbtsValue;
      void *pvValue;
      DBPROBABILISTIC *pdbprobValue;
      DBRELEVANTDOCUMENT *pdbreldocValue;
    } value;
    HRESULT hrError;
  } DBCOMMANDTREE;

  EXTERN_C const IID IID_ICommandTree;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICommandTree : public IUnknown {
  public:
    virtual HRESULT WINAPI FindErrorNodes(const DBCOMMANDTREE *pRoot,ULONG *pcErrorNodes,DBCOMMANDTREE ***prgErrorNodes) = 0;
    virtual HRESULT WINAPI FreeCommandTree(DBCOMMANDTREE **ppRoot) = 0;
    virtual HRESULT WINAPI GetCommandTree(DBCOMMANDTREE **ppRoot) = 0;
    virtual HRESULT WINAPI SetCommandTree(DBCOMMANDTREE **ppRoot,DBCOMMANDREUSE dwCommandReuse,WINBOOL fCopy) = 0;
  };
#else
  typedef struct ICommandTreeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICommandTree *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICommandTree *This);
      ULONG (WINAPI *Release)(ICommandTree *This);
      HRESULT (WINAPI *FindErrorNodes)(ICommandTree *This,const DBCOMMANDTREE *pRoot,ULONG *pcErrorNodes,DBCOMMANDTREE ***prgErrorNodes);
      HRESULT (WINAPI *FreeCommandTree)(ICommandTree *This,DBCOMMANDTREE **ppRoot);
      HRESULT (WINAPI *GetCommandTree)(ICommandTree *This,DBCOMMANDTREE **ppRoot);
      HRESULT (WINAPI *SetCommandTree)(ICommandTree *This,DBCOMMANDTREE **ppRoot,DBCOMMANDREUSE dwCommandReuse,WINBOOL fCopy);
    END_INTERFACE
  } ICommandTreeVtbl;
  struct ICommandTree {
    CONST_VTBL struct ICommandTreeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICommandTree_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICommandTree_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICommandTree_Release(This) (This)->lpVtbl->Release(This)
#define ICommandTree_FindErrorNodes(This,pRoot,pcErrorNodes,prgErrorNodes) (This)->lpVtbl->FindErrorNodes(This,pRoot,pcErrorNodes,prgErrorNodes)
#define ICommandTree_FreeCommandTree(This,ppRoot) (This)->lpVtbl->FreeCommandTree(This,ppRoot)
#define ICommandTree_GetCommandTree(This,ppRoot) (This)->lpVtbl->GetCommandTree(This,ppRoot)
#define ICommandTree_SetCommandTree(This,ppRoot,dwCommandReuse,fCopy) (This)->lpVtbl->SetCommandTree(This,ppRoot,dwCommandReuse,fCopy)
#endif
#endif
  HRESULT WINAPI ICommandTree_FindErrorNodes_Proxy(ICommandTree *This,const DBCOMMANDTREE *pRoot,ULONG *pcErrorNodes,DBCOMMANDTREE ***prgErrorNodes);
  void __RPC_STUB ICommandTree_FindErrorNodes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICommandTree_FreeCommandTree_Proxy(ICommandTree *This,DBCOMMANDTREE **ppRoot);
  void __RPC_STUB ICommandTree_FreeCommandTree_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICommandTree_GetCommandTree_Proxy(ICommandTree *This,DBCOMMANDTREE **ppRoot);
  void __RPC_STUB ICommandTree_GetCommandTree_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICommandTree_SetCommandTree_Proxy(ICommandTree *This,DBCOMMANDTREE **ppRoot,DBCOMMANDREUSE dwCommandReuse,WINBOOL fCopy);
  void __RPC_STUB ICommandTree_SetCommandTree_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IQuery_INTERFACE_DEFINED__
#define __IQuery_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IQuery;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IQuery : public ICommandTree {
  public:
    virtual HRESULT WINAPI AddPostProcessing(DBCOMMANDTREE **ppRoot,WINBOOL fCopy) = 0;
    virtual HRESULT WINAPI GetCardinalityEstimate(DBORDINAL *pulCardinality) = 0;
  };
#else
  typedef struct IQueryVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IQuery *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IQuery *This);
      ULONG (WINAPI *Release)(IQuery *This);
      HRESULT (WINAPI *FindErrorNodes)(IQuery *This,const DBCOMMANDTREE *pRoot,ULONG *pcErrorNodes,DBCOMMANDTREE ***prgErrorNodes);
      HRESULT (WINAPI *FreeCommandTree)(IQuery *This,DBCOMMANDTREE **ppRoot);
      HRESULT (WINAPI *GetCommandTree)(IQuery *This,DBCOMMANDTREE **ppRoot);
      HRESULT (WINAPI *SetCommandTree)(IQuery *This,DBCOMMANDTREE **ppRoot,DBCOMMANDREUSE dwCommandReuse,WINBOOL fCopy);
      HRESULT (WINAPI *AddPostProcessing)(IQuery *This,DBCOMMANDTREE **ppRoot,WINBOOL fCopy);
      HRESULT (WINAPI *GetCardinalityEstimate)(IQuery *This,DBORDINAL *pulCardinality);
    END_INTERFACE
  } IQueryVtbl;
  struct IQuery {
    CONST_VTBL struct IQueryVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IQuery_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IQuery_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IQuery_Release(This) (This)->lpVtbl->Release(This)
#define IQuery_FindErrorNodes(This,pRoot,pcErrorNodes,prgErrorNodes) (This)->lpVtbl->FindErrorNodes(This,pRoot,pcErrorNodes,prgErrorNodes)
#define IQuery_FreeCommandTree(This,ppRoot) (This)->lpVtbl->FreeCommandTree(This,ppRoot)
#define IQuery_GetCommandTree(This,ppRoot) (This)->lpVtbl->GetCommandTree(This,ppRoot)
#define IQuery_SetCommandTree(This,ppRoot,dwCommandReuse,fCopy) (This)->lpVtbl->SetCommandTree(This,ppRoot,dwCommandReuse,fCopy)
#define IQuery_AddPostProcessing(This,ppRoot,fCopy) (This)->lpVtbl->AddPostProcessing(This,ppRoot,fCopy)
#define IQuery_GetCardinalityEstimate(This,pulCardinality) (This)->lpVtbl->GetCardinalityEstimate(This,pulCardinality)
#endif
#endif
  HRESULT WINAPI IQuery_AddPostProcessing_Proxy(IQuery *This,DBCOMMANDTREE **ppRoot,WINBOOL fCopy);
  void __RPC_STUB IQuery_AddPostProcessing_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IQuery_GetCardinalityEstimate_Proxy(IQuery *This,DBORDINAL *pulCardinality);
  void __RPC_STUB IQuery_GetCardinalityEstimate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#include <poppack.h>

  extern RPC_IF_HANDLE __MIDL_itf_cmdtree_0359_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_cmdtree_0359_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
