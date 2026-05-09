const CREDENTIALS_SHEET_NAME = 'credentials';
const CREDENTIALS_HEADERS = ['full name', 'email', 'password hash', 'created at', 'company name', 'address', 'phone no', 'master key', 'access', 'can edit finance entries', 'updated at'];
const CREDENTIAL_ACCESS_OPTIONS = ['stocker', 'finance', 'both'];
const CREDENTIAL_BOOLEAN_OPTIONS = ['true', 'false'];
const APP_UPDATES_SHEET_NAME = 'app updates';
const APP_UPDATES_HEADERS = ['key', 'value', 'updated at'];
const APP_UPDATES_DEFAULT_ROWS = [
  ['latest version', '', ''],
  ['latest build number', '', ''],
  ['apk url', '', ''],
  ['release notes', '', ''],
  ['force update', 'false', ''],
];

function doGet(e) {
  const action = String(e.parameter.action || '').toLowerCase();

  if (action === 'getaccounts') {
    return jsonResponse_({ success: true, data: getAccounts_() });
  }

  if (action === 'getaccountprofile') {
    return jsonResponse_(getAccountProfile_(e.parameter));
  }

  if (action === 'getappupdate') {
    return jsonResponse_(getAppUpdate_());
  }

  return jsonResponse_({ success: false, error: 'Unsupported GET action.' });
}

function doPost(e) {
  try {
    const payload = JSON.parse((e.postData && e.postData.contents) || '{}');
    const action = String(payload.action || '').toLowerCase();

    if (action === 'createaccount') {
      createAccountRow_(payload);
      return jsonResponse_({ success: true });
    }

    if (action === 'authenticateaccount') {
      return jsonResponse_(authenticateAccount_(payload));
    }

    if (action === 'getaccounts') {
      return jsonResponse_({ success: true, data: getAccounts_() });
    }

    if (action === 'getaccountprofile') {
      return jsonResponse_(getAccountProfile_(payload));
    }

    if (action === 'updateaccountaccess') {
      return jsonResponse_(updateAccountAccess_(payload));
    }

    if (action === 'updateaccountprofile') {
      return jsonResponse_(updateAccountProfile_(payload));
    }

    if (action === 'resetaccountpassword') {
      resetAccountPassword_(payload);
      return jsonResponse_({ success: true });
    }

    if (action === 'getappupdate') {
      return jsonResponse_(getAppUpdate_());
    }

    if (action === 'updateappupdate') {
      return jsonResponse_(updateAppUpdate_(payload));
    }

    return jsonResponse_({ success: false, error: 'Unsupported POST action.' });
  } catch (error) {
    return jsonResponse_({ success: false, error: String(error.message || error) });
  }
}

function getAccounts_() {
  const sheet = getOrCreateSheet_(CREDENTIALS_SHEET_NAME, CREDENTIALS_HEADERS);
  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) {
    return [];
  }

  const headers = values[0].map(normalizeHeader_);
  const accounts = [];

  for (let index = 1; index < values.length; index += 1) {
    const row = values[index];
    if (!row.some(cell => String(cell || '').trim() !== '')) {
      continue;
    }

    accounts.push(buildAccountAdminResponse_(headers, row, index + 1));
  }

  return accounts.sort((left, right) => {
    const leftName = String(left.fullName || left.companyName || left.email || '');
    const rightName = String(right.fullName || right.companyName || right.email || '');
    return leftName.localeCompare(rightName);
  });
}

