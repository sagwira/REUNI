# REUNI iOS App - Comprehensive Test Plan
## Testing All Features from Sign Up to Live Ticket Purchase

**Test Date**: 2025-11-10
**App Version**: Current Development
**Test Environment**: Production (Real Stripe payments)
**Tester**: [To be filled]
**Device**: [To be filled - e.g., iPhone 15 Pro, iOS 18.0]

---

## 📋 Test Overview

This comprehensive test plan covers the entire REUNI user journey:
1. ✅ New user sign up
2. ✅ OTP verification
3. ✅ Profile creation
4. ✅ Browse marketplace tickets
5. ✅ View ticket details
6. ✅ **Buy ticket with REAL card**
7. ✅ Stripe seller onboarding
8. ✅ Upload ticket for sale
9. ✅ Real-time notifications
10. ✅ Ticket alerts for new listings

---

## 🎯 Test Objectives

- Verify complete user onboarding flow works end-to-end
- Test real payment processing with live Stripe integration
- Validate Stripe Connect seller account creation
- Confirm real-time ticket notifications work
- Ensure UI follows Apple Human Interface Guidelines
- Document any bugs, UX issues, or improvements needed

---

## 📱 Pre-Test Setup

### Required Items:
- [ ] **Real debit/credit card** for testing payments
- [ ] **Valid UK university email** (for sign up)
- [ ] **UK phone number** (for OTP verification)
- [ ] **Screenshot of a real ticket** (Fatsoma/Fixr) for upload testing
- [ ] **Supabase admin access** to verify database records
- [ ] **Stripe Dashboard access** to verify payments and payouts

### Environment Check:
- [ ] Supabase URL configured: `https://skkaksjbnfxklivniqwy.supabase.co`
- [ ] Stripe publishable key configured in `Config.xcconfig`
- [ ] Push notifications enabled (if testing alerts)
- [ ] Internet connection stable
- [ ] Location services enabled (if needed)

---

## 🧪 Test Cases

---

### **TEST 1: User Sign Up Flow**

**Objective**: New user can create an account successfully

**Steps**:
1. Launch REUNI app
2. Tap "Sign Up" on login screen
3. Fill in all required fields:
   - Full Name: `[Test User Name]`
   - Date of Birth: `[18+ years old]`
   - Email: `[Valid .ac.uk email]`
   - Phone Number: `[UK phone number]`
   - University: Select from dropdown (e.g., "University of Manchester")
   - Password: `[Strong password]`
   - Confirm Password: `[Same password]`
4. Tap "Continue to Profile Creation"

**Expected Results**:
- ✅ All form fields validate correctly
- ✅ Email domain validation passes (must be .ac.uk or approved domains)
- ✅ Password strength check passes (minimum 6 characters)
- ✅ Passwords match validation works
- ✅ User is created in Supabase `auth.users` table
- ✅ OTP verification screen appears

**Actual Results**:
```
[Record what actually happened]
```

**Status**: ⬜ Pass | ⬜ Fail | ⬜ Blocked

**Issues Found**:
```
[Document any bugs or UX issues]
```

**Screenshots**:
```
[Attach screenshots if issues found]
```

---

### **TEST 2: OTP Verification**

**Objective**: User can verify email with OTP code

**Steps**:
1. Check email inbox for OTP code from Supabase
2. Enter 6-digit OTP code in app
3. Tap "Verify"

**Expected Results**:
- ✅ OTP email arrives within 60 seconds
- ✅ OTP code is 6 digits
- ✅ Correct OTP validates successfully
- ✅ Incorrect OTP shows error message
- ✅ User proceeds to profile creation screen

**Actual Results**:
```
OTP Code Received: [Yes/No]
Time to Receive: [X seconds]
Verification Status: [Success/Fail]
```

**Status**: ⬜ Pass | ⬜ Fail | ⬜ Blocked

**Issues Found**:
```
[Document any issues]
```

---

### **TEST 3: Profile Creation**

**Objective**: User can complete profile with avatar and bio

**Steps**:
1. On profile creation screen, tap "Select Photo"
2. Choose photo from camera roll or take new photo
3. Enter bio/description (optional)
4. Tap "Complete Profile"

**Expected Results**:
- ✅ Photo picker works (camera roll access)
- ✅ Selected photo displays correctly
- ✅ Photo uploads to Supabase Storage (`avatars` bucket)
- ✅ Profile is created in `profiles` table with:
  - User ID
  - Full name
  - Email
  - Phone number
  - University
  - Profile picture URL
  - Bio (if entered)
