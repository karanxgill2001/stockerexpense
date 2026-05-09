# Google Sheets Setup

This app is wired to use a Google Apps Script web app as a lightweight server for Google Sheets.

Account login/profile data and app update checks use a separate credentials Apps Script.

## 1. Prepare your spreadsheet

Use the same spreadsheet that contains these tabs:

- `stock`
- `sell item`
- `app updates`

The app expects these columns in row 1.

### `stock`

- `item name`
- `remaining quantity`
- `initial quantity`
- `cost price`
- `SKU`

### `sell item`

- `company name`
- `customer name`
- `phone no`
- `email`
- `shipping address`
- `shipping cost`
- `quantity`
- `SKU`
- `item name`
- `Unit price`
- `total cost`
- `items`
- `order id`
- `created at`

### `app updates`

Row 1 headers:

- `key`
- `value`
- `updated at`

Rows to keep in the sheet:

- `latest version`
- `latest build number`
- `apk url`
- `release notes`
- `force update`

## 2. Add the Apps Script server

1. Open your spreadsheet.
2. Go to `Extensions > Apps Script`.
3. Replace the default script with the code from [stocker/google_apps_script/Code.gs](google_apps_script/Code.gs).
4. Save the script.

## 3. Deploy the web app

1. Click `Deploy > New deployment`.
2. Choose `Web app`.
3. Set `Execute as`: `Me`.
4. Set `Who has access`: `Anyone` or `Anyone with the link`.
5. Deploy and copy the `/exec` URL.

## 4. Run Flutter with the server URL

Run the app with:

```powershell
flutter run --dart-define=GOOGLE_SCRIPT_URL=https://script.google.com/macros/s/YOUR_DEPLOYMENT_ID/exec
```

## 5. What is connected

- Add Stock: saves a row into `stock`
- Add Stock: if the same SKU already exists, it updates that stock row and adds to both `initial quantity` and `remaining quantity` instead of creating a duplicate row
- Sell Items: saves a row into `sell item` and deducts sold quantity from the `remaining quantity` column in `stock`
- Checkout supports adding multiple items into one order and stores the line items in the `items` column
- Inventory: pulls rows from `stock`
- Orders: pulls completed sales from `sell item`

## 6. Checkout behavior

- Sell Items now requires the item to exist in the `stock` sheet.
- Quantity is validated in the app before submission.
- Apps Script deducts stock by matching the sold item `SKU`, including when the same SKU exists in multiple stock rows.

If you update [stocker/google_apps_script/Code.gs](google_apps_script/Code.gs), redeploy the Apps Script web app so the new stock-deduction logic is live.

If you update [stocker/google_apps_script/Credentials_Code.gs](google_apps_script/Credentials_Code.gs), redeploy that credentials web app too. The app version screen and startup update popup read the latest APK link from the `app updates` sheet in that deployment.