const STOCK_SHEET_NAME = 'stock';
const SELL_SHEET_NAME = 'sell item';
const TAX_SETTINGS_SHEET_NAME = 'tax settings';
const FINANCE_ENTRIES_SHEET_NAME = 'finance entries';
const EMPLOYEES_SHEET_NAME = 'employees';
const INVOICE_SETTINGS_SHEET_NAME = 'invoice settings';
const INVOICE_LOGO_KEY_PREFIX = 'invoice logo png base64';
const INVOICE_LOGO_CHUNK_SIZE = 40000;

const STOCK_HEADERS = ['item name', 'remaining quantity', 'initial quantity', 'cost price', 'SKU'];
const SELL_HEADERS = [
  'company name',
  'customer name',
  'phone no',
  'email',
  'shipping address',
  'shipping cost',
  'quantity',
  'SKU',
  'item name',
  'Unit price',
  'tax percentage',
  'tax amount',
  'total cost',
  'items',
  'order id',
  'created at',
];
const TAX_SETTINGS_HEADERS = ['key', 'value', 'updated at'];
const EMPLOYEES_HEADERS = ['employee id', 'name', 'created at', 'updated at'];
const FINANCE_ENTRIES_HEADERS = [
  'entry id',
  'name',
  'account email',
  'type',
  'title',
  'employee name',
  'employee breakdown',
  'amount',
  'display amount',
  'currency code',
  'occurred on',
  'note',
  'created at',
  'updated at',
];
const INVOICE_SETTINGS_HEADERS = ['key', 'value', 'updated at'];

function doGet(e) {
  const action = String(e.parameter.action || '').toLowerCase();

  if (action === 'getstock') {
    return jsonResponse_({ success: true, data: getStockRows_() });
  }

  if (action === 'getorders') {
    return jsonResponse_({ success: true, data: getOrderRows_() });
  }

  if (action === 'gettaxsetting') {
    return jsonResponse_({ success: true, taxPercentage: getTaxSetting_() });
  }

  if (action === 'getfinanceentries') {
    return jsonResponse_({ success: true, data: getFinanceEntries_(e.parameter) });
  }

  if (action === 'getemployees') {
    return jsonResponse_({ success: true, data: getEmployees_() });
  }

  if (action === 'getinvoicelogo') {
    return jsonResponse_({ success: true, invoiceLogoBase64: getInvoiceLogo_() });
  }

  return jsonResponse_({ success: false, error: 'Unsupported GET action.' });
}

function doPost(e) {
  try {
    const payload = JSON.parse((e.postData && e.postData.contents) || '{}');
    const action = String(payload.action || '').toLowerCase();

    if (action === 'addstock') {
      addStockRow_(payload);
      return jsonResponse_({ success: true });
    }

    if (action === 'updatestock') {
      updateStockRow_(payload);
      return jsonResponse_({ success: true });
    }

    if (action === 'deletestock') {
      deleteStockRow_(payload);
      return jsonResponse_({ success: true });
    }

    if (action === 'addsale') {
      addSaleRow_(payload);
      return jsonResponse_({ success: true });
    }

    if (action === 'updateorder') {
      updateOrderRow_(payload);
      return jsonResponse_({ success: true });
    }

    if (action === 'deleteorder') {
      deleteOrderRow_(payload);
      return jsonResponse_({ success: true });
    }

    if (action === 'updatetaxsetting') {
      updateTaxSetting_(payload);
      return jsonResponse_({ success: true });
    }

    if (action === 'upsertfinanceentry') {
      upsertFinanceEntry_(payload);
      return jsonResponse_({ success: true });
    }

    if (action === 'upsertemployee') {
      upsertEmployee_(payload);
      return jsonResponse_({ success: true });
    }

    if (action === 'deletefinanceentry') {
      deleteFinanceEntry_(payload);
      return jsonResponse_({ success: true });
    }

    if (action === 'deleteemployee') {
      deleteEmployee_(payload);
      return jsonResponse_({ success: true });
    }

    if (action === 'updateinvoicelogo') {
      updateInvoiceLogo_(payload);
      return jsonResponse_({ success: true });
    }

    if (action === 'clearinvoicelogo') {
      clearInvoiceLogo_();
      return jsonResponse_({ success: true });
    }

    if (action === 'createaccount') {
      return jsonResponse_({ success: false, error: 'Account actions are no longer supported in the stock backend. Use the credentials backend instead.' });
    }

    return jsonResponse_({ success: false, error: 'Unsupported POST action.' });
  } catch (error) {
    return jsonResponse_({ success: false, error: String(error.message || error) });
  }
}

function getStockRows_() {
  const sheet = getOrCreateSheet_(STOCK_SHEET_NAME, STOCK_HEADERS);
  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) {
    return [];
  }

  return aggregateStockRows_(values);
}

function getOrderRows_() {
  const sheet = getOrCreateSheet_(SELL_SHEET_NAME, SELL_HEADERS);
  normalizeOrderIds_(sheet);
  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) {
    return [];
  }

  const headers = values[0].map(normalizeHeader_);
  return values
    .slice(1)
    .filter(row => row.some(cell => String(cell).trim() !== ''))
    .reverse()
    .map(row => {
      const item = {};
      headers.forEach((header, index) => {
        item[header] = row[index];
      });
      return item;
    });
}

