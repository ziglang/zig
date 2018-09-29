target triple = "wasm32-unknown-unknown"

; Wasm module generated from the following C code:
;   void puts(const char*);
;   void hello() { puts("hello\n"); }

@hello_str = unnamed_addr constant [7 x i8] c"hello\0A\00", align 1

; Function Attrs: nounwind
define hidden void @hello() local_unnamed_addr #0 {
entry:
  tail call void @puts(i8* getelementptr inbounds ([7 x i8], [7 x i8]* @hello_str, i32 0, i32 0))
  ret void
}

; Function Attrs: nounwind
declare void @puts(i8* nocapture readonly) local_unnamed_addr #1
