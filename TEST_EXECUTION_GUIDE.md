# REUNI Test Execution Guide
## Quick Start for Live Testing Session

**Purpose**: Step-by-step guide to test REUNI app with real payments

---

## 🚀 Getting Started

### What You'll Need:
1. **iPhone/iPad** with latest iOS
2. **Real debit/credit card** for payment testing
3. **UK university email** (or approved email domain)
4. **UK phone number** for OTP
5. **Screenshots of real tickets** (Fatsoma or Fixr) for upload testing
6. **Supabase access** - https://app.supabase.com/project/skkaksjbnfxklivniqwy
7. **Stripe Dashboard** - https://dashboard.stripe.com

---

## 📱 Step 1: Build & Install the App

### Option A: Run in Simulator (No Real Card)
```bash
cd /Users/rentamac/Documents/REUNI
open REUNI.xcodeproj

# In Xcode:
# 1. Select iPhone 15 Pro simulator
# 2. Click Run (⌘R)
```

### Option B: Run on Real Device (For Real Card Testing)
```bash
cd /Users/rentamac/Documents/REUNI
open REUNI.xcodeproj

# In Xcode:
# 1. Connect your iPhone
# 2. Select your iPhone from device list
# 3. Signing & Capabilities: Select your team
# 4. Click Run (⌘R)
```

---

## 🧪 Step 2: Test User Sign Up

1. **Launch app** → Should show Login screen
2. **Tap "Sign Up"**
3. **Fill in details**:
   - Full Name: Your name
   - Date of Birth: (Must be 18+)
   - Email: Use real .ac.uk email
   - Phone: UK number
   - University: Select from list
   - Password: (Min 6 characters)
4. **Tap "Continue to Profile Creation"**
5. **Check email** for OTP code
6. **Enter OTP** in app
7. **Upload profile picture** (optional)
8. **Complete profile**

**✅ Success**: You reach the home feed
**❌ Fail**: Document error in test plan

---

## 🎫 Step 3: Browse Tickets

1. **Home feed loads** - should see available tickets
2. **Try search** - search for event name
3. **Try filters** - filter by city
4. **Pull to refresh** - feed should reload

**What to Check**:
- [ ] Tickets display correctly
- [ ] Images load
- [ ] Prices show
- [ ] Real-time updates work (if someone else uploads)

---

## 💳 Step 4: Buy Ticket with REAL CARD ⚠️

**⚠️ WARNING: This test charges your REAL card!**

Choose a **low-price ticket** for testing (e.g., £5-10).

1. **Tap on a ticket** to view details
2. **Review all information**:
   - Event name
   - Date and time
   - Seller info
   - Last entry time
   - Price
3. **Tap "Buy Now"**
4. **Review payment screen**:
   - Ticket price: £X.XX
   - Service fee: £(10% + £1.00)
   - Total: £X.XX
5. **Tap "Pay £X.XX"**
6. **Enter REAL card details** in Stripe sheet:
   - Card number
   - Expiry (MM/YY)
   - CVC
   - Postal code
7. **Tap "Pay"**
8. **Wait for processing**

**✅ Success Indicators**:
- Success screen appears
- Transaction ID shown
- "View Ticket" button works
- Email confirmation received

**Immediately Verify**:
1. Check Stripe Dashboard: https://dashboard.stripe.com/payments
   - Find payment by amount
   - Verify status: "Succeeded"
   - Check application fee taken
2. Check Supabase:
   ```sql
   SELECT * FROM transactions ORDER BY created_at DESC LIMIT 1;
   ```
   - Should show your transaction with status "completed"
3. Check ticket status:
   ```sql
   SELECT id, event_name, sale_status FROM user_tickets
   WHERE sale_status = 'sold'
   ORDER BY updated_at DESC LIMIT 1;
   ```
   - Should show sold ticket

**❌ If Payment Fails**:
- Note exact error message
- Check Stripe Dashboard for failed payment
- Document in test plan
- **DO NOT retry** until issue diagnosed

---

## 🏪 Step 5: Become a Seller

### Set Up Stripe Connect Account

1. **Tap "Upload" or "Sell" tab**
2. **Stripe onboarding appears** (first time only)
3. **Tap "Create Seller Account"**
4. **Complete Stripe Connect**:
   - Business type: Individual
   - Personal details
   - **UK bank account details** (for payouts)
   - ID verification (may be required)
5. **Finish onboarding**

**✅ Success**:
- Onboarding completes
- You can proceed to upload ticket

**Verify in Stripe Dashboard**:
1. Go to: https://dashboard.stripe.com/connect/accounts
2. Find your account (acct_XXXX)
3. Check status: "Complete" or "Pending verification"

---

## 📤 Step 6: Upload Ticket for Sale

**Option 1: Upload Fatsoma Ticket**

1. **Tap "Upload Ticket"**
2. **Select "Fatsoma"**
3. **Search for event**
   - Type event name
   - Select from results
4. **Choose ticket type**
5. **Enter details**:
   - Quantity: 1-10
   - Price per ticket: £XX.XX
   - Upload ticket screenshot
6. **Tap "Upload"**

**Option 2: Upload Fixr Ticket**

1. **Tap "Upload Ticket"**
2. **Select "Fixr"**
3. **Paste Fixr transfer link**
   - Example: `https://fixr.co/transfer-ticket/XXXX`
4. **Review auto-filled details**
5. **Set price**: £XX.XX
6. **Tap "Upload"**

**✅ Success Indicators**:
- Upload completes within 5 seconds
- Success message appears
- Ticket appears in "My Listings"
- Ticket appears in marketplace feed (check on another device or logout/login)

