import { Image } from 'expo-image';
import { useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { Modal, Pressable, ScrollView, useWindowDimensions, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { BackBar, QueryState } from '@/components/chrome';
import { SafetyActions } from '@/components/safety';
import { Body, Mono, Stencil } from '@/components/text';
import type { Schemas } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { useLocale } from '@/lib/i18n';
import { useAlbum } from '@/lib/queries';
import { bw, colors, space } from '@/theme';

type GalleryPhoto = Schemas['GalleryPhoto'];

/** Album: a two-column photo grid; tap a photo to see it full screen. */
export default function AlbumScreen() {
  const { slug } = useLocalSearchParams<{ slug: string }>();
  const insets = useSafeAreaInsets();
  const { width } = useWindowDimensions();
  const { t } = useLocale();
  const album = useAlbum(slug);
  const { me } = useAuth();
  const [open, setOpen] = useState<GalleryPhoto | null>(null);
  const a = album.data;
  const cell = (width - space.l * 2 - 8) / 2;

  return (
    <View style={{ flex: 1, backgroundColor: colors.white }}>
      <BackBar shareUrl={a?.url} shareTitle={a?.title} />
      <QueryState loading={album.isPending} error={album.error} onRetry={album.refetch} />
      {a ? (
        <ScrollView contentContainerStyle={{ padding: space.l, gap: 12, paddingBottom: space.xxl }}>
          <Mono size={11} color={colors.mutedOnWhite}>{t('album.photos', { n: a.photo_count })}</Mono>
          <Stencil size={48} accessibilityRole="header">{a.title}</Stencil>
          {a.subtitle ? <Body color={colors.mutedOnWhite}>{a.subtitle}</Body> : null}
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: 6 }}>
            {a.photos.map((p) => (
              <Pressable key={p.id} accessibilityRole="imagebutton" accessibilityLabel={p.alt ?? p.title ?? a.title} onPress={() => setOpen(p)}>
                <Image source={p.thumb_url} style={{ width: cell, height: cell, borderWidth: bw, borderColor: colors.black }} contentFit="cover" />
              </Pressable>
            ))}
          </View>
        </ScrollView>
      ) : null}

      <Modal visible={!!open} transparent animationType="fade" onRequestClose={() => setOpen(null)}>
        <Pressable accessibilityRole="button" accessibilityLabel={t('common.back')} onPress={() => setOpen(null)} style={{ flex: 1, backgroundColor: 'rgba(0,0,0,0.95)', justifyContent: 'center', paddingTop: insets.top, paddingBottom: insets.bottom }}>
          {open ? (
            <>
              <Image source={open.url} placeholder={open.thumb_url} style={{ width, height: open.width && open.height ? (width * open.height) / open.width : width }} contentFit="contain" accessibilityLabel={open.alt ?? undefined} />
              {open.caption || open.uploader ? (
                <View style={{ padding: space.l, gap: 4 }}>
                  {open.caption ? <Body color={colors.white}>{open.caption}</Body> : null}
                  {open.uploader ? <Mono size={10} color={colors.mutedOnBlack}>@{open.uploader.alias}</Mono> : null}
                </View>
              ) : null}
              {open.uploader && open.uploader.alias !== me.data?.rider_profile?.alias ? (
                <View style={{ paddingHorizontal: space.l }}>
                  <SafetyActions
                    onDark
                    target={{ type: 'photo', id: open.id, name: `@${open.uploader.alias}`, canBlock: true }}
                    beforeNavigate={() => setOpen(null)}
                  />
                </View>
              ) : null}
            </>
          ) : null}
        </Pressable>
      </Modal>
    </View>
  );
}
