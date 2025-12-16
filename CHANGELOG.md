## 0.0.6

* Include `cardDetails` in the card authorization (OTP) request payload
  - Aligns the authorize call with the latest RexPay card API requirements
  - Helps resolve \"AuthData Encryption Failed\" responses during OTP confirmation

### How to Update

1. **Update the SDK**
   - Pull the latest changes from your repository, or
   - Update the package dependency to the latest version (0.0.6)

2. **Rebuild the app**
   - Clean the build cache
   - Rebuild/reinstall the app on your test devices

## 0.0.5

* Add logging and user-facing error messages for bank transfer and USSD payments
  - Log full bank and USSD flows (payment creation, charge, status checks) to help trace issues
  - Surface backend error descriptions on the UI when bank/USSD operations fail or are pending

### How to Update

1. **Update the SDK**
   - Pull the latest changes from your repository, or
   - Update the package dependency to the latest version (0.0.5)

2. **Rebuild the app**
   - Clean the build cache
   - Rebuild/reinstall the app on your test devices

## 0.0.4

* Show OTP authorization errors on the Confirm Payment screen
  - Surface `responseDescription`/`message` from `authorizeCharge` when response code is not `00`
  - Fixes the UX where Confirm Payment appears to do nothing when backend rejects the OTP

### How to Update

1. **Update the SDK**
   - Pull the latest changes from your repository, or
   - Update the package dependency to the latest version (0.0.4)

2. **Rebuild the app**
   - Clean the build cache
   - Rebuild/reinstall the app on your test devices

## 0.0.3

* Added detailed logging for card payments and OTP confirmation
  - Log full card charge flow including public key upload, payment creation and card charge
  - Log OTP capture, payload building and `authorizeCharge` responses to surface failures
  - Helps diagnose cases where **Confirm Payment** appears not to respond after OTP entry

### How to Update

1. **Update the SDK**
   - Pull the latest changes from your repository, or
   - Update the package dependency to the latest version (0.0.3)

2. **Rebuild the app**
   - Clean the build cache
   - Rebuild/reinstall the app on your test devices

## 0.0.2

* Fixed amount conversion issue for card payments
  - Amount sent to card provider now matches the checkout display amount
  - Convert amount from kobo/cents to main currency unit (divide by 100) before sending to API
  - Format amount with 2 decimal places for consistency

### How to Update

## 0.0.1

* TODO: Describe initial release.
