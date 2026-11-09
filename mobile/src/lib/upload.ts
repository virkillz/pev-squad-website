import type { ImagePickerAsset } from 'expo-image-picker';
import { Platform } from 'react-native';

import { ApiError } from './api';
import { API_URL } from './config';
import { currentLocale } from './i18n';
import { refreshAccess } from './session';

/**
 * Sends a picked image as multipart `file`. Builds the form per attempt
 * (a form body can't be re-sent) and retries once with a fresh token on
 * 401, like authenticatedFetch does for JSON requests.
 */
export async function uploadImage<T>(method: 'PUT' | 'POST', path: string, asset: ImagePickerAsset): Promise<T> {
  const form = () => {
    const data = new FormData();
    if (Platform.OS === 'web' && asset.file) {
      data.append('file', asset.file);
    } else {
      const type = asset.mimeType ?? 'image/jpeg';
      const name = asset.fileName ?? `photo.${type.split('/')[1] ?? 'jpg'}`;
      // React Native's FormData takes a {uri, name, type} file descriptor.
      data.append('file', { uri: asset.uri, name, type } as unknown as Blob);
    }
    return data;
  };

  const send = (token: string | null) =>
    fetch(`${API_URL}${path}`, {
      method,
      headers: { Accept: 'application/json', 'Accept-Language': currentLocale(), ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      body: form(),
      signal: AbortSignal.timeout(60_000),
    });

  let response = await send(await refreshAccess());
  if (response.status === 401) {
    const token = await refreshAccess(true);
    if (token) response = await send(token);
  }

  const body = await response.json().catch(() => null);
  if (response.ok) return body as T;
  const err = body?.error;
  throw new ApiError(response.status, err?.code ?? 'http_error', err?.message ?? 'Upload failed', err?.fields);
}
