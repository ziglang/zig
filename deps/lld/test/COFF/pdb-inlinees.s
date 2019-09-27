# REQUIRES: x86
# RUN: llvm-mc -filetype=obj %s -o %t.obj -triple x86_64-windows-msvc
# RUN: lld-link -entry:main -nodefaultlib %t.obj -out:%t.exe -pdb:%t.pdb -debug
# RUN: llvm-pdbutil dump -il %t.pdb | FileCheck %s

# Compiled from this C code, with modifications to test multiple file checksums:
# volatile int x;
# static __forceinline void inlinee_2(void) {
#   ++x;
#   __debugbreak();
#   ++x;
# }
# static __forceinline void inlinee_1(void) {
#   ++x;
#   inlinee_2();
#   ++x;
# }
# int main() {
#   ++x;
#   inlinee_1();
#   ++x;
#   return x;
# }

# CHECK:                             Inlinee Lines
# CHECK:      Mod 0000 | `{{.*}}pdb-inlinees.s.tmp.obj`:
# CHECK-NEXT:  Inlinee |  Line | Source File
# CHECK-NEXT:   0x1000 |     7 | C:\src\llvm-project\build\t.c (MD5: A79D837C976E9F0463A474D74E2EE9E7)
# CHECK-NEXT:   0x1001 |     2 | C:\src\llvm-project\build\file2.h (MD5: FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)

	.text
	.def	 @feat.00;
	.scl	3;
	.type	0;
	.endef
	.globl	@feat.00
.set @feat.00, 0
	.intel_syntax noprefix
	.file	"t.c"
	.def	 main;
	.scl	2;
	.type	32;
	.endef
	.section	.text,"xr",one_only,main
	.globl	main                    # -- Begin function main
main:                                   # @main
.Lfunc_begin0:
	.cv_func_id 0
# %bb.0:                                # %entry
	.cv_file	1 "C:\\src\\llvm-project\\build\\t.c" "A79D837C976E9F0463A474D74E2EE9E7" 1
	.cv_file	2 "C:\\src\\llvm-project\\build\\file2.h" "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" 1
	.cv_loc	0 1 13 0                # t.c:13:0
	inc	dword ptr [rip + x]
.Ltmp0:
	.cv_inline_site_id 1 within 0 inlined_at 1 14 0
	.cv_loc	1 1 8 0                 # t.c:8:0
	inc	dword ptr [rip + x]
.Ltmp1:
	.cv_inline_site_id 2 within 1 inlined_at 1 9 0
	.cv_loc	2 2 3 0                 # file2.h:3:0
	inc	dword ptr [rip + x]
	.cv_loc	2 2 4 0                 # file2.h:4:0
	int3
	.cv_loc	2 2 5 0                 # file2.h:5:0
	inc	dword ptr [rip + x]
.Ltmp2:
	.cv_loc	1 1 10 0                # t.c:10:0
	inc	dword ptr [rip + x]
.Ltmp3:
	.cv_loc	0 1 15 0                # t.c:15:0
	inc	dword ptr [rip + x]
	.cv_loc	0 1 16 0                # t.c:16:0
	mov	eax, dword ptr [rip + x]
	ret
.Ltmp4:
.Lfunc_end0:
                                        # -- End function
	.comm	x,4,2                   # @x
	.section	.debug$S,"dr"
	.p2align	2
	.long	4                       # Debug section magic
	.long	241
	.long	.Ltmp6-.Ltmp5           # Subsection size
.Ltmp5:
	.short	.Ltmp8-.Ltmp7           # Record length
.Ltmp7:
	.short	4412                    # Record kind: S_COMPILE3
	.long	0                       # Flags and language
	.short	208                     # CPUType
	.short	9                       # Frontend version
	.short	0
	.short	0
	.short	0
	.short	9000                    # Backend version
	.short	0
	.short	0
	.short	0
	.asciz	"clang version 9.0.0 (git@github.com:llvm/llvm-project.git aa762a56caf3ef2b0b41c501e66d3ef32903a2d0)" # Null-terminated compiler version string
	.p2align	2
.Ltmp8:
.Ltmp6:
	.p2align	2
	.long	246                     # Inlinee lines subsection
	.long	.Ltmp10-.Ltmp9          # Subsection size
