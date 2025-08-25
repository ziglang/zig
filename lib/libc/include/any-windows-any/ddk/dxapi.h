ULONG
DxApiGetVersion(void);

ULONG
DxApi(
  IN ULONG dwFunctionNum,
  IN PVOID lpvInBuffer,
  IN ULONG cbInBuffer,
  IN PVOID lpvOutBuffer,
  IN ULONG cbOutBuffer);
