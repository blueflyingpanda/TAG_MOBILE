import { Text, View } from 'react-native';
import { useLocale } from '../contexts/LocaleContext';
import { alpha, useTheme } from '../contexts/ThemeContext';
import { Card } from '../ui/Card';

export default function Rules() {
  const { t } = useLocale();
  const { colors } = useTheme();

  const sectionStyle = {
    backgroundColor: alpha(colors.text, 0.06),
  };
  const body = { color: alpha(colors.text, 0.8) };
  const bodySmall = { color: alpha(colors.text, 0.7) };

  const splitBold = (s: string) => {
    const [bold, ...rest] = s.split(':');
    return { bold, rest: rest.join(':') };
  };

  return (
    <Card className="w-full">
      <Text className="mb-8 text-center text-3xl font-bold" style={{ color: colors.text }}>
        {t.rules_title}
      </Text>

      <View className="gap-6">
        <View className="rounded-game p-6" style={sectionStyle}>
          <Text className="mb-4 text-2xl font-semibold" style={{ color: colors.success }}>
            {t.rules_basicGameplay}
          </Text>
          <Text className="mb-3" style={body}>
            <Text className="font-bold">Alias</Text> {t.rules_intro}
          </Text>
          <View className="gap-2">
            {[t.rules_rule1, t.rules_rule2, t.rules_rule3, t.rules_rule4, t.rules_rule5, t.rules_rule6].map(
              (rule, i) => (
                <Text key={i} style={body}>
                  {'•'} {rule}
                </Text>
              ),
            )}
          </View>
        </View>

        <View className="rounded-game p-6" style={sectionStyle}>
          <Text className="mb-4 text-2xl font-semibold" style={{ color: colors.success }}>
            {t.rules_scoring}
          </Text>
          <View className="gap-2">
            {[t.rules_score1, t.rules_score2, t.rules_score3, t.rules_score4].map((s, i) => {
              const { bold, rest } = splitBold(s);
              return (
                <Text key={i} style={body}>
                  <Text className="font-bold">{bold}:</Text>
                  {rest}
                </Text>
              );
            })}
          </View>
        </View>

        <View className="rounded-game p-6" style={sectionStyle}>
          <Text className="mb-4 text-2xl font-semibold" style={{ color: colors.success }}>
            {t.rules_config}
          </Text>
          <View className="gap-4">
            {[
              [t.rules_pointsRequired, t.rules_pointsDesc],
              [t.rules_roundTimer, t.rules_roundTimerDesc],
              [t.rules_skipPenalty, t.rules_skipPenaltyDesc],
              [t.rules_teamsLabel, t.rules_teamsDesc],
            ].map(([title, desc], i) => (
              <View key={i}>
                <Text className="mb-2 font-semibold" style={{ color: colors.text }}>
                  {title}
                </Text>
                <Text className="text-sm" style={bodySmall}>
                  {desc}
                </Text>
              </View>
            ))}
          </View>
        </View>

        <View className="rounded-game p-6" style={sectionStyle}>
          <Text className="mb-4 text-2xl font-semibold" style={{ color: colors.success }}>
            {t.rules_themeManagement}
          </Text>
          <View className="gap-3">
            {[t.rules_feat1, t.rules_feat2, t.rules_feat3, t.rules_feat4, t.rules_feat5].map(
              (feat, i) => {
                const { bold, rest } = splitBold(feat);
                return (
                  <Text key={i} style={body}>
                    <Text className="font-bold">{bold}:</Text>
                    {rest}
                  </Text>
                );
              },
            )}
          </View>
        </View>

        <View className="rounded-game p-6" style={sectionStyle}>
          <Text className="mb-4 text-2xl font-semibold" style={{ color: colors.success }}>
            {t.rules_gameFeatures}
          </Text>
          <View className="gap-4">
            {[
              [t.rules_gameHistory, t.rules_gameHistoryDesc],
              [t.rules_gameResumption, t.rules_gameResumptionDesc],
              [t.rules_cheatingDetection, t.rules_cheatingDetectionDesc],
              [t.rules_resultConfirmation, t.rules_resultConfirmationDesc],
            ].map(([title, desc], i) => (
              <View key={i}>
                <Text className="mb-2 font-semibold" style={{ color: colors.text }}>
                  {title}
                </Text>
                <Text className="text-sm" style={body}>
                  {desc}
                </Text>
              </View>
            ))}
          </View>
        </View>

        <View className="rounded-game p-6" style={sectionStyle}>
          <Text className="mb-4 text-2xl font-semibold" style={{ color: colors.success }}>
            {t.rules_howToPlay}
          </Text>
          <View className="gap-2">
            {[t.rules_step1, t.rules_step2, t.rules_step3, t.rules_step4, t.rules_step5, t.rules_step6].map(
              (step, i) => (
                <Text key={i} style={body}>
                  {i + 1}. {step}
                </Text>
              ),
            )}
          </View>
        </View>

        <View className="rounded-game p-6" style={sectionStyle}>
          <Text className="mb-4 text-2xl font-semibold" style={{ color: colors.success }}>
            {t.rules_difficultyLevels}
          </Text>
          <View className="flex-row flex-wrap justify-center gap-2">
            {[
              [t.rules_veryEasy, alpha(colors.success, 0.15), colors.success],
              [t.rules_easy, alpha(colors.success, 0.25), colors.success],
              [t.rules_medium, alpha(colors.text, 0.1), colors.text],
              [t.rules_hard, alpha(colors.error, 0.2), colors.error],
              [t.rules_veryHard, alpha(colors.error, 0.15), colors.error],
            ].map(([label, bg, fg], i) => (
              <View key={i} className="rounded-game px-3 py-2" style={{ backgroundColor: bg as string }}>
                <Text className="text-center" style={{ color: fg as string }}>
                  {label as string}
                </Text>
              </View>
            ))}
          </View>
        </View>
      </View>
    </Card>
  );
}
