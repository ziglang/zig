#ifndef _OFF_T_DEFINED
#define _OFF_T_DEFINED
#ifndef _OFF_T_
#define _OFF_T_
  typedef long _off_t;
#if !defined(NO_OLDNAMES) || defined(_POSIX)
  typedef long off32_t;
#endif
#endif

#ifndef _OFF64_T_DEFINED
#define _OFF64_T_DEFINED
  __MINGW_EXTENSION typedef long long _off64_t;
#if !defined(NO_OLDNAMES) || defined(_POSIX)
  __MINGW_EXTENSION typedef long long off64_t;
#endif
#endif /*_OFF64_T_DEFINED */


#ifndef _FILE_OFFSET_BITS_SET_OFFT
#define _FILE_OFFSET_BITS_SET_OFFT
#if !defined(NO_OLDNAMES) || defined(_POSIX)
#if (defined(_FILE_OFFSET_BITS) && (_FILE_OFFSET_BITS == 64))
typedef off64_t off_t;
#else
typedef off32_t off_t;
#endif /* #if !defined(NO_OLDNAMES) || defined(_POSIX) */
#endif /* (defined(_FILE_OFFSET_BITS) && (_FILE_OFFSET_BITS == 64)) */
#endif /* _FILE_OFFSET_BITS_SET_OFFT */


#endif /* _OFF_T_DEFINED */
