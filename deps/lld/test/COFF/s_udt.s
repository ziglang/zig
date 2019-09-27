# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-windows-msvc < %s > %t.obj
# RUN: lld-link /DEBUG:FULL /nodefaultlib /entry:main %t.obj /PDB:%t.pdb /OUT:%t.exe
# RUN: llvm-pdbutil dump -types -globals -symbols -modi=0 %t.pdb | FileCheck %s

# CHECK:                               Types (TPI Stream)
# CHECK-NEXT: ============================================================
# CHECK:      0x1003 | LF_STRUCTURE [size = 44] `Struct`
# CHECK-NEXT:          unique name: `.?AUStruct@@`
# CHECK-NEXT:          vtable: <no type>, base list: <no type>, field list: <no type>
# CHECK-NEXT:          options: forward ref (-> 0x1006) | has unique name, sizeof 0
# CHECK-NEXT: 0x1004 | LF_POINTER [size = 12]
# CHECK-NEXT:          referent = 0x1003, mode = pointer, opts = None, kind = ptr64
# CHECK:      0x1006 | LF_STRUCTURE [size = 44] `Struct`
# CHECK-NEXT:          unique name: `.?AUStruct@@`
# CHECK-NEXT:          vtable: <no type>, base list: <no type>, field list: 0x1005
# CHECK-NEXT:          options: has unique name, sizeof 4
# CHECK:                               Global Symbols
# CHECK-NEXT: ============================================================
# CHECK:      {{.*}} | S_UDT [size = 24] `StructTypedef`
# CHECK:               original type = 0x1003
# CHECK:      {{.*}} | S_UDT [size = 16] `Struct`
# CHECK:               original type = 0x1006
# CHECK:      {{.*}} | S_UDT [size = 20] `IntTypedef`
# CHECK:               original type = 0x0074 (int)
# CHECK:                               Symbols
# CHECK-NEXT: ============================================================
# CHECK:      {{.*}} | S_GPROC32 [size = 44] `main`
# CHECK-NEXT:          parent = 0, end = 252, addr = 0001:0000, code size = 52
# CHECK-NEXT:          type = `0x1002 (int (int, char**))`, debug start = 0, debug end = 0, flags = none
# CHECK-NOT:  {{.*}} | S_END
# CHECK:      {{.*}} | S_UDT [size = 28] `main::LocalTypedef`
# CHECK-NEXT:          original type = 0x1004
# CHECK:      {{.*}} | S_END [size = 4]

# source code to re-generate:
# clang-cl /Z7 /GS- /GR- /c foo.cpp
#
# struct Struct {
#   int x;
# };
#
# using IntTypedef = int;
# using StructTypedef = Struct;
# Struct S;
# StructTypedef SS;
# IntTypedef I;
#
# int main(int argc, char **argv) {
#   using LocalTypedef = Struct*;
#   LocalTypedef SPtr;
#   return I + S.x + SS.x + SPtr->x;
# }

	.text
	.def	 @feat.00;
	.scl	3;
	.type	0;
	.endef
	.globl	@feat.00
.set @feat.00, 0
	.intel_syntax noprefix
	.def	 main;
	.scl	2;
	.type	32;
	.endef
	.globl	main                    # -- Begin function main
	.p2align	4, 0x90
main:                                   # @main
.Lfunc_begin0:
	.cv_func_id 0
	.cv_file	1 "D:\\src\\llvmbuild\\cl\\Debug\\x64\\foo.cpp" "2B62298EE3EEF94E1D81FDFE18BD46A6" 1
	.cv_loc	0 1 12 0                # foo.cpp:12:0
.seh_proc main
# %bb.0:                                # %entry
	sub	rsp, 32
	.seh_stackalloc 32
	.seh_endprologue
	mov	dword ptr [rsp + 28], 0
	mov	qword ptr [rsp + 16], rdx
	mov	dword ptr [rsp + 12], ecx
