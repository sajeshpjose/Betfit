function openModal(id) {
  const modal = document.getElementById(id)
  if (!modal) return
  modal.style.display = 'flex'
  requestAnimationFrame(() => requestAnimationFrame(() => modal.classList.add('modal-open')))
}

function closeModal(id) {
  const modal = document.getElementById(id)
  if (!modal) return
  modal.classList.remove('modal-open')
  setTimeout(() => { modal.style.display = 'none' }, 220)
}

// Close on backdrop click
document.addEventListener('click', e => {
  if (e.target.classList.contains('modal-overlay')) {
    e.target.classList.remove('modal-open')
    setTimeout(() => { e.target.style.display = 'none' }, 220)
  }
})

// Close on ESC
document.addEventListener('keydown', e => {
  if (e.key !== 'Escape') return
  document.querySelectorAll('.modal-overlay.modal-open').forEach(m => {
    m.classList.remove('modal-open')
    setTimeout(() => { m.style.display = 'none' }, 220)
  })
})
