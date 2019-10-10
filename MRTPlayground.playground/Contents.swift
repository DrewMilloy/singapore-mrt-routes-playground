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

extension MRTLine: Equatable {
    static func ==(lhs: MRTLine, rhs: MRTLine) -> Bool {
        return lhs.id == rhs.id
    }
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

struct GraphEdgeSummary {
    var start: StationLine
    var end: StationLine
    var line: MRTLine? // if nil, it's a line change
    var stops: Int
    
    init(graphEdge: GraphEdge) {
        start = graphEdge.from
        end = graphEdge.to
        line = graphEdge.line
        stops = line == nil ? 0 : 1
    }
    
    init(start: StationLine, end: StationLine, line: MRTLine?, stops: Int) {
        self.start = start
        self.end = end
        self.line = line
        self.stops = stops
    }

    func add(graphEdge: GraphEdge) -> GraphEdgeSummary {
        guard
            graphEdge.line == self.line &&
            graphEdge.from == self.end
        else {
                print("Attempt to add: \(graphEdge) to \(self)")
//                preconditionFailure("Error: cannot add this edge to the summary")
            return self
        }
        return GraphEdgeSummary(
            start: self.start,
            end: graphEdge.to,
            line: self.line,
            stops: self.stops + 1)
    }

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

extension Sequence where Element == GraphEdgeSummary {
    var routeDescription: String {
        return Array(self.map { $0.debugDescription })
            .joined(separator: "\n")
    }
}

extension GraphEdgeSummary: CustomDebugStringConvertible {
    var debugDescription: String {
        guard let line = self.line else {
            return "Change Lines"
        }
        return "\(self.start.stopDescription) to \(self.end.stopDescription) on \(line.name) - \(self.stops) Stop(s)"
    }
}

extension GraphEdge: CustomDebugStringConvertible {
    var debugDescription: String {
        guard let line = self.line else {
            return "Change"
        }
        return "\(self.from)->\(self.to) (\(line.id))"
    }
}

extension Sequence where Element == GraphEdge {
    var routeDescription: String {
        return Array(self.map { $0.debugDescription })
            .joined(separator: ", ")
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
        let visited: [StationLine] = start.lines
        let q: [[GraphEdge]] = start.lines
            .map { stationLine in
                return graph.filter { $0.from == stationLine && $0.line != nil }
            }
            .compactMap { $0 }
        return breadthFirstSearch(
            queue: q,
            visited: visited,
            destinations: destination.lines)
    }
    
    func breadthFirstSearch(
        queue: [[GraphEdge]],
        visited: [StationLine],
        destinations: [StationLine],
        level: Int = 0) -> [GraphEdge]?
    {
        guard let graphPath = queue.first else {
            return nil
        }
        guard let lastEdge = graphPath.last else {
            fatalError("Path cannot be empty")
        }
        if destinations.contains(lastEdge.to) {
            return graphPath
        }
        let filteredEdges = graph
            .filter { $0.from == lastEdge.to }
            .filter { !visited.contains($0.from) }
        let newVisited = visited + filteredEdges.map { $0.from }
        let newQueue = queue.dropFirst() + filteredEdges.map { graphPath + [$0] }
        return breadthFirstSearch(
            queue: Array(newQueue),
            visited: newVisited,
            destinations: destinations,
            level: level + 1)
    }
    
    func squashRoute(_ route: [GraphEdge]) -> [GraphEdgeSummary] {
        let initialValue: [GraphEdgeSummary] = []
        return route.reduce(initialValue, { accumulator, element in
            guard
                let lastEntry = accumulator.last
            else {
                return [GraphEdgeSummary(graphEdge: element)]
            }
            if lastEntry.line == element.line {
                return accumulator.dropLast()
                    + [lastEntry.add(graphEdge: element)]
            } else {
                return accumulator + [GraphEdgeSummary(graphEdge: element)]
            }
        })
    }
    
    if
        let start = stationIdLookup["BFT"],
        let destination = stationIdLookup["BNK"],
        let route = findRoute(from: start, to: destination)
    {
        let squashedRoute = squashRoute(route)
        print("Found!: " + route.routeDescription)
    }
    
} catch {
    print(error)
}