.Ltmp0:
	.cv_loc	0 1 15 0                # foo.cpp:15:0
	mov	ecx, dword ptr [rip + "?I@@3HA"]
	add	ecx, dword ptr [rip + "?S@@3UStruct@@A"]
	add	ecx, dword ptr [rip + "?SS@@3UStruct@@A"]
	mov	rdx, qword ptr [rsp]
	add	ecx, dword ptr [rdx]
	mov	eax, ecx
	add	rsp, 32
	ret
.Ltmp1:
.Lfunc_end0:
	.seh_handlerdata
	.text
	.seh_endproc
                                        # -- End function
	.bss
	.globl	"?S@@3UStruct@@A"       # @"?S@@3UStruct@@A"
	.p2align	2
"?S@@3UStruct@@A":
	.zero	4

	.globl	"?SS@@3UStruct@@A"      # @"?SS@@3UStruct@@A"
	.p2align	2
"?SS@@3UStruct@@A":
	.zero	4

	.globl	"?I@@3HA"               # @"?I@@3HA"
	.p2align	2
"?I@@3HA":
	.long	0                       # 0x0

	.section	.drectve,"yn"
	.ascii	" /DEFAULTLIB:libcmt.lib"
	.ascii	" /DEFAULTLIB:oldnames.lib"
	.section	.debug$S,"dr"
	.p2align	2
	.long	4                       # Debug section magic
	.long	241
	.long	.Ltmp3-.Ltmp2           # Subsection size
.Ltmp2:
	.short	.Ltmp5-.Ltmp4           # Record length
.Ltmp4:
	.short	4412                    # Record kind: S_COMPILE3
	.long	1                       # Flags and language
	.short	208                     # CPUType
	.short	8                       # Frontend version
	.short	0
	.short	0
	.short	0
	.short	8000                    # Backend version
	.short	0
	.short	0
	.short	0
	.asciz	"clang version 8.0.0 "  # Null-terminated compiler version string
.Ltmp5:
.Ltmp3:
	.p2align	2
	.long	241                     # Symbol subsection for main
	.long	.Ltmp7-.Ltmp6           # Subsection size
.Ltmp6:
	.short	.Ltmp9-.Ltmp8           # Record length
.Ltmp8:
	.short	4423                    # Record kind: S_GPROC32_ID
	.long	0                       # PtrParent
	.long	0                       # PtrEnd
	.long	0                       # PtrNext
	.long	.Lfunc_end0-main        # Code size
	.long	0                       # Offset after prologue
	.long	0                       # Offset before epilogue
	.long	4099                    # Function type index
	.secrel32	main            # Function section relative address
	.secidx	main                    # Function section index
	.byte	0                       # Flags
	.asciz	"main"                  # Function name
.Ltmp9:
	.short	.Ltmp11-.Ltmp10         # Record length
.Ltmp10:
	.short	4114                    # Record kind: S_FRAMEPROC
	.long	32                      # FrameSize
	.long	0                       # Padding
	.long	0                       # Offset of padding
	.long	0                       # Bytes of callee saved registers
	.long	0                       # Exception handler offset
	.short	0                       # Exception handler section
	.long	81920                   # Flags (defines frame register)
.Ltmp11:
	.short	.Ltmp13-.Ltmp12         # Record length
.Ltmp12:
	.short	4414                    # Record kind: S_LOCAL
	.long	116                     # TypeIndex
	.short	1                       # Flags
	.asciz	"argc"
.Ltmp13:
	.cv_def_range	 .Ltmp0 .Ltmp1, "B\021\f\000\000\000"
	.short	.Ltmp15-.Ltmp14         # Record length
.Ltmp14:
	.short	4414                    # Record kind: S_LOCAL
	.long	4096                    # TypeIndex
	.short	1                       # Flags
	.asciz	"argv"
.Ltmp15:
	.cv_def_range	 .Ltmp0 .Ltmp1, "B\021\020\000\000\000"
	.short	.Ltmp17-.Ltmp16         # Record length
.Ltmp16:
	.short	4414                    # Record kind: S_LOCAL
	.long	4101                    # TypeIndex
	.short	0                       # Flags
	.asciz	"SPtr"