function authenticateAccount_(payload) {
  const sheet = getOrCreateSheet_(CREDENTIALS_SHEET_NAME, CREDENTIALS_HEADERS);
  const email = String(payload.email || '').trim().toLowerCase();
  const password = String(payload.password || '');

  if (!email) {
    throw new Error('Email is required.');
  }

  if (!password) {
    throw new Error('Password is required.');
  }

  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) {
    throw new Error('No accounts found. Please create an account first.');
  }

  const headers = values[0].map(normalizeHeader_);
  const emailIndex = headers.indexOf('email');
  const passwordHashIndex = headers.indexOf('password hash');

  if (emailIndex === -1 || passwordHashIndex === -1) {
    throw new Error('Credentials sheet is missing required columns.');
  }

  const passwordHash = hashPassword_(password);

  for (let index = 1; index < values.length; index += 1) {
    const row = values[index];
    if (normalizeHeader_(row[emailIndex]) !== normalizeHeader_(email)) {
      continue;
    }

    if (String(row[passwordHashIndex] || '') !== passwordHash) {
      throw new Error('Invalid email or password.');
    }

    return buildCredentialResponse_(headers, row);
  }

  throw new Error('Invalid email or password.');
}

function createAccountRow_(payload) {
  const sheet = getOrCreateSheet_(CREDENTIALS_SHEET_NAME, CREDENTIALS_HEADERS);
  const companyName = String(payload.companyName || '').trim();
  const fullName = String(payload.fullName || '').trim();
  const address = String(payload.address || '').trim();
  const email = String(payload.email || '').trim().toLowerCase();
  const phoneNo = String(payload.phoneNo || '').trim();
  const masterKey = String(payload.masterKey || '');
  const password = String(payload.password || '');
  const access = normalizeAccessValue_(payload.access || 'both');
  const canEditFinanceEntries = normalizeBooleanString_(
    payload.canEditFinanceEntries,
    'true',
  );

  if (!companyName) {
    throw new Error('Company name is required.');
  }

  if (!fullName) {
    throw new Error('Full name is required.');
  }

  if (!address) {
    throw new Error('Address is required.');
  }

  if (!email) {
    throw new Error('Email is required.');
  }

  if (!phoneNo) {
    throw new Error('Phone number is required.');
  }

  if (!masterKey) {
    throw new Error('Master key is required.');
  }

  if (!password) {
    throw new Error('Password is required.');
  }

  if (findCredentialRowByEmail_(sheet, email)) {
    throw new Error('An account with this email already exists.');
  }

  sheet.appendRow([
    fullName,
    email,
    hashPassword_(password),
    new Date().toISOString(),
    companyName,
    address,
    phoneNo,
    masterKey,
    access,
    canEditFinanceEntries,
    new Date().toISOString(),
  ]);
}

function getAccountProfile_(payload) {
  const sheet = getOrCreateSheet_(CREDENTIALS_SHEET_NAME, CREDENTIALS_HEADERS);
  const email = String(payload.email || '').trim().toLowerCase();
  if (!email) {
    throw new Error('Email is required.');
  }

  const record = findCredentialRecordByEmail_(sheet, email);
  if (!record) {
    throw new Error('Account not found.');
  }

  return buildCredentialResponse_(record.headers, record.rowValues);
}

function updateAccountProfile_(payload) {
  const sheet = getOrCreateSheet_(CREDENTIALS_SHEET_NAME, CREDENTIALS_HEADERS);
  const currentEmail = String(payload.currentEmail || payload.email || '').trim().toLowerCase();
  const companyName = String(payload.companyName || '').trim();
  const fullName = String(payload.fullName || '').trim();
  const address = String(payload.address || '').trim();
  const email = String(payload.email || '').trim().toLowerCase();
  const phoneNo = String(payload.phoneNo || '').trim();
  const masterKey = String(payload.masterKey || '').trim();

  if (!currentEmail) {
    throw new Error('Current email is required.');
  }

  if (!companyName || !fullName || !address || !email || !phoneNo) {
    throw new Error('Company name, full name, address, email, and phone number are required.');
  }

  const currentRecord = findCredentialRecordByEmail_(sheet, currentEmail);
  if (!currentRecord) {
    throw new Error('Account not found.');
  }

  if (email !== currentEmail) {
    const duplicateRecord = findCredentialRecordByEmail_(sheet, email);
    if (duplicateRecord && duplicateRecord.rowNumber !== currentRecord.rowNumber) {
      throw new Error('An account with this email already exists.');
    }
  }

  setCredentialValue_(sheet, currentRecord.headers, currentRecord.rowNumber, 'company name', companyName);
  setCredentialValue_(sheet, currentRecord.headers, currentRecord.rowNumber, 'full name', fullName);
  setCredentialValue_(sheet, currentRecord.headers, currentRecord.rowNumber, 'address', address);
  setCredentialValue_(sheet, currentRecord.headers, currentRecord.rowNumber, 'email', email);
  setCredentialValue_(sheet, currentRecord.headers, currentRecord.rowNumber, 'phone no', phoneNo);
  if (masterKey) {
    setCredentialValue_(sheet, currentRecord.headers, currentRecord.rowNumber, 'master key', masterKey);
  }
  setCredentialValue_(sheet, currentRecord.headers, currentRecord.rowNumber, 'updated at', new Date().toISOString());

  const updatedValues = sheet.getRange(currentRecord.rowNumber, 1, 1, CREDENTIALS_HEADERS.length).getValues()[0];
  return buildCredentialResponse_(currentRecord.headers, updatedValues);
}

