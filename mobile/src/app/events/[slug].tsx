import { useLocalSearchParams, useRouter } from 'expo-router';
import * as WebBrowser from 'expo-web-browser';
import { useState } from 'react';
import { Linking, Pressable, ScrollView, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { PostRow } from '@/components/cards';
import { BackBar, BigButton, QueryState } from '@/components/chrome';
import { SafetyActions } from '@/components/safety';
import { Icon } from '@/components/icon';
import { Body, Mono, Stencil, Tag } from '@/components/text';
import type { EventDetail } from '@/lib/api';
import { dayLabel, timeLabel } from '@/lib/format';
import { useAuth } from '@/lib/auth';
import { API_URL } from '@/lib/config';
import { useLocale } from '@/lib/i18n';
import { useEvent } from '@/lib/queries';
import { bw, colors, space } from '@/theme';

/** Google Calendar "add event" link: works on both platforms without permissions. */
function calendarUrl(e: EventDetail) {
  const fmt = (iso: string) => new Date(iso).toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
  const end = e.ends_at ?? new Date(new Date(e.starts_at).getTime() + 3 * 3600_000).toISOString();
  const q = new URLSearchParams({
    action: 'TEMPLATE',
    text: e.title,
    dates: `${fmt(e.starts_at)}/${fmt(end)}`,
    location: [e.meeting_point, e.location_name].filter(Boolean).join(', '),
    details: e.url,
  });
  return `https://calendar.google.com/calendar/render?${q.toString()}`;
}

function mapsUrl(e: EventDetail) {
  const q = [e.meeting_point, e.location_name].filter(Boolean).join(', ');
  return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(q)}`;
}

export default function EventScreen() {
  const { slug } = useLocalSearchParams<{ slug: string }>();
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const { t, label, locale } = useLocale();
  const event = useEvent(slug);
  const { me, signedIn } = useAuth();
  // Read the clock once per screen, not on every render.
  const [openedAt] = useState(() => Date.now());
  const e = event.data;

  const cell = (title: string, lines: (string | null | undefined)[], right = false, bottom = true) => (
    <View style={{ width: '50%', padding: space.m, paddingHorizontal: space.l, borderRightWidth: right ? 0 : bw, borderBottomWidth: bottom ? bw : 0 }}>
      <Mono size={10} color={colors.mutedOnWhite}>{title}</Mono>
      {lines.filter(Boolean).map((l, i) => (
        <Mono key={i} bold size={14} style={{ marginTop: i ? 0 : 3 }}>{l}</Mono>
      ))}
    </View>
  );

  return (
    <View style={{ flex: 1, backgroundColor: colors.white }}>
      <BackBar shareUrl={e?.url} shareTitle={e?.title} />
      <QueryState loading={event.isPending} error={event.error} onRetry={event.refetch} />
      {e ? (
        <>
          <ScrollView contentContainerStyle={{ paddingBottom: space.xxl }}>
            <View style={{ backgroundColor: colors.black, padding: space.l, paddingBottom: 18 }}>
              <View style={{ flexDirection: 'row', gap: 8, flexWrap: 'wrap' }}>
                <Mono bold size={10} style={{ backgroundColor: colors.orange, paddingHorizontal: 8, paddingVertical: 5 }}>{label('kind', e.kind)}</Mono>
                <Mono bold size={10} color={colors.white} style={{ borderWidth: bw, borderColor: colors.white, paddingHorizontal: 8, paddingVertical: 3 }}>
                  {e.host ? t('event.hostedBy', { alias: e.host.alias }) : t('events.official')}
                </Mono>
                {e.status === 'cancelled' ? (
                  <Mono bold size={10} style={{ backgroundColor: colors.white, paddingHorizontal: 8, paddingVertical: 5 }}>{t('event.cancelled')}</Mono>
                ) : null}
              </View>
              <Stencil size={56} color={colors.white} style={{ marginTop: 14 }} accessibilityRole="header">{e.title}</Stencil>
              {e.location_name ? <Body weight="semi" size={14} color={colors.mutedOnBlack} style={{ marginTop: 8 }}>{e.location_name}</Body> : null}
            </View>

            <View style={{ flexDirection: 'row', flexWrap: 'wrap', borderBottomWidth: bw }}>
              {cell(t('event.start'), [dayLabel(e.local.starts_at, locale), timeLabel(e.local.starts_at, e.timezone)])}
              {cell(t('event.end'), e.local.ends_at ? [dayLabel(e.local.ends_at, locale), timeLabel(e.local.ends_at, e.timezone)] : ['—'], true)}
              {cell(t('event.meetingPoint'), [e.meeting_point ?? e.location_name ?? '—'], false, false)}
              {cell(t('event.rsvpBy'), e.local.rsvp_deadline ? [dayLabel(e.local.rsvp_deadline, locale), timeLabel(e.local.rsvp_deadline, e.timezone)] : ['—'], true, false)}
            </View>

            <View style={{ padding: space.l, paddingVertical: 14, borderBottomWidth: bw, flexDirection: 'row', alignItems: 'center', gap: 14 }}>
              <View style={{ flex: 1 }}>
                <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
                  <Mono bold size={11}>{t('event.seats')}</Mono>
                  <Mono size={11} color={colors.mutedOnWhite}>{t('event.going', { going: e.going_count, waitlist: e.waitlist_count })}</Mono>
                </View>
                {e.capacity ? (
                  <View style={{ flexDirection: 'row', gap: 4, marginTop: 8 }} aria-hidden>
                    {Array.from({ length: Math.min(e.capacity, 20) }, (_, i) => (
                      <View key={i} style={{ flex: 1, height: 14, borderWidth: bw, backgroundColor: i < Math.round((e.going_count / e.capacity!) * Math.min(e.capacity!, 20)) ? colors.black : colors.white }} />
                    ))}
                  </View>
                ) : (
                  <Mono size={11} style={{ marginTop: 6 }}>{t('event.unlimited')}</Mono>
                )}
              </View>
              {e.seats_left !== null && e.seats_left > 0 && e.seats_left <= 10 ? (
                <Tag size={24}>{t('event.seatsLeft', { n: e.seats_left }).toLowerCase()}!</Tag>
              ) : null}
            </View>

            <View style={{ flexDirection: 'row', borderBottomWidth: bw }}>
              <Pressable accessibilityRole="link" onPress={() => Linking.openURL(calendarUrl(e))} style={{ flex: 1, flexDirection: 'row', gap: 8, alignItems: 'center', justifyContent: 'center', paddingVertical: 14, borderRightWidth: bw }}>
                <Icon name="calendarAdd" size={18} />
                <Mono bold size={11}>{t('event.calendar')}</Mono>
              </Pressable>
              <Pressable accessibilityRole="link" onPress={() => Linking.openURL(mapsUrl(e))} style={{ flex: 1, flexDirection: 'row', gap: 8, alignItems: 'center', justifyContent: 'center', paddingVertical: 14 }}>
                <Icon name="pin" size={18} />
                <Mono bold size={11}>{t('event.maps')}</Mono>
              </Pressable>
            </View>

            <View style={{ padding: space.l, gap: 10 }}>
              {(e.description ?? '').split(/\n{2,}/).filter((p) => p.trim()).map((p, i) => (
                <Body key={i} size={15} style={{ lineHeight: 22 }}>{p.trim()}</Body>
              ))}
              {e.partners.length > 0 || e.partners_text ? (
                <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, alignItems: 'center', marginTop: 4 }}>
                  <Mono size={10} color={colors.mutedOnWhite}>{t('event.with')}</Mono>
                  {e.partners.map((p) => (
                    <Pressable key={p.slug} accessibilityRole="link" onPress={() => router.push({ pathname: '/partners/[slug]', params: { slug: p.slug } })} style={{ borderWidth: bw, paddingHorizontal: 8, paddingVertical: 4 }}>
                      <Body weight="bold" size={13}>{p.name}</Body>
                    </Pressable>
                  ))}
                  {e.partners_text ? <Body weight="bold" size={13}>{e.partners_text}</Body> : null}
                </View>
              ) : null}
            </View>

            {e.recaps.length > 0 ? (
              <View style={{ paddingHorizontal: space.l }}>
                <Mono bold size={11} style={{ paddingBottom: 6, borderBottomWidth: bw }}>{t('event.recaps')}</Mono>
                {e.recaps.map((p) => <PostRow key={p.id} post={p} onDark={false} />)}
              </View>
            ) : null}

            {e.category === 'group_ride' && e.host && e.host.slug !== me.data?.rider_profile?.slug ? (
              <View style={{ padding: space.l }}>
                <SafetyActions target={{ type: 'event', id: e.id, name: e.host.alias, canBlock: true }} leave={1} />
              </View>
            ) : null}
          </ScrollView>

          {e.status === 'published' && new Date(e.starts_at).getTime() > openedAt ? (
            <View style={{ borderTopWidth: bw, padding: space.m, paddingHorizontal: space.l, paddingBottom: insets.bottom + space.m, gap: 8, backgroundColor: colors.white }}>
              {/* RSVP has no API yet (roadmap step 5), so signed-in members RSVP on the website. */}
              <BigButton
                label={t('event.rsvp')}
                onPress={() => (signedIn ? WebBrowser.openBrowserAsync(`${API_URL}/events/${e.slug}`) : router.push('/login'))}
              />
              <Mono size={10} color={colors.mutedOnWhite} style={{ textAlign: 'center' }}>{t(signedIn ? 'event.rsvpWebHint' : 'event.rsvpHint')}</Mono>
            </View>
          ) : null}
        </>
      ) : null}
    </View>
  );
}
