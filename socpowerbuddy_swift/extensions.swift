//
//  extensions.swift
//  socpowerbuddy_swift
//
//  Created by Eom SeHwan on 2022/09/17.
//

extension String: LocalizedError {
    public var errorDescription: String? { return self }
    
    public func condenseWhitespace() -> String {
        let components = self.components(separatedBy: .whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.joined(separator: " ")
    }
    
    public mutating func findAndCrop(pattern: String) -> String {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let stringRange = NSRange(location: 0, length: self.utf16.count)
            var line = self
            
            if let searchRange = regex.firstMatch(in: self, options: [], range: stringRange) {
                let start = self.index(self.startIndex, offsetBy: searchRange.range.lowerBound)
                let end = self.index(self.startIndex, offsetBy: searchRange.range.upperBound)
                let value  = String(self[start..<end]).trimmingCharacters(in: .whitespaces)
                line = self.replacingOccurrences(
                    of: value,
                    with: "",
                    options: .regularExpression
                )
                self = line.trimmingCharacters(in: .whitespaces)
                return value.trimmingCharacters(in: .whitespaces)
            }
        } catch {}
        
        return ""
    }
    
    public func find(pattern: String) -> String {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let stringRange = NSRange(location: 0, length: self.utf16.count)
            
            if let searchRange = regex.firstMatch(in: self, options: [], range: stringRange) {
                let start = self.index(self.startIndex, offsetBy: searchRange.range.lowerBound)
                let end = self.index(self.startIndex, offsetBy: searchRange.range.upperBound)
                let value  = String(self[start..<end]).trimmingCharacters(in: .whitespaces)
                return value.trimmingCharacters(in: .whitespaces)
            }
        } catch {}
        
        return ""
    }
    
    public var trimmed: String {
        var buf = [UInt8]()
        var trimming = true
        for c in self.utf8 {
            if trimming && c < 33 { continue }
            trimming = false
            buf.append(c)
        }
        
        while let last = buf.last, last < 33 {
            buf.removeLast()
        }
        
        buf.append(0)
        return String(cString: buf)
    }
    
    public func matches(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
    
    public func removedRegexMatches(pattern: String, replaceWith: String = "") -> String {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: NSRegularExpression.Options.caseInsensitive)
            let range = NSRange(location: 0, length: self.count)
            return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: replaceWith)
        } catch {
            return self
        }
    }
}

public extension Double {
    func roundTo(decimalPlaces: Int) -> String {
        return NSString(format: "%.\(decimalPlaces)f" as NSString, self) as String
    }
    
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
    
    func secondsToHoursMinutesSeconds() -> (Int, Int) {
        let mins = (self.truncatingRemainder(dividingBy: 3600)) / 60
        return (Int(self / 3600), Int(mins))
    }
    
    func printSecondsToHoursMinutesSeconds(short: Bool = false) -> String {
        let (h, m) = self.secondsToHoursMinutesSeconds()
        
        if self == 0 || h < 0 || m < 0 {
            return "n/a"
        }
        
        let minutes = m > 9 ? "\(m)" : "0\(m)"
        
        if short {
            return "\(h):\(minutes)"
        }
        
        if h == 0 {
            return "\(minutes)min"
        } else if m == 0 {
            return "\(h)h"
        }
        
        return "\(h)h \(minutes)min"
    }
}

public extension OperatingSystemVersion {
    func getFullVersion(separator: String = ".") -> String {
        return "\(majorVersion)\(separator)\(minorVersion)\(separator)\(patchVersion)"
    }
}

extension URL {
    func checkFileExist() -> Bool {
        return FileManager.default.fileExists(atPath: self.path)
    }
}
