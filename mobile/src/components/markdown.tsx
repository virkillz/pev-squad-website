import { Image } from 'expo-image';
import { openBrowserAsync } from 'expo-web-browser';
import { Fragment, type ReactNode } from 'react';
import { Text, View } from 'react-native';

import { bw, colors, fonts } from '@/theme';

import { Body } from './text';

/**
 * Renders the Markdown subset staff write in posts: paragraphs, ##/###
 * headings, - and 1. lists, > quotes, images on their own line, **bold**,
 * *italic*, `code` and [links](url). The API already made links absolute
 * and the server strips raw HTML, so nothing here needs sanitizing.
 */
export function Markdown({ source, color = colors.black }: { source: string; color?: string }) {
  const blocks = source.replace(/\r\n/g, '\n').split(/\n{2,}/);
  return <View style={{ gap: 14 }}>{blocks.map((b, i) => <Block key={i} text={b.trim()} color={color} />)}</View>;
}

function Block({ text, color }: { text: string; color: string }) {
  if (!text) return null;

  const image = text.match(/^!\[([^\]]*)\]\(([^)\s]+)\)$/);
  if (image) {
    return (
      <Image
        source={image[2]}
        accessibilityLabel={image[1] || undefined}
        style={{ width: '100%', aspectRatio: 4 / 3, borderWidth: bw, borderColor: color }}
        contentFit="cover"
      />
    );
  }

  const heading = text.match(/^(#{1,4})\s+(.*)$/);
  if (heading) {
    const size = heading[1].length <= 2 ? 21 : 18;
    return (
      <Body weight="heavy" size={size} color={color} accessibilityRole="header">
        <Inline text={heading[2]} color={color} />
      </Body>
    );
  }

  const lines = text.split('\n');
  if (lines.every((l) => /^\s*([-*]|\d+\.)\s+/.test(l))) {
    return (
      <View style={{ gap: 6 }}>
        {lines.map((l, i) => {
          const ordered = l.match(/^\s*(\d+)\.\s+/);
          return (
            <View key={i} style={{ flexDirection: 'row', gap: 8 }}>
              <Body size={16} color={colors.orange} weight="bold" style={{ width: ordered ? 22 : 12 }}>
                {ordered ? `${ordered[1]}.` : '■'}
              </Body>
              <Body size={16} color={color} style={{ flex: 1, lineHeight: 24 }}>
                <Inline text={l.replace(/^\s*([-*]|\d+\.)\s+/, '')} color={color} />
              </Body>
            </View>
          );
        })}
      </View>
    );
  }

  if (lines.every((l) => l.startsWith('>'))) {
    return (
      <View style={{ borderLeftWidth: 4, borderColor: colors.orange, paddingLeft: 12 }}>
        <Body size={17} weight="semi" color={color} style={{ lineHeight: 25 }}>
          <Inline text={lines.map((l) => l.replace(/^>\s?/, '')).join(' ')} color={color} />
        </Body>
      </View>
    );
  }

  return (
    <Body size={16} color={color} style={{ lineHeight: 25 }}>
      <Inline text={lines.join(' ')} color={color} />
    </Body>
  );
}

/** **bold**, *italic*, `code`, [text](url). Unmatched markers stay as text. */
function Inline({ text, color }: { text: string; color: string }) {
  const parts: ReactNode[] = [];
  const re = /(\*\*([^*]+)\*\*|\*([^*]+)\*|_([^_]+)_|`([^`]+)`|\[([^\]]+)\]\(([^)\s]+)\))/g;
  let last = 0;
  let m: RegExpExecArray | null;
  let key = 0;
  while ((m = re.exec(text))) {
    if (m.index > last) parts.push(text.slice(last, m.index));
    if (m[2]) parts.push(<Text key={key++} style={{ fontFamily: fonts.bodyHeavy }}>{m[2]}</Text>);
    else if (m[3] || m[4]) parts.push(<Text key={key++} style={{ fontStyle: 'italic' }}>{m[3] ?? m[4]}</Text>);
    else if (m[5]) parts.push(<Text key={key++} style={{ fontFamily: fonts.mono, fontSize: 14 }}>{m[5]}</Text>);
    else if (m[6]) {
      const href = m[7];
      parts.push(
        <Text key={key++} accessibilityRole="link" onPress={() => openBrowserAsync(href)} style={{ color: colors.orange, textDecorationLine: 'underline', fontFamily: fonts.bodyBold }}>
          {m[6]}
        </Text>,
      );
    }
    last = m.index + m[0].length;
  }
  if (last < text.length) parts.push(text.slice(last));
  return <>{parts.map((p, i) => (typeof p === 'string' ? <Fragment key={`t${i}`}>{p}</Fragment> : p))}</>;
}