function getTaxSetting_() {
  const sheet = getOrCreateSheet_(TAX_SETTINGS_SHEET_NAME, TAX_SETTINGS_HEADERS);
  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) {
    return 0;
  }

  const headers = values[0].map(normalizeHeader_);
  const keyIndex = headers.indexOf('key');
  const valueIndex = headers.indexOf('value');
  if (keyIndex === -1 || valueIndex === -1) {
    return 0;
  }

  for (let index = 1; index < values.length; index += 1) {
    if (normalizeHeader_(values[index][keyIndex]) !== 'tax percentage') {
      continue;
    }

    return Number(values[index][valueIndex] || 0);
  }

  return 0;
}

function updateTaxSetting_(payload) {
  const sheet = getOrCreateSheet_(TAX_SETTINGS_SHEET_NAME, TAX_SETTINGS_HEADERS);
  const percentage = Number(payload.taxPercentage || 0);

  if (percentage < 0 || percentage > 100) {
    throw new Error('Tax percentage must be between 0 and 100.');
  }

  const values = sheet.getDataRange().getValues();
  const headers = values[0].map(normalizeHeader_);
  const keyIndex = headers.indexOf('key');
  const valueIndex = headers.indexOf('value');
  const updatedAtIndex = headers.indexOf('updated at');

  for (let index = 1; index < values.length; index += 1) {
    if (normalizeHeader_(values[index][keyIndex]) !== 'tax percentage') {
      continue;
    }

    if (valueIndex !== -1) {
      sheet.getRange(index + 1, valueIndex + 1).setValue(percentage);
    }
    if (updatedAtIndex !== -1) {
      sheet.getRange(index + 1, updatedAtIndex + 1).setValue(new Date().toISOString());
    }
    return;
  }

  sheet.appendRow(['tax percentage', percentage, new Date().toISOString()]);
}

function getInvoiceLogo_() {
  const sheet = getOrCreateSheet_(
    INVOICE_SETTINGS_SHEET_NAME,
    INVOICE_SETTINGS_HEADERS,
  );
  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) {
    return '';
  }

  const headers = values[0].map(normalizeHeader_);
  const keyIndex = headers.indexOf('key');
  const valueIndex = headers.indexOf('value');
  if (keyIndex === -1 || valueIndex === -1) {
    return '';
  }

  const chunks = [];
  for (let index = 1; index < values.length; index += 1) {
    const normalizedKey = normalizeHeader_(values[index][keyIndex]);
    if (!normalizedKey || normalizedKey.indexOf(INVOICE_LOGO_KEY_PREFIX) !== 0) {
      continue;
    }

    const match = /(\d+)$/.exec(normalizedKey);
    chunks.push({
      order: match ? Number(match[1]) : 1,
      value: String(values[index][valueIndex] || ''),
    });
  }

  if (chunks.length === 0) {
    return '';
  }

  chunks.sort((left, right) => left.order - right.order);
  return chunks.map(chunk => chunk.value).join('');
}

function updateInvoiceLogo_(payload) {
  const sheet = getOrCreateSheet_(
    INVOICE_SETTINGS_SHEET_NAME,
    INVOICE_SETTINGS_HEADERS,
  );
  const invoiceLogoBase64 = String(payload.invoiceLogoBase64 || '').trim();
  if (!invoiceLogoBase64) {
    throw new Error('Invoice logo PNG base64 is required.');
  }

  clearInvoiceLogoRows_(sheet);

  const updatedAt = new Date().toISOString();
  const rows = [];
  for (
    let offset = 0, part = 1;
    offset < invoiceLogoBase64.length;
    offset += INVOICE_LOGO_CHUNK_SIZE, part += 1
  ) {
    rows.push([
      INVOICE_LOGO_KEY_PREFIX + ' ' + part,
      invoiceLogoBase64.slice(offset, offset + INVOICE_LOGO_CHUNK_SIZE),
      updatedAt,
    ]);
  }

  if (rows.length === 0) {
    rows.push([INVOICE_LOGO_KEY_PREFIX + ' 1', '', updatedAt]);
  }

  sheet
    .getRange(sheet.getLastRow() + 1, 1, rows.length, INVOICE_SETTINGS_HEADERS.length)
    .setValues(rows);
}

function clearInvoiceLogo_() {
  const sheet = getOrCreateSheet_(
    INVOICE_SETTINGS_SHEET_NAME,
    INVOICE_SETTINGS_HEADERS,
  );
  clearInvoiceLogoRows_(sheet);
}

function clearInvoiceLogoRows_(sheet) {
  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) {
    return;
  }

  const headers = values[0].map(normalizeHeader_);
  const keyIndex = headers.indexOf('key');
  if (keyIndex === -1) {
    return;
  }

  for (let index = values.length - 1; index >= 1; index -= 1) {
    const normalizedKey = normalizeHeader_(values[index][keyIndex]);
    if (normalizedKey.indexOf(INVOICE_LOGO_KEY_PREFIX) === 0) {
      sheet.deleteRow(index + 1);
    }
  }
}

