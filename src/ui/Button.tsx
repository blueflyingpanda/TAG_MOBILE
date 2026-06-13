import type { ReactNode } from 'react';
import { Pressable, Text, ViewStyle, TextStyle, StyleProp } from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withSpring,
} from 'react-native-reanimated';
import { alpha, useTheme } from '../contexts/ThemeContext';

type Variant = 'error' | 'success' | 'neutral' | 'muted';

type Props = {
  variant: Variant;
  onPress?: () => void;
  disabled?: boolean;
  children?: ReactNode;
  style?: StyleProp<ViewStyle>;
  textStyle?: StyleProp<TextStyle>;
};

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

export function Button({ variant, onPress, disabled, children, style, textStyle }: Props) {
  const { colors } = useTheme();
  const scale = useSharedValue(1);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  const variantStyle: ViewStyle =
    variant === 'error'
      ? { backgroundColor: colors.error }
      : variant === 'success'
        ? { backgroundColor: colors.success }
        : variant === 'neutral'
          ? { backgroundColor: colors.text }
          : {
              backgroundColor: colors.card,
              borderWidth: 1,
              borderColor: alpha(colors.text, 0.15),
            };

  const textColor = variant === 'muted' ? colors.text : colors.white;

  return (
    <AnimatedPressable
      onPress={onPress}
      disabled={disabled}
      onPressIn={() => {
        if (!disabled) scale.value = withSpring(0.95, { stiffness: 400, damping: 25 });
      }}
      onPressOut={() => {
        scale.value = withSpring(1, { stiffness: 400, damping: 25 });
      }}
      className="flex-row items-center justify-center rounded-game p-4"
      style={[variantStyle, disabled && { opacity: 0.5 }, animatedStyle, style]}
    >
      <Text className="text-base font-bold leading-6" style={[{ color: textColor }, textStyle]}>
        {children}
      </Text>
    </AnimatedPressable>
  );
}
