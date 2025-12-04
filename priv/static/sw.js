// Hellen AI Service Worker
const CACHE_NAME = 'hellen-ai-v1';
const OFFLINE_URL = '/offline.html';

// Static assets to cache on install
const STATIC_ASSETS = [
  '/',
  '/dashboard',
  '/offline.html',
  '/manifest.json'
];

// Install event - cache static assets
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('[SW] Caching static assets');
        return cache.addAll(STATIC_ASSETS);
      })
      .then(() => self.skipWaiting())
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames
          .filter((name) => name !== CACHE_NAME)
          .map((name) => {
            console.log('[SW] Deleting old cache:', name);
            return caches.delete(name);
          })
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch event - network first with cache fallback
self.addEventListener('fetch', (event) => {
  // Skip non-GET requests
  if (event.request.method !== 'GET') {
    return;
  }

  // Skip LiveView websocket and API requests
  const url = new URL(event.request.url);
  if (url.pathname.startsWith('/live') ||
      url.pathname.startsWith('/api') ||
      url.pathname.startsWith('/phoenix')) {
    return;
  }

  event.respondWith(
    fetch(event.request)
      .then((response) => {
        // Clone the response for caching
        if (response.status === 200) {
          const responseClone = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, responseClone);
          });
        }
        return response;
      })
      .catch(() => {
        // Try to serve from cache
        return caches.match(event.request).then((cachedResponse) => {
          if (cachedResponse) {
            return cachedResponse;
          }
          // If it's a navigation request, show offline page
          if (event.request.mode === 'navigate') {
            return caches.match(OFFLINE_URL);
          }
          // Return a placeholder for images
          if (event.request.destination === 'image') {
            return new Response(
              '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><rect fill="#e2e8f0" width="100" height="100"/></svg>',
              { headers: { 'Content-Type': 'image/svg+xml' } }
            );
          }
          return new Response('Offline', { status: 503 });
        });
      })
  );
});

// Background sync for offline form submissions (future use)
self.addEventListener('sync', (event) => {
  if (event.tag === 'sync-lessons') {
    console.log('[SW] Syncing lessons...');
    // Future: sync offline lesson data
  }
});

// Push notifications (future use)
self.addEventListener('push', (event) => {
  if (event.data) {
    const data = event.data.json();
    const options = {
      body: data.body,
      icon: '/images/icons/icon-192x192.png',
      badge: '/images/icons/icon-72x72.png',
      vibrate: [100, 50, 100],
      data: {
        url: data.url || '/dashboard'
      }
    };
    event.waitUntil(
      self.registration.showNotification(data.title || 'Hellen AI', options)
    );
  }
});

// Notification click handler
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.openWindow(event.notification.data.url)
  );
});