function updateAccountAccess_(payload) {
  const sheet = getOrCreateSheet_(CREDENTIALS_SHEET_NAME, CREDENTIALS_HEADERS);
  const email = String(payload.email || '').trim().toLowerCase();
  const access = normalizeAccessValue_(payload.access || 'both');
  const canEditFinanceEntries = normalizeBooleanString_(
    payload.canEditFinanceEntries,
    'true',
  );

  if (!email) {
    throw new Error('Email is required.');
  }

  const record = findCredentialRecordByEmail_(sheet, email);
  if (!record) {
    throw new Error('Account not found.');
  }

  setCredentialValue_(sheet, record.headers, record.rowNumber, 'access', access);
  setCredentialValue_(
    sheet,
    record.headers,
    record.rowNumber,
    'can edit finance entries',
    canEditFinanceEntries,
  );
  setCredentialValue_(sheet, record.headers, record.rowNumber, 'updated at', new Date().toISOString());

  const updatedValues = sheet.getRange(record.rowNumber, 1, 1, CREDENTIALS_HEADERS.length).getValues()[0];
  return buildAccountAdminResponse_(record.headers, updatedValues, record.rowNumber);
}

function resetAccountPassword_(payload) {
  const sheet = getOrCreateSheet_(CREDENTIALS_SHEET_NAME, CREDENTIALS_HEADERS);
  const email = String(payload.email || '').trim().toLowerCase();
  const masterKey = String(payload.masterKey || '');
  const newPassword = String(payload.newPassword || '');

  if (!email) {
    throw new Error('Email is required.');
  }

  if (!masterKey) {
    throw new Error('Master key is required.');
  }

  if (!newPassword) {
    throw new Error('New password is required.');
  }

  const record = findCredentialRecordByEmail_(sheet, email);
  if (!record) {
    throw new Error('Account not found.');
  }

  const masterKeyIndex = record.headers.indexOf('master key');
  const passwordHashIndex = record.headers.indexOf('password hash');
  if (masterKeyIndex === -1 || passwordHashIndex === -1) {
    throw new Error('Credentials sheet is missing required columns.');
  }

  const storedMasterKey = String(record.rowValues[masterKeyIndex] || '');
  if (!storedMasterKey) {
    throw new Error('Master key is not set for this account.');
  }

  if (storedMasterKey !== masterKey && storedMasterKey !== hashPassword_(masterKey)) {
    throw new Error('Master key does not match.');
  }

  sheet.getRange(record.rowNumber, passwordHashIndex + 1).setValue(hashPassword_(newPassword));
  setCredentialValue_(sheet, record.headers, record.rowNumber, 'updated at', new Date().toISOString());
}

