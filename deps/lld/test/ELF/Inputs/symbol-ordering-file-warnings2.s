.text
.global missing
missing:
  callq undefined
  # This is a "bad" (undefined) instance of the symbol
  callq multi
