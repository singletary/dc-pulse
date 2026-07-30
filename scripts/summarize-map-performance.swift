#!/usr/bin/env swift

import Foundation

struct SignpostEvent {
    let date: Date
    let name: String
    let type: String
    let id: UInt64
    let message: String
}

guard CommandLine.arguments.count == 4 else {
    FileHandle.standardError.write(Data(
        "usage: summarize-map-performance.swift <radius> <cache-state> <run-number>\n".utf8
    ))
    exit(64)
}

let radius = CommandLine.arguments[1]
let cacheState = CommandLine.arguments[2]
let runNumber = CommandLine.arguments[3]
let input = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? ""
let formatter = ISO8601DateFormatter()
formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

func parsedDate(_ value: String) -> Date? {
    guard value.count >= 5 else { return nil }
    var normalized = value.replacingOccurrences(of: " ", with: "T")
    let timezoneColon = normalized.index(normalized.endIndex, offsetBy: -2)
    normalized.insert(":", at: timezoneColon)
    return formatter.date(from: normalized)
}

let events: [SignpostEvent] = input.split(separator: "\n").compactMap { line in
    guard line.first == "{",
          let data = line.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let timestamp = object["timestamp"] as? String,
          let date = parsedDate(timestamp),
          let name = object["signpostName"] as? String,
          let type = object["signpostType"] as? String,
          let message = object["eventMessage"] as? String else {
        return nil
    }
    let id = (object["signpostID"] as? NSNumber)?.uint64Value ?? 0
    return SignpostEvent(date: date, name: name, type: type, id: id, message: message)
}.sorted { $0.date < $1.date }

func firstEvent(named name: String, type: String = "event") -> SignpostEvent? {
    events.first { $0.name == name && $0.type == type }
}

func seconds(from start: Date, to event: SignpostEvent?) -> Double? {
    event.map { $0.date.timeIntervalSince(start) }
}

func formatted(_ value: Double?) -> String {
    value.map { String(format: "%.3f", $0) } ?? ""
}

func capture(_ pattern: String, in value: String) -> String? {
    guard let expression = try? NSRegularExpression(pattern: pattern),
          let match = expression.firstMatch(
              in: value,
              range: NSRange(value.startIndex..., in: value)
          ),
          let range = Range(match.range(at: 1), in: value) else {
        return nil
    }
    return String(value[range])
}

guard let presentation = firstEvent(named: "Map Presentation Started") else {
    FileHandle.standardError.write(Data("Map Presentation Started was not captured.\n".utf8))
    exit(65)
}
let launch = firstEvent(named: "App Launch Started")
let initialResults = firstEvent(named: "Initial Nearby Results Ready")

let intervalBegins = Dictionary(
    uniqueKeysWithValues: events
        .filter { $0.type == "begin" }
        .map { ($0.id, $0) }
)
let intervalEnds = Dictionary(
    uniqueKeysWithValues: events
        .filter { $0.type == "end" }
        .map { ($0.id, $0) }
)

let coverageBegin = events.first { $0.name == "Map Coverage Session" && $0.type == "begin" }
let coverageEnd = coverageBegin.flatMap { intervalEnds[$0.id] }
let coverageDuration = coverageBegin.flatMap { begin in
    coverageEnd.map { $0.date.timeIntervalSince(begin.date) }
}
let bounded = firstEvent(named: "Bounded Map Coverage Complete")
let finalItems = bounded.flatMap { capture(#"count=(\d+)"#, in: $0.message) } ?? ""
let outcome = coverageEnd.flatMap { capture(#"outcome=([A-Za-z]+)"#, in: $0.message) } ?? ""

var sourceTotals: [String: Double] = [:]
var sourceFailures: [String: Int] = [:]
var failedSourceRequests = 0
var timedOutSourceRequests = 0
var failedSourceOffsets: [String] = []
for (id, begin) in intervalBegins where begin.name == "Map Source Request" {
    guard let end = intervalEnds[id],
          let source = capture(#"source=([A-Za-z0-9]+)"#, in: begin.message) else {
        continue
    }
    sourceTotals[source, default: 0] += end.date.timeIntervalSince(begin.date)
    let failed = !end.message.contains("outcome=succeeded") &&
        !end.message.contains("outcome=cancelled")
    if failed {
        failedSourceRequests += 1
        sourceFailures[source, default: 0] += 1
        if end.message.contains("outcome=timedOut") {
            timedOutSourceRequests += 1
        }
        let offset = capture(#"offset=(\d+)"#, in: begin.message) ?? "unknown"
        failedSourceOffsets.append("\(source):\(offset)")
    }
}

let columns = [
    radius,
    cacheState,
    runNumber,
    formatted(launch.flatMap { start in seconds(from: start.date, to: initialResults) }),
    formatted(launch.flatMap { start in seconds(from: start.date, to: firstEvent(named: "Map Interactive")) }),
    formatted(launch.flatMap { start in seconds(from: start.date, to: firstEvent(named: "First Map Markers")) }),
    formatted(seconds(from: presentation.date, to: firstEvent(named: "Map Interactive"))),
    formatted(seconds(from: presentation.date, to: firstEvent(named: "First Map Markers"))),
    formatted(seconds(from: presentation.date, to: firstEvent(named: "Close-in Coverage Complete"))),
    formatted(seconds(from: presentation.date, to: bounded)),
    formatted(coverageDuration),
    finalItems,
    outcome,
    formatted(sourceTotals["dc311"]),
    formatted(sourceTotals["buildingPermits"]),
    formatted(sourceTotals["ddotPermits"]),
    String(failedSourceRequests),
    String(timedOutSourceRequests),
    String(sourceFailures["dc311", default: 0]),
    String(sourceFailures["buildingPermits", default: 0]),
    String(sourceFailures["ddotPermits", default: 0]),
    "\"\(failedSourceOffsets.sorted().joined(separator: "|"))\""
]

print(columns.joined(separator: ","))