.Ltmp17:
	.cv_def_range	 .Ltmp0 .Ltmp1, "B\021\000\000\000\000"
	.short	.Ltmp19-.Ltmp18         # Record length
.Ltmp18:
	.short	4360                    # Record kind: S_UDT
	.long	4101                    # Type
	.asciz	"main::LocalTypedef"
.Ltmp19:
	.short	2                       # Record length
	.short	4431                    # Record kind: S_PROC_ID_END
.Ltmp7:
	.p2align	2
	.cv_linetable	0, main, .Lfunc_end0
	.long	241                     # Symbol subsection for globals
	.long	.Ltmp21-.Ltmp20         # Subsection size
.Ltmp20:
	.short	.Ltmp23-.Ltmp22         # Record length
.Ltmp22:
	.short	4365                    # Record kind: S_GDATA32
	.long	4103                    # Type
	.secrel32	"?S@@3UStruct@@A" # DataOffset
	.secidx	"?S@@3UStruct@@A"       # Segment
	.asciz	"S"                     # Name
.Ltmp23:
	.short	.Ltmp25-.Ltmp24         # Record length
.Ltmp24:
	.short	4365                    # Record kind: S_GDATA32
	.long	4100                    # Type
	.secrel32	"?SS@@3UStruct@@A" # DataOffset
	.secidx	"?SS@@3UStruct@@A"      # Segment
	.asciz	"SS"                    # Name
.Ltmp25:
	.short	.Ltmp27-.Ltmp26         # Record length
.Ltmp26:
	.short	4365                    # Record kind: S_GDATA32
	.long	116                     # Type
	.secrel32	"?I@@3HA"       # DataOffset
	.secidx	"?I@@3HA"               # Segment
	.asciz	"I"                     # Name
.Ltmp27:
.Ltmp21:
	.p2align	2
	.long	241
	.long	.Ltmp29-.Ltmp28         # Subsection size
.Ltmp28:
	.short	.Ltmp31-.Ltmp30         # Record length
.Ltmp30:
	.short	4360                    # Record kind: S_UDT
	.long	4103                    # Type
	.asciz	"Struct"
.Ltmp31:
	.short	.Ltmp33-.Ltmp32         # Record length
.Ltmp32:
	.short	4360                    # Record kind: S_UDT
	.long	4100                    # Type
	.asciz	"StructTypedef"
.Ltmp33:
	.short	.Ltmp35-.Ltmp34         # Record length
.Ltmp34:
	.short	4360                    # Record kind: S_UDT
	.long	116                     # Type
	.asciz	"IntTypedef"
.Ltmp35:
.Ltmp29:
	.p2align	2
	.cv_filechecksums               # File index to string table offset subsection
	.cv_stringtable                 # String table
	.long	241
	.long	.Ltmp37-.Ltmp36         # Subsection size
.Ltmp36:
	.short	6                       # Record length
	.short	4428                    # Record kind: S_BUILDINFO
	.long	4108                    # LF_BUILDINFO index
