import Slider from '@react-native-community/slider';
import { useState } from 'react';
import { Pressable, Text, View } from 'react-native';
import { useLocale } from '../contexts/LocaleContext';
import { alpha, useTheme } from '../contexts/ThemeContext';
import type { GameSettings, Theme } from '../types';
import { Card } from '../ui/Card';
import { Checkbox, StarRating } from '../ui/controls';

interface GameSetupProps {
  theme: Theme;
  initialDifficulty?: number;
  onStart: (settings: GameSettings) => void;
  onBack: () => void;
}

export default function GameSetup({
  theme,
  initialDifficulty = 3,
  onStart,
  onBack,
}: GameSetupProps) {
  const { t } = useLocale();
  const { colors } = useTheme();
  const [selectedTeams, setSelectedTeams] = useState<string[]>([
    theme.description.teams[0],
    theme.description.teams[1] || theme.description.teams[0],
  ]);
  const [difficulty, setDifficulty] = useState(initialDifficulty);
  const [pointsRequired, setPointsRequired] = useState(50);
  const [roundTimer, setRoundTimer] = useState(60);
  const [skipPenalty, setSkipPenalty] = useState(true);

  const toggleTeam = (team: string) => {
    if (selectedTeams.includes(team)) {
      if (selectedTeams.length > 2) {
        setSelectedTeams(selectedTeams.filter((t) => t !== team));
      }
    } else {
      if (selectedTeams.length < 10) {
        setSelectedTeams([...selectedTeams, team]);
      }
    }
  };

  const handleStart = () => {
    if (selectedTeams.length < 2) return;
    onStart({ theme, selectedTeams, difficulty, pointsRequired, roundTimer, skipPenalty });
  };

  return (
    <Card className="w-full">
      <Text className="mb-2 text-center text-3xl font-bold" style={{ color: colors.text }}>
        {theme.name}
      </Text>
      <Text className="mb-6 text-center" style={{ color: alpha(colors.text, 0.6) }}>
        {Object.keys(theme.description.words).length} words •{' '}
        {theme.description.teams.length} teams available
      </Text>

      <View className="gap-6">
        <View>
          <Text className="mb-3 font-semibold" style={{ color: colors.text }}>
            {t.gs_selectTeams}
          </Text>
          <View className="flex-row flex-wrap gap-3">
            {theme.description.teams.map((team) => {
              const selected = selectedTeams.includes(team);
              return (
                <Pressable
                  key={team}
                  onPress={() => toggleTeam(team)}
                  className="rounded-game p-3"
                  style={
                    selected
                      ? { backgroundColor: colors.success, minWidth: '45%' }
                      : {
                          backgroundColor: alpha(colors.text, 0.06),
                          borderWidth: 1,
                          borderColor: alpha(colors.text, 0.15),
                          minWidth: '45%',
                        }
                  }
                >
                  <Text
                    className="text-center font-semibold"
                    style={{ color: selected ? colors.white : colors.text }}
                  >
                    {team}
                  </Text>
                </Pressable>
              );
            })}
          </View>
          <Text className="mt-2 text-sm" style={{ color: alpha(colors.text, 0.6) }}>
            {t.gs_selectedTeams(selectedTeams.length, theme.description.teams.length)}
          </Text>
        </View>

        <View>
          <Text className="mb-2 font-semibold" style={{ color: colors.text }}>
            {t.gs_difficulty}
          </Text>
          <StarRating value={difficulty} onChange={setDifficulty} />
          <Text className="mt-2 text-sm" style={{ color: alpha(colors.text, 0.6) }}>
            {t.gs_difficultyHint(difficulty)}
          </Text>
        </View>

        <View>
          <Text className="mb-2 font-semibold" style={{ color: colors.text }}>
            {t.gs_pointsRequired(pointsRequired)}
          </Text>
          <Slider
            minimumValue={10}
            maximumValue={100}
            step={10}
            value={pointsRequired}
            onValueChange={setPointsRequired}
            minimumTrackTintColor={colors.success}
            maximumTrackTintColor={alpha(colors.text, 0.2)}
            thumbTintColor={colors.success}
          />
          <View className="mt-1 flex-row justify-between">
            <Text className="text-sm" style={{ color: alpha(colors.text, 0.6) }}>10</Text>
            <Text className="text-sm" style={{ color: alpha(colors.text, 0.6) }}>100</Text>
          </View>
        </View>

        <View>
          <Text className="mb-2 font-semibold" style={{ color: colors.text }}>
            {t.gs_roundTimer(roundTimer)}
          </Text>
          <Slider
            minimumValue={15}
            maximumValue={120}
            step={15}
            value={roundTimer}
            onValueChange={setRoundTimer}
            minimumTrackTintColor={colors.success}
            maximumTrackTintColor={alpha(colors.text, 0.2)}
            thumbTintColor={colors.success}
          />
          <View className="mt-1 flex-row justify-between">
            <Text className="text-sm" style={{ color: alpha(colors.text, 0.6) }}>15s</Text>
            <Text className="text-sm" style={{ color: alpha(colors.text, 0.6) }}>120s</Text>
          </View>
        </View>

        <Checkbox checked={skipPenalty} onChange={setSkipPenalty} label={t.gs_skipPenalty} />

        <View className="flex-row gap-4 pt-4">
          <Pressable
            onPress={onBack}
            className="flex-1 items-center rounded-game px-6 py-3"
            style={{
              backgroundColor: alpha(colors.text, 0.06),
              borderWidth: 1,
              borderColor: alpha(colors.text, 0.15),
            }}
          >
            <Text className="font-semibold" style={{ color: colors.text }}>
              {t.gs_back}
            </Text>
          </Pressable>
          <Pressable
            onPress={handleStart}
            disabled={selectedTeams.length < 2}
            className="flex-1 items-center rounded-game px-6 py-3"
            style={{
              backgroundColor: colors.success,
              opacity: selectedTeams.length < 2 ? 0.5 : 1,
            }}
          >
            <Text className="font-semibold" style={{ color: colors.white }}>
              {t.gs_startGame}
            </Text>
          </Pressable>
        </View>
      </View>
    </Card>
  );
}
