import type { ReactNode } from 'react';
import { StyleProp, View, ViewStyle } from 'react-native';
import { useTheme } from '../contexts/ThemeContext';

type Props = {
  children: ReactNode;
  className?: string;
  style?: StyleProp<ViewStyle>;
};

/** Rounded card surface — replaces the web `rounded-game bg-card shadow-sm` panels */
export function Card({ children, className, style }: Props) {
  const { colors } = useTheme();

  return (
    <View
      className={`rounded-game p-6 ${className ?? ''}`}
      style={[
        {
          backgroundColor: colors.card,
          shadowColor: '#000',
          shadowOpacity: 0.08,
          shadowRadius: 4,
          shadowOffset: { width: 0, height: 1 },
          elevation: 2,
        },
        style,
      ]}
    >
      {children}
    </View>
  );
}
