import Foundation

typealias StationId = String
typealias LineId = String

struct MRTStation: Decodable, Hashable {
    var id: StationId
    var localizedName: LocalizedName
    var lineCodes: [String]
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case localizedName = "localized_names"
        case lineCodes = "lines"
    }
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

struct MRTLine: Decodable {
    var id: LineId
    var name: String
    var stations: [StationId?]
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

struct GraphEdge {
    var a: MRTStation
    var b: MRTStation
    var line: MRTLine
}

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

do {
    let url = Bundle.main.url(forResource: "mrt", withExtension: "json")
    let data = try url
        .flatMap { try Data(contentsOf: $0) }
//    print(data)
    let jsonDecoder = JSONDecoder()
    let file: MRTFile! = try data
            .flatMap { try jsonDecoder.decode(MRTFile.self, from: $0) }
    
//    print(file)

    var stationLookup: [StationId: MRTStation] = [:]

    file.stations.forEach { stationLookup[$0.id] = $0 }

    var graph = [GraphEdge]()
    
    file.lines.forEach { line in
        line.stations
            .compactMap { $0.flatMap { stationLookup[$0] } }
            .pairWise
            .forEach { pair in
            graph.append(GraphEdge(a: pair.0, b: pair.1, line: line))
            graph.append(GraphEdge(a: pair.1, b: pair.0, line: line))
        }
    }

    var stationConnections: [StationId: [(StationId, LineId)]] = [:]
    
    file.stations.forEach { station in
        let connections = graph
            .filter { $0.a == station }
            .map { ($0.b.id, $0.line.id) }
        stationConnections[station.id] = connections
    }
    
    print(stationConnections)
    
    let start = "BFT"
    let destination = "BNK"
    
    
    func findRoute(from start: StationId, to destination: StationId) {
        var visited: [StationId] = [start]
        var q = Queue<[(StationId, LineId)]>()
        q.enQueue(item: [(start, "")])
        while let stations = q.deQueue() {
            let station = stations.last!
            if (station.0 == destination) {
                print("Found it")
                print(stations)
                return
            }
            stationConnections[station.0]?
                .filter { !visited.contains($0.0) }
                .forEach {
                    visited.append($0.0)
                    q.enQueue(item: stations + [$0])
                }
        }
    }
    
//    func findRoute(from start: StationId, to destination: StationId, visited: [StationId] = []) -> Int? {
//        let newVisited = visited + [start]
//        guard start != destination else {
//            print(newVisited)
//            return 0
//        }
//        let connections = stationConnections[start]?
//            .filter { !visited.contains($0) }
//        return connections?
//            .compactMap {
//                findRoute(from: $0, to: destination, visited: newVisited)
//            }
//            .map { $0 + 1 }
//            .min()
//    }
    
    findRoute(from: start, to: destination)
    
//    print(graph)
    
} catch {
    print(error)
}
