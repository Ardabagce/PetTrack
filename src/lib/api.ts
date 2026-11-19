import Constants from 'expo-constants';
import { getState, newId } from './store';

/**
 * PetTrack backend (deploy `server/` on Coolify). Set EXPO_PUBLIC_API_URL, e.g. https://api.pettrack.app.
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

export async function api<T>(path: string, init: { method?: string; body?: unknown } = {}): Promise<T> {
  if (!hasBackend()) throw new Error('No server configured');
  const token = await deviceToken();
  const res = await fetch(`${API_URL}${path}`, {
    method: init.method ?? 'GET',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: init.body === undefined ? undefined : JSON.stringify(init.body),
  });
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new Error(text || `Server error ${res.status}`);
  }
  return (await res.json()) as T;
}

export const publicProfileUrl = (slug: string) => `${API_URL || 'https://pettrack.app'}/p/${slug}`;
