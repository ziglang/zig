target triple = "wasm32-unknown-unknown"

declare i32 @bar() local_unnamed_addr #1

define i32 @foo() local_unnamed_addr #0 {
entry:
  %call = tail call i32 @bar() #2
  ret i32 %call
}
