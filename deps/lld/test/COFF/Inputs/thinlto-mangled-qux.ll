target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc19.0.24215"

%class.baz = type { %class.bar }
%class.bar = type { i32 (...)** }

$"\01?x@bar@@UEBA_NXZ" = comdat any

$"\01??_7baz@@6B@" = comdat any

$"\01??_Gbaz@@UEAAPEAXI@Z" = comdat any

@"\01??_7baz@@6B@" = linkonce_odr unnamed_addr constant { [2 x i8*] } { [2 x i8*] [i8* bitcast (i8* (%class.baz*, i32)* @"\01??_Gbaz@@UEAAPEAXI@Z" to i8*), i8* bitcast (i1 (%class.bar*)* @"\01?x@bar@@UEBA_NXZ" to i8*)] }, comdat, !type !0, !type !1

define void @"\01?qux@@YAXXZ"() local_unnamed_addr {
  ret void
}

define linkonce_odr i8* @"\01??_Gbaz@@UEAAPEAXI@Z"(%class.baz* %this, i32 %should_call_delete) unnamed_addr comdat {
  ret i8* null
}

define linkonce_odr zeroext i1 @"\01?x@bar@@UEBA_NXZ"(%class.bar* %this) unnamed_addr comdat {
  ret i1 false
}

!0 = !{i64 0, !"?AVbar@@"}
!1 = !{i64 0, !"?AVbaz@@"}