- ✅ User is redirected to home screen

**Actual Results**:
```
Photo Upload: [Success/Fail]
Profile Created: [Yes/No]
Database Record: [Verified in Supabase]
```

**Status**: ⬜ Pass | ⬜ Fail | ⬜ Blocked

**Issues Found**:
```
[Document any issues]
```

---

### **TEST 4: Browse Marketplace Tickets**

**Objective**: User can view available tickets on home feed

**Steps**:
1. After login, observe home feed
2. Scroll through available tickets
3. Use search bar to search for event
4. Apply filters (city, age restriction)
5. Pull to refresh

**Expected Results**:
- ✅ Home feed loads within 3 seconds
- ✅ Tickets display with:
  - Event name
  - Event image
  - Price
  - Date and time
  - Seller info
  - Last entry time
- ✅ Search works correctly
- ✅ Filters apply immediately
- ✅ Pull to refresh updates feed
- ✅ Sold tickets are hidden from feed
- ✅ Real-time updates work (if another user uploads ticket, it appears)

**Actual Results**:
```
Tickets Loaded: [X tickets]
Load Time: [X seconds]
Search Works: [Yes/No]
Filters Work: [Yes/No]
Real-time Updates: [Yes/No]
```

**Status**: ⬜ Pass | ⬜ Fail | ⬜ Blocked

**Issues Found**:
```
[Document any issues]
```

---

### **TEST 5: View Ticket Details**

**Objective**: User can view full ticket information before purchase

**Steps**:
1. Tap on a ticket card from home feed
2. Review ticket details screen
3. Check seller information
4. Verify event details (date, time, location, last entry)
5. Note ticket source (Fatsoma/Fixr logo)

**Expected Results**:
- ✅ Ticket details screen loads instantly
- ✅ All information displays correctly:
  - Event title
  - Event image (if available)
  - Seller profile picture and username
  - Seller university
  - Event date in UK timezone
  - Last entry time (highlighted in red/green)
  - Ticket type (if from Fixr)
  - Ticket source logo (Fatsoma/Fixr)
  - Available quantity
  - Age restriction (if applicable)
  - Total price
- ✅ "Make Offer" button visible
- ✅ "Buy Now" button visible

**Actual Results**:
```
Details Load: [Instant/Slow/Error]
All Info Present: [Yes/No]
UI Follows Apple HIG: [Yes/No - Note any issues]
```

**Status**: ⬜ Pass | ⬜ Fail | ⬜ Blocked

**Issues Found**:
```
[Document any UX or display issues]
```

---

### **TEST 6: Buy Ticket with REAL CARD** ⚠️ **CRITICAL TEST**

**Objective**: Complete real payment flow with live Stripe integration

**⚠️ WARNING**: This test uses **REAL MONEY**. Use a test amount ticket if possible.

**Steps**:
1. On ticket details screen, tap "Buy Now"
2. Review payment screen showing:
   - Ticket price
   - Service fee (10% + £1.00 flat fee)
   - Total amount
3. Verify "Credit card" payment method is selected
4. Tap "Pay £[Total]" button
5. Stripe payment sheet appears
6. Enter **REAL card details**:
   - Card number
   - Expiry date (MM/YY)
   - CVC
   - Postal code
7. Tap "Pay"
8. Wait for processing
9. Observe success screen

**Expected Results**:
- ✅ Payment breakdown is correct:
  - Ticket price: £[X]
  - Service fee: £[10% + £1.00]
  - Total: £[Ticket + Fee]
- ✅ Stripe payment sheet appears
- ✅ Card details validate correctly
- ✅ Payment processes successfully
- ✅ Success screen shows:
  - Confirmation message
  - Transaction ID
  - Event details
  - "View Ticket" button
- ✅ **Database Updates**:
  - Transaction created in `transactions` table with status "completed"
  - Ticket `sale_status` updated to "sold"
  - Ticket removed from marketplace feed
- ✅ **Stripe Dashboard Checks**:
  - Payment Intent created and succeeded
  - Platform fee (10% + £1.00) held by platform
  - Remaining amount transferred to seller's Stripe Connect account (minus Stripe fees)
- ✅ **Notifications**:
  - Buyer receives confirmation
  - Seller receives sale notification

**Actual Results**:
```
Payment Amount: £[X.XX]
Payment Status: [Success/Failed]
Transaction ID: [UUID from success screen]
Stripe Payment Intent ID: [From Stripe Dashboard - pi_XXXX]
Database Transaction Record: [Verified/Not Found]
Ticket Status Updated: [Yes/No]
Seller Payout Amount: £[X.XX]
Platform Fee Collected: £[X.XX]
```

