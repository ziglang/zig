#if (NTDDI_VERSION >= NTDDI_WINXP)
struct FLOATSAFE {
  KFLOATING_SAVE FloatSave;
  NTSTATUS ntStatus;
  FLOATSAFE::FLOATSAFE(void) {
    ntStatus = KeSaveFloatingPointState(&FloatSave);
  }
  FLOATSAFE::~FLOATSAFE(void) {
    if (NT_SUCCESS(ntStatus)) {
      KeRestoreFloatingPointState(&FloatSave);
    }
  }
};
#endif
