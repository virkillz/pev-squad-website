import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Pressable, ScrollView, View } from 'react-native';

import { BackBar, QueryState } from '@/components/chrome';
import { Body, Mono, Stencil } from '@/components/text';
import { api, unwrap } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { useLocale } from '@/lib/i18n';
import { bw, colors, space, touch } from '@/theme';

/** Pengaturan → Member diblokir: the list, with unblock. */
export default function BlockedScreen() {
  const client = useQueryClient();
  const { t } = useLocale();
  const { signedIn } = useAuth();
  const [busy, setBusy] = useState<number | null>(null);

  const blocks = useQuery({
    queryKey: ['me', 'blocks'],
    enabled: signedIn,
    queryFn: async () => unwrap(await api.GET('/api/v1/blocks')).data,
  });

  async function unblock(userId: number) {
    setBusy(userId);
    try {
      await api.DELETE('/api/v1/blocks/{user_id}', { params: { path: { user_id: userId } } });
      // Their content comes back everywhere.
      await client.invalidateQueries();
    } finally {
      setBusy(null);
    }
  }

  return (
    <View style={{ flex: 1, backgroundColor: colors.black }}>
      <BackBar />
      <ScrollView contentContainerStyle={{ padding: space.l, gap: space.m, paddingBottom: space.xxl }}>
        <Stencil size={48} color={colors.white} accessibilityRole="header" style={{ marginBottom: space.s }}>{t('blocked.title')}</Stencil>
        {blocks.data ? (
          blocks.data.length === 0 ? (
            <Body color={colors.mutedOnBlack}>{t('blocked.empty')}</Body>
          ) : (
            blocks.data.map((b) => (
              <View key={b.user_id} style={{ flexDirection: 'row', alignItems: 'center', borderWidth: bw, borderColor: colors.white }}>
                <Body weight="bold" color={colors.white} style={{ flex: 1, padding: space.m }}>
                  {b.alias ?? t('blocked.noProfile')}
                </Body>
                <Pressable
                  accessibilityRole="button"
                  accessibilityLabel={`${t('blocked.unblock')} ${b.alias ?? ''}`}
                  disabled={busy === b.user_id}
                  onPress={() => unblock(b.user_id)}
                  style={{ minHeight: touch + 4, justifyContent: 'center', paddingHorizontal: space.m, borderLeftWidth: bw, borderColor: colors.white, backgroundColor: colors.orange, opacity: busy === b.user_id ? 0.5 : 1 }}>
                  <Mono bold size={11}>{t('blocked.unblock')}</Mono>
                </Pressable>
              </View>
            ))
          )
        ) : (
          <QueryState onDark loading={blocks.isPending} error={blocks.error} onRetry={blocks.refetch} />
        )}
      </ScrollView>
    </View>
  );
}
