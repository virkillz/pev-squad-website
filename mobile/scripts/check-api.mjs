import assert from 'node:assert/strict';

// Read-only smoke check. No account, token, or database writes required.
const base = process.env.EXPO_PUBLIC_API_URL || 'http://localhost:4000';

async function get(path, locale) {
  const response = await fetch(new URL(path, base), {
    headers: { Accept: 'application/json', 'Accept-Language': locale },
    signal: AbortSignal.timeout(15_000),
  });
  assert.equal(response.status, 200, `${path}: HTTP ${response.status}. Check the API URL and deployment.`);
  assert.match(response.headers.get('content-type') ?? '', /application\/json/, `${path}: expected JSON`);
  const body = await response.json();
  assert.ok(body.data, `${path}: missing data`);
  console.log(`OK ${locale} ${path}`);
  return body;
}

async function check(locale) {
  const { data: home } = await get('/api/v1/home', locale);
  for (const key of ['upcoming', 'posts', 'albums', 'listings']) assert.ok(Array.isArray(home[key]), `home.${key}`);
  const { data: community } = await get('/api/v1/community', locale);
  assert.ok(community.stats);

  for (const [path, detailKey] of [
    ['/api/v1/events?when=upcoming', 'slug'],
    ['/api/v1/events?when=past', 'slug'],
    ['/api/v1/posts?kind=news', 'slug'],
    ['/api/v1/posts?kind=article', 'slug'],
    ['/api/v1/listings', 'id'],
    ['/api/v1/listings?sold=true', 'id'],
    ['/api/v1/riders', 'slug'],
    ['/api/v1/albums', 'slug'],
  ]) {
    const url = new URL(path, base);
    url.searchParams.set('limit', '1');
    const page = await get(url.pathname + url.search, locale);
    assert.ok(Array.isArray(page.data), `${path}: expected a list`);
    assert.ok(page.next === null || typeof page.next === 'string', `${path}: invalid cursor`);
    if (page.data.length) {
      await get(`${url.pathname}/${encodeURIComponent(page.data[0][detailKey])}`, locale);
    }
    if (page.next) {
      url.searchParams.set('after', page.next);
      const next = await get(url.pathname + url.search, locale);
      assert.ok(Array.isArray(next.data));
      assert.notEqual(next.data[0]?.[detailKey], page.data[0]?.[detailKey], `${path}: repeated page`);
    }
  }

  for (const partner of [...community.communities, ...community.brands].slice(0, 2)) {
    await get(`/api/v1/partners/${encodeURIComponent(partner.slug)}`, locale);
  }
}

try {
  for (const locale of ['id', 'en']) await check(locale);
  console.log('Public API checks passed.');
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
