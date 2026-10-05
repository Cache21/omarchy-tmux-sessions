// Run: node tests/model.test.js
const M = require("../Model.js")

let failed = 0
function eq(actual, expected, msg) {
  const a = JSON.stringify(actual)
  const e = JSON.stringify(expected)
  if (a === e) {
    console.log("  ok   " + msg)
  } else {
    failed++
    console.log("  FAIL " + msg + "\n       expected " + e + "\n       got      " + a)
  }
}

console.log("parseSessions")
const raw = "work\t2\t1\t100\t500\t/home/u/notes\napi\t1\t0\t200\t900\t/home/u/Projects/api\n\nbroken line\n"
const ss = M.parseSessions(raw)
eq(ss.length, 2, "skips blank and malformed lines")
eq(ss[0], { name: "work", windows: 2, clients: 1, created: 100, activity: 500, path: "/home/u/notes" }, "parses fields")
eq(M.parseSessions(""), [], "empty output -> no sessions")
eq(M.parseSessions(null), [], "null -> no sessions")
eq(M.parseSessions("x\tnope\t\t\t\t").length, 1, "non-numeric fields tolerated")
eq(M.parseSessions("x\tnope\t\t\t\t")[0].windows, 0, "non-numeric -> 0")

console.log("relativeTime")
eq(M.relativeTime(1000, 1030), "now", "< 1 min")
eq(M.relativeTime(1000, 1000 + 180), "3 min ago", "minutes")
eq(M.relativeTime(1000, 1000 + 7200), "2 h ago", "hours")
eq(M.relativeTime(1000, 1000 + 86400 * 3), "3 d ago", "days")
eq(M.relativeTime(0, 1000), "", "no timestamp")

console.log("shortPath")
eq(M.shortPath("/home/u/x", "/home/u"), "~/x", "home prefix")
eq(M.shortPath("/home/u", "/home/u"), "~", "home itself")
eq(M.shortPath("/home/user2/x", "/home/u"), "/home/user2/x", "not a false prefix")

console.log("sortSessions")
eq(M.sortSessions(ss, "").map(s => s.name), ["api", "work"], "most recent activity first")
eq(M.sortSessions(ss, "wo").map(s => s.name), ["work"], "filters by name")
eq(M.sortSessions(ss, "Projects").map(s => s.name), ["api"], "filters by path too")
eq(M.sortSessions(ss, "zzz"), [], "no match")

console.log("detailLine")
eq(M.detailLine(ss[1], "/home/u", 960), "1 window · 1 min ago · ~/Projects/api", "singular + path")
eq(M.detailLine(ss[0], "/home/u", 520), "2 windows · now · ~/notes", "plural")

console.log(failed ? "\n" + failed + " failed" : "\nall passed")
process.exit(failed ? 1 : 0)
