import { Image } from 'expo-image';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { openBrowserAsync } from 'expo-web-browser';
import { Pressable, ScrollView, View } from 'react-native';

import { BackBar, QueryState } from '@/components/chrome';
import { Icon } from '@/components/icon';
import { Markdown } from '@/components/markdown';
import { Body, Mono, Stencil } from '@/components/text';
import { dateLabel } from '@/lib/format';
import { useLocale } from '@/lib/i18n';
import { usePost } from '@/lib/queries';
import { bw, colors, space } from '@/theme';

/**
 * Article reader. The ID/EN switch is the app language, so switching it
 * refetches the post in the other language when the post has it.
 */
export default function PostScreen() {
  const { slug } = useLocalSearchParams<{ slug: string }>();
  const router = useRouter();
  const { t, label, locale, setLocale } = useLocale();
  const post = usePost(slug);
  const p = post.data;
  const other = locale === 'id' ? 'en' : 'id';

  return (
    <View style={{ flex: 1, backgroundColor: colors.white }}>
      <BackBar shareUrl={p?.url} shareTitle={p?.title} />
      <QueryState loading={post.isPending} error={post.error} onRetry={post.refetch} />
      {p ? (
        <ScrollView contentContainerStyle={{ paddingBottom: space.xxl * 2 }}>
          {p.cover_url ? <Image source={p.cover_url} style={{ aspectRatio: 16 / 9, borderBottomWidth: bw }} contentFit="cover" /> : null}
          <View style={{ padding: space.l, gap: 12 }}>
            <Mono bold size={10}>
              {(p.kind === 'news' ? t('news.news') : t('news.articles')) + (p.topic ? ` · ${label('topic', p.topic)}` : '')} · {dateLabel(p.published_at, locale)} · {t('news.minutes', { n: p.reading_minutes })}
            </Mono>
            <Stencil size={40} accessibilityRole="header">{p.title}</Stencil>

            {p.locale !== locale ? (
              <View style={{ flexDirection: 'row', gap: 10, backgroundColor: colors.black, padding: 12 }}>
                <Icon name="translate" size={18} color={colors.orange} />
                <Body size={13} color={colors.white} style={{ flex: 1 }}>{t('post.fallback')}</Body>
              </View>
            ) : p.machine_translated ? (
              <View style={{ flexDirection: 'row', gap: 10, backgroundColor: colors.black, padding: 12, alignItems: 'center' }}>
                <Icon name="translate" size={18} color={colors.orange} />
                <Body size={13} color={colors.white} style={{ flex: 1 }}>{t('post.machine')}</Body>
                {p.available_locales.includes(other) ? (
                  <Pressable accessibilityRole="button" onPress={() => setLocale(other)} hitSlop={8}>
                    <Mono bold size={12} color={colors.orange}>{other.toUpperCase()} →</Mono>
                  </Pressable>
                ) : null}
              </View>
            ) : null}

            {p.event ? (
              <Pressable accessibilityRole="link" onPress={() => router.push({ pathname: '/events/[slug]', params: { slug: p.event!.slug } })} style={{ borderWidth: bw, padding: 10 }}>
                <Mono size={10} color={colors.mutedOnWhite}>{t('post.recapOf')}</Mono>
                <Body weight="heavy" size={15}>{p.event.title} →</Body>
              </Pressable>
            ) : null}

            <Markdown source={p.body} />

            {p.source_url ? (
              <Pressable accessibilityRole="link" onPress={() => openBrowserAsync(p.source_url!)} style={{ borderTopWidth: bw, paddingTop: 12, marginTop: 8 }}>
                <Mono size={10} color={colors.mutedOnWhite}>{t('post.source')}</Mono>
                <Body weight="bold" color={colors.orange} style={{ textDecorationLine: 'underline' }}>{p.source_name ?? p.source_url}</Body>
              </Pressable>
            ) : null}
          </View>
        </ScrollView>
      ) : null}
    </View>
  );
}