.Ltmp9:
	.long	0                       # Inlinee lines signature

                                        # Inlined function inlinee_1 starts at t.c:7
	.long	4098                    # Type index of inlined function
	.cv_filechecksumoffset	1       # Offset into filechecksum table
	.long	7                       # Starting line number

                                        # Inlined function inlinee_2 starts at file2.h:2
	.long	4099                    # Type index of inlined function
	.cv_filechecksumoffset	2       # Offset into filechecksum table
	.long	2                       # Starting line number
.Ltmp10:
	.p2align	2
	.section	.debug$S,"dr",associative,main
	.p2align	2
	.long	4                       # Debug section magic
	.long	241                     # Symbol subsection for main
	.long	.Ltmp12-.Ltmp11         # Subsection size
.Ltmp11:
	.short	.Ltmp14-.Ltmp13         # Record length
.Ltmp13:
	.short	4423                    # Record kind: S_GPROC32_ID
	.long	0                       # PtrParent
	.long	0                       # PtrEnd
	.long	0                       # PtrNext
	.long	.Lfunc_end0-main        # Code size
	.long	0                       # Offset after prologue
	.long	0                       # Offset before epilogue
	.long	4101                    # Function type index
	.secrel32	main            # Function section relative address
	.secidx	main                    # Function section index
	.byte	0                       # Flags
	.asciz	"main"                  # Function name
	.p2align	2
.Ltmp14:
	.short	.Ltmp16-.Ltmp15         # Record length
.Ltmp15:
	.short	4114                    # Record kind: S_FRAMEPROC
	.long	0                       # FrameSize
	.long	0                       # Padding
	.long	0                       # Offset of padding
	.long	0                       # Bytes of callee saved registers
	.long	0                       # Exception handler offset
	.short	0                       # Exception handler section
	.long	0                       # Flags (defines frame register)
	.p2align	2
.Ltmp16:
	.short	.Ltmp18-.Ltmp17         # Record length
.Ltmp17:
	.short	4429                    # Record kind: S_INLINESITE
	.long	0                       # PtrParent
	.long	0                       # PtrEnd
	.long	4098                    # Inlinee type index
	.cv_inline_linetable	1 1 7 .Lfunc_begin0 .Lfunc_end0
	.p2align	2
.Ltmp18:
	.short	.Ltmp20-.Ltmp19         # Record length
.Ltmp19:
	.short	4429                    # Record kind: S_INLINESITE
	.long	0                       # PtrParent
	.long	0                       # PtrEnd
	.long	4099                    # Inlinee type index
	.cv_inline_linetable	2 2 2 .Lfunc_begin0 .Lfunc_end0
	.p2align	2
.Ltmp20:
	.short	2                       # Record length
	.short	4430                    # Record kind: S_INLINESITE_END
	.short	2                       # Record length
	.short	4430                    # Record kind: S_INLINESITE_END
	.short	2                       # Record length
	.short	4431                    # Record kind: S_PROC_ID_END
.Ltmp12:
	.p2align	2
	.cv_linetable	0, main, .Lfunc_end0
	.section	.debug$S,"dr"
	.long	241                     # Symbol subsection for globals
	.long	.Ltmp22-.Ltmp21         # Subsection size
.Ltmp21:
	.short	.Ltmp24-.Ltmp23         # Record length
.Ltmp23:
	.short	4365                    # Record kind: S_GDATA32
	.long	4102                    # Type
	.secrel32	x               # DataOffset
	.secidx	x                       # Segment
	.asciz	"x"                     # Name
	.p2align	2
.Ltmp24:
.Ltmp22:
	.p2align	2
	.cv_filechecksums               # File index to string table offset subsection
	.cv_stringtable                 # String table
	.long	241
	.long	.Ltmp26-.Ltmp25         # Subsection size
.Ltmp25:
	.short	.Ltmp28-.Ltmp27         # Record length
.Ltmp27:
	.short	4428                    # Record kind: S_BUILDINFO
	.long	4105                    # LF_BUILDINFO index
	.p2align	2
