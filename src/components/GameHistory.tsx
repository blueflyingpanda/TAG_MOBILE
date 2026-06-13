import { useEffect, useState } from 'react';
import { Pressable, Text, View } from 'react-native';
import { useLocale } from '../contexts/LocaleContext';
import { alpha, useTheme } from '../contexts/ThemeContext';
import type { GameDetailsResponse, GameListItem, GameState } from '../types';
import { Card } from '../ui/Card';
import { getGame, getGames } from '../utils/games';
import { getTheme } from '../utils/themes';

interface GameHistoryProps {
  onBack: () => void;
  onResumeGame: (gameState: GameState, gameId: number) => void;
}

export default function GameHistory({ onBack, onResumeGame }: GameHistoryProps) {
  const { t } = useLocale();
  const { colors } = useTheme();
  const [games, setGames] = useState<GameListItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedGame, setSelectedGame] = useState<GameDetailsResponse | null>(null);

  useEffect(() => {
    const fetchGames = async () => {
      setIsLoading(true);
      try {
        const response = await getGames(1, 50, undefined, undefined, undefined, 'id', true);
        setGames(response.items);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load games');
      } finally {
        setIsLoading(false);
      }
    };
    fetchGames();
  }, []);

  const formatDate = (dateString: string) => new Date(dateString).toLocaleString();

  const handleViewDetails = async (game: GameListItem) => {
    try {
      const gameDetails = await getGame(game.id);
      setSelectedGame(gameDetails);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load game details');
    }
  };

  const handleResumeGame = async (game: GameDetailsResponse) => {
    if (!game.info?.teams || game.info.teams.length === 0) {
      setError('Cannot resume game: missing teams data');
      return;
    }
    try {
      const fullTheme = await getTheme(game.theme_id);
      const gameState: GameState = {
        settings: {
          theme: fullTheme,
          selectedTeams: game.info.teams.map((team) => team.name),
          difficulty: game.difficulty ?? 5,
          pointsRequired: game.points,
          roundTimer: game.round,
          skipPenalty: game.skip_penalty,
        },
        currentTeamIndex: game.info.current_team_index || 0,
        currentRound: game.info.current_round || game.round,
        teamScores: Object.fromEntries(game.info.teams.map((team) => [team.name, team.score])),
        wordsUsed: [...game.words_guessed, ...game.words_skipped],
        currentWordIndex: game.words_guessed.length + game.words_skipped.length,
        roundStartTime: null,
        roundEndTime: null,
        isRoundActive: false,
        isPaused: false,
        roundResults: [
          ...game.words_guessed.map((word) => ({ word, guessed: true })),
          ...game.words_skipped.map((word) => ({ word, guessed: false })),
        ],
      };
      onResumeGame(gameState, game.id);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load theme data');
    }
  };

  const mutedBorder = {
    backgroundColor: alpha(colors.text, 0.04),
    borderWidth: 1,
    borderColor: alpha(colors.text, 0.1),
  };

  if (selectedGame) {
    return (
      <Card className="w-full">
        <View className="mb-6 flex-row items-center justify-between">
          <Pressable
            onPress={() => setSelectedGame(null)}
            className="rounded-game px-4 py-2"
            style={{
              backgroundColor: alpha(colors.text, 0.06),
              borderWidth: 1,
              borderColor: alpha(colors.text, 0.15),
            }}
          >
            <Text className="font-semibold" style={{ color: colors.text }}>
              {t.gh_backToGames}
            </Text>
          </Pressable>
        </View>

        <View className="gap-6">
          <View>
            <Text className="mb-2 text-3xl font-bold" style={{ color: colors.text }}>
              {t.gh_gameDetails}
            </Text>
            <View className="flex-row flex-wrap items-center gap-4">
              <Text style={{ color: alpha(colors.text, 0.8) }}>
                {t.gh_theme(selectedGame.theme.name)}
              </Text>
              <Text style={{ color: alpha(colors.text, 0.8) }}>
                {t.gh_language(selectedGame.theme.language.toUpperCase())}
              </Text>
              <Text style={{ color: alpha(colors.text, 0.8) }}>
                {t.gh_pointsRequired(selectedGame.points)}
              </Text>
              <Text style={{ color: alpha(colors.text, 0.8) }}>
                {t.gh_skipPenalty(selectedGame.skip_penalty)}
              </Text>
            </View>
            <Text className="mt-2" style={{ color: alpha(colors.text, 0.6) }}>
              {t.gh_started(formatDate(selectedGame.started_at))}
              {selectedGame.ended_at ? `  ${t.gh_ended(formatDate(selectedGame.ended_at))}` : ''}
            </Text>
          </View>

          <View className="gap-6">
            <View>
              <Text className="mb-4 text-xl font-semibold" style={{ color: colors.text }}>
                {t.gh_teams}
              </Text>
              <View className="rounded-game p-4" style={mutedBorder}>
                {selectedGame.info?.teams && selectedGame.info.teams.length > 0 ? (
                  selectedGame.info.teams.map((team, index) => (
                    <Text key={index} className="mb-2" style={{ color: alpha(colors.text, 0.8) }}>
                      {t.gh_teamScore(team.name, team.score)}
                    </Text>
                  ))
                ) : (
                  <Text style={{ color: alpha(colors.text, 0.6) }}>{t.gh_noTeams}</Text>
                )}
              </View>
            </View>

            <View>
              <Text className="mb-4 text-xl font-semibold" style={{ color: colors.text }}>
                {t.gh_gameStatus}
              </Text>
              <View className="rounded-game p-4" style={mutedBorder}>
                <Text className="mb-2" style={{ color: alpha(colors.text, 0.8) }}>
                  {t.gh_currentRound(selectedGame.info?.current_round || selectedGame.round)}
                </Text>
                <Text className="mb-2" style={{ color: alpha(colors.text, 0.8) }}>
                  {t.gh_currentTeam(
                    selectedGame.info?.teams && selectedGame.info.current_team_index !== undefined
                      ? selectedGame.info.teams[selectedGame.info.current_team_index]?.name ||
                          'Unknown'
                      : 'Unknown',
                  )}
                </Text>
                <Text className="mb-2" style={{ color: alpha(colors.text, 0.8) }}>
                  {selectedGame.ended_at ? t.gh_completed : t.gh_inProgress}
                </Text>
              </View>
            </View>
          </View>

          {!selectedGame.ended_at && (
            <View className="items-center">
              <Pressable
                onPress={() => handleResumeGame(selectedGame)}
                className="rounded-game px-6 py-2"
                style={{ backgroundColor: colors.success }}
              >
                <Text className="font-semibold" style={{ color: colors.white }}>
                  {t.gh_resumeGame}
                </Text>
              </Pressable>
            </View>
          )}
        </View>
      </Card>
    );
  }

  if (isLoading) {
    return (
      <Card className="w-full p-8">
        <Text className="text-center" style={{ color: alpha(colors.text, 0.8) }}>
          {t.gh_loading}
        </Text>
      </Card>
    );
  }

  if (error) {
    return (
      <Card className="w-full p-8">
        <Text className="mb-4 text-center" style={{ color: colors.error }}>
          {error}
        </Text>
        <Pressable
          onPress={onBack}
          className="self-center rounded-game px-6 py-2"
          style={{ backgroundColor: colors.success }}
        >
          <Text className="font-semibold" style={{ color: colors.white }}>
            {t.gh_back}
          </Text>
        </Pressable>
      </Card>
    );
  }

  return (
    <Card className="w-full">
      <View className="mb-6 flex-row flex-wrap items-center justify-between gap-3">
        <Text className="text-3xl font-bold" style={{ color: colors.text }}>
          {t.gh_title}
        </Text>
        <Pressable
          onPress={onBack}
          className="rounded-game px-4 py-2"
          style={{
            backgroundColor: alpha(colors.text, 0.06),
            borderWidth: 1,
            borderColor: alpha(colors.text, 0.15),
          }}
        >
          <Text className="font-semibold" style={{ color: colors.text }}>
            {t.gh_back}
          </Text>
        </Pressable>
      </View>

      {games.length === 0 ? (
        <Text className="py-8 text-center" style={{ color: alpha(colors.text, 0.6) }}>
          {t.gh_noGames}
        </Text>
      ) : (
        <View className="gap-4">
          {games.map((game) => (
            <Pressable
              key={game.id}
              className="rounded-game p-4"
              style={mutedBorder}
              onPress={() => handleViewDetails(game)}
            >
              <View className="gap-4">
                <View>
                  <Text className="mb-2 font-semibold" style={{ color: colors.text }}>
                    {game.theme.name}
                  </Text>
                  <Text className="mb-2 text-sm" style={{ color: alpha(colors.text, 0.6) }}>
                    {t.gh_language(game.theme.language.toUpperCase())}
                  </Text>
                  <Text className="text-sm" style={{ color: alpha(colors.text, 0.6) }}>
                    {t.gh_started(formatDate(game.started_at))}
                    {game.ended_at ? `  ${t.gh_ended(formatDate(game.ended_at))}` : ''}
                  </Text>
                </View>
                <View>
                  <Text className="text-sm" style={{ color: alpha(colors.text, 0.8) }}>
                    {t.gh_pointsRequired(game.points)}
                  </Text>
                  <Text className="text-sm" style={{ color: alpha(colors.text, 0.8) }}>
                    {t.gh_roundTime(game.round)}
                  </Text>
                  <Text className="text-sm" style={{ color: alpha(colors.text, 0.8) }}>
                    {t.gh_skipPenalty(game.skip_penalty)}
                  </Text>
                  <Text
                    className="text-sm"
                    style={{ color: game.ended_at ? colors.success : colors.error }}
                  >
                    {game.ended_at ? t.gh_completed : t.gh_inProgress}
                  </Text>
                </View>
              </View>
            </Pressable>
          ))}
        </View>
      )}
    </Card>
  );
}
