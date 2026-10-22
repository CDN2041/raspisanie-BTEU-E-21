// Офлайн-режим.
// Свои файлы: сначала сеть (чтобы приходили обновления), но если сеть думает дольше 3 секунд, сразу отдаём из кэша.
// Шрифты Google: сразу из кэша, а в фоне обновляем (файлы шрифтов не меняются).
var CACHE = "pary-e21-v43";
var CORE = ["./", "index.html", "schedule.json", "manifest.webmanifest", "icon.png"];
var WAIT = 3000;

self.addEventListener("install", function (e) {
  e.waitUntil(caches.open(CACHE).then(function (c) { return c.addAll(CORE); }).then(function () { return self.skipWaiting(); }));
});
self.addEventListener("activate", function (e) {
  e.waitUntil(caches.keys().then(function (ks) {
    return Promise.all(ks.filter(function (k) { return k.indexOf("pary-e21-") === 0 && k !== CACHE; }).map(function (k) { return caches.delete(k); }));
  }).then(function () { return self.clients.claim(); }));
});

function put(req, r) {
  if (r && (r.ok || r.type === "opaque")) { var copy = r.clone(); caches.open(CACHE).then(function (c) { c.put(req, copy); }); }
  return r;
}
function fromCache(req) {
  return caches.match(req, { ignoreSearch: true }).then(function (m) { return m || (req.mode === "navigate" ? caches.match("./") : undefined); });
}

self.addEventListener("fetch", function (e) {
  var req = e.request;
  if (req.method !== "GET") return;
  var url = new URL(req.url);

  if (url.hostname === "fonts.googleapis.com" || url.hostname === "fonts.gstatic.com") {
    var net = fetch(req).then(function (r) { return put(req, r); });
    e.waitUntil(net.catch(function () {}));
    e.respondWith(caches.match(req).then(function (m) { return m || net; }));
    return;
  }
  // Чужие адреса (например, GitHub API из админки) не трогаем
  if (url.origin !== self.location.origin) return;

  var net2 = fetch(req).then(function (r) { return put(req, r); });
  e.waitUntil(net2.catch(function () {}));
  e.respondWith(new Promise(function (resolve, reject) {
    var done = false;
    function finish(r) { if (!done && r) { done = true; resolve(r); } }
    var timer = setTimeout(function () { fromCache(req).then(finish); }, WAIT);
    net2.then(function (r) { clearTimeout(timer); finish(r); }).catch(function () {
      clearTimeout(timer);
      fromCache(req).then(function (m) { if (m) finish(m); else if (!done) reject(new Error("offline")); });
    });
  }));
});
