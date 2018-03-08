
declare void @f() local_unnamed_addr

define void @__imp_f() local_unnamed_addr {
entry:
  ret void
}

define void @mainCRTStartup() local_unnamed_addr {
entry:
  tail call void @f()
  ret void
}

