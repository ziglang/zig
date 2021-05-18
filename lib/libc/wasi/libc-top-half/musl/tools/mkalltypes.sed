/^TYPEDEF/s/TYPEDEF \(.*\) \([^ ]*\);$/#if defined(__NEED_\2) \&\& !defined(__DEFINED_\2)\
typedef \1 \2;\
#define __DEFINED_\2\
#endif\
/
/^STRUCT/s/STRUCT * \([^ ]*\) \(.*\);$/#if defined(__NEED_struct_\1) \&\& !defined(__DEFINED_struct_\1)\
struct \1 \2;\
#define __DEFINED_struct_\1\
#endif\
/
/^UNION/s/UNION * \([^ ]*\) \(.*\);$/#if defined(__NEED_union_\1) \&\& !defined(__DEFINED_union_\1)\
union \1 \2;\
#define __DEFINED_union_\1\
#endif\
/
