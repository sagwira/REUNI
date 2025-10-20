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
