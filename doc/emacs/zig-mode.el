(setq zig
      '(("\\b\\(@sizeOf\\|@alignOf\\|@maxValue\\|@minValue\\|@memberCount\\|@typeOf\\|@addWithOverflow\\|@subWithOverflow\\|@mulWithOverflow\\|@shlWithOverflow\\|@cInclude\\|@cDefine\\|@cUndef\\|@compileVar\\|@generatedCode\\|@ctz\\|@clz\\|@import\\|@cImport\\|@errorName\\|@typeName\\|@isInteger\\|@isFloat\\|@canImplicitCast\\|@embedFile\\|@cmpxchg\\|@fence\\|@divExact\\|@truncate\\|@compileError\\|@compileLog\\|@intType\\|@unreachable\\|@setFnTest\\|@setFnVisible\\|@setDebugSafety\\|@alloca\\|@setGlobalAlign\\|@setGlobalSection\\)" . font-lock-builtin-face)

("\\b\\(fn\\|use\\|while\\|for\\|break\\|continue\\|goto\\|if\\|else\\|switch\\|try\\|return\\|defer\\|asm\\|unreachable\\|const\\|var\\|extern\\|packed\\|export\\|pub\\|noalias\\|inline\\|comptime\\|nakedcc\\|coldcc\\|volatile\\|struct\\|enum\\|union\\)\\b" . font-lock-keyword-face)

        ("\\b\\(null\\|undefined\\|this\\)\\b" . font-lock-constant-face)

("\\b\\(bool\\|f32\\|f64\\|void\\|Unreachable\\|type\\|error\\|i8\\|\\|u8\\|\\|i16\\|\\|u16\\|\\|i32\\|\\|u32\\|\\|64\\|u64\\|isize\\|usize\\|c_short\\|c_ushort\\|c_int\\|c_uint\\|c_long\\|c_ulong\\|c_longlong\\|c_ulonglong\\|c_long_double\\)\\b" . font-lock-type-face)

        ))
    


(define-derived-mode zig-mode c-mode "zig mode"
  "Major mode for editing Zig language"
  (setq font-lock-defaults '(zig)))

(provide 'zig-mode)
