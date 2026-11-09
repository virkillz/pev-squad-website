import { Image } from 'expo-image';
import { Link } from 'expo-router';
import { Pressable, View } from 'react-native';

import type { Album, Event, Listing, Partner, Post, Rider } from '@/lib/api';
import { dateLabel, dayLabel, dayOfMonth, daysUntil, monthShort, rupiah, rupiahShort, thousands, timeLabel, weekday } from '@/lib/format';
import { useLocale } from '@/lib/i18n';
import { bw, colors, space } from '@/theme';

import { ImagePlaceholder } from './chrome';
import { Body, Mono, Stencil } from './text';

function initials(name: string) {
  return name
    .split(/\s+/)
    .map((w) => w[0])
    .join('')
    .slice(0, 2)
    .toUpperCase();
}

/** "SISA 4" / "PENUH" / null for unlimited events. */
function useSeats(event: Event) {
  const { t } = useLocale();
  if (event.seats_left === null) return null;
  return event.seats_left === 0 ? t('event.full') : t('event.seatsLeft', { n: event.seats_left });
}

/** Home's big orange "next ride" card. */
export function NextRideCard({ event }: { event: Event }) {
  const { t, label, locale } = useLocale();
  const seats = useSeats(event);
  const d = daysUntil(event.starts_at);
  const cell = { flex: 1, padding: 8, borderColor: colors.black } as const;

  return (
    <Link href={{ pathname: '/events/[slug]', params: { slug: event.slug } }} asChild>
      <Pressable accessibilityRole="link" style={{ backgroundColor: colors.orange, borderWidth: bw, borderColor: colors.orange }}>
        <View style={{ flexDirection: 'row', borderBottomWidth: bw }}>
          <Mono bold size={11} style={{ padding: 8, borderRightWidth: bw }}>{label('kind', event.kind)}</Mono>
          <Mono bold size={11} style={{ padding: 8, flex: 1 }}>
            {event.category === 'official' ? t('events.official') : t('events.groupRide')}
          </Mono>
          <Mono bold size={11} color={colors.orange} style={{ padding: 8, backgroundColor: colors.black }}>
            {d === 0 ? t('event.today') : t('event.daysLeft', { n: d })}
          </Mono>
        </View>
        <View style={{ padding: space.m, gap: space.m }}>
          <Stencil size={44}>{event.title}</Stencil>
          <View style={{ flexDirection: 'row', borderWidth: bw }}>
            <View style={[cell, { borderRightWidth: bw }]}>
              <Mono size={10} color={colors.mutedOnOrange}>{weekday(event.local.starts_at, locale)}</Mono>
              <Mono bold size={15}>{dayOfMonth(event.local.starts_at)} {monthShort(event.local.starts_at, locale)}</Mono>
            </View>
            <View style={[cell, seats ? { borderRightWidth: bw } : null]}>
              <Mono size={10} color={colors.mutedOnOrange}>{t('event.start')}</Mono>
              <Mono bold size={15}>{timeLabel(event.local.starts_at, event.timezone)}</Mono>
            </View>
            {seats ? (
              <View style={cell}>
                <Mono size={10} color={colors.mutedOnOrange}>{t('event.seats')}</Mono>
                <Mono bold size={15}>{seats}</Mono>
              </View>
            ) : null}
          </View>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap: 12 }}>
            <Body weight="bold" size={14} style={{ flex: 1 }}>{event.location_name}</Body>
            <Mono bold size={12} color={colors.white} style={{ backgroundColor: colors.black, paddingHorizontal: 16, paddingVertical: 12 }}>
              RSVP →
            </Mono>
          </View>
        </View>
      </Pressable>
    </Link>
  );
}