function getAppUpdate_() {
  const sheet = getOrCreateKeyValueSheet_(
    APP_UPDATES_SHEET_NAME,
    APP_UPDATES_HEADERS,
    APP_UPDATES_DEFAULT_ROWS,
  );
  const settings = readKeyValueSheet_(sheet);

  return {
    success: true,
    version: String(settings.values['latest version'] || '').trim(),
    buildNumber: String(settings.values['latest build number'] || '').trim(),
    apkUrl: String(settings.values['apk url'] || '').trim(),
    releaseNotes: String(settings.values['release notes'] || '').trim(),
    forceUpdate: parseBoolean_(settings.values['force update']),
    updatedAt: settings.updatedAt,
  };
}

function updateAppUpdate_(payload) {
  const sheet = getOrCreateKeyValueSheet_(
    APP_UPDATES_SHEET_NAME,
    APP_UPDATES_HEADERS,
    APP_UPDATES_DEFAULT_ROWS,
  );
  const updatedAt = new Date().toISOString();

  upsertKeyValueSheetRow_(sheet, 'latest version', String(payload.version || '').trim(), updatedAt);
  upsertKeyValueSheetRow_(
    sheet,
    'latest build number',
    String(payload.buildNumber || '').trim(),
    updatedAt,
  );
  upsertKeyValueSheetRow_(sheet, 'apk url', String(payload.apkUrl || '').trim(), updatedAt);
  upsertKeyValueSheetRow_(
    sheet,
    'release notes',
    String(payload.releaseNotes || '').trim(),
    updatedAt,
  );
  upsertKeyValueSheetRow_(
    sheet,
    'force update',
    normalizeBooleanString_(payload.forceUpdate, 'false'),
    updatedAt,
  );

  return getAppUpdate_();
}

function findCredentialRowByEmail_(sheet, email) {
  const normalizedEmail = normalizeHeader_(email);
  if (!normalizedEmail) {
    return null;
  }

  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) {
    return null;
  }

  const headers = values[0].map(normalizeHeader_);
  const emailIndex = headers.indexOf('email');
  if (emailIndex === -1) {
    return null;
  }

  for (let index = 1; index < values.length; index += 1) {
    if (normalizeHeader_(values[index][emailIndex]) === normalizedEmail) {
      return index + 1;
    }
  }

  return null;
}

function findCredentialRecordByEmail_(sheet, email) {
  const normalizedEmail = normalizeHeader_(email);
  if (!normalizedEmail) {
    return null;
  }

  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) {
    return null;
  }

  const headers = values[0].map(normalizeHeader_);
  const emailIndex = headers.indexOf('email');
  if (emailIndex === -1) {
    return null;
  }

  for (let index = 1; index < values.length; index += 1) {
    if (normalizeHeader_(values[index][emailIndex]) === normalizedEmail) {
      return {
        rowNumber: index + 1,
        rowValues: values[index],
        headers: headers,
      };
    }
  }

  return null;
}

function buildCredentialResponse_(headers, row) {
  const fullNameIndex = headers.indexOf('full name');
  const companyNameIndex = headers.indexOf('company name');
  const addressIndex = headers.indexOf('address');
  const emailIndex = headers.indexOf('email');
  const phoneNoIndex = headers.indexOf('phone no');
  const masterKeyIndex = headers.indexOf('master key');
  const accessIndex = headers.indexOf('access');
  const canEditFinanceEntriesIndex = headers.indexOf('can edit finance entries');

  return {
    success: true,
    companyName: companyNameIndex === -1 ? '' : String(row[companyNameIndex] || ''),
    fullName: fullNameIndex === -1 ? '' : String(row[fullNameIndex] || ''),
    address: addressIndex === -1 ? '' : String(row[addressIndex] || ''),
    email: emailIndex === -1 ? '' : String(row[emailIndex] || ''),
    phoneNo: phoneNoIndex === -1 ? '' : String(row[phoneNoIndex] || ''),
    masterKey: sanitizeMasterKeyForResponse_(masterKeyIndex === -1 ? '' : String(row[masterKeyIndex] || '')),
    access: normalizeAccessValue_(accessIndex === -1 ? 'both' : String(row[accessIndex] || 'both')),
    canEditFinanceEntries: canEditFinanceEntriesIndex === -1
      ? true
      : parseBoolean_(row[canEditFinanceEntriesIndex]),
  };
}

