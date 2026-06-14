async function renderNav(activePage) {
  let userEmail = localStorage.getItem('bf_user_email') || ''
  if (!userEmail) {
    try {
      const user = await getCurrentUser()
      if (user?.email) {
        userEmail = user.email
        localStorage.setItem('bf_user_email', userEmail)
      }
    } catch {}
  }

  const links = [
    { id: 'dashboard',  label: 'Dashboard',  icon: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/></svg>`, href: '/dashboard.html' },
    { id: 'challenges', label: 'Challenges', icon: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M8 21h8M12 17v4M5 3H3v8l9 4 9-4V3h-2M5 3l7 3 7-3"/></svg>`, href: '/challenges.html' },
    { id: 'companies',  label: 'Companies',  icon: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9,22 9,12 15,12 15,22"/></svg>`, href: '/companies.html' },
    { id: 'teams',      label: 'Teams',      icon: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>`, href: '/teams.html' },
    { id: 'members',    label: 'Members',    icon: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>`, href: '/members.html' },
    { id: 'step_logs',  label: 'Step Logs',  icon: `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="22,12 18,12 15,21 9,3 6,12 2,12"/></svg>`, href: '/step_logs.html' },
  ]

  const container = document.getElementById('nav-container')
  if (container) {
    container.innerHTML = `
      <aside class="sidebar">
        <div class="sidebar-logo">
          <span class="logo-mark">betfit.</span>
          <span class="logo-sub">admin</span>
        </div>
        <nav class="sidebar-nav">
          ${links.map(l => `
            <a href="${l.href}" class="nav-link ${activePage === l.id ? 'active' : ''}">
              <span class="nav-icon">${l.icon}</span>
              <span>${l.label}</span>
            </a>
          `).join('')}
        </nav>
        <div class="sidebar-footer">
          <div class="sidebar-user">
            <div class="user-avatar">${userEmail ? userEmail[0].toUpperCase() : 'A'}</div>
            <div class="user-info">
              <div class="user-email-text">${userEmail}</div>
              <button class="sign-out-btn" onclick="signOut()">Sign out</button>
            </div>
          </div>
        </div>
      </aside>
    `
  }
}