/** Event list row with the black date block. */
export function EventRow({ event }: { event: Event }) {
  const { t, label, locale } = useLocale();
  const seats = useSeats(event);
  return (
    <Link href={{ pathname: '/events/[slug]', params: { slug: event.slug } }} asChild>
      <Pressable accessibilityRole="link" style={{ flexDirection: 'row', borderBottomWidth: bw }}>
        <View style={{ width: 70, backgroundColor: colors.black, alignItems: 'center', justifyContent: 'center', paddingVertical: 10 }}>
          <Mono size={10} color={colors.orange}>{weekday(event.local.starts_at, locale)}</Mono>
          <Stencil size={38} color={colors.white}>{dayOfMonth(event.local.starts_at)}</Stencil>
          <Mono size={10} color={colors.white}>{monthShort(event.local.starts_at, locale)}</Mono>
        </View>
        <View style={{ flex: 1, padding: 10, paddingRight: 12 }}>
          <Mono size={10} color={colors.mutedOnWhite}>
            {label('kind', event.kind)} · {event.category === 'official' ? t('events.official') : t('events.groupRide')}
            {event.status === 'cancelled' ? ` · ${t('event.cancelled')}` : ''}
          </Mono>
          <Body weight="heavy" size={17} style={{ marginTop: 4 }}>{event.title}</Body>
          {event.host ? <Mono size={10} color={colors.mutedOnWhite} style={{ marginTop: 2 }}>@{event.host.alias}</Mono> : null}
          <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginTop: 8, gap: 8 }}>
            <Mono size={11} style={{ flex: 1 }} numberOfLines={1}>
              {timeLabel(event.local.starts_at, event.timezone)}
              {event.location_name ? ` · ${event.location_name}` : ''}
            </Mono>
            {seats ? (
              <Mono bold size={11} style={{ backgroundColor: event.seats_left !== null && event.seats_left <= 5 ? colors.orange : undefined, paddingHorizontal: 6, paddingVertical: 3 }}>
                {seats}
              </Mono>
            ) : null}
          </View>
        </View>
      </Pressable>
    </Link>
  );
}

/** Compact past-event row. */
export function PastEventRow({ event }: { event: Event }) {
  const { label, locale } = useLocale();
  return (
    <Link href={{ pathname: '/events/[slug]', params: { slug: event.slug } }} asChild>
      <Pressable accessibilityRole="link" style={{ flexDirection: 'row', gap: 12, alignItems: 'baseline', paddingVertical: 11, borderBottomWidth: bw, borderColor: colors.ruleOnWhite }}>
        <Mono size={11} color={colors.mutedOnWhite} style={{ width: 58 }}>
          {dayOfMonth(event.local.starts_at).padStart(2, '0')} {monthShort(event.local.starts_at, locale)}
        </Mono>
        <Body weight="bold" size={15} style={{ flex: 1 }}>{event.title}</Body>
        <Mono size={10} color={colors.mutedOnWhite}>{label('kind', event.kind)}</Mono>
      </Pressable>
    </Link>
  );
}

/** News row: thumbnail, topic, title, date. */
export function PostRow({ post, onDark = true }: { post: Post; onDark?: boolean }) {
  const { t, label, locale } = useLocale();
  const fg = onDark ? colors.white : colors.black;
  return (
    <Link href={{ pathname: '/posts/[slug]', params: { slug: post.slug } }} asChild>
      <Pressable accessibilityRole="link" style={{ flexDirection: 'row', gap: 12, paddingVertical: 12, borderBottomWidth: bw, borderColor: onDark ? colors.ruleOnBlack : colors.ruleOnWhite, alignItems: 'center' }}>
        {post.cover_url ? (
          <Image source={post.cover_url} style={{ width: 84, height: 64, borderWidth: bw, borderColor: fg }} contentFit="cover" accessibilityIgnoresInvertColors />
        ) : (
          <ImagePlaceholder style={{ width: 84, height: 64, borderWidth: bw, borderColor: fg }} />
        )}
        <View style={{ flex: 1 }}>
          <Mono size={10} color={colors.orange}>
            {post.kind === 'news' ? t('news.news') : t('news.articles')}
            {post.topic ? ` · ${label('topic', post.topic)}` : ''}
          </Mono>
          <Body weight="heavy" size={15} color={fg} style={{ marginTop: 3 }} numberOfLines={3}>{post.title}</Body>
          <Mono size={10} color={onDark ? colors.mutedOnBlack : colors.mutedOnWhite} style={{ marginTop: 5 }}>
            {dateLabel(post.published_at, locale)} · {t('news.minutes', { n: post.reading_minutes })}
          </Mono>
        </View>
      </Pressable>
    </Link>
  );
}

