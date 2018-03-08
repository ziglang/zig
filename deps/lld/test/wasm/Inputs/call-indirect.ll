@indirect_bar = internal local_unnamed_addr global i32 ()* @bar, align 4
@indirect_foo = internal local_unnamed_addr global i32 ()* @foo, align 4

declare i32 @foo() local_unnamed_addr

define i32 @bar() {
entry:
  ret i32 1
}

define void @call_bar_indirect() local_unnamed_addr #1 {
entry:
  %0 = load i32 ()*, i32 ()** @indirect_bar, align 4
  %1 = load i32 ()*, i32 ()** @indirect_foo, align 4
  %call = tail call i32 %0() #2
  ret void
}
