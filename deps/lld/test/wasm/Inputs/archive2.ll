target triple = "wasm32-unknown-unknown"

declare i32 @foo() local_unnamed_addr #1

define i32 @bar() local_unnamed_addr #0 {
entry:
  %call = tail call i32 @foo() #2
  ret i32 %call
}

define void @archive2_symbol() local_unnamed_addr #0 {
entry:
  ret void
}