function addStockRow_(payload) {
  const sheet = getOrCreateSheet_(STOCK_SHEET_NAME, STOCK_HEADERS);
  const quantity = Number(payload.quantity || payload.initialQuantity || 0);
  const initialQuantity = Number(payload.initialQuantity || quantity || 0);
  const costPrice = Number(payload.costPrice || 0);
  const itemName = String(payload.itemName || '').trim();
  const sku = String(payload.sku || '').trim();
  const existingRow = findExistingStockRow_(sheet, itemName, sku);

  if (!existingRow) {
    sheet.appendRow([
      itemName,
      quantity,
      initialQuantity,
      costPrice,
      sku,
    ]);
    return;
  }

  const headers = sheet.getRange(1, 1, 1, STOCK_HEADERS.length).getValues()[0].map(normalizeHeader_);
  const itemNameIndex = headers.indexOf('item name');
  const quantityIndex = headers.indexOf('remaining quantity') !== -1
    ? headers.indexOf('remaining quantity')
    : headers.indexOf('quantity');
  const initialQuantityIndex = headers.indexOf('initial quantity');
  const costPriceIndex = headers.indexOf('cost price');
  const skuIndex = headers.indexOf('sku');

  if (itemNameIndex !== -1 && itemName) {
    sheet.getRange(existingRow, itemNameIndex + 1).setValue(itemName);
  }

  if (skuIndex !== -1 && sku) {
    sheet.getRange(existingRow, skuIndex + 1).setValue(sku);
  }

  if (quantityIndex !== -1) {
    const currentRemainingQuantity = Number(sheet.getRange(existingRow, quantityIndex + 1).getValue() || 0);
    sheet.getRange(existingRow, quantityIndex + 1).setValue(currentRemainingQuantity + quantity);
  }

  if (initialQuantityIndex !== -1) {
    const currentInitialQuantity = Number(sheet.getRange(existingRow, initialQuantityIndex + 1).getValue() || 0);
    sheet.getRange(existingRow, initialQuantityIndex + 1).setValue(currentInitialQuantity + initialQuantity);
  }

  if (costPriceIndex !== -1 && costPrice > 0) {
    sheet.getRange(existingRow, costPriceIndex + 1).setValue(costPrice);
  }
}

function updateStockRow_(payload) {
  const sheet = getOrCreateSheet_(STOCK_SHEET_NAME, STOCK_HEADERS);
  const currentItemName = String(payload.currentItemName || payload.itemName || '').trim();
  const currentSku = String(payload.currentSku || payload.sku || '').trim();
  const itemName = String(payload.itemName || '').trim();
  const sku = String(payload.sku || '').trim();
  const quantity = Number(payload.quantity || 0);
  const initialQuantity = Number(payload.initialQuantity || quantity || 0);
  const costPrice = Number(payload.costPrice || 0);

  if (!itemName) {
    throw new Error('Item name is required.');
  }

  if (!sku) {
    throw new Error('SKU is required.');
  }

  if (quantity < 0) {
    throw new Error('Quantity cannot be negative.');
  }

  if (initialQuantity < 0) {
    throw new Error('Initial quantity cannot be negative.');
  }

  const matchingRows = findMatchingStockRows_(sheet, currentItemName, currentSku);
  if (matchingRows.length === 0) {
    throw new Error('Stock item not found.');
  }

  const rowNumber = matchingRows[0];
  sheet.getRange(rowNumber, 1, 1, STOCK_HEADERS.length).setValues([[
    itemName,
    quantity,
    initialQuantity,
    costPrice,
    sku,
  ]]);

  for (let index = matchingRows.length - 1; index >= 1; index -= 1) {
    sheet.deleteRow(matchingRows[index]);
  }

  mergeDuplicateStockRows_(sheet);
}

function deleteStockRow_(payload) {
  const sheet = getOrCreateSheet_(STOCK_SHEET_NAME, STOCK_HEADERS);
  const itemName = String(payload.itemName || '').trim();
  const sku = String(payload.sku || '').trim();
  const matchingRows = findMatchingStockRows_(sheet, itemName, sku);

  if (matchingRows.length === 0) {
    throw new Error('Stock item not found.');
  }

  for (let index = matchingRows.length - 1; index >= 0; index -= 1) {
    sheet.deleteRow(matchingRows[index]);
  }
}

function findExistingStockRow_(sheet, itemName, sku) {
  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) {
    return null;
  }

  const headers = values[0].map(normalizeHeader_);
  const itemNameIndex = headers.indexOf('item name');
  const skuIndex = headers.indexOf('sku');
  const normalizedItemName = normalizeHeader_(itemName);
  const normalizedSku = normalizeHeader_(sku);

  for (let index = 1; index < values.length; index += 1) {
    const rowItemName = itemNameIndex === -1 ? '' : normalizeHeader_(values[index][itemNameIndex]);
    const rowSku = skuIndex === -1 ? '' : normalizeHeader_(values[index][skuIndex]);
    const matchesSku = normalizedSku && rowSku === normalizedSku;
    const matchesItemName = normalizedItemName && rowItemName === normalizedItemName;

    if (matchesSku || (!normalizedSku && matchesItemName)) {
      return index + 1;
    }
  }

  return null;
}

