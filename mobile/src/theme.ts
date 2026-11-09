/**
 * The "Kinetic" design tokens, taken from the website's
 * backend/assets/css/kinetic.css so the app and the site match.
 *
 * Four type registers, never mixed:
 *   stencil = poster voice (big headlines only)
 *   body    = UI voice (cards, rows, text)
 *   mono    = data voice (dates, prices, labels)
 *   tag     = the hand (one marker gesture per screen)
 */
export const colors = {
  orange: '#FF4800',
  black: '#000000',
  white: '#FFFFFF',
  /** Muted text on black / on white / on orange (all pass 4.5:1). */
  mutedOnBlack: 'rgba(255,255,255,0.62)',
  mutedOnWhite: 'rgba(0,0,0,0.62)',
  mutedOnOrange: 'rgba(0,0,0,0.78)',
  ruleOnBlack: 'rgba(255,255,255,0.3)',
  ruleOnWhite: 'rgba(0,0,0,0.15)',
  placeholder: '#1a1a1a',
  placeholderLight: '#ececec',
} as const;

/** Border width used everywhere: hard 2px rules. */
export const bw = 2;

export const fonts = {
  stencil: 'BigShouldersStencil_900Black',
  stencilBold: 'BigShouldersStencil_800ExtraBold',
  body: 'Inter_400Regular',
  bodySemi: 'Inter_600SemiBold',
  bodyBold: 'Inter_700Bold',
  bodyHeavy: 'Inter_800ExtraBold',
  bodyBlack: 'Inter_900Black',
  mono: 'JetBrainsMono_500Medium',
  monoBold: 'JetBrainsMono_700Bold',
  tag: 'PermanentMarker_400Regular',
} as const;

export const space = { xs: 4, s: 8, m: 12, l: 16, xl: 24, xxl: 32 } as const;

/** Minimum touch target. */
export const touch = 44;
