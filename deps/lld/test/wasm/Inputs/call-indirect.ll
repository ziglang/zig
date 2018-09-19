target triple = "wasm32-unknown-unknown"

@indirect_bar = internal local_unnamed_addr global i64 ()* @bar, align 4
@indirect_foo = internal local_unnamed_addr global i32 ()* @foo, align 4

declare i32 @foo() local_unnamed_addr

define i64 @bar() {
entry:
  ret i64 1
}

define void @call_bar_indirect() local_unnamed_addr #1 {
entry:
  %0 = load i64 ()*, i64 ()** @indirect_bar, align 4
  %1 = load i32 ()*, i32 ()** @indirect_foo, align 4
  %call0 = tail call i64 %0() #2
  %call1 = tail call i32 %1() #2
  ret void
}