function findMatchingStockRows_(sheet, itemName, sku) {
  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) {
    return [];
  }

  const headers = values[0].map(normalizeHeader_);
  const itemNameIndex = headers.indexOf('item name');
  const skuIndex = headers.indexOf('sku');
  const normalizedItemName = normalizeHeader_(itemName);
  const normalizedSku = normalizeHeader_(sku);
  const rows = [];

  for (let index = 1; index < values.length; index += 1) {
    const rowItemName = itemNameIndex === -1 ? '' : normalizeHeader_(values[index][itemNameIndex]);
    const rowSku = skuIndex === -1 ? '' : normalizeHeader_(values[index][skuIndex]);
    const matchesSku = normalizedSku && rowSku === normalizedSku;
    const matchesItemName = normalizedItemName && rowItemName === normalizedItemName;

    if (matchesSku || (!normalizedSku && matchesItemName)) {
      rows.push(index + 1);
    }
  }

  return rows;
}

function aggregateStockRows_(values) {
  const headers = values[0].map(normalizeHeader_);
  const itemNameIndex = headers.indexOf('item name');
  const quantityIndex = headers.indexOf('remaining quantity') !== -1
    ? headers.indexOf('remaining quantity')
    : headers.indexOf('quantity');
  const initialQuantityIndex = headers.indexOf('initial quantity');
  const costPriceIndex = headers.indexOf('cost price');
  const skuIndex = headers.indexOf('sku');

  if (itemNameIndex === -1 || quantityIndex === -1 || initialQuantityIndex === -1 || costPriceIndex === -1 || skuIndex === -1) {
    return values.slice(1).filter(row => row.some(cell => String(cell).trim() !== '')).map(row => {
      const item = {};
      headers.forEach((header, index) => {
        item[header] = row[index];
      });
      return item;
    });
  }

  const aggregatedMap = {};
  const aggregatedItems = [];

  for (let index = 1; index < values.length; index += 1) {
    const row = values[index];
    if (!row.some(cell => String(cell).trim() !== '')) {
      continue;
    }

    const itemName = String(row[itemNameIndex] || '').trim();
    const sku = String(row[skuIndex] || '').trim();
    const remainingQuantity = Number(row[quantityIndex] || 0);
    const initialQuantity = Number(row[initialQuantityIndex] || 0);
    const costPrice = Number(row[costPriceIndex] || 0);
    const key = normalizeHeader_(sku) || ('name::' + normalizeHeader_(itemName)) || ('row::' + index);
    const existingIndex = aggregatedMap[key];

    if (existingIndex == null) {
      aggregatedMap[key] = aggregatedItems.length;
      aggregatedItems.push({
        'item name': itemName,
        'remaining quantity': remainingQuantity,
        'initial quantity': initialQuantity,
        'cost price': costPrice,
        'sku': sku,
      });
      continue;
    }

    const existing = aggregatedItems[existingIndex];
    existing['item name'] = existing['item name'] || itemName;
    existing['sku'] = existing['sku'] || sku;
    existing['remaining quantity'] = Number(existing['remaining quantity'] || 0) + remainingQuantity;
    existing['initial quantity'] = Number(existing['initial quantity'] || 0) + initialQuantity;
    if (costPrice > 0) {
      existing['cost price'] = costPrice;
    }
  }

  return aggregatedItems;
}

function mergeDuplicateStockRows_(sheet) {
  const values = sheet.getDataRange().getValues();
  if (values.length <= 2) {
    return;
  }

  const headers = values[0].map(normalizeHeader_);
  const itemNameIndex = headers.indexOf('item name');
  const quantityIndex = headers.indexOf('remaining quantity') !== -1
    ? headers.indexOf('remaining quantity')
    : headers.indexOf('quantity');
  const initialQuantityIndex = headers.indexOf('initial quantity');
  const costPriceIndex = headers.indexOf('cost price');
  const skuIndex = headers.indexOf('sku');

  if (itemNameIndex === -1 || quantityIndex === -1 || initialQuantityIndex === -1 || costPriceIndex === -1 || skuIndex === -1) {
    return;
  }

  const mergedRows = [];
  const mergedMap = {};

  for (let index = 1; index < values.length; index += 1) {
    const row = values[index];
    if (!row.some(cell => String(cell).trim() !== '')) {
      continue;
    }

    const itemName = String(row[itemNameIndex] || '').trim();
    const sku = String(row[skuIndex] || '').trim();
    const remainingQuantity = Number(row[quantityIndex] || 0);
    const initialQuantity = Number(row[initialQuantityIndex] || 0);
    const costPrice = Number(row[costPriceIndex] || 0);
    const normalizedSku = normalizeHeader_(sku);
    const normalizedItemName = normalizeHeader_(itemName);
    const key = normalizedSku || ('name::' + normalizedItemName) || ('row::' + index);
    const existingIndex = mergedMap[key];

    if (existingIndex == null) {
      mergedMap[key] = mergedRows.length;
      mergedRows.push({
        itemName: itemName,
        remainingQuantity: remainingQuantity,
        initialQuantity: initialQuantity,
        costPrice: costPrice,
        sku: sku,
      });
      continue;
    }

    const existing = mergedRows[existingIndex];
    existing.itemName = existing.itemName || itemName;
    existing.sku = existing.sku || sku;
    existing.remainingQuantity += remainingQuantity;
    existing.initialQuantity += initialQuantity;
    if (costPrice > 0) {
      existing.costPrice = costPrice;
    }
  }

  const existingRowCount = sheet.getLastRow();
  if (existingRowCount > 1) {
    sheet.getRange(2, 1, existingRowCount - 1, STOCK_HEADERS.length).clearContent();
  }

  if (mergedRows.length > 0) {
    const output = mergedRows.map(row => [
      row.itemName,
      row.remainingQuantity,
      row.initialQuantity,
      row.costPrice,
      row.sku,
    ]);
    sheet.getRange(2, 1, output.length, STOCK_HEADERS.length).setValues(output);
  }
}

