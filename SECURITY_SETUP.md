# Security Setup Guide

This guide explains how to securely configure the REUNI application after rotating compromised API keys.

## 🚨 Security Incident Response

**If API keys have been exposed in git history:**

1. **Rotate ALL API keys immediately** at [Supabase Dashboard](https://app.supabase.com)
2. Follow the setup steps below with the NEW keys
3. The git history has been cleaned using BFG Repo Cleaner
4. Never commit `.env` or `Config.xcconfig` files

## 📱 iOS App Configuration

### Step 1: Copy the Config Template

```bash
cd REUNI
cp Config.xcconfig.example Config.xcconfig
```

### Step 2: Edit Config.xcconfig

Open `Config.xcconfig` and add your Supabase credentials:

```
SUPABASE_URL = https://your-project-id.supabase.co
SUPABASE_ANON_KEY = your_supabase_anon_key_here
```

**Where to find these values:**
- Go to [Supabase Dashboard](https://app.supabase.com/project/_/settings/api)
- Copy your Project URL
- Copy your `anon` `public` key (NOT the service_role key)

### Step 3: Configure Xcode Project

1. Open `REUNI.xcodeproj` in Xcode
2. Select the `REUNI` project in the navigator
3. Select the `REUNI` target
4. Go to the "Build Settings" tab
5. Search for "Configuration Files"
6. Under "Debug" configuration, select `Config.xcconfig`
7. Under "Release" configuration, select `Config.xcconfig`

### Step 4: Update Info.plist

Add the Supabase key to Info.plist:

1. Open `REUNI/Info.plist`
2. Add a new row with:
   - Key: `SUPABASE_ANON_KEY`
   - Type: String
   - Value: `$(SUPABASE_ANON_KEY)`

This uses the value from Config.xcconfig without hardcoding it.

## 🐍 Python API Configuration

### Step 1: Copy the .env Template

```bash
cd fatsoma-scraper-api
cp .env.example .env
```

### Step 2: Edit .env

Open `fatsoma-scraper-api/.env` and add your credentials:

```env
# Supabase Configuration
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_SERVICE_KEY=your_supabase_service_role_key_here

# Fatsoma API
FATSOMA_API_KEY=your_fatsoma_api_key_here
```

**Where to find these values:**
- Supabase: [Dashboard > Settings > API](https://app.supabase.com/project/_/settings/api)
  - Use the `service_role` key for Python backend (NOT the anon key)
- Fatsoma API: Contact Fatsoma support or check your developer dashboard

### Step 3: Install Python Dependencies

```bash
cd fatsoma-scraper-api
pip install python-dotenv
```

## ✅ Verification

### Test iOS App

1. Build and run the app in Xcode
2. Check that it connects to Supabase successfully
3. If you see "SUPABASE_ANON_KEY not found" error, review Step 4 above

### Test Python Scripts

```bash
cd fatsoma-scraper-api
python3 main.py
```

If you see "Missing Supabase credentials" error, check your `.env` file.

## 🔒 Security Best Practices

### What to NEVER commit to git:

- ❌ `Config.xcconfig` (iOS secrets)
- ❌ `fatsoma-scraper-api/.env` (Python secrets)
- ❌ Any file containing API keys or tokens
- ❌ `.log`, `.db`, or `.pid` files

### What IS safe to commit:

- ✅ `Config.xcconfig.example` (template with placeholders)
- ✅ `fatsoma-scraper-api/.env.example` (template)
- ✅ Source code files (`.swift`, `.py`)
- ✅ Documentation (`.md` files)

### Before every commit:

```bash
# Always review what you're committing
git status

# Make sure no secrets are included
git diff

# Scan for secrets
ggshield secret scan repo .
```

## 🔄 Key Rotation Procedure

If keys need to be rotated again:

1. **Generate new keys** in Supabase Dashboard
2. **Update local config files:**
   - iOS: Edit `Config.xcconfig`
   - Python: Edit `fatsoma-scraper-api/.env`
3. **Test** that everything still works
4. **Revoke old keys** in Supabase Dashboard
5. **NEVER** commit the config files with new keys

## 📧 Support

If you encounter issues:
1. Check that `.gitignore` includes `Config.xcconfig` and `*.env`
2. Verify your API keys are correct and not expired
3. Run `ggshield secret scan repo .` to check for leaks

## 🔐 Current Security Status

- ✅ Git history cleaned (secrets removed)
- ✅ `.gitignore` configured properly
- ✅ Environment-based configuration in place
- ✅ GitGuardian monitoring enabled
- ✅ Template files created for easy setup

---

**Last Updated:** 2025-11-02
**Status:** All secrets rotated and removed from git history
