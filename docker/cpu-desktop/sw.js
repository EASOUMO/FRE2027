// Replaces the service worker that the GPU setup's web page (Selkies) leaves
// in the browser for this address. Browsers keep reusing that page for
// weeks (it is served without cache headers), so without this file, a
// browser that once opened the GPU setup keeps showing it instead of noVNC.
// Browsers re-download sw.js on every visit, bypassing their cache; this
// version takes over the open tabs, reloads them from the server and then
// unregisters itself.
self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names.map((name) => caches.delete(name)));
    await self.clients.claim();
    const tabs = await self.clients.matchAll({ type: 'window' });
    tabs.forEach((tab) => tab.navigate(tab.url));
  })());
});

// Page loads go to the server, never to the stale cached copy.
self.addEventListener('fetch', (event) => {
  if (event.request.mode !== 'navigate') return;
  event.respondWith((async () => {
    const response = await fetch(event.request.url, { cache: 'reload' });
    self.registration.unregister();
    return response;
  })());
});
