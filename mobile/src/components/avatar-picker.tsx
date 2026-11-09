import { useQueryClient } from '@tanstack/react-query';
import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import { useState } from 'react';
import { ActivityIndicator, Alert, Linking, Platform, Pressable, View } from 'react-native';

import { ApiError } from '@/lib/api';
import { useLocale } from '@/lib/i18n';
import { uploadImage } from '@/lib/upload';
import { bw, colors, space } from '@/theme';

import { Body, Mono, Stencil } from './text';

const PICK: ImagePicker.ImagePickerOptions = {
  mediaTypes: ['images'],
  quality: 0.85,
  // iOS: hand over a JPEG rather than HEIC. The server crops to 4:5 itself.
  preferredAssetRepresentationMode: ImagePicker.UIImagePickerPreferredAssetRepresentationMode.Compatible,
};

/**
 * Rider photo on the profile screen: camera or library, uploaded to
 * PUT /me/avatar. Needs a saved profile, since the file is named after it.
 */
export function AvatarPicker({ url, alias, enabled }: { url: string | null; alias: string; enabled: boolean }) {
  const client = useQueryClient();
  const { t } = useLocale();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function upload(result: ImagePicker.ImagePickerResult) {
    const asset = result.canceled ? null : result.assets[0];
    if (!asset) return;
    setBusy(true);
    setError(null);
    try {
      await uploadImage('PUT', '/api/v1/me/avatar', asset);
      await client.invalidateQueries({ queryKey: ['me'] });
    } catch (e) {
      const field = e instanceof ApiError ? Object.values(e.fields ?? {})[0]?.[0] : undefined;
      setError(field ?? t('common.error'));
    } finally {
      setBusy(false);
    }
  }

  async function fromCamera() {
    const permission = await ImagePicker.requestCameraPermissionsAsync();
    if (!permission.granted) {
      Alert.alert(t('avatar.title'), t('avatar.cameraDenied'), [
        { text: t('profile.cancel'), style: 'cancel' },
        { text: t('avatar.openSettings'), onPress: () => Linking.openSettings() },
      ]);
      return;
    }
    upload(await ImagePicker.launchCameraAsync(PICK));
  }

  const fromLibrary = async () => upload(await ImagePicker.launchImageLibraryAsync(PICK));

  function choose() {
    if (Platform.OS === 'web') return void fromLibrary();
    Alert.alert(t('avatar.title'), undefined, [
      { text: t('avatar.camera'), onPress: fromCamera },
      { text: t('avatar.library'), onPress: fromLibrary },
      { text: t('profile.cancel'), style: 'cancel' },
    ]);
  }

  return (
    <View style={{ flexDirection: 'row', gap: space.l, alignItems: 'flex-end' }}>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={url ? t('avatar.change') : t('avatar.add')}
        accessibilityState={{ disabled: !enabled || busy }}
        disabled={!enabled || busy}
        onPress={choose}
        style={{ width: 104, height: 130, borderWidth: bw, borderColor: colors.black, backgroundColor: colors.orange, alignItems: 'center', justifyContent: 'center', overflow: 'hidden' }}>
        {url ? (
          <Image source={url} style={{ width: '100%', height: '100%' }} contentFit="cover" transition={150} />
        ) : (
          <Stencil size={56}>{(alias || '?').slice(0, 1).toUpperCase()}</Stencil>
        )}
        {busy ? (
          <View style={{ position: 'absolute', inset: 0, backgroundColor: 'rgba(0,0,0,0.55)', alignItems: 'center', justifyContent: 'center' }}>
            <ActivityIndicator color={colors.white} />
          </View>
        ) : null}
      </Pressable>
      <View style={{ flex: 1, gap: space.s }}>
        {enabled ? (
          <Pressable accessibilityRole="button" onPress={choose} disabled={busy} style={{ alignSelf: 'flex-start', borderWidth: bw, borderColor: colors.black, paddingHorizontal: space.m, paddingVertical: 10 }}>
            <Mono bold size={11}>{busy ? t('avatar.uploading') : url ? t('avatar.change') : t('avatar.add')}</Mono>
          </Pressable>
        ) : null}
        <Body size={12} color={colors.mutedOnWhite}>{enabled ? t('avatar.hint') : t('avatar.later')}</Body>
        {error ? <Body size={13} weight="semi">⚠ {error}</Body> : null}
      </View>
    </View>
  );
}
