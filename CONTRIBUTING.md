# Contributing

Thanks for your interest in Actuali.

## Building

- Xcode with the iOS 26.1+ SDK
- Open `Actuali/Actuali.xcodeproj`; Swift Package Manager resolves dependencies on first build

```bash
xcodebuild -project Actuali/Actuali.xcodeproj -scheme Actuali -sdk iphonesimulator build
```

## Tests

```bash
xcodebuild -project Actuali/Actuali.xcodeproj -scheme Actuali \
  -destination 'platform=iOS Simulator,name=<any installed simulator>' test
```

The sync engine tests (`Actuali/ActualiTests/SyncEngineFixtureTests.swift` and friends) verify CRDT behavior against fixtures derived from upstream Actual Budget — please keep them passing.

## Issues

Bug reports and feature requests are welcome — please open a GitHub issue.

## Pull requests

- Keep changes focused; one concern per PR
- Make sure the project builds and tests pass before opening a PR
- For sync-engine changes, reference the corresponding upstream behavior (`packages/crdt` / `packages/loot-core` in [actualbudget/actual](https://github.com/actualbudget/actual)) so it can be verified
- Don't bump the build number; that happens at release time
