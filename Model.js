// Pure helpers for the tmux sessions menu. No QML/Quickshell dependencies so
// they can be unit-tested with plain node (tests/model.test.js).

// Parses `tmux-sessions list` output (TAB-separated: name, windows, clients,
// created, activity, path) into session objects. Malformed lines are skipped.
function parseSessions(text) {
  var out = []
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (!line.trim()) continue
    var f = line.split("\t")
    if (f.length < 5 || !f[0]) continue
    out.push({
      name: f[0],
      windows: toInt(f[1]),
      clients: toInt(f[2]),
      created: toInt(f[3]),
      activity: toInt(f[4]),
      path: f.slice(5).join("\t")
    })
  }
  return out
}

function toInt(v) {
  var n = parseInt(v, 10)
  return isNaN(n) ? 0 : n
}

// "3 min ago" style relative time from unix seconds.
function relativeTime(sec, nowSec) {
  if (!sec) return ""
  var d = Math.max(0, (nowSec || Math.floor(Date.now() / 1000)) - sec)
  if (d < 60) return "now"
  if (d < 3600) return Math.floor(d / 60) + " min ago"
  if (d < 86400) return Math.floor(d / 3600) + " h ago"
  return Math.floor(d / 86400) + " d ago"
}

// Replaces $HOME with ~ for display.
function shortPath(path, home) {
  var p = String(path || "")
  if (home && (p === home || p.indexOf(home + "/") === 0)) return "~" + p.slice(home.length)
  return p
}

// Subsequence match with a prefix / word-boundary bonus. Returns -1 for no
// match, otherwise a score where higher is better.
function fuzzyScore(query, text) {
  var q = String(query || "").toLowerCase()
  var s = String(text || "").toLowerCase()
  if (!q) return 0
  if (s.indexOf(q) === 0) return 1000 - s.length
  var contig = s.indexOf(q)
  if (contig !== -1) return 500 - contig - s.length
  var qi = 0
  var score = 0
  var prevMatch = -2
  for (var si = 0; si < s.length && qi < q.length; si++) {
    if (s[si] === q[qi]) {
      score += (si === prevMatch + 1) ? 6 : 1
      if (si === 0 || s[si - 1] === "-" || s[si - 1] === "_" || s[si - 1] === " ") score += 4
      prevMatch = si
      qi++
    }
  }
  if (qi < q.length) return -1
  return score - s.length * 0.1
}

// Menu ordering: fuzzy match quality when filtering, otherwise most recent
// activity first; name breaks ties. Returns a new array.
function sortSessions(sessions, query) {
  var scored = []
  for (var i = 0; i < sessions.length; i++) {
    var s = sessions[i]
    var fz = query ? Math.max(fuzzyScore(query, s.name), fuzzyScore(query, s.path) - 200) : 0
    if (query && fz < 0) continue
    scored.push({ s: s, fz: fz })
  }
  scored.sort(function (a, b) {
    if (query && a.fz !== b.fz) return b.fz - a.fz
    if (a.s.activity !== b.s.activity) return b.s.activity - a.s.activity
    return a.s.name.localeCompare(b.s.name)
  })
  return scored.map(function (x) { return x.s })
}

// One-line detail under the session name.
function detailLine(s, home, nowSec) {
  var parts = []
  parts.push(s.windows + (s.windows === 1 ? " window" : " windows"))
  var rt = relativeTime(s.activity, nowSec)
  if (rt) parts.push(rt)
  if (s.path) parts.push(shortPath(s.path, home))
  return parts.join(" · ")
}

// node test entry point; ignored by QML's JS import.
if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    parseSessions: parseSessions,
    relativeTime: relativeTime,
    shortPath: shortPath,
    fuzzyScore: fuzzyScore,
    sortSessions: sortSessions,
    detailLine: detailLine
  }
}