**Verify Upload**:
```sql
SELECT id, event_name, price_per_ticket, sale_status, created_at
FROM user_tickets
WHERE user_id = '[YOUR_USER_ID]'
ORDER BY created_at DESC
LIMIT 1;
```

---

## 🔔 Step 7: Test Real-Time Notifications

**Test Setup**: Need 2 devices or 1 device + simulator

**Device A** (Buyer):
1. Login and stay on home feed

**Device B** (Seller):
1. Upload a new ticket (follow Step 6)

**Back to Device A**:
1. Watch home feed - **new ticket should appear within 3 seconds**
2. Check for push notification (if enabled)

**✅ Success**:
- New ticket appears without manual refresh
- Real-time subscription working

---

## 📊 Step 8: Verify Everything in Databases

### Supabase Checks

Open Supabase SQL Editor: https://app.supabase.com/project/skkaksjbnfxklivniqwy/sql

```sql
-- 1. Check your user profile
SELECT * FROM profiles WHERE email = '[YOUR_EMAIL]';

-- 2. Check your uploaded tickets
SELECT * FROM user_tickets WHERE user_id = '[YOUR_USER_ID]';

-- 3. Check your purchases
SELECT * FROM transactions WHERE buyer_id = '[YOUR_USER_ID]';

-- 4. Check your sales
SELECT * FROM transactions WHERE seller_id = '[YOUR_USER_ID]';

-- 5. Check Stripe Connect status
SELECT id, full_name, stripe_connect_account_id, stripe_account_status
FROM profiles
WHERE id = '[YOUR_USER_ID]';
```

### Stripe Dashboard Checks

**For Buyer (after payment)**:
1. Payments: https://dashboard.stripe.com/payments
   - Find your payment
   - Status should be "Succeeded"
   - Check amount matches

**For Seller (after sale)**:
1. Connect → Accounts: https://dashboard.stripe.com/connect/accounts
   - Find your Connect account
   - Check status
2. Connect → Transfers: https://dashboard.stripe.com/connect/transfers
   - Verify transfer created to your account
   - Check amount: (Ticket Price - 10% - £1.00 - Stripe fees)

---

## 🐛 Common Issues & Fixes

### Issue: Email OTP Not Received
**Fix**:
- Check spam folder
- Verify email is correct
- Wait 2 minutes
- Check Supabase Auth logs

### Issue: Payment Fails
**Fix**:
- Verify card details correct
- Check card has sufficient funds
- Check Stripe test mode vs live mode
- Review Stripe Dashboard for specific error

### Issue: Ticket Upload Fails
**Fix**:
- Verify Stripe seller account is "active"
- Check image file size (<5MB recommended)
- Verify Supabase Storage bucket exists
- Check console logs in Xcode

### Issue: Real-Time Not Working
**Fix**:
- Check internet connection
- Verify Supabase real-time enabled
- Check app logs for subscription status
- Try closing and reopening app

---

## 📝 Document Results

As you test, fill in the **REUNI_COMPREHENSIVE_TEST_PLAN.md** file:

For each test:
1. Mark status: ✅ Pass | ❌ Fail | 🚫 Blocked
2. Record actual results
3. Take screenshots of issues
4. Note any improvements needed

---

## ⚡ Quick Reference - SQL Queries

Copy these for quick database checks:

```sql
-- Find user by email
SELECT * FROM profiles WHERE email = 'YOUR_EMAIL';

-- Recent tickets uploaded
SELECT event_name, price_per_ticket, sale_status, created_at
FROM user_tickets
ORDER BY created_at DESC
LIMIT 10;

-- Recent transactions
SELECT t.id, u.full_name as seller, t.buyer_id, t.total_amount, t.status, t.created_at
FROM transactions t
JOIN profiles u ON t.seller_id = u.id
ORDER BY t.created_at DESC
LIMIT 10;

-- Check ticket sold status
SELECT id, event_name, sale_status, user_id as seller_id
FROM user_tickets
WHERE sale_status = 'sold'
ORDER BY updated_at DESC
LIMIT 5;

-- Stripe Connect accounts
SELECT full_name, email, stripe_connect_account_id, stripe_account_status
FROM profiles
WHERE stripe_connect_account_id IS NOT NULL;
```

---

## 🎯 Success Criteria

**MVP Complete When**:
- [ ] User can sign up and verify email
- [ ] User can browse tickets
- [ ] **User can buy ticket with real card**
- [ ] Payment processes correctly
- [ ] Money transfers to seller correctly
- [ ] User can create Stripe seller account
- [ ] User can upload ticket for sale
- [ ] Ticket appears in marketplace immediately
- [ ] Real-time updates work
- [ ] No critical bugs

**Ready for Beta When**:
- [ ] All above + App follows Apple HIG
- [ ] All database records correct
- [ ] Email notifications working
- [ ] Push notifications working (optional for MVP)

---

## 📞 Support

**Database**: Supabase Dashboard
- URL: https://app.supabase.com/project/skkaksjbnfxklivniqwy
- SQL Editor for queries
- Auth → Users for user management
- Storage for uploaded images

**Payments**: Stripe Dashboard
- URL: https://dashboard.stripe.com
- Payments → All payments
- Connect → Accounts and transfers
- Webhooks → Event logs

**API Monitoring**: Admin Dashboard
- URL: http://localhost:3000/dashboard
- Login with admin credentials
- Check API status, uptime, incidents

---

**Ready to Start Testing?**

1. Build and install app ✅
2. Open test plan document ✅
3. Start with TEST 1 (Sign Up)
4. Work through each test sequentially
5. Document everything!

Good luck! 🚀

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