function buildAccountAdminResponse_(headers, row, rowNumber) {
  const fullNameIndex = headers.indexOf('full name');
  const companyNameIndex = headers.indexOf('company name');
  const addressIndex = headers.indexOf('address');
  const emailIndex = headers.indexOf('email');
  const phoneNoIndex = headers.indexOf('phone no');
  const accessIndex = headers.indexOf('access');
  const canEditFinanceEntriesIndex = headers.indexOf('can edit finance entries');
  const createdAtIndex = headers.indexOf('created at');
  const updatedAtIndex = headers.indexOf('updated at');

  return {
    rowNumber: rowNumber,
    companyName: companyNameIndex === -1 ? '' : String(row[companyNameIndex] || ''),
    fullName: fullNameIndex === -1 ? '' : String(row[fullNameIndex] || ''),
    address: addressIndex === -1 ? '' : String(row[addressIndex] || ''),
    email: emailIndex === -1 ? '' : String(row[emailIndex] || ''),
    phoneNo: phoneNoIndex === -1 ? '' : String(row[phoneNoIndex] || ''),
    access: normalizeAccessValue_(accessIndex === -1 ? 'both' : String(row[accessIndex] || 'both')),
    canEditFinanceEntries: canEditFinanceEntriesIndex === -1
      ? true
      : parseBoolean_(row[canEditFinanceEntriesIndex]),
    createdAt: createdAtIndex === -1 ? '' : String(row[createdAtIndex] || ''),
    updatedAt: updatedAtIndex === -1 ? '' : String(row[updatedAtIndex] || ''),
  };
}

function sanitizeMasterKeyForResponse_(value) {
  const text = String(value || '').trim();
  if (/^[a-f0-9]{64}$/i.test(text)) {
    return '';
  }

  return text;
}

function setCredentialValue_(sheet, headers, rowNumber, headerName, value) {
  const index = headers.indexOf(headerName);
  if (index === -1) {
    return;
  }

  sheet.getRange(rowNumber, index + 1).setValue(value);
}

function getOrCreateKeyValueSheet_(sheetName, headers, defaultRows) {
  const sheet = getOrCreateSheet_(sheetName, headers);
  const values = sheet.getDataRange().getValues();
  const existingKeys = values.slice(1).map(row => normalizeHeader_(row[0]));
  const rowsToAppend = [];

  defaultRows.forEach(row => {
    if (!existingKeys.includes(normalizeHeader_(row[0]))) {
      rowsToAppend.push(row);
    }
  });

  if (rowsToAppend.length > 0) {
    sheet.getRange(sheet.getLastRow() + 1, 1, rowsToAppend.length, headers.length)
      .setValues(rowsToAppend);
  }

  return sheet;
}

function upsertKeyValueSheetRow_(sheet, key, value, updatedAt) {
  const values = sheet.getDataRange().getValues();
  if (values.length === 0) {
    return;
  }

  const headers = values[0].map(normalizeHeader_);
  const keyIndex = headers.indexOf('key');
  const valueIndex = headers.indexOf('value');
  const updatedAtIndex = headers.indexOf('updated at');
  if (keyIndex === -1 || valueIndex === -1 || updatedAtIndex === -1) {
    throw new Error('App updates sheet is missing required columns.');
  }

  const normalizedKey = normalizeHeader_(key);
  for (let index = 1; index < values.length; index += 1) {
    if (normalizeHeader_(values[index][keyIndex]) !== normalizedKey) {
      continue;
    }

    sheet.getRange(index + 1, valueIndex + 1).setValue(value);
    sheet.getRange(index + 1, updatedAtIndex + 1).setValue(updatedAt);
    return;
  }

  sheet.appendRow([key, value, updatedAt]);
}

