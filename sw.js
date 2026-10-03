const CACHE='fluxo-shell-v3';
const FILES=['./','./index.html','./styles.css','./app.mjs','./api.mjs','./domain.mjs','./config.js','./manifest.webmanifest','./icon.svg','./icons/icon-192.png','./icons/icon-512.png','./icons/maskable-512.png'];
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(c=>c.addAll(FILES))));
self.addEventListener('activate',event=>event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith('fluxo-shell-')&&k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim())));
self.addEventListener('message',event=>{if(event.data==='SKIP_WAITING')self.skipWaiting();});
self.addEventListener('fetch',event=>{
  const u=new URL(event.request.url);
  // Nunca guardar respostas da base de dados, tokens ou pedidos de escrita.
  if(event.request.method!=='GET'||u.origin!==self.location.origin||!u.pathname.startsWith(new URL(self.registration.scope).pathname))return;
  if(!FILES.some(f=>new URL(f,self.registration.scope).pathname===u.pathname))return;
  event.respondWith(fetch(event.request).then(r=>r.ok?(caches.open(CACHE).then(c=>{c.put(event.request,r.clone());return r;})):r).catch(()=>caches.match(event.request).then(r=>r||Response.error())));
});
