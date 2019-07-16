/* Dummy crtn file.

   In this configuration, crti.o and crtn.o are both empty because the
   .init_array/.fini_array sections are used exclusively.

   Older ports cannot use this because even if the linker used to
   build libc itself has .init_array support, we don't want to produce
   a crt[in].o that presume a linker that new will be used to link
   other things later.

   But new configurations without compatibility concerns for
   toolchains without .init_array support can use this to avoid the
   superfluous .init and .fini boilerplate code.  */
