class DialogOtaConfig {
  static const String serviceUuid = 'FEF5';
  static const String memDevCharaUuid = '8082CAA8-41A6-4021-91C6-56F9B954CC34';
  static const String gpioMapCharaUuid = '724249F0-5EC3-4B5F-8804-42345AF08651';
  static const String patchLenCharaUuid =
      '9D84B9A3-000C-49D8-9183-855B673FDA31';
  static const String patchDataCharaUuid =
      '457871E8-D516-4CA1-9116-57D0B17B9CB2';
  static const String servStatusCharaUuid =
      '5F78DF94-798C-46F5-990A-B3EB6A065C88';

  static const int errorCommunication = 0xffff; // ble communication error
  static const int errorSuotaNotFound = 0xfffe; // mSuota service was not found
  static const int errorReadFile = 0xfffd; // read fileUtils error
  static const int errorOnStart = 0xfffc; // Work can't upgrade
  static const int errorLowPower = 0xfffb; // Low power can't upgrade
  static const int errorSendImg = 0xfffa; // Write Characteristic error

  static const Map<int, String> errorMap = {
    // Application error codes
    errorCommunication: 'Ble communication error.',
    errorSuotaNotFound: 'The remote device does not support SUOTA.',
    errorReadFile: 'Read fileUtils error.',
    errorOnStart: 'Work can\'t upgrade.',
    errorLowPower: 'Low power can\'t upgrade.',
    errorSendImg: 'Send img error.',

    // Value zero must not be used !! Notifications are sent when status changes.
    0x03: 'Forced exit of SPOTA service. See Table 1',
    0x04: 'Patch Data CRC mismatch.',
    0x05: 'Received patch Length not equal to PATCH_LEN characteristic value.',
    0x06: 'External Memory Error. Writing to external device failed.',
    0x07: 'Internal Memory Error. Not enough internal memory space for patch.',
    0x08: 'Invalid memory device.',
    0x09: 'Application error.',

    // SUOTAR application specific error codes
    0x11: 'Invalid image bank',
    0x12: 'Invalid image header',
    0x13: 'Invalid image size',
    0x14: 'Invalid product header',
    0x15: 'Same Image Error',
    0x16: 'Failed to read from external memory device',
  };
}

enum DialogOtaType { type531, type580, type585 }