/** The large featured card at the top of the News tab. */
export function PostFeature({ post }: { post: Post }) {
  const { t, label, locale } = useLocale();
  return (
    <Link href={{ pathname: '/posts/[slug]', params: { slug: post.slug } }} asChild>
      <Pressable accessibilityRole="link" style={{ borderWidth: bw, borderColor: colors.white }}>
        <View>
          {post.cover_url ? (
            <Image source={post.cover_url} style={{ height: 190, borderBottomWidth: bw, borderColor: colors.white }} contentFit="cover" />
          ) : (
            <ImagePlaceholder style={{ height: 120, borderBottomWidth: bw, borderColor: colors.white }} />
          )}
          <Mono bold size={10} style={{ position: 'absolute', left: 0, top: 0, backgroundColor: colors.orange, paddingHorizontal: 8, paddingVertical: 6 }}>
            {post.event_id ? 'RECAP' : post.topic ? label('topic', post.topic) : t('news.news')}
          </Mono>
        </View>
        <View style={{ padding: space.m, gap: 8 }}>
          <Stencil size={30} color={colors.white}>{post.title}</Stencil>
          {post.excerpt ? <Body size={14} color="rgba(255,255,255,0.78)" numberOfLines={3}>{post.excerpt}</Body> : null}
          <Mono size={10} color={colors.mutedOnBlack}>
            {dateLabel(post.published_at, locale)} · {t('news.minutes', { n: post.reading_minutes })}
          </Mono>
        </View>
      </Pressable>
    </Link>
  );
}

/** For Sale grid card. */
export function ListingCard({ listing, onDark = false }: { listing: Listing; onDark?: boolean }) {
  const { t, label, locale } = useLocale();
  const sold = listing.state === 'sold';
  const fg = onDark ? colors.white : colors.black;
  return (
    <Link href={{ pathname: '/listings/[id]', params: { id: String(listing.id) } }} asChild>
      <Pressable accessibilityRole="link" style={{ flex: 1, borderWidth: bw, borderColor: fg, backgroundColor: colors.white }}>
        <View style={{ opacity: sold ? 0.55 : 1 }}>
          {listing.photo ? (
            <Image source={listing.photo.thumb_url} style={{ height: 132, borderBottomWidth: bw }} contentFit="cover" />
          ) : (
            <ImagePlaceholder light style={{ height: 132, borderBottomWidth: bw }} />
          )}
          <Mono bold size={9} color={colors.white} style={{ position: 'absolute', left: 0, top: 0, backgroundColor: colors.black, paddingHorizontal: 6, paddingVertical: 4 }}>
            {label('cat', listing.category)}
          </Mono>
        </View>
        {sold ? (
          <Stencil size={24} color={colors.orange} style={{ position: 'absolute', alignSelf: 'center', top: 50, borderWidth: 3, borderColor: colors.orange, backgroundColor: colors.white, paddingHorizontal: 10, paddingTop: 4, transform: [{ rotate: '-8deg' }] }}>
            {t('forSale.sold')}
          </Stencil>
        ) : null}
        <View style={{ padding: 8 }}>
          <Body weight="heavy" size={14} numberOfLines={2} color={sold ? colors.mutedOnWhite : colors.black}>{listing.title}</Body>
          <Mono size={10} color={colors.mutedOnWhite} style={{ marginTop: 4 }} numberOfLines={1}>
            {[label('cond', listing.condition), listing.km ? `${thousands(listing.km)} KM` : null, listing.city?.toUpperCase()].filter(Boolean).join(' · ')}
          </Mono>
          <Mono bold size={14} style={{ marginTop: 6, textDecorationLine: sold ? 'line-through' : 'none' }}>
            {rupiahShort(listing.price_idr, locale)}
            {listing.negotiable && !sold ? <Mono size={10} color={colors.mutedOnWhite}>{'  '}{t('forSale.nego')}</Mono> : null}
          </Mono>
        </View>
      </Pressable>
    </Link>
  );
}

/** Gallery album tile for Home's horizontal strip and the album list. */
export function AlbumTile({ album, width = 150 }: { album: Album; width?: number }) {
  const { t, locale } = useLocale();
  const cover = album.preview[0];
  return (
    <Link href={{ pathname: '/albums/[slug]', params: { slug: album.slug } }} asChild>
      <Pressable accessibilityRole="link" style={{ width, borderWidth: bw, borderColor: colors.white }}>
        {cover ? (
          <Image source={cover.thumb_url} style={{ width: width - bw * 2, height: width - bw * 2, borderBottomWidth: bw, borderColor: colors.white }} contentFit="cover" />
        ) : (
          <ImagePlaceholder style={{ width: width - bw * 2, height: width - bw * 2 }} />
        )}
        <View style={{ padding: 8 }}>
          <Body weight="heavy" size={14} color={colors.white} numberOfLines={1}>{album.title}</Body>
          <Mono size={10} color={colors.mutedOnBlack} style={{ marginTop: 4 }}>
            {t('album.photos', { n: album.photo_count })}
            {album.taken_on ? ` · ${monthShort(album.taken_on, locale)} ${album.taken_on.slice(0, 4)}` : ''}
          </Mono>
        </View>
      </Pressable>
    </Link>
  );
}

