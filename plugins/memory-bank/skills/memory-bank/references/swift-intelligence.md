# Swift/iOS-Specific Intelligence

Load this reference only when working with Swift projects (detected by: `Package.swift`, `*.xcodeproj`, `*.xcworkspace`, `Podfile`).

## Source File Types

| Type | Extensions | Notes |
|------|-----------|-------|
| Source code | `.swift` | Primary analysis target |
| Interface Builder | `.xib`, `.storyboard` | Check for view controller references |
| Assets | `.xcassets` | Feature-related asset catalogs |
| Config | `.xcconfig`, `.entitlements`, `Info.plist` | Build and entitlement settings |
| Project | `.xcodeproj`, `.xcworkspace`, `Package.swift` | `project.pbxproj` is text but very large: search it for the setting or target you need, don't read it whole |

## Patterns to Identify

| Area | What to look for |
|------|-----------------|
| **Architecture** | MVVM, MVC, Clean/VIPER, Coordinator, TCA (The Composable Architecture) |
| **UI** | SwiftUI views (`View` protocol), UIKit view controllers, mixed approaches |
| **Concurrency** | Combine publishers, async/await, `@MainActor`, `Sendable`, actors. Record each target's Swift language mode and default actor isolation from its build settings or `Package.swift`: they differ per target and change what the same code means |
| **DI** | Protocol-based DI, `@EnvironmentObject`, `@Injected` wrappers, factory patterns |
| **State & observation** | `@Observable` models with `@State` / `@Bindable` / `@Environment`, or `ObservableObject` with `@Published` / `@StateObject` / `@EnvironmentObject`; `@Binding`, `@AppStorage`; SwiftData `@Model` / `@Query` |
| **Module structure** | Targets, frameworks, SPM packages, feature modules |
| **Build system** | Schemes, configurations, build phases, run scripts |

## When Documenting Types

Note these Swift-specific attributes in IMPLEMENTATION.md:
- Protocol conformances (what protocols a type adopts)
- Property wrappers in use
- Concurrency model (MainActor, Sendable, async/await, Combine)
- Platform availability (iOS-only, macOS-only, cross-platform)

## Always Ignore

`DerivedData/`, `.build/`, `Pods/`, `*.generated.swift`, build caches.
