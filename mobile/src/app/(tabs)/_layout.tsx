import { TabList, TabSlot, Tabs, TabTrigger, type TabTriggerSlotProps } from 'expo-router/ui';
import type { ComponentProps } from 'react';
import { Pressable, View, type PressableProps } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { Icon, type IconName } from '@/components/icon';
import { Mono } from '@/components/text';
import { useLocale } from '@/lib/i18n';
import { bw, colors } from '@/theme';

/**
 * The five tabs, drawn as the Kinetic tab bar from the mockup: black bar,
 * 2px white rules, the active tab filled orange. Built on Expo Router's
 * headless tabs so the bar is fully ours.
 */
export default function TabsLayout() {
  const insets = useSafeAreaInsets();
  const { t } = useLocale();

  const tabs: { name: string; href: '/' | '/events' | '/news' | '/for-sale' | '/community'; icon: IconName; label: string }[] = [
    { name: 'index', href: '/', icon: 'home', label: t('tab.home') },
    { name: 'events', href: '/events', icon: 'calendar', label: t('tab.events') },
    { name: 'news', href: '/news', icon: 'news', label: t('tab.news') },
    { name: 'for-sale', href: '/for-sale', icon: 'tag', label: t('tab.forSale') },
    { name: 'community', href: '/community', icon: 'people', label: t('tab.community') },
  ];

  return (
    <Tabs>
      <TabSlot />
      <TabList asChild>
        <View style={{ flexDirection: 'row', backgroundColor: colors.black, borderTopWidth: bw, borderColor: colors.white, paddingBottom: insets.bottom }}>
          {tabs.map((tab, i) => (
            <TabTrigger key={tab.name} name={tab.name} href={tab.href} asChild>
              <TabButton icon={tab.icon} label={tab.label} first={i === 0} />
            </TabTrigger>
          ))}
        </View>
      </TabList>
    </Tabs>
  );
}

type TabButtonProps = Omit<TabTriggerSlotProps, 'ref'> & Pick<ComponentProps<typeof Pressable>, 'ref'> & { icon: IconName; label: string; first: boolean };

function TabButton({ icon, label, first, isFocused, ref, ...props }: TabButtonProps) {
  const fg = isFocused ? colors.black : colors.white;
  return (
    <Pressable
      {...(props as PressableProps)}
      ref={ref}
      accessibilityRole="tab"
      accessibilityState={{ selected: isFocused }}
      accessibilityLabel={label}
      style={{
        flex: 1,
        alignItems: 'center',
        gap: 5,
        paddingTop: 10,
        paddingBottom: 8,
        backgroundColor: isFocused ? colors.orange : colors.black,
        borderLeftWidth: first ? 0 : bw,
        borderColor: colors.white,
      }}>
      <Icon name={icon} size={22} color={fg} />
      <Mono bold size={9} color={fg} numberOfLines={1}>
        {label}
      </Mono>
    </Pressable>
  );
}