.Ltmp28:
.Ltmp26:
	.p2align	2
	.section	.debug$T,"dr"
	.p2align	2
	.long	4                       # Debug section magic
	# ArgList (0x1000) {
	#   TypeLeafKind: LF_ARGLIST (0x1201)
	#   NumArgs: 0
	#   Arguments [
	#   ]
	# }
	.byte	0x06, 0x00, 0x01, 0x12
	.byte	0x00, 0x00, 0x00, 0x00
	# Procedure (0x1001) {
	#   TypeLeafKind: LF_PROCEDURE (0x1008)
	#   ReturnType: void (0x3)
	#   CallingConvention: NearC (0x0)
	#   FunctionOptions [ (0x0)
	#   ]
	#   NumParameters: 0
	#   ArgListType: () (0x1000)
	# }
	.byte	0x0e, 0x00, 0x08, 0x10
	.byte	0x03, 0x00, 0x00, 0x00
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x00, 0x10, 0x00, 0x00
	# FuncId (0x1002) {
	#   TypeLeafKind: LF_FUNC_ID (0x1601)
	#   ParentScope: 0x0
	#   FunctionType: void () (0x1001)
	#   Name: inlinee_1
	# }
	.byte	0x16, 0x00, 0x01, 0x16
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x01, 0x10, 0x00, 0x00
	.byte	0x69, 0x6e, 0x6c, 0x69
	.byte	0x6e, 0x65, 0x65, 0x5f
	.byte	0x31, 0x00, 0xf2, 0xf1
	# FuncId (0x1003) {
	#   TypeLeafKind: LF_FUNC_ID (0x1601)
	#   ParentScope: 0x0
	#   FunctionType: void () (0x1001)
	#   Name: inlinee_2
	# }
	.byte	0x16, 0x00, 0x01, 0x16
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x01, 0x10, 0x00, 0x00
	.byte	0x69, 0x6e, 0x6c, 0x69
	.byte	0x6e, 0x65, 0x65, 0x5f
	.byte	0x32, 0x00, 0xf2, 0xf1
	# Procedure (0x1004) {
	#   TypeLeafKind: LF_PROCEDURE (0x1008)
	#   ReturnType: int (0x74)
	#   CallingConvention: NearC (0x0)
	#   FunctionOptions [ (0x0)
	#   ]
	#   NumParameters: 0
	#   ArgListType: () (0x1000)
	# }
	.byte	0x0e, 0x00, 0x08, 0x10
	.byte	0x74, 0x00, 0x00, 0x00
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x00, 0x10, 0x00, 0x00
	# FuncId (0x1005) {
	#   TypeLeafKind: LF_FUNC_ID (0x1601)
	#   ParentScope: 0x0
	#   FunctionType: int () (0x1004)
	#   Name: main
	# }
	.byte	0x12, 0x00, 0x01, 0x16
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x04, 0x10, 0x00, 0x00
	.byte	0x6d, 0x61, 0x69, 0x6e
	.byte	0x00, 0xf3, 0xf2, 0xf1
	# Modifier (0x1006) {
	#   TypeLeafKind: LF_MODIFIER (0x1001)
	#   ModifiedType: int (0x74)
	#   Modifiers [ (0x2)
	#     Volatile (0x2)
	#   ]
	# }
	.byte	0x0a, 0x00, 0x01, 0x10
	.byte	0x74, 0x00, 0x00, 0x00
	.byte	0x02, 0x00, 0xf2, 0xf1
	# StringId (0x1007) {
	#   TypeLeafKind: LF_STRING_ID (0x1605)
	#   Id: 0x0
	#   StringData: C:\src\llvm-project\build
	# }
	.byte	0x22, 0x00, 0x05, 0x16
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x43, 0x3a, 0x5c, 0x73
	.byte	0x72, 0x63, 0x5c, 0x6c
	.byte	0x6c, 0x76, 0x6d, 0x2d
	.byte	0x70, 0x72, 0x6f, 0x6a
	.byte	0x65, 0x63, 0x74, 0x5c
	.byte	0x62, 0x75, 0x69, 0x6c
	.byte	0x64, 0x00, 0xf2, 0xf1
	# StringId (0x1008) {
	#   TypeLeafKind: LF_STRING_ID (0x1605)
	#   Id: 0x0
	#   StringData: t.c
	# }
	.byte	0x0a, 0x00, 0x05, 0x16
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x74, 0x2e, 0x63, 0x00
	# BuildInfo (0x1009) {
	#   TypeLeafKind: LF_BUILDINFO (0x1603)
	#   NumArgs: 5
	#   Arguments [
	#     ArgType: C:\src\llvm-project\build (0x1007)
	#     ArgType: 0x0
	#     ArgType: t.c (0x1008)
	#     ArgType: 0x0
	#     ArgType: 0x0
	#   ]
	# }
	.byte	0x1a, 0x00, 0x03, 0x16
	.byte	0x05, 0x00, 0x07, 0x10
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x00, 0x00, 0x08, 0x10
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x00, 0x00, 0xf2, 0xf1

	.addrsig
	.addrsig_sym x
