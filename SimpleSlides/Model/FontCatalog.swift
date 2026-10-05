import SwiftUI
import UIKit
import CoreText

/// Resolves stored font names to SwiftUI fonts and manages user-imported fonts.
enum FontCatalog {
    static let system = "System"
    static let systemRounded = "System Rounded"
    static let systemSerif = "System Serif"
    static let systemMono = "System Mono"

    static let systemFamilies = [system, systemRounded, systemSerif, systemMono]

    static func font(name: String, size: Double, weight: FontWeightOption, italic: Bool = false) -> Font {
        var f: Font
        switch name {
        case system: f = .system(size: size, weight: weight.weight, design: .default)
        case systemRounded: f = .system(size: size, weight: weight.weight, design: .rounded)
        case systemSerif: f = .system(size: size, weight: weight.weight, design: .serif)
        case systemMono: f = .system(size: size, weight: weight.weight, design: .monospaced)
        default: f = .custom(name, size: size).weight(weight.weight)
        }
        return italic ? f.italic() : f
    }

    /// Installed font families, alphabetised.
    static var installedFamilies: [String] {
        UIFont.familyNames.sorted()
    }

    static var fontsDirectory: URL {
        let url = URL.documentsDirectory.appending(path: "Fonts", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Registers every font previously imported by the user.
    static func registerImportedFonts() {
        let files = (try? FileManager.default.contentsOfDirectory(at: fontsDirectory, includingPropertiesForKeys: nil)) ?? []
        for url in files {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// Copies a font file into the app and registers it. Returns the family name.
    @discardableResult
    static func importFont(from source: URL) throws -> String? {
        let accessing = source.startAccessingSecurityScopedResource()
        defer { if accessing { source.stopAccessingSecurityScopedResource() } }
        let dest = fontsDirectory.appending(path: source.lastPathComponent)
        if FileManager.default.fileExists(atPath: dest.path()) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: source, to: dest)
        CTFontManagerRegisterFontsForURL(dest as CFURL, .process, nil)
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(dest as CFURL) as? [CTFontDescriptor],
              let first = descriptors.first,
              let family = CTFontDescriptorCopyAttribute(first, kCTFontFamilyNameAttribute) as? String
        else { return nil }
        return family
    }
}
