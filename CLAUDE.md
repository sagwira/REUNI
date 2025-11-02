# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

REUNI is an iOS application built with SwiftUI and SwiftData. The app uses Apple's modern declarative UI framework and SwiftData for persistent storage.

## Build & Test Commands

This is an Xcode project. Use Xcode or xcodebuild for building and testing:

```bash
# Build the app
xcodebuild -project REUNI.xcodeproj -scheme REUNI -configuration Debug build

# Run unit tests
xcodebuild test -project REUNI.xcodeproj -scheme REUNI -destination 'platform=iOS Simulator,name=iPhone 15'

# Run UI tests
xcodebuild test -project REUNI.xcodeproj -scheme REUNI -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:REUNIUITests

# Clean build folder
xcodebuild clean -project REUNI.xcodeproj -scheme REUNI
```

## Architecture

### SwiftData Integration

The app uses SwiftData for data persistence with a centralized model container:

- **ModelContainer**: Created in `REUNIApp.swift:13-24` with schema configuration
- **Model Classes**: Data models are decorated with `@Model` macro (see `Item.swift`)
- **ModelContext**: Injected via SwiftUI environment (`@Environment(\.modelContext)`)
- **Queries**: Data fetching using `@Query` property wrapper in views

### App Structure

- **REUNIApp.swift**: Main app entry point, sets up SwiftData model container
- **ContentView.swift**: Primary view with navigation split layout
- **Item.swift**: Example SwiftData model

### Configuration

- **Bundle ID**: ReUni.REUNI
- **Deployment Target**: iOS 26.1 (note: this is an unusually high version)
- **Development Team**: AC3ZXDVXD2
- **Swift Version**: 5.0
- **Concurrency**: Swift 6 concurrency features enabled with `MainActor` isolation

### Entitlements & Capabilities

The app is configured with:
- Push notifications (remote-notification background mode)
- CloudKit integration (development environment)
- SwiftUI previews enabled

## Development Notes

- The project uses Swift 6 language features (`SWIFT_APPROACHABLE_CONCURRENCY`)
- String catalogs are used for localization
- SwiftUI previews are configured with in-memory model containers for testing

## Security & Git Guidelines

### CRITICAL: Never Commit Sensitive Files

**NEVER commit the following to GitHub:**
- ❌ `.env` files (contain API keys and secrets)
- ❌ `*.log` files (may contain sensitive runtime data)
- ❌ `*.pid` files (process IDs)
- ❌ `*.db` or `*.sqlite` files (local databases)
- ❌ Debug files: `*.html`, `*.png` screenshots from scrapers
- ❌ `api_response.json` or other JSON data dumps
- ❌ Any file containing API keys, tokens, or credentials

**Safe to commit:**
- ✅ `.env.example` (template with placeholder values)
- ✅ Swift source files (`*.swift`)
- ✅ Database schema files (`*.sql`)
- ✅ Documentation files (`*.md`)
- ✅ Configuration templates

### .gitignore is Configured

The `.gitignore` file is properly configured to prevent sensitive files from being committed. Key exclusions:

```
# Sensitive files
*.env
*.log
*.pid
*.db
fatsoma-scraper-api/.env
fatsoma-scraper-api/*.log
fatsoma-scraper-api/*.db
fatsoma-scraper-api/*.html
fatsoma-scraper-api/*.png
```

### Pre-Commit Checklist

Before every `git commit` and `git push`, verify:

1. ✅ Run `git status` and review ALL files being committed
2. ✅ Ensure NO `.env` files are included
3. ✅ Ensure NO log files are included
4. ✅ Ensure NO database files are included
5. ✅ Ensure NO debug screenshots/HTML dumps are included
6. ✅ Only commit files related to the iOS app and database schemas

### If Sensitive Files Were Already Committed

If sensitive files were accidentally committed to git history:

```bash
# Remove from git tracking (keeps local file)
git rm --cached path/to/sensitive/file

# Commit the removal
git commit -m "Remove sensitive file from git tracking"

# Push to remote
git push origin main
```

**Note**: This only removes files from future commits. To remove from git history entirely, you would need to rewrite history (contact admin).
