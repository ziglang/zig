/* As _CRT_MT is getting defined in libgcc when using shared version, or it is getting defined by startup code itself,
   this library is a dummy version for supporting the link library for gcc's option -mthreads.  As we support TLS-cleanup
   even without specifying this library, this library is deprecated and just kept for compatibility.  */
int _CRT_MT_OLD = 1;