.Ltmp37:
	.p2align	2
	.section	.debug$T,"dr"
	.p2align	2
	.long	4                       # Debug section magic
	# Pointer (0x1000) {
	#   TypeLeafKind: LF_POINTER (0x1002)
	#   PointeeType: char* (0x670)
	#   PtrType: Near64 (0xC)
	#   PtrMode: Pointer (0x0)
	#   IsFlat: 0
	#   IsConst: 0
	#   IsVolatile: 0
	#   IsUnaligned: 0
	#   IsRestrict: 0
	#   IsThisPtr&: 0
	#   IsThisPtr&&: 0
	#   SizeOf: 8
	# }
	.byte	0x0a, 0x00, 0x02, 0x10
	.byte	0x70, 0x06, 0x00, 0x00
	.byte	0x0c, 0x00, 0x01, 0x00
	# ArgList (0x1001) {
	#   TypeLeafKind: LF_ARGLIST (0x1201)
	#   NumArgs: 2
	#   Arguments [
	#     ArgType: int (0x74)
	#     ArgType: char** (0x1000)
	#   ]
	# }
	.byte	0x0e, 0x00, 0x01, 0x12
	.byte	0x02, 0x00, 0x00, 0x00
	.byte	0x74, 0x00, 0x00, 0x00
	.byte	0x00, 0x10, 0x00, 0x00
	# Procedure (0x1002) {
	#   TypeLeafKind: LF_PROCEDURE (0x1008)
	#   ReturnType: int (0x74)
	#   CallingConvention: NearC (0x0)
	#   FunctionOptions [ (0x0)
	#   ]
	#   NumParameters: 2
	#   ArgListType: (int, char**) (0x1001)
	# }
	.byte	0x0e, 0x00, 0x08, 0x10
	.byte	0x74, 0x00, 0x00, 0x00
	.byte	0x00, 0x00, 0x02, 0x00
	.byte	0x01, 0x10, 0x00, 0x00
	# FuncId (0x1003) {
	#   TypeLeafKind: LF_FUNC_ID (0x1601)
	#   ParentScope: 0x0
	#   FunctionType: int (int, char**) (0x1002)
	#   Name: main
	# }
	.byte	0x12, 0x00, 0x01, 0x16
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x02, 0x10, 0x00, 0x00
	.byte	0x6d, 0x61, 0x69, 0x6e
	.byte	0x00, 0xf3, 0xf2, 0xf1
	# Struct (0x1004) {
	#   TypeLeafKind: LF_STRUCTURE (0x1505)
	#   MemberCount: 0
	#   Properties [ (0x280)
	#     ForwardReference (0x80)
	#     HasUniqueName (0x200)
	#   ]
	#   FieldList: 0x0
	#   DerivedFrom: 0x0
	#   VShape: 0x0
	#   SizeOf: 0
	#   Name: Struct
	#   LinkageName: .?AUStruct@@
	# }
	.byte	0x2a, 0x00, 0x05, 0x15
	.byte	0x00, 0x00, 0x80, 0x02
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x00, 0x00, 0x53, 0x74
	.byte	0x72, 0x75, 0x63, 0x74
	.byte	0x00, 0x2e, 0x3f, 0x41
	.byte	0x55, 0x53, 0x74, 0x72
	.byte	0x75, 0x63, 0x74, 0x40
	.byte	0x40, 0x00, 0xf2, 0xf1
	# Pointer (0x1005) {
	#   TypeLeafKind: LF_POINTER (0x1002)
	#   PointeeType: Struct (0x1004)
	#   PtrType: Near64 (0xC)
	#   PtrMode: Pointer (0x0)
	#   IsFlat: 0
	#   IsConst: 0
	#   IsVolatile: 0
	#   IsUnaligned: 0
	#   IsRestrict: 0
	#   IsThisPtr&: 0
	#   IsThisPtr&&: 0
	#   SizeOf: 8
	# }
	.byte	0x0a, 0x00, 0x02, 0x10
	.byte	0x04, 0x10, 0x00, 0x00
	.byte	0x0c, 0x00, 0x01, 0x00
	# FieldList (0x1006) {
	#   TypeLeafKind: LF_FIELDLIST (0x1203)
	#   DataMember {
	#     TypeLeafKind: LF_MEMBER (0x150D)
	#     AccessSpecifier: Public (0x3)
	#     Type: int (0x74)
	#     FieldOffset: 0x0
	#     Name: x
	#   }
	# }
	.byte	0x0e, 0x00, 0x03, 0x12
	.byte	0x0d, 0x15, 0x03, 0x00
	.byte	0x74, 0x00, 0x00, 0x00
	.byte	0x00, 0x00, 0x78, 0x00
	# Struct (0x1007) {
	#   TypeLeafKind: LF_STRUCTURE (0x1505)
	#   MemberCount: 1
	#   Properties [ (0x200)
	#     HasUniqueName (0x200)
	#   ]
	#   FieldList: <field list> (0x1006)
	#   DerivedFrom: 0x0
	#   VShape: 0x0
	#   SizeOf: 4
	#   Name: Struct
	#   LinkageName: .?AUStruct@@
	# }
	.byte	0x2a, 0x00, 0x05, 0x15
	.byte	0x01, 0x00, 0x00, 0x02
	.byte	0x06, 0x10, 0x00, 0x00
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x04, 0x00, 0x53, 0x74
	.byte	0x72, 0x75, 0x63, 0x74
	.byte	0x00, 0x2e, 0x3f, 0x41
	.byte	0x55, 0x53, 0x74, 0x72
	.byte	0x75, 0x63, 0x74, 0x40
	.byte	0x40, 0x00, 0xf2, 0xf1
	# StringId (0x1008) {
	#   TypeLeafKind: LF_STRING_ID (0x1605)
	#   Id: 0x0
	#   StringData: D:\src\llvmbuild\cl\Debug\x64\foo.cpp
	# }
	.byte	0x2e, 0x00, 0x05, 0x16
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x44, 0x3a, 0x5c, 0x73
	.byte	0x72, 0x63, 0x5c, 0x6c
	.byte	0x6c, 0x76, 0x6d, 0x62
	.byte	0x75, 0x69, 0x6c, 0x64
	.byte	0x5c, 0x63, 0x6c, 0x5c
	.byte	0x44, 0x65, 0x62, 0x75
	.byte	0x67, 0x5c, 0x78, 0x36
	.byte	0x34, 0x5c, 0x66, 0x6f
	.byte	0x6f, 0x2e, 0x63, 0x70
	.byte	0x70, 0x00, 0xf2, 0xf1
	# UdtSourceLine (0x1009) {
	#   TypeLeafKind: LF_UDT_SRC_LINE (0x1606)
	#   UDT: Struct (0x1007)
	#   SourceFile: D:\src\llvmbuild\cl\Debug\x64\foo.cpp (0x1008)
	#   LineNumber: 1
	# }
	.byte	0x0e, 0x00, 0x06, 0x16
	.byte	0x07, 0x10, 0x00, 0x00
	.byte	0x08, 0x10, 0x00, 0x00
	.byte	0x01, 0x00, 0x00, 0x00
	# StringId (0x100A) {
	#   TypeLeafKind: LF_STRING_ID (0x1605)
	#   Id: 0x0
	#   StringData: D:\\src\\llvmbuild\\cl\\Debug\\x64
	# }
	.byte	0x2a, 0x00, 0x05, 0x16
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x44, 0x3a, 0x5c, 0x5c
	.byte	0x73, 0x72, 0x63, 0x5c
	.byte	0x5c, 0x6c, 0x6c, 0x76
	.byte	0x6d, 0x62, 0x75, 0x69
	.byte	0x6c, 0x64, 0x5c, 0x5c
	.byte	0x63, 0x6c, 0x5c, 0x5c
	.byte	0x44, 0x65, 0x62, 0x75
	.byte	0x67, 0x5c, 0x5c, 0x78
	.byte	0x36, 0x34, 0x00, 0xf1
	# StringId (0x100B) {
	#   TypeLeafKind: LF_STRING_ID (0x1605)
	#   Id: 0x0
	#   StringData: foo.cpp
	# }
	.byte	0x0e, 0x00, 0x05, 0x16
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x66, 0x6f, 0x6f, 0x2e
	.byte	0x63, 0x70, 0x70, 0x00
	# BuildInfo (0x100C) {
	#   TypeLeafKind: LF_BUILDINFO (0x1603)
	#   NumArgs: 5
	#   Arguments [
	#     ArgType: D:\\src\\llvmbuild\\cl\\Debug\\x64 (0x100A)
	#     ArgType: 0x0
	#     ArgType: foo.cpp (0x100B)
	#     ArgType: 0x0
	#     ArgType: 0x0
	#   ]
	# }
	.byte	0x1a, 0x00, 0x03, 0x16
	.byte	0x05, 0x00, 0x0a, 0x10
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x00, 0x00, 0x0b, 0x10
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x00, 0x00, 0xf2, 0xf1

	.addrsig
	.addrsig_sym "?S@@3UStruct@@A"
	.addrsig_sym "?SS@@3UStruct@@A"
	.addrsig_sym "?I@@3HA"