/** Roster card: 4:5-ish photo, alias, type badge, city · ride. */
export function RiderCard({ rider }: { rider: Rider }) {
  const { label } = useLocale();
  return (
    <Link href={{ pathname: '/riders/[slug]', params: { slug: rider.slug } }} asChild>
      <Pressable accessibilityRole="link" style={{ flex: 1, borderWidth: bw, backgroundColor: colors.white }}>
        {rider.avatar_url ? (
          <Image source={rider.avatar_url} style={{ height: 168, borderBottomWidth: bw }} contentFit="cover" accessibilityLabel={rider.alias} />
        ) : (
          <View style={{ height: 168, borderBottomWidth: bw, backgroundColor: colors.black, alignItems: 'center', justifyContent: 'center' }}>
            <Stencil size={48} color={colors.orange}>{initials(rider.alias)}</Stencil>
          </View>
        )}
        <View style={{ padding: 8 }}>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap: 6 }}>
            <Body weight="heavy" size={15} numberOfLines={1} style={{ flex: 1 }}>{rider.alias}</Body>
            <Mono bold size={9} color={colors.white} style={{ backgroundColor: colors.black, paddingHorizontal: 5, paddingVertical: 3 }}>
              {label('pev', rider.primary_pev_type)}
            </Mono>
          </View>
          <Mono size={10} color={colors.mutedOnWhite} style={{ marginTop: 4 }} numberOfLines={1}>
            {[rider.city, rider.main_ride].filter(Boolean).join(' · ').toUpperCase()}
          </Mono>
        </View>
      </Pressable>
    </Link>
  );
}

/** Partner community row (on black) or brand tile (on white). */
export function PartnerRow({ partner }: { partner: Partner }) {
  const { t } = useLocale();
  const note =
    partner.event_count > 0
      ? t('community.eventsTogether', { n: partner.event_count })
      : partner.partner_since
        ? t('community.since', { year: partner.partner_since.slice(0, 4) })
        : '→';
  return (
    <Link href={{ pathname: '/partners/[slug]', params: { slug: partner.slug } }} asChild>
      <Pressable accessibilityRole="link" style={{ flexDirection: 'row', gap: 12, alignItems: 'center', paddingVertical: 12, borderBottomWidth: bw, borderColor: colors.ruleOnBlack }}>
        <PartnerLogo partner={partner} />
        <View style={{ flex: 1 }}>
          <Body weight="heavy" size={16} color={colors.white}>{partner.name}</Body>
          <Mono size={10} color={colors.mutedOnBlack} style={{ marginTop: 3 }} numberOfLines={1}>
            {[partner.region, partner.vehicle_focus?.toUpperCase()].filter(Boolean).join(' · ').toUpperCase() || partner.tagline}
          </Mono>
        </View>
        <Mono bold size={10} color={colors.orange}>{note}</Mono>
      </Pressable>
    </Link>
  );
}

export function BrandTile({ partner }: { partner: Partner }) {
  const { t } = useLocale();
  return (
    <Link href={{ pathname: '/partners/[slug]', params: { slug: partner.slug } }} asChild>
      <Pressable accessibilityRole="link" style={{ flex: 1, gap: 8, borderWidth: bw, padding: 10 }}>
        <PartnerLogo partner={partner} dark />
        <Body weight="heavy" size={15}>{partner.name}</Body>
        <Mono size={10} color={colors.mutedOnWhite}>
          {partner.event_count > 0 ? t('community.eventsTogether', { n: partner.event_count }) : (partner.tagline ?? '').toUpperCase()}
        </Mono>
      </Pressable>
    </Link>
  );
}

function PartnerLogo({ partner, dark = false }: { partner: Partner; dark?: boolean }) {
  if (partner.logo_url) {
    return <Image source={partner.logo_url} style={{ width: 44, height: 44, backgroundColor: colors.white }} contentFit="contain" accessibilityLabel={partner.name} />;
  }
  return (
    <View aria-hidden style={{ width: 44, height: 44, backgroundColor: dark ? colors.black : colors.white, alignItems: 'center', justifyContent: 'center' }}>
      <Mono bold size={13} color={dark ? colors.orange : colors.black}>{initials(partner.name)}</Mono>
    </View>
  );
}

/** Full price line for the listing page: "Rp 32.500.000". */
export const priceFull = rupiah;
/** Re-exported for screens that show an event's day in long form. */
export { dayLabel };
