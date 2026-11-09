// Browser previews have no SecureStore. These values contain no credentials.
export async function readPreference(key: string): Promise<string | null> {
  return window.localStorage.getItem(`pevsquad.${key}`);
}

export async function writePreference(key: string, value: string): Promise<void> {
  window.localStorage.setItem(`pevsquad.${key}`, value);
}
