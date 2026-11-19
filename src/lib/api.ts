import Constants from 'expo-constants';
import { tr } from './i18n';
import { getState, newId } from './store';

/**
 * PetTrack backend (deploy `server/` on Coolify). Set EXPO_PUBLIC_API_URL, e.g. https://pettrack.bagce.dev.
 * Without it the app runs fully offline and server features show a demo.
 */
export const API_URL: string =
  (process.env.EXPO_PUBLIC_API_URL as string | undefined) ||
  ((Constants.expoConfig?.extra as { apiUrl?: string } | undefined)?.apiUrl ?? '');

export const hasBackend = () => API_URL.length > 0;

async function deviceToken(): Promise<string> {
  const { settings, setSettings } = getState();
  if (settings.deviceToken) return settings.deviceToken;
  const res = await fetch(`${API_URL}/api/devices`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ hint: newId() }) });
  if (!res.ok) throw new Error(`Server error ${res.status}`);
  const { token } = (await res.json()) as { token: string };
  setSettings({ deviceToken: token });
  return token;
}

export class ApiError extends Error {
  constructor(public status: number, message: string) { super(message); }
}

/** Turns a FastAPI error body ({"detail": ...}) into a readable sentence. */
function errorMessage(status: number, text: string): string {
  try {
    const detail = (JSON.parse(text) as { detail?: unknown }).detail;
    if (typeof detail === 'string') return tr(detail);
    if (Array.isArray(detail) && detail[0]?.msg) return String(detail[0].msg);
  } catch { /* not JSON */ }
  return text && text.length < 160 && !text.trimStart().startsWith('<') ? text : `Server error ${status}`;
}

export async function api<T>(path: string, init: { method?: string; body?: unknown } = {}): Promise<T> {
  if (!hasBackend()) throw new Error('No server configured');
  const send = async (token: string) => fetch(`${API_URL}${path}`, {
    method: init.method ?? 'GET',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: init.body === undefined ? undefined : JSON.stringify(init.body),
  });
  let res: Response;
  try {
    res = await send(await deviceToken());
    // The server no longer knows this device (e.g. its database was reset): register again and retry once.
    if (res.status === 401) {
      getState().setSettings({ deviceToken: undefined });
      res = await send(await deviceToken());
    }
  } catch (e) {
    throw new Error(tr('Could not reach the PetTrack server. Check your connection and try again.'), { cause: e });
  }
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new ApiError(res.status, errorMessage(res.status, text));
  }
  return (await res.json()) as T;
}

export const publicProfileUrl = (slug: string) => `${API_URL || 'https://pettrack.bagce.dev'}/p/${slug}`;