function addSaleRow_(payload) {
  const sheet = getOrCreateSheet_(SELL_SHEET_NAME, SELL_HEADERS);
  normalizeOrderIds_(sheet);
  const items = normalizeOrderItems_(payload);
  const quantity = items.reduce((sum, item) => sum + Number(item.quantity || 0), 0);
  const orderId = buildOrderId_(sheet);
  const createdAt = new Date().toISOString();
  const primaryItem = items[0] || { itemName: payload.itemName || '', sku: payload.sku || '', unitPrice: Number(payload.unitPrice || 0) };
  const itemSummary = items.length <= 1
    ? String(primaryItem.itemName || payload.itemName || '')
    : String(primaryItem.itemName || payload.itemName || '') + ' +' + (items.length - 1) + ' more';

  sheet.appendRow([
    payload.companyName || '',
    payload.customerName || '',
    payload.phoneNo || '',
    payload.email || '',
    payload.shippingAddress || '',
    Number(payload.shippingCost || 0),
    quantity,
    primaryItem.sku || payload.sku || '',
    itemSummary,
    Number(primaryItem.unitPrice || payload.unitPrice || 0),
    Number(payload.taxPercentage || 0),
    Number(payload.taxAmount || 0),
    Number(payload.totalCost || 0),
    JSON.stringify(items),
    orderId,
    createdAt,
  ]);

  items.forEach(item => {
    deductStock_(String(item.sku || ''), Number(item.quantity || 0));
  });
}

function updateOrderRow_(payload) {
  const sheet = getOrCreateSheet_(SELL_SHEET_NAME, SELL_HEADERS);
  normalizeOrderIds_(sheet);
  const rowNumber = findOrderRowById_(sheet, String(payload.orderId || ''));
  if (!rowNumber) {
    throw new Error('Order not found for ID ' + payload.orderId + '.');
  }

  const headers = sheet.getRange(1, 1, 1, SELL_HEADERS.length).getValues()[0].map(normalizeHeader_);
  const rowValues = sheet.getRange(rowNumber, 1, 1, SELL_HEADERS.length).getValues()[0];
  const itemsIndex = headers.indexOf('items');
  const shippingCostIndex = headers.indexOf('shipping cost');
  const taxPercentageIndex = headers.indexOf('tax percentage');
  const taxAmountIndex = headers.indexOf('tax amount');
  const totalCostIndex = headers.indexOf('total cost');

  const items = parseOrderItemsFromRow_(headers, rowValues);
  const itemsSubtotal = items.reduce((sum, item) => sum + (Number(item.quantity || 0) * Number(item.unitPrice || 0)), 0);
  const shippingCost = Number(payload.shippingCost || 0);
  const taxPercentage = taxPercentageIndex === -1 ? 0 : Number(rowValues[taxPercentageIndex] || 0);
  const taxAmount = taxAmountIndex === -1 ? 0 : Number(rowValues[taxAmountIndex] || 0);

  setCellByHeader_(sheet, headers, rowNumber, 'company name', payload.companyName || '');
  setCellByHeader_(sheet, headers, rowNumber, 'customer name', payload.customerName || '');
  setCellByHeader_(sheet, headers, rowNumber, 'phone no', payload.phoneNo || '');
  setCellByHeader_(sheet, headers, rowNumber, 'email', payload.email || '');
  setCellByHeader_(sheet, headers, rowNumber, 'shipping address', payload.shippingAddress || '');

  if (shippingCostIndex !== -1) {
    sheet.getRange(rowNumber, shippingCostIndex + 1).setValue(shippingCost);
  }

  if (taxPercentageIndex !== -1) {
    sheet.getRange(rowNumber, taxPercentageIndex + 1).setValue(taxPercentage);
  }

  if (taxAmountIndex !== -1) {
    sheet.getRange(rowNumber, taxAmountIndex + 1).setValue(taxAmount);
  }

  if (totalCostIndex !== -1) {
    sheet.getRange(rowNumber, totalCostIndex + 1).setValue(itemsSubtotal + taxAmount + shippingCost);
  }

  if (itemsIndex !== -1) {
    sheet.getRange(rowNumber, itemsIndex + 1).setValue(JSON.stringify(items));
  }
}

function deleteOrderRow_(payload) {
  const sheet = getOrCreateSheet_(SELL_SHEET_NAME, SELL_HEADERS);
  normalizeOrderIds_(sheet);
  const rowNumber = findOrderRowById_(sheet, String(payload.orderId || ''));
  if (!rowNumber) {
    throw new Error('Order not found for ID ' + payload.orderId + '.');
  }

  const headers = sheet.getRange(1, 1, 1, SELL_HEADERS.length).getValues()[0].map(normalizeHeader_);
  const rowValues = sheet.getRange(rowNumber, 1, 1, SELL_HEADERS.length).getValues()[0];
  const items = parseOrderItemsFromRow_(headers, rowValues);

  items.forEach(item => {
    restoreStock_(String(item.sku || ''), Number(item.quantity || 0));
  });

  sheet.deleteRow(rowNumber);
  normalizeOrderIds_(sheet);
}

