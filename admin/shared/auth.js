function getToken() {
  return localStorage.getItem('bf_access_token')
}

function checkAuth() {
  // Extract token from URL hash on magic link redirect
  const hash = new URLSearchParams(window.location.hash.slice(1))
  const token = hash.get('access_token')
  if (token) {
    localStorage.setItem('bf_access_token', token)
    history.replaceState(null, '', window.location.pathname)
  }

  if (!localStorage.getItem('bf_access_token')) {
    window.location.href = '/login.html'
  }
}

async function checkAdminAccess() {
  checkAuth()
  try {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/admins?select=email&limit=1`, {
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': `Bearer ${getToken()}`
      }
    })
    const data = await res.json()
    // If no row returned, this user is not an admin
    if (!res.ok || !Array.isArray(data) || data.length === 0) {
      localStorage.removeItem('bf_access_token')
      localStorage.removeItem('bf_user_email')
      window.location.href = '/login.html?error=unauthorized'
    }
  } catch {
    window.location.href = '/login.html?error=unauthorized'
  }
}

function signOut() {
  localStorage.removeItem('bf_access_token')
  localStorage.removeItem('bf_refresh_token')
  localStorage.removeItem('bf_user_email')
  window.location.href = '/login.html'
}

async function refreshSession() {
  const refreshToken = localStorage.getItem('bf_refresh_token')
  if (!refreshToken) { signOut(); return false }

  try {
    const res = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=refresh_token`, {
      method: 'POST',
      headers: { 'apikey': SUPABASE_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: refreshToken })
    })

    if (!res.ok) { signOut(); return false }

    const data = await res.json()
    localStorage.setItem('bf_access_token', data.access_token)
    if (data.refresh_token) localStorage.setItem('bf_refresh_token', data.refresh_token)
    return true
  } catch {
    signOut()
    return false
  }
}

async function getCurrentUser() {
  const token = getToken()
  if (!token) return null
  try {
    const res = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': `Bearer ${token}`
      }
    })
    if (!res.ok) return null
    return await res.json()
  } catch {
    return null
  }
}
