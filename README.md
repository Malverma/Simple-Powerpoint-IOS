# SimpleSlides

A minimalist slideshow / presentation maker for iPhone and iPad: simple by default, deep on demand. See [spec.md](spec.md).

## Build

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
xcodegen generate
open SimpleSlides.xcodeproj
```

Requires Xcode 16+, iOS 17+.

## CI

Every push to `main` builds an unsigned `SimpleSlides.ipa` on GitHub Actions and attaches it to the
[`latest` release](../../releases/tag/latest). Install it on a device by sideloading (AltStore, SideStore,
Sideloadly, etc.), which re-signs it with your Apple ID.