**Stripe Dashboard Verification**:
1. Go to https://dashboard.stripe.com/payments
2. Find payment by Transaction ID or amount
3. Verify:
   - [ ] Payment succeeded
   - [ ] Correct amount charged
   - [ ] Application fee taken (platform fee)
   - [ ] Transfer to seller's Stripe Connect account initiated

**Supabase Database Verification**:
```sql
-- Run in Supabase SQL Editor
SELECT * FROM transactions
WHERE id = '[TRANSACTION_ID]';

SELECT sale_status FROM user_tickets
WHERE id = '[TICKET_ID]';
```

**Status**: ⬜ Pass | ⬜ Fail | ⬜ Blocked

**⚠️ Critical Issues**:
```
[Document any payment failures, incorrect amounts, missing records, etc.]
```

**Card Used for Test**:
```
Card Type: [Visa/Mastercard/etc.]
Last 4 Digits: [XXXX]
Amount Charged: £[X.XX]
```

---

### **TEST 7: View Purchased Ticket**

**Objective**: Buyer can access their purchased ticket

**Steps**:
1. From success screen, tap "View Ticket"
2. Navigate to "My Purchases" tab
3. Find purchased ticket
4. Tap to view details

**Expected Results**:
- ✅ "My Purchases" tab shows purchased ticket
- ✅ Ticket displays:
  - Event name and image
  - Event date/time
  - Ticket screenshot (from seller)
  - QR code or entry details
  - Purchase date
  - Transaction ID
- ✅ Can access ticket offline (once loaded)

**Actual Results**:
```
Ticket Visible: [Yes/No]
Ticket Screenshot Received: [Yes/No]
All Details Present: [Yes/No]
```

**Status**: ⬜ Pass | ⬜ Fail | ⬜ Blocked

---

### **TEST 8: Stripe Seller Onboarding**

**Objective**: User can create Stripe Connect seller account to sell tickets

**Steps**:
1. Navigate to "Upload Ticket" or "Sell" tab
2. If first time selling, observe Stripe onboarding screen
3. Tap "Create Seller Account"
4. Complete Stripe Connect onboarding:
   - Business type: Individual
   - Personal details (name, DOB, address)
   - Bank account details (UK bank account)
   - Identity verification (if required)
5. Complete onboarding

**Expected Results**:
- ✅ Onboarding screen appears for new sellers
- ✅ Stripe Connect hosted onboarding opens
- ✅ User can enter all required information
- ✅ Bank account validates successfully
- ✅ Account is created in Stripe Dashboard
- ✅ `stripe_connect_account_id` saved in `profiles` table
- ✅ Account status set to "active" or "pending" based on verification
- ✅ User can proceed to upload ticket if account active

**Actual Results**:
```
Onboarding Started: [Yes/No]
Onboarding Completed: [Yes/No]
Stripe Account ID: [acct_XXXX]
Account Status: [active/pending/restricted]
Database Updated: [Yes/No]
```

**Stripe Dashboard Verification**:
1. Go to https://dashboard.stripe.com/connect/accounts
2. Find account by Account ID
3. Verify:
   - [ ] Account exists
   - [ ] Status is correct
   - [ ] Payouts enabled
   - [ ] Bank account added

**Status**: ⬜ Pass | ⬜ Fail | ⬜ Blocked

**Issues Found**:
```
[Document any onboarding issues]
```

---

### **TEST 9: Upload Ticket for Sale**

**Objective**: Seller can upload ticket to marketplace

**Prerequisites**:
- ✅ Stripe seller account created and active
- ✅ Have screenshot of real ticket (Fatsoma or Fixr)

**Steps**:
1. Navigate to "Upload Ticket" tab
2. Select ticket source:
   - [ ] Test Fatsoma flow
   - [ ] Test Fixr flow
3. **For Fatsoma**:
   - Search for event
   - Select event from list
   - Choose ticket type
   - Enter quantity (1-10)
   - Enter selling price (per ticket)
   - Upload ticket screenshot
   - Add optional notes
   - Tap "Upload"
4. **For Fixr**:
   - Paste Fixr transfer link
   - System extracts ticket details
   - Review auto-filled information
   - Set selling price
   - Tap "Upload"

