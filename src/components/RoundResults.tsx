import { useEffect, useState } from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';
import Animated, { FadeInDown, SlideInDown } from 'react-native-reanimated';
import { useLocale } from '../contexts/LocaleContext';
import { alpha, useTheme } from '../contexts/ThemeContext';

interface RoundResultsProps {
  results: { word: string; guessed: boolean }[];
  onConfirm: (
    results: { word: string; guessed: boolean }[],
    lastWordGuessed: boolean | null,
  ) => void;
  skipPenalty?: boolean;
  lastWord?: string;
}

export default function RoundResults({
  results,
  onConfirm,
  skipPenalty = true,
  lastWord,
}: RoundResultsProps) {
  const { t } = useLocale();
  const { colors } = useTheme();
  const [finalResults, setFinalResults] = useState(results);
  const [lastWordGuessed, setLastWordGuessed] = useState<boolean | null>(null);

  useEffect(() => {
    setFinalResults(results);
  }, [results]);

  const toggleWord = (index: number) => {
    const updated = [...finalResults];
    updated[index] = { ...updated[index], guessed: !updated[index].guessed };
    setFinalResults(updated);
  };

  const baseGuessed = finalResults.filter((r) => r.guessed).length;
  const skippedCount = finalResults.length - baseGuessed;
  const guessedCount = baseGuessed + (lastWordGuessed ? 1 : 0);
  const earned =
    (skipPenalty ? baseGuessed - skippedCount : baseGuessed) + (lastWordGuessed ? 1 : 0);

  return (
    <Animated.View entering={SlideInDown.duration(400)} className="flex-1 p-4">
      <ScrollView className="flex-1" contentContainerStyle={{ paddingBottom: 80 }}>
        <View
          className="w-full rounded-game p-6"
          style={{ backgroundColor: colors.card }}
        >
          <Text className="mb-2 text-center text-3xl font-bold" style={{ color: colors.text }}>
            {t.rr_title}
          </Text>
          <Text className="mb-6 text-center" style={{ color: alpha(colors.text, 0.6) }}>
            {t.rr_hint}
          </Text>
          {results.length === 0 && (
            <Text className="mb-6 text-center" style={{ color: alpha(colors.text, 0.6) }}>
              {t.rr_noWords}
            </Text>
          )}

          <View className="mb-6 flex-row justify-center gap-6">
            <View className="items-center">
              <Animated.View key={`g-${guessedCount}`} entering={FadeInDown.duration(200)}>
                <Text className="text-2xl font-bold" style={{ color: colors.success }}>
                  {guessedCount}
                </Text>
              </Animated.View>
              <Text className="text-sm" style={{ color: alpha(colors.text, 0.6) }}>
                {t.rr_guessed}
              </Text>
            </View>
            <View className="items-center">
              <Animated.View key={`e-${earned}`} entering={FadeInDown.duration(200)}>
                <Text
                  className="text-2xl font-bold"
                  style={{
                    color:
                      earned > 0
                        ? colors.success
                        : earned < 0
                          ? colors.error
                          : alpha(colors.text, 0.8),
                  }}
                >
                  ⭐ {earned}
                </Text>
              </Animated.View>
              <Text className="text-sm" style={{ color: alpha(colors.text, 0.6) }}>
                {t.rr_earned}
              </Text>
            </View>
            <View className="items-center">
              <Animated.View key={`s-${skippedCount}`} entering={FadeInDown.duration(200)}>
                <Text className="text-2xl font-bold" style={{ color: colors.error }}>
                  {skippedCount}
                </Text>
              </Animated.View>
              <Text className="text-sm" style={{ color: alpha(colors.text, 0.6) }}>
                {t.rr_skipped}
              </Text>
            </View>
          </View>

          <View className="gap-2">
            {finalResults.map((result, index) => (
              <Pressable
                key={index}
                onPress={() => toggleWord(index)}
                className="w-full rounded-game p-4"
                style={{
                  backgroundColor: result.guessed
                    ? alpha(colors.success, 0.15)
                    : alpha(colors.error, 0.1),
                  borderWidth: 1,
                  borderColor: result.guessed
                    ? alpha(colors.success, 0.3)
                    : alpha(colors.error, 0.3),
                }}
              >
                <View className="flex-row items-center justify-between">
                  <Text className="font-semibold" style={{ color: colors.text }}>
                    {result.word}
                  </Text>
                  <Text className="text-2xl">{result.guessed ? '✅' : '❌'}</Text>
                </View>
              </Pressable>
            ))}
          </View>

          {lastWord && (
            <View className="mt-6">
              <Text className="mb-2 text-sm" style={{ color: alpha(colors.text, 0.5) }}>
                {t.rr_lastWord}
              </Text>
              <Pressable
                onPress={() => setLastWordGuessed((prev) => (prev ? null : true))}
                className="w-full rounded-game p-4"
                style={{
                  backgroundColor: lastWordGuessed
                    ? alpha(colors.success, 0.15)
                    : alpha(colors.text, 0.05),
                  borderWidth: 1,
                  borderColor: lastWordGuessed
                    ? alpha(colors.success, 0.3)
                    : alpha(colors.text, 0.1),
                }}
              >
                <View className="flex-row items-center justify-between">
                  <Text
                    className="font-semibold"
                    style={{
                      color: lastWordGuessed ? colors.text : alpha(colors.text, 0.6),
                    }}
                  >
                    {lastWord}
                  </Text>
                  <Text className="text-2xl">{lastWordGuessed ? '✅' : '❓'}</Text>
                </View>
              </Pressable>
            </View>
          )}
        </View>
      </ScrollView>

      <View className="absolute bottom-4 left-0 right-0 items-center">
        <Pressable
          onPress={() => onConfirm(finalResults, lastWordGuessed)}
          className="rounded-game px-6 py-3"
          style={{ backgroundColor: colors.success }}
        >
          <Text className="font-semibold" style={{ color: colors.white }}>
            {t.rr_confirm}
          </Text>
        </Pressable>
      </View>
    </Animated.View>
  );
}
