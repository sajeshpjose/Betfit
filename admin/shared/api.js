function isTokenExpired(token) {
  try {
    const payload = JSON.parse(atob(token.split('.')[1]))
    return payload.exp * 1000 < Date.now()
  } catch { return true }
}

function getHeaders(extra = {}) {
  return {
    'apikey': SUPABASE_KEY,
    'Authorization': `Bearer ${getToken()}`,
    'Content-Type': 'application/json',
    ...extra
  }
}

async function ensureFreshToken() {
  const token = getToken()
  if (!token || !isTokenExpired(token)) return
  const refreshToken = localStorage.getItem('bf_refresh_token')
  if (!refreshToken) {
    window.location.href = '/login.html?reason=expired'
    return
  }
  const refreshed = await refreshSession()
  if (!refreshed) window.location.href = '/login.html?reason=expired'
}

async function handleResponse(res, retryFn) {
  if (res.status === 204) return null

  if (res.status === 401) {
    // Try refresh once, then fall back to re-login
    const refreshToken = localStorage.getItem('bf_refresh_token')
    if (refreshToken && retryFn) {
      const refreshed = await refreshSession()
      if (refreshed) return retryFn()
    }
    // No refresh token or refresh failed — redirect to login
    localStorage.removeItem('bf_access_token')
    localStorage.removeItem('bf_refresh_token')
    localStorage.removeItem('bf_user_email')
    window.location.href = '/login.html?reason=expired'
    return null
  }

  const text = await res.text()
  let data
  try { data = JSON.parse(text) } catch { data = text }
  if (!res.ok) {
    const msg = (typeof data === 'object' && (data.message || data.error || data.hint)) || `HTTP ${res.status}`
    throw new Error(msg)
  }
  return data
}

async function get(path) {
  await ensureFreshToken()
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, { headers: getHeaders() })
  return handleResponse(res, () => get(path))
}

async function post(path, body, prefer = 'return=representation') {
  await ensureFreshToken()
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    method: 'POST',
    headers: getHeaders({ 'Prefer': prefer }),
    body: JSON.stringify(body)
  })
  return handleResponse(res, () => post(path, body, prefer))
}

async function patch(path, body) {
  await ensureFreshToken()
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    method: 'PATCH',
    headers: getHeaders({ 'Prefer': 'return=representation' }),
    body: JSON.stringify(body)
  })
  return handleResponse(res, () => patch(path, body))
}

async function del(path) {
  await ensureFreshToken()
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, { method: 'DELETE', headers: getHeaders() })
  return handleResponse(res, () => del(path))
}

async function getCount(path) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    headers: {
      ...getHeaders(),
      'Prefer': 'count=exact',
      'Range': '0-0'
    }
  })
  const range = res.headers.get('Content-Range') || '0-0/0'
  return parseInt(range.split('/')[1]) || 0
}
