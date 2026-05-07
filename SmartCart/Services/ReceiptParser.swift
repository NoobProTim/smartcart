// ReceiptParser.swift — SmartCart/Services/ReceiptParser.swift
// Converts raw OCR text into [ParsedReceiptItem].
//
// P0-2 FIX: parse() now returns a ScanResult enum instead of throwing.
// This lets ReceiptScannerView handle camera, OCR, and parse errors
// distinctly with plain-English messages — no more opaque thrown errors.

import Foundation
import Vision

// P0-2: ScanResult wraps success or one of three typed failures.
enum ScanResult {
    case success([ParsedReceiptItem])
    case cameraPermissionDenied             // User blocked camera access in Settings
    case ocrFailed(String)                  // Vision framework returned no text; message attached
    case noItemsParsed                      // OCR succeeded but zero product lines found
}

struct ReceiptParser {

    // MARK: — Public entry point

    /// Parse a receipt image into a ScanResult.
    /// Called from ReceiptScannerView on the VNImageRequestHandler completion queue.
    static func parse(observations: [VNRecognizedTextObservation]) -> ScanResult {
        // Flatten all recognised text into ordered strings
        let lines = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard !lines.isEmpty else {
            return .ocrFailed("No text was detected in the image. Try better lighting or a flatter receipt.")
        }

        let parsed = extractItems(from: lines)
        return parsed.isEmpty ? .noItemsParsed : .success(parsed)
    }

    // MARK: — Core extraction

    private static func extractItems(from lines: [String]) -> [ParsedReceiptItem] {
        var results: [ParsedReceiptItem] = []
        var i = 0
        while i < lines.count {
            let line = lines[i]

            // Skip lines that are clearly structural: totals, tax, store headers, blank
            guard !isNoiseLine(line) else { i += 1; continue }

            // Try to find a price on this line, or the next ±1 lines
            let price = extractPrice(from: line)
                ?? (i + 1 < lines.count ? extractPrice(from: lines[i + 1]) : nil)
                ?? (i > 0             ? extractPrice(from: lines[i - 1]) : nil)

            let raw        = line.trimmingCharacters(in: .whitespaces)
            let normalised = normalise(raw)

            guard normalised.count >= 3 else { i += 1; continue }  // Too short — skip

            let confidence: ConfidenceLevel
            if price != nil && normalised.count >= 5 { confidence = .high   }
            else if price != nil || normalised.count >= 8 { confidence = .medium }
            else { confidence = .low }

            results.append(ParsedReceiptItem(
                rawName: raw, normalisedName: normalised,
                parsedPrice: price, confidence: confidence
            ))
            i += 1
        }
        return results
    }

    // MARK: — Helpers

    /// Normalise a product name for deduplication and Flipp search.
    /// Lowercases, strips punctuation and filler words, collapses whitespace.
    static func normalise(_ raw: String) -> String {
        let fillerWords: Set<String> = [
            "the", "a", "an", "of", "and", "or", "&", "w/", "with",
            "no", "pkg", "pack", "bag", "box", "can", "jar"
        ]
        return raw
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty && !fillerWords.contains($0) }
            .joined(separator: " ")
    }

    /// Try to parse a dollar amount from a string. Returns nil if none found.
    private static func extractPrice(from line: String) -> Double? {
        // Match patterns like $3.49, 3.49, 12.00
        let pattern = #"\$?\b(\d{1,4}\.\d{2})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line)
        else { return nil }
        return Double(line[range])
    }

    /// Return true for lines that are unlikely to be product names.
    private static func isNoiseLine(_ line: String) -> Bool {
        let noise = [
            "subtotal", "total", "tax", "hst", "gst", "change",
            "cash", "debit", "credit", "visa", "mastercard",
            "thank you", "receipt", "store", "tel", "phone",
            "www.", "http", "member", "loyalty", "points"
        ]
        let lower = line.lowercased()
        return noise.contains(where: { lower.contains($0) })
    }
}
