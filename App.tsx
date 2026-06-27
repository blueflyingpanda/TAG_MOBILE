import './global.css';
import 'react-native-url-polyfill/auto';

import { LinearGradient } from 'expo-linear-gradient';
import { StatusBar } from 'expo-status-bar';
import { useEffect, useState } from 'react';
import { Image, Pressable, ScrollView, Text, View } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider, useSafeAreaInsets } from 'react-native-safe-area-context';
import CreateTheme from './src/components/CreateTheme';
import EditTheme from './src/components/EditTheme';
import GameHistory from './src/components/GameHistory';
import GamePlay from './src/components/GamePlay';
import GameSetup from './src/components/GameSetup';
import Login from './src/components/Login';
import RoundResults from './src/components/RoundResults';
import Rules from './src/components/Rules';
import ThemeDetails from './src/components/ThemeDetails';
import ThemeSelection, { type ThemeFilters } from './src/components/ThemeSelection';
import { LocaleProvider, useLocale } from './src/contexts/LocaleContext';
import { alpha, ThemeProvider, useTheme } from './src/contexts/ThemeContext';
import type { GameSettings, GameState, Theme, User } from './src/types';
import { checkWinCondition, initializeGameState } from './src/utils/game';
import { createGame, updateGame } from './src/utils/games';
import {
  clearStoredToken,
  getCurrentUser,
  loadStoredToken,
  loginWithGoogle,
  setUnauthorizedHandler,
} from './src/utils/oauth';
import { storage } from './src/utils/storage';

type AppScreen =
  | 'login'
  | 'theme-selection'
  | 'theme-details'
  | 'edit-theme'
  | 'game-setup'
  | 'game-play'
  | 'round-results'
  | 'game-history'
  | 'create-theme'
  | 'rules';

