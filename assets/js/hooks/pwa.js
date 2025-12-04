// PWA Hooks for LiveView

// Register service worker
export function registerServiceWorker() {
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('/sw.js')
        .then((registration) => {
          console.log('[PWA] Service Worker registered:', registration.scope);
        })
        .catch((error) => {
          console.error('[PWA] Service Worker registration failed:', error);
        });
    });
  }
}

// Install Prompt Hook - Shows install banner when PWA can be installed
export const InstallPrompt = {
  mounted() {
    this.deferredPrompt = null;

    // Listen for the beforeinstallprompt event
    window.addEventListener('beforeinstallprompt', (e) => {
      e.preventDefault();
      this.deferredPrompt = e;
      this.showBanner();
    });

    // Check if already installed
    window.addEventListener('appinstalled', () => {
      this.deferredPrompt = null;
      this.hideBanner();
      console.log('[PWA] App installed');
    });

    // Check if running as standalone (already installed)
    if (window.matchMedia('(display-mode: standalone)').matches) {
      this.hideBanner();
    }
  },

  showBanner() {
    this.el.classList.remove('hidden');
    this.el.classList.add('flex');
  },

  hideBanner() {
    this.el.classList.add('hidden');
    this.el.classList.remove('flex');
  },

  handleEvent(event, callback) {
    if (event === 'install') {
      this.install();
    } else if (event === 'dismiss') {
      this.hideBanner();
    }
  },

  install() {
    if (this.deferredPrompt) {
      this.deferredPrompt.prompt();
      this.deferredPrompt.userChoice.then((choiceResult) => {
        if (choiceResult.outcome === 'accepted') {
          console.log('[PWA] User accepted the install prompt');
        }
        this.deferredPrompt = null;
      });
    }
  }
};

// Offline Indicator Hook - Shows indicator when offline
export const OfflineIndicator = {
  mounted() {
    this.updateStatus();

    window.addEventListener('online', () => this.updateStatus());
    window.addEventListener('offline', () => this.updateStatus());
  },

  updateStatus() {
    if (navigator.onLine) {
      this.el.classList.add('hidden');
      this.pushEvent('online', {});
    } else {
      this.el.classList.remove('hidden');
      this.pushEvent('offline', {});
    }
  }
};

// Update Available Hook - Shows notification when new version is available
export const UpdateAvailable = {
  mounted() {
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.ready.then((registration) => {
        registration.addEventListener('updatefound', () => {
          const newWorker = registration.installing;
          newWorker.addEventListener('statechange', () => {
            if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
              // New version available
              this.el.classList.remove('hidden');
            }
          });
        });
      });
    }
  },

  handleEvent(event, callback) {
    if (event === 'update') {
      window.location.reload();
    } else if (event === 'dismiss') {
      this.el.classList.add('hidden');
    }
  }
};
