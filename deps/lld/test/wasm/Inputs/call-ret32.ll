target triple = "wasm32-unknown-unknown"

@ret32_address = global i32 (float)* @ret32, align 4

define hidden i32* @call_ret32() {
entry:
  %call1 = call i32 @ret32(float 0.000000e+00)
  ret i32* bitcast (i32 (float)** @ret32_address to i32*)
}

declare i32 @ret32(float)