function AppInner() {
  const { theme, colors, toggle: toggleTheme } = useTheme();
  const { t, locale, setLocale } = useLocale();
  const insets = useSafeAreaInsets();
  const [isReady, setIsReady] = useState(false);
  const [screen, setScreen] = useState<AppScreen>('login');
  const [user, setUser] = useState<User | null>(null);
  const [selectedTheme, setSelectedTheme] = useState<Theme | null>(null);
  const [selectedThemeId, setSelectedThemeId] = useState<number | null>(null);
  const [themeFilters, setThemeFilters] = useState<ThemeFilters | null>(null);
  const [gameState, setGameState] = useState<GameState | null>(null);
  const [roundLastWord, setRoundLastWord] = useState<string | null>(null);

  // Hide header buttons during round results confirmation and active rounds
  const hideHeaderButtons =
    screen === 'round-results' ||
    (screen === 'game-play' && (gameState?.isRoundActive ?? false));

  // Helper function to update game via API
  const updateGameViaAPI = async (state: GameState) => {
    try {
      const gameId = await storage.getCurrentGameId();
      if (!gameId) return;

      const gameIdNum = parseInt(gameId);
      if (isNaN(gameIdNum)) return; // Skip for local games

      const wordsGuessed: string[] = [];
      const wordsSkipped: string[] = [];

      state.roundResults.forEach((result) => {
        if (result.guessed) {
          wordsGuessed.push(result.word);
        } else {
          wordsSkipped.push(result.word);
        }
      });

      const updateData = {
        info: {
          teams: Object.entries(state.teamScores).map(([name, score]) => ({
            name,
            score,
          })),
          current_team_index: state.currentTeamIndex,
          current_round: state.currentRound,
        },
        words_guessed: wordsGuessed,
        words_skipped: wordsSkipped,
      };

      await updateGame(gameIdNum, updateData);
    } catch (error) {
      console.error('Failed to update game via API:', error);
      // Don't block gameplay if API update fails
    }
  };

  // Startup: restore token, user and any in-progress game
  useEffect(() => {
    const handleStartup = async () => {
      try {
        await loadStoredToken();
        const userData = getCurrentUser();
        if (userData) {
          await storage.saveUser(userData);
          setUser(userData);
          const savedState = await storage.getGameState();
          if (savedState) {
            setGameState(savedState);
            setScreen('game-play');
          } else {
            setScreen('theme-selection');
          }
        } else {
          setScreen('login');
        }
      } finally {
        setIsReady(true);
      }
    };
    handleStartup();
  }, []);

  useEffect(() => {
    if (gameState) {
      storage.saveGameState(gameState);
    }
  }, [gameState]);

  const handleLogout = () => {
    clearStoredToken();
    storage.clearUser();
    storage.clearGameState();
    storage.clearCurrentGameId();
    setUser(null);
    setGameState(null);
    setScreen('login');
  };

  useEffect(() => {
    setUnauthorizedHandler(handleLogout);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleLogin = async () => {
    try {
      const token = await loginWithGoogle();
      if (!token) return; // cancelled
      const userData = getCurrentUser();
      if (userData) {
        await storage.saveUser(userData);
        setUser(userData);
        setScreen('theme-selection');
      }
    } catch (err) {
      console.error('OAuth login failed:', err);
    }
  };

  const handleThemeSelect = (selected: Theme) => {
    setSelectedTheme(selected);
    setScreen('game-setup');
  };

  const handleGameStart = async (settings: GameSettings) => {
    const safeSettings = {
      ...settings,
      roundTimer: Math.max(settings.roundTimer, 15),
      difficulty: Math.max(1, Math.min(settings.difficulty, 5)),
      skipPenalty: !!settings.skipPenalty,
    };

    try {
      const gameData = {
        theme_id: settings.theme.id,
        difficulty: settings.difficulty,
        started_at: new Date().toISOString(),
        ended_at: null,
        points: settings.pointsRequired,
        round: settings.roundTimer,
        skip_penalty: settings.skipPenalty,
        info: {
          teams: settings.selectedTeams.map((team) => ({
            name: team,
            score: 0,
          })),
          current_team_index: 0,
          current_round: 0,
        },
      };

      const createdGame = await createGame(gameData);
      await storage.saveCurrentGameId(createdGame.id.toString());
    } catch (error) {
      console.error('Failed to create game:', error);
      // Fallback to local game creation if API fails
      const newGameId = `local_game_${Date.now()}_${Math.random()
        .toString(36)
        .substr(2, 9)}`;
      await storage.saveCurrentGameId(newGameId);
    }

    const newGameState = initializeGameState(safeSettings);
    setGameState(newGameState);
    setScreen('game-play');
  };

  const handleRoundEnd = (
    results: { word: string; guessed: boolean }[],
    lastWord?: string,
  ) => {
    if (!gameState) return;
    // Ignore late or duplicate end signals if the game already has a winner
    const existingWinners = checkWinCondition(gameState);
    if (existingWinners.length > 0) return;

    // If no words were processed and there's no last word to credit,
    // advance to the next team immediately.
    if (results.length === 0 && !lastWord) {
      const updatedState = { ...gameState };
      updatedState.currentTeamIndex =
        (updatedState.currentTeamIndex + 1) %
        updatedState.settings.selectedTeams.length;
      if (updatedState.currentTeamIndex === 0) {
        updatedState.currentRound += 1;
      }
      updatedState.roundResults = [];
      updatedState.isRoundActive = false;
      updatedState.roundStartTime = null;
      updatedState.currentWordIndex = 0;

      setGameState(updatedState);
      updateGameViaAPI(updatedState);
      setScreen('game-play');
      return;
    }

    setRoundLastWord(lastWord ?? null);
    setGameState({ ...gameState, roundResults: results });
    setScreen('round-results');
  };

  const handleRoundResultsConfirm = (
    finalResults: { word: string; guessed: boolean }[],
    lastWordGuessed: boolean | null,
  ) => {
    if (!gameState) return;

    const updatedState = { ...gameState };
    const currentTeam =
      gameState.settings.selectedTeams[gameState.currentTeamIndex];
    let scoreChange = 0;

    finalResults.forEach((result) => {
      if (result.guessed) {
        scoreChange += 1;
      } else if (gameState.settings.skipPenalty) {
        scoreChange -= 1;
      }
    });

    // Last word: +1 if guessed, no penalty and not tracked if not guessed
    const resultsForAPI = [...finalResults];
    if (lastWordGuessed && roundLastWord) {
      scoreChange += 1;
      updatedState.wordsUsed.push(roundLastWord);
      resultsForAPI.push({ word: roundLastWord, guessed: true });
    }
    setRoundLastWord(null);

    updatedState.teamScores[currentTeam] += scoreChange;
    updatedState.wordsUsed.push(...finalResults.map((r) => r.word));

    const winners = checkWinCondition(updatedState);

    if (winners.length > 0) {
      const tempStateForAPI = { ...updatedState, roundResults: resultsForAPI };
      updateGameViaAPI(tempStateForAPI);

      storage.clearGameState();
      setGameState(updatedState);
      setScreen('game-play'); // Will show winner screen
      return;
    }

    updatedState.currentTeamIndex =
      (updatedState.currentTeamIndex + 1) %
      updatedState.settings.selectedTeams.length;

    if (updatedState.currentTeamIndex === 0) {
      updatedState.currentRound += 1;
    }

    updatedState.roundResults = [];
    updatedState.isRoundActive = false;
    updatedState.roundStartTime = null;
    updatedState.currentWordIndex = 0;

    const tempStateForAPI = { ...updatedState, roundResults: resultsForAPI };
    updateGameViaAPI(tempStateForAPI);

    setGameState(updatedState);
    setScreen('game-play');
  };

  const handleGameEnd = async () => {
    if (gameState) {
      try {
        const gameId = await storage.getCurrentGameId();
        if (gameId && !isNaN(parseInt(gameId))) {
          const teams = Object.entries(gameState.teamScores).map(
            ([name, score]) => ({
              name,
              score,
            }),
          );

          const wordsGuessed: string[] = [];
          const wordsSkipped: string[] = [];

          gameState.roundResults.forEach((result) => {
            if (result.guessed) {
              wordsGuessed.push(result.word);
            } else {
              wordsSkipped.push(result.word);
            }
          });

          await updateGame(parseInt(gameId), {
            info: {
              teams,
              current_team_index: gameState.currentTeamIndex,
              current_round: gameState.currentRound,
            },
            words_guessed: wordsGuessed,
            words_skipped: wordsSkipped,
            ended_at: new Date().toISOString(),
          });
        }
      } catch (error) {
        console.error('Failed to end game via API:', error);
      }
    }

    await storage.clearGameState();
    await storage.clearCurrentGameId();
    setGameState(null);
    setSelectedTheme(null);
    setScreen('theme-selection');
  };

  const navButton = (label: string, target: AppScreen) => {
    const active = screen === target;
    return (
      <Pressable
        onPress={() => {
          if (active) return;
          setScreen(target);
          if (target === 'theme-selection') setSelectedTheme(null);
        }}
        className="rounded-game px-4 py-2"
        style={
          active
            ? { backgroundColor: colors.success }
            : {
                backgroundColor: colors.card,
                borderWidth: 1,
                borderColor: alpha(colors.text, 0.15),
              }
        }
      >
        <Text
          className="text-sm font-semibold"
          style={{ color: active ? colors.white : colors.text }}
        >
          {label}
        </Text>
      </Pressable>
    );
  };

  const content = (
    <>
      {user && (
        <View className="mb-4">
          <View className="flex-row items-center justify-between gap-2">
            {/* Language pill — left */}
            <Pressable
              onPress={() => setLocale(locale === 'en' ? 'ru' : 'en')}
              className="h-8 w-8 items-center justify-center rounded-full"
              style={{
                backgroundColor: alpha(colors.text, 0.07),
                borderWidth: 1,
                borderColor: alpha(colors.text, 0.15),
              }}
            >
              <Text className="text-base">{locale === 'en' ? '🇬🇧' : '🇷🇺'}</Text>
            </Pressable>

            {/* User info — center */}
            <View className="flex-row items-center gap-3">
              {user.picture && (
                <Image
                  source={{ uri: user.picture }}
                  className="h-8 w-8 rounded-full"
                  style={{ borderWidth: 2, borderColor: alpha(colors.text, 0.15) }}
                />
              )}
              <View>
                <Text className="text-sm font-semibold" style={{ color: colors.text }}>
                  {user.username}
                </Text>
                {user.email ? (
                  <Text className="text-sm" style={{ color: alpha(colors.text, 0.8) }}>
                    {user.email}
                  </Text>
                ) : null}
              </View>
            </View>

            {/* Dark mode toggle — right. Explicit pixel geometry so the thumb
                sits exactly over each icon: track inner width 54 (56 - 2px
                border), thumb 20 with a 3px inset, so it travels 54-20-3-3=28. */}
            <Pressable
              onPress={toggleTheme}
              style={{
                width: 56,
                height: 28,
                borderRadius: 14,
                borderWidth: 1,
                justifyContent: 'center',
                backgroundColor: alpha(colors.text, 0.07),
                borderColor: alpha(colors.text, 0.15),
              }}
            >
              {/* icons centered under the thumb's two rest positions */}
              <Text
                style={{ position: 'absolute', left: 3, width: 20, textAlign: 'center', fontSize: 12 }}
              >
                ☀️
              </Text>
              <Text
                style={{ position: 'absolute', left: 31, width: 20, textAlign: 'center', fontSize: 12 }}
              >
                🌙
              </Text>
              <View
                style={{
                  position: 'absolute',
                  left: 3,
                  width: 20,
                  height: 20,
                  borderRadius: 10,
                  backgroundColor: colors.card,
                  transform: [{ translateX: theme === 'dark' ? 28 : 0 }],
                  zIndex: 1,
                }}
              />
            </Pressable>
          </View>

          {!hideHeaderButtons && (
            <View className="mt-3 flex-row flex-wrap items-center justify-center gap-2">
              {navButton(t.nav_home, 'theme-selection')}
              {navButton(t.nav_history, 'game-history')}
              {navButton(t.nav_rules, 'rules')}
              <Pressable
                onPress={handleLogout}
                className="rounded-game px-4 py-2"
                style={{ backgroundColor: colors.error }}
              >
                <Text className="text-sm font-semibold" style={{ color: colors.white }}>
                  {t.nav_logout}
                </Text>
              </Pressable>
            </View>
          )}
        </View>
      )}

      {screen === 'login' && <Login onLogin={handleLogin} />}
      {screen === 'theme-selection' && user && (
        <ThemeSelection
          user={user}
          initialFilters={themeFilters ?? undefined}
          onThemeSelect={handleThemeSelect}
          onCreateTheme={() => setScreen('create-theme')}
          onThemeDetails={(themeId, filters) => {
            setSelectedThemeId(themeId);
            setThemeFilters(filters || null);
            setScreen('theme-details');
          }}
        />
      )}
      {screen === 'theme-details' && user && selectedThemeId && (
        <ThemeDetails
          user={user}
          themeId={selectedThemeId}
          filters={themeFilters || undefined}
          onBack={(filters) => {
            if (filters) setThemeFilters(filters);
            setScreen('theme-selection');
          }}
          onThemeSelect={handleThemeSelect}
          onEdit={() => setScreen('edit-theme')}
        />
      )}
      {screen === 'edit-theme' && user && selectedThemeId && (
        <EditTheme
          user={user}
          themeId={selectedThemeId}
          onBack={() => setScreen('theme-details')}
          onSaved={() => setScreen('theme-details')}
        />
      )}
      {screen === 'create-theme' && user && (
        <CreateTheme
          user={user}
          onBack={() => setScreen('theme-selection')}
          onThemeCreated={(created) => {
            console.log('Theme created and registered:', created);
            setScreen('theme-selection');
          }}
        />
      )}
      {screen === 'game-setup' && user && selectedTheme && (
        <GameSetup
          theme={selectedTheme}
          onStart={handleGameStart}
          onBack={() => setScreen('theme-selection')}
        />
      )}
      {screen === 'game-play' && user && gameState && (
        <GamePlay
          gameState={gameState}
          setGameState={setGameState}
          onRoundEnd={handleRoundEnd}
          onGameEnd={handleGameEnd}
        />
      )}
      {screen === 'round-results' && user && gameState && (
        <RoundResults
          results={gameState.roundResults}
          skipPenalty={Boolean(gameState.settings.skipPenalty)}
          lastWord={roundLastWord ?? undefined}
          onConfirm={handleRoundResultsConfirm}
        />
      )}
      {screen === 'game-history' && user && (
        <GameHistory
          onBack={() => setScreen('theme-selection')}
          onResumeGame={(resumedState, gameId) => {
            storage.saveCurrentGameId(gameId.toString());
            setGameState(resumedState);
            setScreen('game-play');
          }}
        />
      )}
      {screen === 'rules' && <Rules />}
    </>
  );

  const gameFullScreen =
    screen === 'game-play' || screen === 'round-results' || screen === 'create-theme';

  return (
    <View className="flex-1">
      <StatusBar style={theme === 'dark' ? 'light' : 'dark'} />
      <LinearGradient
        colors={[colors.bgStart, colors.bgMid, colors.bgEnd]}
        start={{ x: 0.85, y: 0 }}
        end={{ x: 0.15, y: 1 }}
        style={{ position: 'absolute', left: 0, right: 0, top: 0, bottom: 0 }}
      />
      {isReady && (
        <View
          className="flex-1"
          style={{
            paddingTop: insets.top + 8,
            paddingBottom: insets.bottom,
          }}
        >
          {gameFullScreen ? (
            <View className="flex-1 px-2">{content}</View>
          ) : (
            <ScrollView
              className="flex-1 px-4"
              contentContainerStyle={{ flexGrow: 1, justifyContent: 'center', paddingVertical: 8 }}
            >
              {content}
            </ScrollView>
          )}
        </View>
      )}
    </View>
  );
}

export default function App() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <ThemeProvider>
          <LocaleProvider>
            <AppInner />
          </LocaleProvider>
        </ThemeProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
