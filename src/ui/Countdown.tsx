import { Text, View } from 'react-native';
import Animated, { FadeInDown, FadeOutUp } from 'react-native-reanimated';
import { useTheme } from '../contexts/ThemeContext';

type Props = {
  seconds: number;
  isWarning?: boolean;
  suffix?: string;
};

/** Digit flip — keyed re-mount with enter/exit animations (web Countdown parity) */
export function Countdown({ seconds, isWarning = false, suffix = '' }: Props) {
  const { colors } = useTheme();

  return (
    <View className="h-12 min-w-[90px] items-center justify-center overflow-hidden px-1">
      <Animated.View
        key={seconds}
        entering={FadeInDown.duration(120)}
        exiting={FadeOutUp.duration(120)}
      >
        <Text
          className="text-3xl font-bold tabular-nums"
          style={{ color: isWarning ? colors.error : colors.text }}
        >
          {seconds}
          {suffix}
        </Text>
      </Animated.View>
    </View>
  );
}