function normalizeOrderItems_(payload) {
  const rawItems = Array.isArray(payload.items) ? payload.items : [];
  const normalizedItems = rawItems
    .filter(item => item && (item.sku || item.itemName))
    .map(item => ({
      itemName: String(item.itemName || ''),
      sku: String(item.sku || ''),
      quantity: Math.max(1, Number(item.quantity || 1)),
      unitPrice: Number(item.unitPrice || 0),
    }));

  if (normalizedItems.length > 0) {
    return normalizedItems;
  }

  return [{
    itemName: String(payload.itemName || ''),
    sku: String(payload.sku || ''),
    quantity: Math.max(1, Number(payload.quantity || 1)),
    unitPrice: Number(payload.unitPrice || 0),
  }];
}

function buildOrderId_(sheet) {
  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) {
    return 'ord-1';
  }

  const headers = values[0].map(normalizeHeader_);
  const orderIdIndex = headers.indexOf('order id');
  let maxOrderNumber = 0;

  for (let index = 1; index < values.length; index += 1) {
    const orderId = orderIdIndex === -1 ? '' : String(values[index][orderIdIndex] || '');
    const match = /ord-(\d+)/i.exec(orderId);
    if (!match) {
      continue;
    }

    maxOrderNumber = Math.max(maxOrderNumber, Number(match[1] || 0));
  }

  return 'ord-' + (maxOrderNumber + 1);
}

function normalizeOrderIds_(sheet) {
  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) {
    return;
  }

  const headers = values[0].map(normalizeHeader_);
  const orderIdIndex = headers.indexOf('order id');
  if (orderIdIndex === -1) {
    return;
  }

  let orderCounter = 1;
  for (let index = 1; index < values.length; index += 1) {
    const row = values[index];
    if (!row.some(cell => String(cell).trim() !== '')) {
      continue;
    }

    const normalizedOrderId = 'ord-' + orderCounter;
    if (String(row[orderIdIndex] || '') !== normalizedOrderId) {
      sheet.getRange(index + 1, orderIdIndex + 1).setValue(normalizedOrderId);
    }
    orderCounter += 1;
  }
}

function findOrderRowById_(sheet, orderId) {
  const normalizedOrderId = String(orderId || '').trim().toLowerCase();
  if (!normalizedOrderId) {
    return null;
  }

  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) {
    return null;
  }

  const headers = values[0].map(normalizeHeader_);
  const orderIdIndex = headers.indexOf('order id');
  if (orderIdIndex === -1) {
    return null;
  }

  for (let index = 1; index < values.length; index += 1) {
    if (String(values[index][orderIdIndex] || '').trim().toLowerCase() == normalizedOrderId) {
      return index + 1;
    }
  }

  return null;
}

function parseOrderItemsFromRow_(headers, rowValues) {
  const itemsIndex = headers.indexOf('items');
  if (itemsIndex !== -1) {
    const rawItems = rowValues[itemsIndex];
    if (rawItems) {
      const parsed = JSON.parse(String(rawItems));
      if (Array.isArray(parsed) && parsed.length > 0) {
        return parsed;
      }
    }
  }

  return [{
    itemName: String(getValueByHeader_(headers, rowValues, 'item name') || ''),
    sku: String(getValueByHeader_(headers, rowValues, 'sku') || ''),
    quantity: Math.max(1, Number(getValueByHeader_(headers, rowValues, 'quantity') || 1)),
    unitPrice: Number(getValueByHeader_(headers, rowValues, 'unit price') || 0),
  }];
}

function restoreStock_(sku, quantity) {
  const normalizedSku = normalizeHeader_(sku);
  if (!normalizedSku || quantity <= 0) {
    return;
  }

  const sheet = getOrCreateSheet_(STOCK_SHEET_NAME, STOCK_HEADERS);
  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) {
    return;
  }

  const headers = values[0].map(normalizeHeader_);
  const quantityIndex = headers.indexOf('remaining quantity') !== -1
    ? headers.indexOf('remaining quantity')
    : headers.indexOf('quantity');
  const skuIndex = headers.indexOf('sku');
  if (quantityIndex === -1 || skuIndex === -1) {
    return;
  }

  for (let index = 1; index < values.length; index += 1) {
    if (normalizeHeader_(values[index][skuIndex]) !== normalizedSku) {
      continue;
    }

    const currentQuantity = Number(values[index][quantityIndex] || 0);
    sheet.getRange(index + 1, quantityIndex + 1).setValue(currentQuantity + quantity);
    return;
  }
}

function getValueByHeader_(headers, rowValues, headerName) {
  const index = headers.indexOf(headerName);
  return index === -1 ? '' : rowValues[index];
}

function setCellByHeader_(sheet, headers, rowNumber, headerName, value) {
  const index = headers.indexOf(headerName);
  if (index === -1) {
    return;
  }

  sheet.getRange(rowNumber, index + 1).setValue(value);
}

