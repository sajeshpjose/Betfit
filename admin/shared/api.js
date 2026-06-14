function getHeaders(extra = {}) {
  return {
    'apikey': SUPABASE_KEY,
    'Authorization': `Bearer ${getToken()}`,
    'Content-Type': 'application/json',
    ...extra
  }
}

async function handleResponse(res) {
  if (res.status === 204) return null
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
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    headers: getHeaders()
  })
  return handleResponse(res)
}

async function post(path, body, prefer = 'return=representation') {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    method: 'POST',
    headers: getHeaders({ 'Prefer': prefer }),
    body: JSON.stringify(body)
  })
  return handleResponse(res)
}

async function patch(path, body) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    method: 'PATCH',
    headers: getHeaders({ 'Prefer': 'return=representation' }),
    body: JSON.stringify(body)
  })
  return handleResponse(res)
}

async function del(path) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    method: 'DELETE',
    headers: getHeaders()
  })
  return handleResponse(res)
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
