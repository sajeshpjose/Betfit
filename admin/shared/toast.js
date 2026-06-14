function showToast(message, type = 'success') {
  let container = document.getElementById('toast-container')
  if (!container) {
    container = document.createElement('div')
    container.id = 'toast-container'
    Object.assign(container.style, {
      position: 'fixed', bottom: '24px', right: '24px',
      zIndex: '9999', display: 'flex', flexDirection: 'column', gap: '8px',
      alignItems: 'flex-end', pointerEvents: 'none'
    })
    document.body.appendChild(container)
  }

  const toast = document.createElement('div')
  Object.assign(toast.style, {
    padding: '12px 20px',
    borderRadius: '100px',
    fontSize: '13px',
    fontWeight: '600',
    fontFamily: 'Inter, sans-serif',
    background: type === 'success' ? '#D5FF45' : '#FF453A',
    color: type === 'success' ? '#000' : '#fff',
    boxShadow: '0 4px 20px rgba(0,0,0,0.5)',
    transform: 'translateX(120px)',
    opacity: '0',
    transition: 'transform 0.3s cubic-bezier(0.34,1.56,0.64,1), opacity 0.3s ease',
    maxWidth: '320px',
    pointerEvents: 'auto'
  })
  toast.textContent = message
  container.appendChild(toast)

  requestAnimationFrame(() => requestAnimationFrame(() => {
    toast.style.transform = 'translateX(0)'
    toast.style.opacity = '1'
  }))

  setTimeout(() => {
    toast.style.transform = 'translateX(120px)'
    toast.style.opacity = '0'
    setTimeout(() => toast.remove(), 300)
  }, 3000)
}