**Expected Results**:
- ✅ Event search works (for Fatsoma)
- ✅ Event list loads from Fatsoma API
- ✅ Can select ticket type
- ✅ Price validation works (minimum £1)
- ✅ Photo picker works for ticket screenshot
- ✅ Upload button disabled until all required fields filled
- ✅ Upload processes within 5 seconds
- ✅ **Database Updates**:
  - New record created in `user_tickets` table
  - Seller ID linked correctly
  - Ticket screenshot uploaded to Supabase Storage
  - Sale status set to "active"
- ✅ Success confirmation shown
- ✅ Ticket appears in marketplace feed immediately (real-time)
- ✅ Ticket appears in seller's "My Listings" tab

**Actual Results**:
```
Source Tested: [Fatsoma/Fixr]
Event Search: [Works/Broken]
Upload Time: [X seconds]
Database Record Created: [Yes/No]
Screenshot Uploaded: [Yes/No]
Appears in Marketplace: [Yes/No]
Real-time Update: [Yes/No]
```

**Supabase Verification**:
```sql
SELECT * FROM user_tickets
WHERE user_id = '[SELLER_USER_ID]'
ORDER BY created_at DESC
LIMIT 1;
```

**Status**: ⬜ Pass | ⬜ Fail | ⬜ Blocked

**Issues Found**:
```
[Document any upload issues, validation errors, or UX problems]
```

---

### **TEST 10: Real-Time Ticket Alerts**

**Objective**: Users receive notifications when new tickets matching their preferences are listed

**Steps**:
1. **Setup** (on Device A):
   - Enable push notifications
   - Set notification preferences (if available)
   - Note current tickets in feed
2. **Trigger** (on Device B or web):
   - Upload a new ticket to marketplace
3. **Observe** (on Device A):
   - Watch for notification
   - Check home feed for new ticket

**Expected Results**:
- ✅ New ticket appears in home feed within 3 seconds (real-time subscription)
- ✅ Push notification sent (if notifications enabled)
- ✅ Notification shows:
  - Event name
  - Price
  - "New ticket available"
- ✅ Tapping notification opens ticket details
- ✅ Notification badge appears on app icon

**Actual Results**:
```
Real-time Feed Update: [Yes/No - X seconds delay]
Push Notification Received: [Yes/No]
Notification Delay: [X seconds]
Notification Content Correct: [Yes/No]
Tap Action Works: [Yes/No]
```

**Technical Notes**:
```
Real-time Channel: user-tickets-channel-[UUID]
Supabase Real-time Status: [Connected/Disconnected]
```

**Status**: ⬜ Pass | ⬜ Fail | ⬜ Blocked

**Issues Found**:
```
[Document notification delivery issues or delays]
```

---

### **TEST 11: Seller Receives Payment**

**Objective**: Verify seller receives payout for sold ticket

**Prerequisites**:
- ✅ Ticket sold (from TEST 6)
- ✅ Seller has active Stripe Connect account

**Steps**:
1. Check Stripe Dashboard (Connect Account)
2. Verify transfer from platform
3. Check payout schedule

**Expected Results**:
- ✅ Transfer created from platform to seller
- ✅ Transfer amount = Ticket Price - Platform Fee (10% + £1) - Stripe Fees
- ✅ Payout scheduled (depends on Stripe settings - daily/weekly/monthly)
- ✅ Seller can see transaction in app "Earnings" section

**Actual Results**:
```
Transfer Created: [Yes/No]
Transfer Amount: £[X.XX]
Expected Amount: £[X.XX]
Payout Status: [Pending/Paid]
Payout Date: [Date]
```

**Calculation Breakdown**:
```
Ticket Price: £[X.XX]
Platform Fee (10%): £[X.XX]
Flat Fee: £1.00
Total Platform Fee: £[X.XX]
Stripe Processing Fee (~2.9% + 20p): £[X.XX]
Seller Receives: £[X.XX]
```

**Stripe Dashboard Verification**:
1. Log in as seller's Connect account
2. Go to Balance → Transactions
3. Verify transfer matches calculation

**Status**: ⬜ Pass | ⬜ Fail | ⬜ Blocked

---

### **TEST 12: Apple HIG Compliance**

**Objective**: Verify app follows Apple Human Interface Guidelines

**Areas to Check**:

**Navigation**:
- [ ] Back buttons work consistently
- [ ] Navigation hierarchy makes sense
- [ ] Tab bar icons are clear
- [ ] Modal presentations are appropriate

**Typography**:
- [ ] System fonts used appropriately
- [ ] Text is readable (minimum 11pt for body text)
- [ ] Dynamic Type supported (test with larger text in Settings)
- [ ] Proper text hierarchy (headings, body, captions)

