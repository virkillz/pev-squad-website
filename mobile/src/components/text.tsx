import { Text, type TextProps, type TextStyle } from 'react-native';

import { colors, fonts } from '@/theme';

/**
 * The four type registers. Use these instead of raw <Text> so the app
 * never drifts from the site's typography.
 */
type Props = TextProps & { color?: string; size?: number; style?: TextStyle | TextStyle[] };

/** Poster voice: uppercase stencil, big headlines only. */
export function Stencil({ color = colors.black, size = 44, style, ...rest }: Props) {
  return (
    <Text
      {...rest}
      style={[
        {
          fontFamily: fonts.stencil,
          fontSize: size,
          lineHeight: size * 0.92,
          color,
          textTransform: 'uppercase',
        },
        style as TextStyle,
      ]}
    />
  );
}

/** UI voice. `weight`: regular | semi | bold | heavy | black. */
export function Body({
  color = colors.black,
  size = 15,
  weight = 'regular',
  style,
  ...rest
}: Props & { weight?: 'regular' | 'semi' | 'bold' | 'heavy' | 'black' }) {
  const family = {
    regular: fonts.body,
    semi: fonts.bodySemi,
    bold: fonts.bodyBold,
    heavy: fonts.bodyHeavy,
    black: fonts.bodyBlack,
  }[weight];
  return (
    <Text
      {...rest}
      style={[{ fontFamily: family, fontSize: size, lineHeight: size * 1.3, color }, style as TextStyle]}
    />
  );
}

/** Data voice: dates, prices, labels. Uppercase with tracking. */
export function Mono({ color = colors.black, size = 11, bold = false, style, ...rest }: Props & { bold?: boolean }) {
  return (
    <Text
      {...rest}
      style={[
        {
          fontFamily: bold ? fonts.monoBold : fonts.mono,
          fontSize: size,
          letterSpacing: size * 0.08,
          color,
        },
        style as TextStyle,
      ]}
    />
  );
}

/** The hand: one marker gesture per screen, slightly rotated. */
export function Tag({ color = colors.orange, size = 22, style, ...rest }: Props) {
  return (
    <Text
      {...rest}
      style={[
        { fontFamily: fonts.tag, fontSize: size, color, transform: [{ rotate: '-4deg' }] },
        style as TextStyle,
      ]}
    />
  );
}
