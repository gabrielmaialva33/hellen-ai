const UploadDragDrop = {
  mounted() {
    const container = this.el.closest('.upload-container');
    if (!container) return;
    
    const overlay = this.el.querySelector('.upload-drag-overlay');
    let dragCounter = 0;

    // Prevent default drag behavior on entire page
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
      document.body.addEventListener(eventName, preventDefaults, false);
    });

    function preventDefaults(e) {
      e.preventDefault();
    }

    // Highlight drop zone when item is dragged over
    this.el.addEventListener('dragenter', (e) => {
      dragCounter++;
      if (dragCounter === 1) {
        container.classList.add('drag-over');
      }
    });

    this.el.addEventListener('dragleave', (e) => {
      dragCounter--;
      if (dragCounter === 0) {
        container.classList.remove('drag-over');
      }
    });

    this.el.addEventListener('dragover', (e) => {
      e.preventDefault();
    });

    this.el.addEventListener('drop', (e) => {
      dragCounter = 0;
      container.classList.remove('drag-over');
      
      // Add a subtle success animation
      const card = this.el.querySelector('.upload-card');
      if (card) {
        card.style.transform = 'scale(0.95)';
        setTimeout(() => {
          card.style.transform = '';
        }, 200);
      }
    });
  },
  
  destroyed() {
    // Cleanup
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
      document.body.removeEventListener(eventName, this.preventDefaults, false);
    });
  }
};

export default UploadDragDrop;