function readKeyValueSheet_(sheet) {
  const values = sheet.getDataRange().getValues();
  const entries = {};
  let updatedAt = '';

  for (let index = 1; index < values.length; index += 1) {
    const row = values[index];
    const key = normalizeHeader_(row[0]);
    if (!key) {
      continue;
    }

    entries[key] = row[1];

    const rowUpdatedAt = String(row[2] || '').trim();
    if (rowUpdatedAt && (!updatedAt || rowUpdatedAt > updatedAt)) {
      updatedAt = rowUpdatedAt;
    }
  }

  return {
    values: entries,
    updatedAt: updatedAt,
  };
}

function parseBoolean_(value) {
  const normalized = normalizeHeader_(value);
  return normalized === 'true' || normalized === '1' || normalized === 'yes';
}

function normalizeBooleanString_(value, fallbackValue) {
  const normalized = normalizeHeader_(value);
  if (normalized === 'true' || normalized === '1' || normalized === 'yes') {
    return 'true';
  }

  if (normalized === 'false' || normalized === '0' || normalized === 'no') {
    return 'false';
  }

  return normalizeHeader_(fallbackValue) === 'false' ? 'false' : 'true';
}

function hashPassword_(password) {
  const digest = Utilities.computeDigest(
    Utilities.DigestAlgorithm.SHA_256,
    String(password || ''),
    Utilities.Charset.UTF_8,
  );

  return digest.map(byte => {
    const value = (byte + 256) % 256;
    return ('0' + value.toString(16)).slice(-2);
  }).join('');
}

function getOrCreateSheet_(sheetName, headers) {
  const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = spreadsheet.getSheetByName(sheetName);

  if (!sheet) {
    sheet = spreadsheet.insertSheet(sheetName);
  }

  if (sheet.getLastRow() === 0) {
    sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
  } else {
    syncSheetHeaders_(sheet, headers);
  }

  if (normalizeHeader_(sheetName) === normalizeHeader_(CREDENTIALS_SHEET_NAME)) {
    ensureCredentialValidations_(sheet);
  }

  return sheet;
}

function syncSheetHeaders_(sheet, headers) {
  const currentColumnCount = Math.max(sheet.getLastColumn(), headers.length);
  const currentHeaders = sheet.getRange(1, 1, 1, currentColumnCount).getValues()[0];
  const normalizedCurrent = currentHeaders.map(normalizeHeader_);

  if (headers === CREDENTIALS_HEADERS) {
    ensureCredentialSheetColumns_(sheet, currentHeaders, normalizedCurrent);
  }

  const finalHeaders = sheet.getRange(1, 1, 1, headers.length).getValues()[0];
  const normalizedFinal = finalHeaders.map(normalizeHeader_);
  let changed = false;

  headers.forEach((header, index) => {
    if (normalizedFinal[index] !== normalizeHeader_(header)) {
      finalHeaders[index] = header;
      changed = true;
    }
  });

  if (changed) {
    sheet.getRange(1, 1, 1, headers.length).setValues([finalHeaders]);
  }
}