**Colors**:
- [ ] Dark mode supported
- [ ] Sufficient contrast ratios
- [ ] Semantic colors used (e.g., red for destructive actions)
- [ ] Custom brand colors don't interfere with accessibility

**Interactions**:
- [ ] Tap targets ≥44x44 points
- [ ] Loading states shown for async operations
- [ ] Error messages are helpful
- [ ] Success confirmations shown
- [ ] Haptic feedback appropriate (if used)

**Accessibility**:
- [ ] VoiceOver labels present
- [ ] Images have alt text
- [ ] Form fields have labels
- [ ] Buttons have accessible labels

**Performance**:
- [ ] Smooth scrolling (60 FPS)
- [ ] No janky animations
- [ ] Images load progressively
- [ ] App doesn't freeze during network requests

**Issues Found**:
```
[Document any HIG violations or UX improvements]

Examples:
- Buttons too small
- Missing loading states
- Poor contrast in dark mode
- Confusing navigation
- etc.
```

---

## 📊 Test Summary

### Overall Results

**Total Tests**: 12
**Tests Passed**: ___
**Tests Failed**: ___
**Tests Blocked**: ___

**Pass Rate**: ___%

---

### Critical Issues Found

**Priority 1 (Blocker - Must Fix)**:
```
1. [Issue description]
2. [Issue description]
```

**Priority 2 (High - Should Fix)**:
```
1. [Issue description]
2. [Issue description]
```

**Priority 3 (Medium - Nice to Fix)**:
```
1. [Issue description]
2. [Issue description]
```

**Priority 4 (Low - Future Enhancement)**:
```
1. [Issue description]
2. [Issue description]
```

---

### Recommended Improvements

**UX Enhancements**:
```
1. [Suggestion]
2. [Suggestion]
```

**Performance Optimizations**:
```
1. [Suggestion]
2. [Suggestion]
```

**Feature Additions**:
```
1. [Suggestion]
2. [Suggestion]
```

---

### Database Verification Queries

Run these in Supabase SQL Editor to verify test data:

```sql
-- Check new user created
SELECT * FROM auth.users
WHERE email = '[TEST_EMAIL]';

-- Check profile created
SELECT * FROM profiles
WHERE email = '[TEST_EMAIL]';

-- Check ticket uploaded
SELECT * FROM user_tickets
WHERE user_id = '[SELLER_ID]'
ORDER BY created_at DESC;

-- Check transaction created
SELECT * FROM transactions
WHERE buyer_id = '[BUYER_ID]' OR seller_id = '[SELLER_ID]'
ORDER BY created_at DESC;

-- Check Stripe accounts
SELECT
  id,
  full_name,
  stripe_connect_account_id,
  stripe_account_status
FROM profiles
WHERE id IN ('[BUYER_ID]', '[SELLER_ID]');

-- Check API monitoring (if deployed)
SELECT * FROM api_status;
SELECT * FROM api_uptime_history
WHERE checked_at >= NOW() - INTERVAL '24 hours'
ORDER BY checked_at DESC;
```

---

### Stripe Dashboard Verification

**Payments**: https://dashboard.stripe.com/payments
- [ ] Test payment visible
- [ ] Correct amount
- [ ] Application fee correct

**Connect Accounts**: https://dashboard.stripe.com/connect/accounts
- [ ] Seller account created
- [ ] Account verified
- [ ] Payouts enabled

**Transfers**: https://dashboard.stripe.com/connect/transfers
- [ ] Transfer to seller created
- [ ] Correct amount after fees

**Webhooks**: https://dashboard.stripe.com/webhooks
- [ ] Webhook events firing correctly
- [ ] No failed webhook deliveries

---

## 🚀 Next Steps After Testing

### If All Tests Pass:
1. Document final results
2. Take screenshots of successful flows
3. Record demo video
4. Prepare for App Store submission
5. Create user documentation
6. Plan marketing launch

### If Tests Fail:
1. Document all failures in detail
2. Prioritize issues
3. Fix critical blockers first
4. Re-test after fixes
5. Iterate until all tests pass

---

## 📝 Notes

**Testing Environment**:
```
Device: [iPhone model, iOS version]
Build: [Build number]
Date: [Date tested]
Tester: [Name]
Network: [WiFi/Cellular - speed]
```

**Additional Notes**:
```
[Any other observations, edge cases tested, or important findings]
```

---

**Test Completed By**: _______________
**Date**: _______________
**Signature**: _______________

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
