import { Text, View } from 'react-native';
import Animated, { SlideInUp, SlideOutDown } from 'react-native-reanimated';
import { useTheme } from '../contexts/ThemeContext';

type Props = {
  variant: 'error' | 'success';
  value: number;
};

export function Counter({ variant, value }: Props) {
  const { colors } = useTheme();

  return (
    <View className="h-10 items-center justify-center overflow-hidden">
      <Animated.View
        key={value}
        entering={SlideInUp.duration(150)}
        exiting={SlideOutDown.duration(150)}
      >
        <Text
          className="text-3xl font-semibold leading-none"
          style={{ color: variant === 'error' ? colors.error : colors.success }}
        >
          {value}
        </Text>
      </Animated.View>
    </View>
  );
}