function ensureCredentialSheetColumns_(sheet, currentHeaders, normalizedCurrent) {
  const canEditIndex = normalizedCurrent.indexOf('can edit finance entries');
  const updatedAtIndex = normalizedCurrent.indexOf('updated at');
  const expectedCanEditIndex = CREDENTIALS_HEADERS.indexOf('can edit finance entries');

  if (canEditIndex === -1) {
    if (updatedAtIndex !== -1) {
      sheet.insertColumnBefore(updatedAtIndex + 1);
      sheet.getRange(1, expectedCanEditIndex + 1).setValue('can edit finance entries');

      const lastDataRow = sheet.getLastRow();
      if (lastDataRow > 1) {
        sheet.getRange(2, expectedCanEditIndex + 1, lastDataRow - 1, 1)
          .setValue('true');
      }
    } else {
      const lastColumn = sheet.getLastColumn();
      if (lastColumn < CREDENTIALS_HEADERS.length) {
        sheet.insertColumnsAfter(lastColumn, CREDENTIALS_HEADERS.length - lastColumn);
      }

      sheet.getRange(1, expectedCanEditIndex + 1).setValue('can edit finance entries');
      const lastDataRow = sheet.getLastRow();
      if (lastDataRow > 1) {
        sheet.getRange(2, expectedCanEditIndex + 1, lastDataRow - 1, 1)
          .setValue('true');
      }
    }
  }

  const refreshedHeaders = sheet.getRange(1, 1, 1, CREDENTIALS_HEADERS.length).getValues()[0];
  const refreshedNormalized = refreshedHeaders.map(normalizeHeader_);
  const refreshedUpdatedAtIndex = refreshedNormalized.indexOf('updated at');
  if (refreshedUpdatedAtIndex !== CREDENTIALS_HEADERS.indexOf('updated at')) {
    sheet.getRange(1, CREDENTIALS_HEADERS.indexOf('updated at') + 1)
      .setValue('updated at');
  }
}

function ensureCredentialValidations_(sheet) {
  const values = sheet.getDataRange().getValues();
  if (values.length === 0) {
    return;
  }

  const headers = values[0].map(normalizeHeader_);
  const accessIndex = headers.indexOf('access');
  const canEditFinanceEntriesIndex = headers.indexOf('can edit finance entries');

  const accessRule = SpreadsheetApp.newDataValidation()
    .requireValueInList(CREDENTIAL_ACCESS_OPTIONS, true)
    .setAllowInvalid(false)
    .build();

  const booleanRule = SpreadsheetApp.newDataValidation()
    .requireValueInList(CREDENTIAL_BOOLEAN_OPTIONS, true)
    .setAllowInvalid(false)
    .build();

  const maxRows = Math.max(sheet.getMaxRows() - 1, 1);
  if (accessIndex !== -1) {
    sheet.getRange(2, accessIndex + 1, maxRows, 1).setDataValidation(accessRule);
  }
  if (canEditFinanceEntriesIndex !== -1) {
    sheet.getRange(2, canEditFinanceEntriesIndex + 1, maxRows, 1)
      .setDataValidation(booleanRule);
  }

  for (let index = 1; index < values.length; index += 1) {
    if (accessIndex !== -1) {
      const rawValue = normalizeCellText_(values[index][accessIndex]);
      const normalizedValue = normalizeAccessValue_(rawValue || 'both');
      if (rawValue !== normalizedValue) {
        sheet.getRange(index + 1, accessIndex + 1).setValue(normalizedValue);
      }
    }

    if (canEditFinanceEntriesIndex !== -1) {
      const rawBooleanValue = normalizeCellText_(
        values[index][canEditFinanceEntriesIndex],
      );
      const normalizedBooleanValue = normalizeBooleanString_(
        rawBooleanValue,
        'true',
      );
      if (rawBooleanValue !== normalizedBooleanValue) {
        sheet.getRange(index + 1, canEditFinanceEntriesIndex + 1)
          .setValue(normalizedBooleanValue);
      }
    }
  }
}

function normalizeAccessValue_(value) {
  const normalized = normalizeHeader_(value);
  if (normalized === 'stocker' || normalized === 'finance' || normalized === 'both') {
    return normalized;
  }

  if (normalized === 'stock' || normalized === 'stock manager') {
    return 'stocker';
  }

  if (normalized === 'expense tracker') {
    return 'finance';
  }

  return 'both';
}

function normalizeCellText_(value) {
  return String(value == null ? '' : value)
    .trim();
}

function normalizeHeader_(value) {
  return String(value == null ? '' : value)
    .trim()
    .toLowerCase();
}

function jsonResponse_(payload) {
  return ContentService
    .createTextOutput(JSON.stringify(payload))
    .setMimeType(ContentService.MimeType.JSON);
}