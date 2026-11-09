import * as SecureStore from 'expo-secure-store';

// Device preferences only. Future session tokens must stay in SecureStore.
export const readPreference = (key: string) => SecureStore.getItemAsync(key);
export const writePreference = (key: string, value: string) => SecureStore.setItemAsync(key, value);
