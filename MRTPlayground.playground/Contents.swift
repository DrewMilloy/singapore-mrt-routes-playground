import Foundation

// # Utilities

extension Collection {
    var pairWise: [(Element, Element)] {
        guard let first = self.first,
            let second = self.dropFirst().first else {
                return []
        }
        return [(first, second)] + self.dropFirst().pairWise
    }
}

struct Queue<T> {
    private var items: [T] = []
    mutating func enQueue(item: T) {
        items.append(item)
    }
    mutating func deQueue() -> T? {
        guard items.count > 0 else {
            return nil
        }
        return items.remove(at: 0)
    }
}

// # JSON Model

typealias StationId = String
typealias LineId = String
typealias StationLine = String

struct MRTStation: Decodable, Hashable {
    var id: StationId
    var name: LocalizedName
    var lines: [StationLine]
}

extension MRTStation: CustomDebugStringConvertible {
    var debugDescription: String {
        return self.id
    }
}

struct LocalizedName: Decodable, Hashable {
    var en: String
    var zh: String
    var ta: String
}

extension LocalizedName: CustomDebugStringConvertible {
    var debugDescription: String {
        return self.en
    }
}

struct MRTLine: Decodable {
    var id: LineId
    var name: String
    var stations: [StationLine]
}

extension MRTLine: CustomDebugStringConvertible {
    var debugDescription: String {
        return self.name
    }
}

struct MRTFile: Decodable {
    var stations: [MRTStation]
    var lines: [MRTLine]
}

// # Internal Model

struct GraphEdge {
    var from: StationLine
    var to: StationLine
    var line: MRTLine? // if nil, it's a line change
}

var stationIdLookup: [StationId: MRTStation] = [:]
var stationLookup: [StationLine: MRTStation] = [:]
var lineLookup: [StationLine: MRTLine] = [:]

extension StationLine {
    var stopDescription: String {
        guard let station = stationLookup[self] else {
            return self
        }
        return "\(self) (\(station.name))"
    }
}

extension Sequence where Element == GraphEdge {
    var routeDescription: String {
        return Array(self.map { edge in
            guard let line = edge.line else {
                return "Change Lines"
            }
            return "\(edge.from.stopDescription) to \(edge.to.stopDescription) on \(line.name)"
        }).joined(separator: "\n")
    }
}

do {
    let url = Bundle.main.url(forResource: "mrt", withExtension: "json")
    let data = try url
        .flatMap { try Data(contentsOf: $0) }
    let jsonDecoder = JSONDecoder()
    let file: MRTFile! = try data
            .flatMap { try jsonDecoder.decode(MRTFile.self, from: $0) }
    
    var graph: [GraphEdge] = []

    file.lines.forEach { line in
        line.stations
            .forEach { lineLookup[$0] = line }
        
        line.stations
            .pairWise
            .forEach { pair in
                graph.append(GraphEdge(from: pair.0, to: pair.1, line: line))
                graph.append(GraphEdge(from: pair.1, to: pair.0, line: line))
        }
    }

    file.stations.forEach { station in
        stationIdLookup[station.id] = station
        station.lines.forEach { stationLookup[$0] = station }
        
        station.lines
            .pairWise
            .forEach { pair in
                graph.append(GraphEdge(from: pair.0, to: pair.1, line: nil))
                graph.append(GraphEdge(from: pair.1, to: pair.0, line: nil))
            }
    }
    
    func findRoute(from start: MRTStation, to destination: MRTStation) -> [GraphEdge]? {
        var visited: [StationLine] = []
        var q = Queue<[GraphEdge]>()
        start.lines.forEach { stationLine in
            visited.append(stationLine)
            graph
                .filter { $0.from == stationLine }
                .forEach { q.enQueue(item: [$0]) }
        }
        while let graphPath = q.deQueue() {
            guard let lastEdge = graphPath.last else {
                fatalError("Path cannot be empty")
            }
            if stationLookup[lastEdge.to] == destination {
                return graphPath
            }
            graph
                .filter { $0.from == lastEdge.to }
                .filter { !visited.contains($0.from) }
                .forEach { edge in
                    visited.append(edge.from)
                    q.enQueue(item: graphPath + [edge])
                }
        }
        return nil
    }
    
    if
        let start = stationIdLookup["BFT"],
        let destination = stationIdLookup["BNK"],
        let route = findRoute(from: start, to: destination)
    {
        print("Found!: " + route.routeDescription)
    }
    
} catch {
    print(error)
}
