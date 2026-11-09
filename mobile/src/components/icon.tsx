import Svg, { Circle, Path, Rect } from 'react-native-svg';

/** Square-capped 2px stroke icons, drawn to match the mockup. */
export type IconName =
  | 'home'
  | 'calendar'
  | 'news'
  | 'tag'
  | 'people'
  | 'back'
  | 'share'
  | 'pin'
  | 'calendarAdd'
  | 'chat'
  | 'instagram'
  | 'translate'
  | 'search'
  | 'flag'
  | 'block';

export function Icon({ name, size = 22, color = '#000' }: { name: IconName; size?: number; color?: string }) {
  const p = { stroke: color, strokeWidth: 2, strokeLinecap: 'square' as const, fill: 'none' };
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24" accessibilityElementsHidden importantForAccessibility="no">
      {name === 'flag' && (
        <>
          <Path d="M5 21V4" {...p} />
          <Path d="M5 4h12l-2 4 2 4H5" {...p} />
        </>
      )}
      {name === 'block' && (
        <>
          <Circle cx={12} cy={12} r={8} {...p} />
          <Path d="M6.5 17.5l11-11" {...p} />
        </>
      )}
      {name === 'home' && (
        <>
          <Path d="M3 11l9-7 9 7v9H3z" {...p} />
          <Path d="M9 20v-6h6v6" {...p} />
        </>
      )}
      {name === 'calendar' && (
        <>
          <Rect x={3} y={5} width={18} height={16} {...p} />
          <Path d="M3 10h18M8 3v4M16 3v4" {...p} />
        </>
      )}
      {name === 'news' && (
        <>
          <Rect x={3} y={4} width={18} height={16} {...p} />
          <Path d="M7 8h10M7 12h10M7 16h6" {...p} />
        </>
      )}
      {name === 'tag' && (
        <>
          <Path d="M3 3h8l10 10-8 8L3 11z" {...p} />
          <Circle cx={8} cy={8} r={1.5} {...p} />
        </>
      )}
      {name === 'people' && (
        <>
          <Circle cx={9} cy={8} r={3.5} {...p} />
          <Path d="M2 20c.8-3.5 3.5-5.5 7-5.5s6.2 2 7 5.5" {...p} />
          <Path d="M16 4.5a3.5 3.5 0 0 1 0 7M18 14.8c2 .8 3.4 2.5 4 5.2" {...p} />
        </>
      )}
      {name === 'back' && <Path d="M15 5l-7 7 7 7" {...p} />}
      {name === 'share' && (
        <>
          <Path d="M12 3v12M7 8l5-5 5 5" {...p} />
          <Path d="M5 13v8h14v-8" {...p} />
        </>
      )}
      {name === 'pin' && (
        <>
          <Path d="M12 21s-7-6.5-7-12a7 7 0 0 1 14 0c0 5.5-7 12-7 12z" {...p} />
          <Circle cx={12} cy={9} r={2.5} {...p} />
        </>
      )}
      {name === 'calendarAdd' && (
        <>
          <Rect x={3} y={5} width={18} height={16} {...p} />
          <Path d="M3 10h18M8 3v4M16 3v4M12 13v5M9.5 15.5h5" {...p} />
        </>
      )}
      {name === 'chat' && <Path d="M4 20l1.5-4A8 8 0 1 1 9 19z" {...p} />}
      {name === 'instagram' && (
        <>
          <Rect x={3} y={3} width={18} height={18} rx={5} {...p} />
          <Circle cx={12} cy={12} r={4} {...p} />
        </>
      )}
      {name === 'translate' && (
        <>
          <Path d="M4 5h9M8.5 3v2M6 5c0 4 3 7 6 8M11 5c0 3-2.5 6-6 8" {...p} />
          <Path d="M13 21l4-9 4 9M14.5 18h5" {...p} />
        </>
      )}
      {name === 'search' && (
        <>
          <Circle cx={11} cy={11} r={7} {...p} />
          <Path d="M20 20l-4-4" {...p} />
        </>
      )}
    </Svg>
  );
}
