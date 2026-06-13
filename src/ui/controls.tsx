import { Pressable, Text, View } from 'react-native';
import { alpha, useTheme } from '../contexts/ThemeContext';

/** Checkbox with label — replaces web <input type="checkbox"> */
export function Checkbox({
  checked,
  onChange,
  label,
}: {
  checked: boolean;
  onChange: (value: boolean) => void;
  label: string;
}) {
  const { colors } = useTheme();

  return (
    <Pressable
      className="flex-row items-center gap-2"
      onPress={() => onChange(!checked)}
      hitSlop={6}
    >
      <View
        className="h-5 w-5 items-center justify-center rounded"
        style={{
          backgroundColor: checked ? colors.success : 'transparent',
          borderWidth: 1.5,
          borderColor: checked ? colors.success : alpha(colors.text, 0.4),
        }}
      >
        {checked && <Text style={{ color: colors.white, fontSize: 12, fontWeight: '700' }}>✓</Text>}
      </View>
      <Text style={{ color: alpha(colors.text, 0.8) }}>{label}</Text>
    </Pressable>
  );
}

/** Segmented option pills — replaces web <select> dropdowns */
export function OptionPills<T extends string>({
  options,
  value,
  onChange,
}: {
  options: { value: T; label: string }[];
  value: T;
  onChange: (value: T) => void;
}) {
  const { colors } = useTheme();

  return (
    <View className="flex-row flex-wrap gap-2">
      {options.map((opt) => {
        const selected = opt.value === value;
        return (
          <Pressable
            key={opt.value}
            onPress={() => onChange(opt.value)}
            className="rounded-game px-4 py-2"
            style={{
              backgroundColor: selected ? colors.success : alpha(colors.text, 0.06),
              borderWidth: selected ? 0 : 1,
              borderColor: alpha(colors.text, 0.15),
            }}
          >
            <Text
              className="text-sm font-semibold"
              style={{ color: selected ? colors.white : colors.text }}
            >
              {opt.label}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

/** 1-5 star difficulty selector */
export function StarRating({
  value,
  onChange,
  size = 28,
}: {
  value: number;
  onChange: (value: number) => void;
  size?: number;
}) {
  const { colors } = useTheme();

  return (
    <View className="flex-row items-center gap-1">
      {[1, 2, 3, 4, 5].map((level) => (
        <Pressable key={level} onPress={() => onChange(level)} hitSlop={4}>
          <Text
            style={{
              fontSize: size,
              color: level <= value ? colors.success : alpha(colors.text, 0.4),
            }}
          >
            ★
          </Text>
        </Pressable>
      ))}
    </View>
  );
}