function deductStock_(sku, soldQuantity) {
  const normalizedSku = normalizeHeader_(sku);
  if (!normalizedSku) {
    throw new Error('SKU is required to update stock.');
  }

  const sheet = getOrCreateSheet_(STOCK_SHEET_NAME, STOCK_HEADERS);
  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) {
    throw new Error('No stock rows available to update.');
  }

  const headers = values[0].map(normalizeHeader_);
  const quantityIndex = headers.indexOf('remaining quantity') !== -1
    ? headers.indexOf('remaining quantity')
    : headers.indexOf('quantity');
  const skuIndex = headers.indexOf('sku');

  if (quantityIndex === -1 || skuIndex === -1) {
    throw new Error('Stock sheet is missing remaining quantity or SKU columns.');
  }

  const matchingRows = [];
  let availableQuantity = 0;

  for (let index = 1; index < values.length; index += 1) {
    const rowSku = normalizeHeader_(values[index][skuIndex]);
    if (rowSku !== normalizedSku) {
      continue;
    }

    const currentQuantity = Number(values[index][quantityIndex] || 0);
    matchingRows.push({ rowNumber: index + 1, currentQuantity: currentQuantity });
    availableQuantity += currentQuantity;
  }

  if (matchingRows.length === 0) {
    throw new Error('Stock item not found for SKU ' + sku + '.');
  }

  if (availableQuantity < soldQuantity) {
    throw new Error('Insufficient stock for SKU ' + sku + '. Available: ' + availableQuantity);
  }

  let remainingToDeduct = soldQuantity;
  for (let index = 0; index < matchingRows.length && remainingToDeduct > 0; index += 1) {
    const match = matchingRows[index];
    const deduction = Math.min(match.currentQuantity, remainingToDeduct);
    sheet.getRange(match.rowNumber, quantityIndex + 1).setValue(match.currentQuantity - deduction);
    remainingToDeduct -= deduction;
  }
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
    ensureSheetHeaders_(sheet, headers);
  }

  applyHeaderStyle_(sheet, headers.length);

  return sheet;
}

function ensureSheetHeaders_(sheet, headers) {
  const currentColumnCount = Math.max(sheet.getLastColumn(), headers.length);
  const currentHeaders = sheet.getRange(1, 1, 1, currentColumnCount).getValues()[0];
  let normalizedCurrent = currentHeaders.map(normalizeHeader_);

  headers.forEach((header, index) => {
    const normalizedHeader = normalizeHeader_(header);
    const existingIndex = normalizedCurrent.indexOf(normalizedHeader);

    if (existingIndex === index) {
      if (currentHeaders[index] !== header) {
        currentHeaders[index] = header;
      }
      return;
    }

    if (existingIndex === -1) {
      sheet.insertColumnBefore(index + 1);
      currentHeaders.splice(index, 0, header);
    } else {
      currentHeaders[index] = header;
    }

    normalizedCurrent = currentHeaders.map(normalizeHeader_);
  });

  if (sheet.getLastColumn() < headers.length) {
    sheet.insertColumnsAfter(sheet.getLastColumn(), headers.length - sheet.getLastColumn());
  }

  const nextHeaders = headers.slice();
  sheet.getRange(1, 1, 1, nextHeaders.length).setValues([nextHeaders]);
}

function applyHeaderStyle_(sheet, headerCount) {
  if (!sheet || headerCount <= 0) {
    return;
  }

  const headerRange = sheet.getRange(1, 1, 1, headerCount);
  headerRange
    .setBackground('#000000')
    .setFontColor('#ffffff')
    .setFontWeight('bold');
}

function normalizeHeader_(value) {
  return String(value || '')
    .trim()
    .toLowerCase();
}

function jsonResponse_(payload) {
  return ContentService
    .createTextOutput(JSON.stringify(payload))
    .setMimeType(ContentService.MimeType.JSON);
}

function getEmployees_() {
  const sheet = getOrCreateSheet_(EMPLOYEES_SHEET_NAME, EMPLOYEES_HEADERS);
  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) {
    return [];
  }

  const headers = values[0].map(normalizeHeader_);
  return values
    .slice(1)
    .filter(row => row.some(cell => String(cell).trim() !== ''))
    .map(row => {
      const item = {};
      headers.forEach((header, index) => {
        item[header] = row[index];
      });
      return item;
    })
    .sort((left, right) => String(left['name'] || '').localeCompare(String(right['name'] || '')));
}

function getFinanceEntries_(parameters) {
  const sheet = getOrCreateSheet_(
    FINANCE_ENTRIES_SHEET_NAME,
    FINANCE_ENTRIES_HEADERS,
  );
  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) {
    return [];
  }

  const headers = values[0].map(normalizeHeader_);

  return values
    .slice(1)
    .filter(row => row.some(cell => String(cell).trim() !== ''))
    .map(row => {
      const item = {};
      headers.forEach((header, index) => {
        item[header] = row[index];
      });
      return item;
    })
    .sort((left, right) => {
      const occurredComparison = compareIsoStringsDesc_(
        left['occurred on'],
        right['occurred on'],
      );
      if (occurredComparison !== 0) {
        return occurredComparison;
      }

      return compareIsoStringsDesc_(left['created at'], right['created at']);
    });
}

