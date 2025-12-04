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
 * Theme Toggle Hook
 * Handles theme switching between light and dark modes
 */
export const ThemeToggle = {
  mounted() {
    this.el.addEventListener('click', () => {
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
