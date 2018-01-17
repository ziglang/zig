declare dllimport void @f() local_unnamed_addr

define void @g() local_unnamed_addr {
entry:
  tail call void @f()
  ret void
}
