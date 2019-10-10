const fs = require("fs")

const jsonSource = fs.readFileSync("mrt_stations.json")

const source = JSON.parse(jsonSource)

var allStations = {}
var allLines = {}

const lineStationRegex = /([A-Z]+)([0-9]*)/

for (var index in source) {
  const station = source[index]

  const existing = allStations[station.abbr]
  if (existing) {
    //console.log("NOTE Conflict:") //, station.abbr, "already exists as", existing, "vs", station)
  } else {
    for (var lineIndex in station.lines) {
        const line = station.lines[lineIndex]

        parseLineStation(line, station)
    }
    allStations[station.abbr] = station
  }
}

var lines = []

var sortedStations = []

for (var stationId in allStations) {
  const station = allStations[stationId]
  sortedStations.push({id: stationId, localized_names: {en: station.en, zh: station.zh, ta: station.ta}, lines: station.lines})
}

for (var lineCode in allLines) {
  const stationIds = allLines[lineCode]
  lines.push({id: lineCode, name: "", stations: stationIds})
}

function compareById( a, b ) {
  if ( a.id < b.id ){
    return -1;
  }
  if ( a.id > b.id ){
    return 1;
  }
  return 0;
}

const jsonOutput = JSON.stringify({stations: sortedStations.sort(compareById), lines: lines})

fs.writeFileSync("mrt.json", jsonOutput)
//
// console.log(allStations)
// console.log(allLines)

function parseLineStation(code, station) {
  const result = lineStationRegex.exec(code)
  const lineCode = result[1]
  var stationNumber = result[2]
  if (!stationNumber) {
    stationNumber = 0
  }
  // nothing yet
  if (!allLines[lineCode]) {
    allLines[lineCode] = []
  }
  allLines[lineCode][parseInt(stationNumber)] = station.abbr
}
