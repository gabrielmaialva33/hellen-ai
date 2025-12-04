/**
 * Scroll Animation Hook
 * Animates elements as they enter the viewport using Intersection Observer
 */
export const ScrollAnimation = {
  mounted() {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add('animate-fade-in-up');
            entry.target.classList.remove('opacity-0', 'translate-y-8');
          }
        });
      },
      {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
      }
    );

    // Find all elements with data-animate attribute
    this.el.querySelectorAll('[data-animate]').forEach((el) => {
      el.classList.add('opacity-0', 'translate-y-8', 'transition-all', 'duration-700');
      observer.observe(el);
    });

    this.observer = observer;
  },

  destroyed() {
    if (this.observer) {
      this.observer.disconnect();
    }
  }
};

/**
 * Theme Hook
 * Only initializes theme from localStorage - NO click handler
 * This hook should be placed on the page wrapper
 */
export const ThemeHook = {
  mounted() {
    // Initialize theme from localStorage or system preference
    const savedTheme = localStorage.getItem('theme');
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;

    if (savedTheme === 'dark' || (!savedTheme && prefersDark)) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }
};

/**
 * Theme Toggle Hook
 * Handles click to toggle theme - use this on the toggle button
 */
export const ThemeToggle = {
  mounted() {
    this.el.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();

      const html = document.documentElement;
      const isDark = html.classList.contains('dark');

      if (isDark) {
        html.classList.remove('dark');
        localStorage.setItem('theme', 'light');
      } else {
        html.classList.add('dark');
        localStorage.setItem('theme', 'dark');
      }
    });
  }
};
