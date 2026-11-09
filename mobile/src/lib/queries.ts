import { useInfiniteQuery, useQuery } from '@tanstack/react-query';

import { api, unwrap } from './api';
import { useLocale } from './i18n';

/**
 * One hook per API read. The language is part of every key, so switching
 * ID/EN refetches translated content instead of showing the cached copy.
 * Lists use the API's `{data, next}` cursor with useInfiniteQuery.
 */

export function useHome() {
  const { locale } = useLocale();
  return useQuery({
    queryKey: ['home', locale],
    queryFn: async () => unwrap(await api.GET('/api/v1/home')).data,
  });
}

export function useEvents(when: 'upcoming' | 'past', category?: 'official' | 'group_ride') {
  const { locale } = useLocale();
  return useInfiniteQuery({
    queryKey: ['events', when, category ?? 'all', locale],
    initialPageParam: undefined as string | undefined,
    queryFn: async ({ pageParam }) =>
      unwrap(
        await api.GET('/api/v1/events', {
          params: { query: { when, category, after: pageParam, limit: 20 } },
        }),
      ),
    getNextPageParam: (last) => last.next ?? undefined,
  });
}

export function useEvent(slug: string) {
  const { locale } = useLocale();
  return useQuery({
    queryKey: ['event', slug, locale],
    queryFn: async () =>
      unwrap(await api.GET('/api/v1/events/{slug}', { params: { path: { slug } } })).data,
  });
}

export function usePosts(kind: 'news' | 'article', topic?: string) {
  const { locale } = useLocale();
  return useInfiniteQuery({
    queryKey: ['posts', kind, topic ?? 'all', locale],
    initialPageParam: undefined as string | undefined,
    queryFn: async ({ pageParam }) =>
      unwrap(
        await api.GET('/api/v1/posts', {
          params: { query: { kind, topic, after: pageParam, limit: 20 } },
        }),
      ),
    getNextPageParam: (last) => last.next ?? undefined,
  });
}

export function usePost(slug: string) {
  const { locale } = useLocale();
  return useQuery({
    queryKey: ['post', slug, locale],
    queryFn: async () =>
      unwrap(await api.GET('/api/v1/posts/{slug}', { params: { path: { slug } } })).data,
  });
}

export function useListings(category?: string, sold = false) {
  const { locale } = useLocale();
  return useInfiniteQuery({
    queryKey: ['listings', category ?? 'all', sold, locale],
    initialPageParam: undefined as string | undefined,
    queryFn: async ({ pageParam }) =>
      unwrap(
        await api.GET('/api/v1/listings', {
          params: { query: { category, sold, after: pageParam, limit: 20 } },
        }),
      ),
    getNextPageParam: (last) => last.next ?? undefined,
  });
}

export function useListing(id: number) {
  const { locale } = useLocale();
  return useQuery({
    queryKey: ['listing', id, locale],
    queryFn: async () =>
      unwrap(await api.GET('/api/v1/listings/{id}', { params: { path: { id } } })).data,
  });
}

export function useCommunity() {
  const { locale } = useLocale();
  return useQuery({
    queryKey: ['community', locale],
    queryFn: async () => unwrap(await api.GET('/api/v1/community')).data,
  });
}

export function useRiders(type?: string, search?: string) {
  const { locale } = useLocale();
  return useInfiniteQuery({
    queryKey: ['riders', type ?? 'all', search ?? '', locale],
    initialPageParam: undefined as string | undefined,
    queryFn: async ({ pageParam }) =>
      unwrap(
        await api.GET('/api/v1/riders', {
          params: { query: { type, search: search || undefined, after: pageParam, limit: 20 } },
        }),
      ),
    getNextPageParam: (last) => last.next ?? undefined,
  });
}

export function useRider(slug: string) {
  const { locale } = useLocale();
  return useQuery({
    queryKey: ['rider', slug, locale],
    queryFn: async () =>
      unwrap(await api.GET('/api/v1/riders/{slug}', { params: { path: { slug } } })).data,
  });
}

export function usePartner(slug: string) {
  const { locale } = useLocale();
  return useQuery({
    queryKey: ['partner', slug, locale],
    queryFn: async () =>
      unwrap(await api.GET('/api/v1/partners/{slug}', { params: { path: { slug } } })).data,
  });
}

export function useAlbums() {
  const { locale } = useLocale();
  return useInfiniteQuery({
    queryKey: ['albums', locale],
    initialPageParam: undefined as string | undefined,
    queryFn: async ({ pageParam }) =>
      unwrap(await api.GET('/api/v1/albums', { params: { query: { after: pageParam, limit: 20 } } })),
    getNextPageParam: (last) => last.next ?? undefined,
  });
}

export function useAlbum(slug: string) {
  const { locale } = useLocale();
  return useQuery({
    queryKey: ['album', slug, locale],
    queryFn: async () =>
      unwrap(await api.GET('/api/v1/albums/{slug}', { params: { path: { slug } } })).data,
  });
}

/** Flattens useInfiniteQuery pages into one list. */
export function flatPages<T>(data: { pages: { data: T[] }[] } | undefined): T[] {
  return data ? data.pages.flatMap((p) => p.data) : [];
}
