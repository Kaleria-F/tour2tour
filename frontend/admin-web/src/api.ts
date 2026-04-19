import type {
  AdminImportJob,
  AdminPlace,
  AdminPlaceCandidate,
  TokenResponse,
  UserMe,
} from './types';

const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL?.toString().trim() || 'http://127.0.0.1:8888';

const TOKEN_KEY = 'admin_access_token';

export function getStoredToken(): string | null {
  return window.localStorage.getItem(TOKEN_KEY);
}

export function setStoredToken(token: string | null) {
  if (!token) {
    window.localStorage.removeItem(TOKEN_KEY);
    return;
  }
  window.localStorage.setItem(TOKEN_KEY, token);
}

async function request<T>(
  path: string,
  options: RequestInit = {},
  token?: string | null,
): Promise<T> {
  const headers = new Headers(options.headers);
  if (!headers.has('Content-Type') && !(options.body instanceof FormData)) {
    headers.set('Content-Type', 'application/json');
  }
  if (token) {
    headers.set('Authorization', `Bearer ${token}`);
  }
  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...options,
    headers,
  });
  if (!response.ok) {
    let detail = `${response.status} ${response.statusText}`;
    try {
      const payload = await response.json();
      if (payload?.detail) {
        detail = Array.isArray(payload.detail)
          ? payload.detail.map((item: any) => item.msg || String(item)).join(', ')
          : String(payload.detail);
      }
    } catch {
      // ignore
    }
    throw new Error(detail);
  }
  if (response.status === 204) {
    return undefined as T;
  }
  return response.json() as Promise<T>;
}

export async function login(email: string, password: string): Promise<TokenResponse> {
  return request<TokenResponse>('/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email, password }),
  });
}

export async function verify2fa(challengeId: string, code: string): Promise<TokenResponse> {
  return request<TokenResponse>('/auth/2fa/verify', {
    method: 'POST',
    body: JSON.stringify({ challenge_id: challengeId, code }),
  });
}

export async function getMe(token: string): Promise<UserMe> {
  return request<UserMe>('/users/me', { method: 'GET' }, token);
}

export async function listPlaces(token: string): Promise<AdminPlace[]> {
  const payload = await request<{ items: AdminPlace[] }>('/places', { method: 'GET' }, token);
  return payload.items;
}

export async function createPlace(token: string, data: Record<string, unknown>): Promise<AdminPlace> {
  return request<AdminPlace>('/places', { method: 'POST', body: JSON.stringify(data) }, token);
}

export async function updatePlace(
  token: string,
  id: string,
  data: Record<string, unknown>,
): Promise<AdminPlace> {
  return request<AdminPlace>(`/places/${id}`, { method: 'PATCH', body: JSON.stringify(data) }, token);
}

export async function deletePlace(token: string, id: string): Promise<void> {
  return request<void>(`/places/${id}`, { method: 'DELETE' }, token);
}

export async function listCandidates(token: string): Promise<AdminPlaceCandidate[]> {
  return request<AdminPlaceCandidate[]>('/places/candidates/list?status=pending_review', { method: 'GET' }, token);
}

export async function decideCandidate(
  token: string,
  id: string,
  status: string,
  notes?: string,
): Promise<AdminPlaceCandidate> {
  return request<AdminPlaceCandidate>(
    `/places/candidates/${id}/decision`,
    { method: 'POST', body: JSON.stringify({ status, notes }) },
    token,
  );
}

export async function deleteCandidate(token: string, id: string): Promise<void> {
  return request<void>(`/places/candidates/${id}`, { method: 'DELETE' }, token);
}

export async function listImportJobs(token: string): Promise<AdminImportJob[]> {
  return request<AdminImportJob[]>('/places/imports/list', { method: 'GET' }, token);
}

export async function uploadImportCsv(
  token: string,
  file: File,
  source: string,
  kind: string,
  createdBy?: string,
): Promise<AdminImportJob> {
  const form = new FormData();
  form.append('source', source);
  form.append('kind', kind);
  if (createdBy) {
    form.append('created_by', createdBy);
  }
  form.append('file', file);
  return request<AdminImportJob>(
    '/places/imports/upload',
    { method: 'POST', body: form },
    token,
  );
}

export async function uploadPlaceImage(token: string, file: File): Promise<{ url: string }> {
  const form = new FormData();
  form.append('file', file);
  return request<{ url: string }>('/places/upload-image', { method: 'POST', body: form }, token);
}
