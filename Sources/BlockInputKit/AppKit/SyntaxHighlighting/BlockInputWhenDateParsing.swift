import Foundation

/// Dependency-free scanner for `@YYYY-MM-DD` patterns that render as inline chip badges with a calendar icon.
enum BlockInputWhenDateParsing {
    static func whenDateRanges(
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
            guard nsText.character(at: location) == atSign,
                  location == 0 || !isWordCharacter(nsText.character(at: location - 1)) else {
                location += 1
                continue
            }
            let triggerStart = location
            let dateStart = location + 1
            let dateLength = 10
            guard dateStart + dateLength <= nsText.length else {
                location = dateStart
                continue
            }
            let dateSubstring = nsText.substring(with: NSRange(location: dateStart, length: dateLength))
            guard isValidISODateFormat(dateSubstring) else {
                location = dateStart
                continue
            }
            let fullRange = NSRange(location: triggerStart, length: 1 + dateLength)
            guard !excludedRangeLookup.intersects(fullRange) else {
                location = dateStart + dateLength
                continue
            }
            ranges.append(BlockInputInlineMarkdownRange(
                style: .whenDate,
                fullRange: fullRange,
                contentRange: NSRange(location: dateStart, length: dateLength),
                delimiterRanges: [NSRange(location: triggerStart, length: 1)]
            ))
            location = dateStart + dateLength
        }
        return ranges
    }

    private static func isValidISODateFormat(_ dateString: String) -> Bool {
        let nsString = dateString as NSString
        guard nsString.length == 10,
              nsString.character(at: 4) == hyphen,
              nsString.character(at: 7) == hyphen,
              isDigit(nsString.character(at: 0)),
              isDigit(nsString.character(at: 1)),
              isDigit(nsString.character(at: 2)),
              isDigit(nsString.character(at: 3)),
              isDigit(nsString.character(at: 5)),
              isDigit(nsString.character(at: 6)),
              isDigit(nsString.character(at: 8)),
              isDigit(nsString.character(at: 9)) else {
            return false
        }
        guard let year = Int(nsString.substring(with: NSRange(location: 0, length: 4))),
              let month = Int(nsString.substring(with: NSRange(location: 5, length: 2))),
              let day = Int(nsString.substring(with: NSRange(location: 8, length: 2))) else {
            return false
        }
        let components = DateComponents(year: year, month: month, day: day)
        return Calendar.current.date(from: components) != nil
    }

    private static func isDigit(_ character: unichar) -> Bool {
        character >= zeroCodeUnit && character <= nineCodeUnit
    }

    private static func isWordCharacter(_ character: unichar) -> Bool {
        (character >= aCodeUnit && character <= zCodeUnit)
            || (character >= ACodeUnit && character <= ZCodeUnit)
            || (character >= zeroCodeUnit && character <= nineCodeUnit)
            || character == hyphen
            || character == underscore
    }

    private static let atSign: unichar = 0x40
    private static let hyphen: unichar = 0x2D
    private static let underscore: unichar = 0x5F
    private static let aCodeUnit: unichar = 0x61
    private static let zCodeUnit: unichar = 0x7A
    private static let ACodeUnit: unichar = 0x41
    private static let ZCodeUnit: unichar = 0x5A
    private static let zeroCodeUnit: unichar = 0x30
    private static let nineCodeUnit: unichar = 0x39
}
