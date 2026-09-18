// Model.js - Helper functions for Cerkak Player plugin

.pragma library

function formatTime(seconds) {
  if (seconds === undefined || seconds === null || isNaN(seconds) || seconds < 0) {
    return "00:00"
  }
  var s = Math.floor(seconds)
  var sec = s % 60
  var min = Math.floor(s / 60) % 60
  var hrs = Math.floor(s / 3600)
  var secStr = (sec < 10 ? "0" : "") + sec
  var minStr = (min < 10 ? "0" : "") + min
  if (hrs > 0) {
    return hrs + ":" + minStr + ":" + secStr
  }
  return minStr + ":" + secStr
}

function cleanTitle(title) {
  if (!title) return ""
  var t = String(title).trim()
  var match = t.match(/irah-?irahan\s*:\s*([^,.\n\r]+)/i)
  if (match && match[1]) {
    return match[1].replace(/^[\s.'"]+|[\s.'"]+$/g, "")
  }
  var match2 = t.match(/judul\s*:\s*([^,.\n\r]+)/i)
  if (match2 && match2[1]) {
    return match2[1].replace(/^[\s.'"]+|[\s.'"]+$/g, "")
  }
  t = t.replace(/^(Cerkak|Cerita Cekak|Cekak)\s*[-–:]\s*/i, "")
  t = t.replace(/^Basa Jawa\s*[-–:]\s*/i, "")
  return t.replace(/^[\s.'"]+|[\s.'"]+$/g, "")
}

function filterStories(items, query) {
  if (!items || !Array.isArray(items)) return []
  if (!query || String(query).trim() === "") return items
  var q = String(query).trim().toLowerCase()
  var filtered = []
  for (var i = 0; i < items.length; i++) {
    var item = items[i]
    var title = String(item.title || "").toLowerCase()
    var fullTitle = String(item.fullTitle || "").toLowerCase()
    if (title.indexOf(q) !== -1 || fullTitle.indexOf(q) !== -1 || String(i + 1) === q) {
      filtered.push(item)
    }
  }
  return filtered
}

function volumeIcon(volume, muted) {
  if (muted || volume <= 0) return "󰝟"
  if (volume < 33) return "󰕿"
  if (volume < 66) return "󰖀"
  return "󰕾"
}