function upsertFinanceEntry_(payload) {
  const sheet = getOrCreateSheet_(
    FINANCE_ENTRIES_SHEET_NAME,
    FINANCE_ENTRIES_HEADERS,
  );
  const entryId = String(payload.entryId || payload.id || '').trim();
  const name = String(payload.name || '').trim();
  const accountEmail = String(payload.accountEmail || '').trim().toLowerCase();
  const type = String(payload.type || '').trim().toLowerCase();
  const title = String(payload.title || '').trim();
  const employeeName = String(payload.employeeName || '').trim();
  const employeeBreakdown = String(payload.employeeBreakdown || '').trim();
  const amount = Number(payload.amount || 0);
  const displayAmount = Number(payload.displayAmount || 0);
  const storedAmount = displayAmount || amount;
  const currencyCode = String(payload.currencyCode || 'USD').trim().toUpperCase();
  const occurredOn = String(payload.occurredOn || '').trim();
  const note = String(payload.note || '').trim();
  const createdAt = String(payload.createdAt || '').trim() || new Date().toISOString();
  const updatedAt = new Date().toISOString();

  if (!entryId) {
    throw new Error('Finance entry ID is required.');
  }

  if (!accountEmail) {
    throw new Error('Account email is required for finance entries.');
  }

  if (!type) {
    throw new Error('Finance entry type is required.');
  }

  if (!title) {
    throw new Error('Finance entry title is required.');
  }

  if (!isFinite(storedAmount) || storedAmount === 0) {
    throw new Error('Finance entry display amount must be a non-zero number.');
  }

  if (!currencyCode) {
    throw new Error('Finance entry currency code is required.');
  }

  if (!occurredOn) {
    throw new Error('Finance entry date is required.');
  }

  const rowNumber = findFinanceEntryRow_(sheet, entryId, accountEmail);
  const rowValues = [[
    entryId,
    name,
    accountEmail,
    type,
    title,
    employeeName,
    employeeBreakdown,
    storedAmount,
    storedAmount,
    currencyCode,
    occurredOn,
    note,
    createdAt,
    updatedAt,
  ]];

  if (rowNumber) {
    sheet.getRange(rowNumber, 1, 1, FINANCE_ENTRIES_HEADERS.length).setValues(rowValues);
    return;
  }

  sheet.appendRow(rowValues[0]);
}

function deleteFinanceEntry_(payload) {
  const sheet = getOrCreateSheet_(
    FINANCE_ENTRIES_SHEET_NAME,
    FINANCE_ENTRIES_HEADERS,
  );
  const entryId = String(payload.entryId || payload.id || '').trim();

  if (!entryId) {
    throw new Error('Finance entry ID is required.');
  }

  const rowNumber = findFinanceEntryRow_(sheet, entryId);
  if (!rowNumber) {
    throw new Error('Finance entry not found.');
  }

  sheet.deleteRow(rowNumber);
}

function findFinanceEntryRow_(sheet, entryId) {
  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) {
    return null;
  }

  const headers = values[0].map(normalizeHeader_);
  const entryIdIndex = headers.indexOf('entry id');
  const normalizedEntryId = normalizeHeader_(entryId);

  for (let index = 1; index < values.length; index += 1) {
    if (normalizeHeader_(values[index][entryIdIndex]) !== normalizedEntryId) {
      continue;
    }

    return index + 1;
  }

  return null;
}

function compareIsoStringsDesc_(leftValue, rightValue) {
  const left = String(leftValue || '');
  const right = String(rightValue || '');
  if (left === right) {
    return 0;
  }

  return left > right ? -1 : 1;
}

function upsertEmployee_(payload) {
  const sheet = getOrCreateSheet_(EMPLOYEES_SHEET_NAME, EMPLOYEES_HEADERS);
  const employeeId = String(payload.employeeId || payload.id || '').trim();
  const name = String(payload.name || '').trim();
  const createdAt = String(payload.createdAt || '').trim() || new Date().toISOString();
  const updatedAt = new Date().toISOString();

  if (!employeeId) {
    throw new Error('Employee ID is required.');
  }

  if (!name) {
    throw new Error('Employee name is required.');
  }

  const rowNumber = findEmployeeRow_(sheet, employeeId);
  const rowValues = [[employeeId, name, createdAt, updatedAt]];
  if (rowNumber) {
    sheet.getRange(rowNumber, 1, 1, EMPLOYEES_HEADERS.length).setValues(rowValues);
    return;
  }

  sheet.appendRow(rowValues[0]);
}

function deleteEmployee_(payload) {
  const sheet = getOrCreateSheet_(EMPLOYEES_SHEET_NAME, EMPLOYEES_HEADERS);
  const employeeId = String(payload.employeeId || payload.id || '').trim();
  if (!employeeId) {
    throw new Error('Employee ID is required.');
  }

  const rowNumber = findEmployeeRow_(sheet, employeeId);
  if (!rowNumber) {
    throw new Error('Employee not found.');
  }

  sheet.deleteRow(rowNumber);
}

function findEmployeeRow_(sheet, employeeId) {
  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) {
    return null;
  }

  const headers = values[0].map(normalizeHeader_);
  const employeeIdIndex = headers.indexOf('employee id');
  const normalizedEmployeeId = normalizeHeader_(employeeId);

  for (let index = 1; index < values.length; index += 1) {
    if (normalizeHeader_(values[index][employeeIdIndex]) !== normalizedEmployeeId) {
      continue;
    }

    return index + 1;
  }

  return null;
}