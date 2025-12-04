// Firebase Authentication Hook for Phoenix LiveView
// Uses Firebase SDK loaded via CDN in root.html.heex

const firebaseConfig = {
  apiKey: "AIzaSyD-xkOOfGgaEZ_fyzCvUhsxuIyLJJpaXWc",
  authDomain: "hellen-ai.firebaseapp.com",
  projectId: "hellen-ai",
  storageBucket: "hellen-ai.firebasestorage.app",
  messagingSenderId: "366151843508",
  appId: "1:366151843508:web:8e1f3b3191e9392e31e1e1",
  measurementId: "G-42LER22MWF"
};

let firebaseApp = null;
let firebaseAuth = null;

// Initialize Firebase (called once)
function initFirebase() {
  if (firebaseApp) return { app: firebaseApp, auth: firebaseAuth };

  // Check if Firebase SDK is loaded
  if (typeof firebase === 'undefined') {
    console.error('[Firebase] SDK not loaded. Make sure Firebase scripts are included in the page.');
    return null;
  }

  // Initialize app if not already initialized
  if (!firebase.apps.length) {
    firebaseApp = firebase.initializeApp(firebaseConfig);
  } else {
    firebaseApp = firebase.app();
  }

  firebaseAuth = firebase.auth();
  console.log('[Firebase] Initialized successfully');

  return { app: firebaseApp, auth: firebaseAuth };
}

// Google Sign In Hook
export const GoogleSignIn = {
  mounted() {
    this.button = this.el;
    this.originalText = this.button.innerHTML;

    // Initialize Firebase
    const firebase = initFirebase();
    if (!firebase) {
      this.showError('Firebase SDK nao carregado');
      return;
    }

    this.auth = firebase.auth;
    this.provider = new window.firebase.auth.GoogleAuthProvider();

    // Add scopes for user info
    this.provider.addScope('email');
    this.provider.addScope('profile');

    // Handle click
    this.button.addEventListener('click', (e) => this.handleSignIn(e));
  },

  async handleSignIn(e) {
    e.preventDefault();

    if (!this.auth) {
      this.showError('Firebase nao inicializado');
      return;
    }

    this.setLoading(true);

    try {
      // Sign in with popup
      const result = await this.auth.signInWithPopup(this.provider);
      const user = result.user;

      console.log('[Firebase] Google sign-in successful:', user.email);

      // Get ID token
      const idToken = await user.getIdToken();

      // Send token to backend
      await this.sendTokenToBackend(idToken);

    } catch (error) {
      console.error('[Firebase] Sign-in error:', error);
      this.setLoading(false);

      // Handle specific errors
      if (error.code === 'auth/popup-closed-by-user') {
        // User closed popup, no need to show error
        return;
      } else if (error.code === 'auth/network-request-failed') {
        this.showError('Erro de conexao. Verifique sua internet.');
      } else if (error.code === 'auth/popup-blocked') {
        this.showError('Popup bloqueado. Permita popups para este site.');
      } else {
        this.showError('Erro ao fazer login com Google');
      }
    }
  },

  async sendTokenToBackend(idToken) {
    try {
      // Get CSRF token
      const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content");

      // Send to backend session endpoint
      const response = await fetch('/session/firebase', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify({ id_token: idToken })
      });

      const data = await response.json();

      if (response.ok && data.redirect) {
        // Redirect to dashboard
        window.location.href = data.redirect;
      } else {
        this.setLoading(false);
        this.showError(data.error || 'Erro ao autenticar');
      }

    } catch (error) {
      console.error('[Firebase] Backend auth error:', error);
      this.setLoading(false);
      this.showError('Erro ao comunicar com o servidor');
    }
  },

  setLoading(loading) {
    if (loading) {
      this.button.disabled = true;
      this.button.innerHTML = `
        <svg class="animate-spin h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <span>Conectando...</span>
      `;
    } else {
      this.button.disabled = false;
      this.button.innerHTML = this.originalText;
    }
  },

  showError(message) {
    // Push event to LiveView to show flash message
    this.pushEvent('firebase_error', { message });
  }
};

export { initFirebase };
