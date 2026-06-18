import Foundation

/// Dependency-free scanner for `#tag` patterns that render as inline chip badges.
enum BlockInputHashtagParsing {
    static func hashtagRanges(
        in text: String,
        excluding excludedRanges: [NSRange] = []
    ) -> [BlockInputInlineMarkdownRange] {
        let nsText = text as NSString
        guard nsText.length > 0 else {
            return []
        }
        let excludedRangeLookup = BlockInputExcludedRangeLookup(
            textLength: nsText.length,
            ranges: excludedRanges
        )
        var ranges: [BlockInputInlineMarkdownRange] = []
        var location = 0
        while location < nsText.length {
            guard nsText.character(at: location) == hash,
                  location == 0 || !isHashtagWordCharacter(nsText.character(at: location - 1)) else {
                location += 1
                continue
            }
            let tagStart = location
            let nameStart = location + 1
            guard nameStart < nsText.length,
                  isHashtagLeadingCharacter(nsText.character(at: nameStart)) else {
                location = nameStart
                continue
            }
            var endLocation = nameStart + 1
            while endLocation < nsText.length,
                  isHashtagCharacter(nsText.character(at: endLocation)) {
                endLocation += 1
            }
            let fullRange = NSRange(location: tagStart, length: endLocation - tagStart)
            guard !excludedRangeLookup.intersects(fullRange) else {
                location = endLocation
                continue
            }
            ranges.append(BlockInputInlineMarkdownRange(
                style: .hashtag,
                fullRange: fullRange,
                contentRange: fullRange,
                delimiterRanges: []
            ))
            location = endLocation
        }
        return ranges
    }

    private static let hash: unichar = 0x23

    private static func isHashtagLeadingCharacter(_ character: unichar) -> Bool {
        (character >= aCodeUnit && character <= zCodeUnit)
            || (character >= ACodeUnit && character <= ZCodeUnit)
            || (character >= zeroCodeUnit && character <= nineCodeUnit)
    }

    private static func isHashtagCharacter(_ character: unichar) -> Bool {
        isHashtagLeadingCharacter(character)
            || character == hyphen
            || character == underscore
    }

    private static func isHashtagWordCharacter(_ character: unichar) -> Bool {
        isHashtagCharacter(character)
    }

    private static let aCodeUnit: unichar = 0x61
    private static let zCodeUnit: unichar = 0x7A
    private static let ACodeUnit: unichar = 0x41
    private static let ZCodeUnit: unichar = 0x5A
    private static let zeroCodeUnit: unichar = 0x30
    private static let nineCodeUnit: unichar = 0x39
    private static let hyphen: unichar = 0x2D
    private static let underscore: unichar = 0x5F
}
