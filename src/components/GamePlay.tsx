import { useEffect, useRef, useState } from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';
import Animated, { FadeInUp, FadeOutUp, ZoomIn } from 'react-native-reanimated';
import { useLocale } from '../contexts/LocaleContext';
import { alpha, useTheme } from '../contexts/ThemeContext';
import type { GameState } from '../types';
import { Button } from '../ui/Button';
import { Countdown } from '../ui/Countdown';
import { Counter } from '../ui/Counter';
import {
  checkWinCondition,
  getAvailableWords,
  getCurrentTeam,
  shuffleArray,
} from '../utils/game';
import { storage } from '../utils/storage';
import { GamePlayCardStack } from './GamePlayCardStack';

interface GamePlayProps {
  gameState: GameState;
  setGameState: (state: GameState) => void;
  onRoundEnd: (results: { word: string; guessed: boolean }[], lastWord?: string) => void;
  onGameEnd: () => void;
}

export default function GamePlay({
  gameState,
  setGameState,
  onRoundEnd,
  onGameEnd,
}: GamePlayProps) {
  const { t } = useLocale();
  const { colors } = useTheme();
  const [currentWord, setCurrentWord] = useState('');
  const [roundWords, setRoundWords] = useState<string[]>([]);
  const [roundResults, setRoundResults] = useState<
    { word: string; guessed: boolean }[]
  >([]);
  const [currentTime, setCurrentTime] = useState(0);
  const [pausedRemainingTime, setPausedRemainingTime] = useState<number | null>(
    null,
  );
  const [roundPausedOnce, setRoundPausedOnce] = useState(false);
  const timerIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const roundResultsRef = useRef<{ word: string; guessed: boolean }[]>([]);
  const roundEndingRef = useRef(false);

  const [isCardExiting, setIsCardExiting] = useState(false);

  // Cheating detection
  const [cheatingDetected, setCheatingDetected] = useState(false);
  const roundStartTimeRef = useRef<number | null>(null);

  const availableWords = getAvailableWords(
    gameState.settings.theme,
    gameState.wordsUsed,
    gameState.settings.difficulty,
  );
  const currentTeam = getCurrentTeam(gameState);

  const remainingTime =
    gameState.isRoundActive && gameState.roundStartTime && !gameState.isPaused
      ? Math.max(
          0,
          Math.ceil(
            (gameState.settings.roundTimer * 1000 -
              (Date.now() - gameState.roundStartTime)) /
              1000,
          ),
        )
      : gameState.isPaused
        ? pausedRemainingTime || 0
        : 0;

  const startRound = () => {
    if (availableWords.length === 0) {
      const maxScore = Math.max(...Object.values(gameState.teamScores));
      const winners = Object.entries(gameState.teamScores)
        .filter(([, score]) => score === maxScore)
        .map(([team]) => team);

      if (winners.length > 0) {
        // Don't call onGameEnd - let the winner display handle it
        return;
      }

      onGameEnd();
      return;
    }

    roundEndingRef.current = false;
    const shuffled = shuffleArray([...availableWords]);
    setRoundWords(shuffled);
    const firstWord = shuffled[0] || '';
    setCurrentWord(firstWord);
    setRoundResults([]);
    roundResultsRef.current = [];
    setCheatingDetected(false);
    setRoundPausedOnce(false);
    roundStartTimeRef.current = Date.now();

    setGameState({
      ...gameState,
      isRoundActive: true,
      isPaused: false,
      roundStartTime: Date.now(),
      currentWordIndex: 0,
    });
  };

  const endRound = (timedOut = false) => {
    roundEndingRef.current = true;
    if (timerIntervalRef.current) {
      clearInterval(timerIntervalRef.current);
    }

    const roundEndResults = [...roundResultsRef.current];

    // If timed out and current word was never actioned, surface it separately
    // so the user can optionally credit it without any skip penalty
    const timedOutLastWord =
      timedOut && currentWord && !roundEndResults.some((r) => r.word === currentWord)
        ? currentWord
        : undefined;

    setGameState({
      ...gameState,
      isRoundActive: false,
      roundEndTime: Date.now(),
    });

    setCheatingDetected(false);
    roundStartTimeRef.current = null;

    setTimeout(() => {
      setRoundResults(roundEndResults);
      onRoundEnd(roundEndResults, timedOutLastWord);
    }, 100);
  };

  const endRoundRef = useRef(endRound);
  endRoundRef.current = endRound;

  useEffect(() => {
    if (
      gameState.isRoundActive &&
      gameState.roundStartTime !== null &&
      !gameState.isPaused
    ) {
      const startTime = gameState.roundStartTime;
      const roundTimer = gameState.settings.roundTimer;

      const tick = () => {
        if (startTime === null) return;

        const time = Math.max(
          0,
          Math.ceil((roundTimer * 1000 - (Date.now() - startTime)) / 1000),
        );
        setCurrentTime(time);

        if (time <= 0) {
          endRoundRef.current(true);
        }
      };

      tick();
      timerIntervalRef.current = setInterval(tick, 1000);

      return () => {
        if (timerIntervalRef.current) {
          clearInterval(timerIntervalRef.current);
        }
      };
    } else {
      setCurrentTime(0);
    }
  }, [
    gameState.isRoundActive,
    gameState.roundStartTime,
    gameState.isPaused,
    gameState.settings.roundTimer,
  ]);

  const stopRound = () => {
    if (timerIntervalRef.current) {
      clearInterval(timerIntervalRef.current);
    }

    const currentRemaining = Math.max(
      0,
      Math.ceil(
        (gameState.settings.roundTimer * 1000 -
          (Date.now() - (gameState.roundStartTime || 0))) /
          1000,
      ),
    );
    setPausedRemainingTime(currentRemaining);

    // Shuffle all remaining words including current word as penalty
    const remainingWords = roundWords.slice(roundResults.length);
    const shuffledRemaining = shuffleArray(remainingWords);
    const newRoundWords = [
      ...roundWords.slice(0, roundResults.length),
      ...shuffledRemaining,
    ];

    setRoundWords(newRoundWords);
    const newCurrentWord = shuffledRemaining[0] || '';
    setCurrentWord(newCurrentWord);

    setRoundPausedOnce(true);

    const updatedState = {
      ...gameState,
      isPaused: true,
      roundStartTime: null,
    };

    setGameState(updatedState);

    // Save to local storage (but don't send to API)
    storage.saveGameState(updatedState);
  };

  const resumeRound = () => {
    const remainingSeconds = pausedRemainingTime || 0;
    const newStartTime =
      Date.now() - (gameState.settings.roundTimer - remainingSeconds) * 1000;

    const updatedState = {
      ...gameState,
      isPaused: false,
      roundStartTime: newStartTime,
    };

    setGameState(updatedState);
    setPausedRemainingTime(null);

    storage.clearGameState();
  };

  const checkForCheating = (guessedWordsCount: number): boolean => {
    if (!roundStartTimeRef.current) return false;

    const elapsedSeconds = Math.floor(
      (Date.now() - roundStartTimeRef.current) / 1000,
    );

    return guessedWordsCount > elapsedSeconds;
  };

  /** Same cadence as web (100ms) so the next card rises under the exiting one */
  const CARD_ADVANCE_MS = 100;

  const handleWordAction = (guessed: boolean) => {
    if (!currentWord || isCardExiting || cheatingDetected) return;

    setIsCardExiting(true);

    setTimeout(() => {
      if (roundEndingRef.current) return;
      const newResults = [...roundResults, { word: currentWord, guessed }];
      setRoundResults(newResults);
      roundResultsRef.current = newResults;

      const guessedCount = newResults.filter((r) => r.guessed).length;
      const isCheating = checkForCheating(guessedCount);

      if (isCheating) {
        setCheatingDetected(true);
        setIsCardExiting(false);
        setCurrentWord('');
        return;
      }

      const nextIndex = gameState.currentWordIndex + 1;

      if (nextIndex >= roundWords.length) {
        setIsCardExiting(false);
        endRound();
        return;
      }

      const nextWordValue = roundWords[nextIndex];
      setCurrentWord(nextWordValue);
      setGameState({
        ...gameState,
        currentWordIndex: nextIndex,
      });
      setIsCardExiting(false);
    }, CARD_ADVANCE_MS);
  };

  // Check for winners: either reached target score or no words left
  let winners: string[] = [];

  const targetWinners = checkWinCondition(gameState);
  if (targetWinners.length > 0) {
    winners = targetWinners;
  } else if (availableWords.length === 0) {
    const maxScore = Math.max(...Object.values(gameState.teamScores));
    winners = Object.entries(gameState.teamScores)
      .filter(([, score]) => score === maxScore)
      .map(([team]) => team);
  }

  const displaySeconds = currentTime || remainingTime;
  const timerWarning =
    displaySeconds <= 5 && displaySeconds > 0 && !gameState.isPaused;
  const guessedThisRound = roundResults.filter((r) => r.guessed).length;
  const skippedThisRound = roundResults.filter((r) => !r.guessed).length;

  const backWord =
    !roundEndingRef.current &&
    gameState.isRoundActive &&
    !gameState.isPaused &&
    gameState.currentWordIndex + 1 < roundWords.length
      ? roundWords[gameState.currentWordIndex + 1]
      : null;

  if (winners.length > 0) {
    return (
      <View className="flex-1 p-4">
        <ScrollView className="flex-1" contentContainerStyle={{ paddingBottom: 80 }}>
          <Animated.View entering={ZoomIn.duration(500)}>
            <View
              className="w-full gap-6 rounded-game p-8"
              style={{
                backgroundColor: colors.card,
                borderWidth: 1,
                borderColor: alpha(colors.text, 0.1),
              }}
            >
              <Text className="mb-3 text-center text-5xl">🎉</Text>
              <Text className="mb-4 text-center text-4xl font-bold" style={{ color: colors.text }}>
                {t.gp_gameOver}
              </Text>
              <Text
                className="mb-6 text-center text-2xl font-semibold"
                style={{ color: colors.success }}
              >
                {winners.length === 1
                  ? t.gp_singleWinner(winners[0])
                  : t.gp_multipleWinners(winners.join(' & '))}
              </Text>

              <View className="gap-3">
                {Object.entries(gameState.teamScores).map(([team, score]) => (
                  <View
                    key={team}
                    className="flex-row items-center justify-between rounded-game p-3"
                    style={{
                      backgroundColor: alpha(colors.text, 0.04),
                      borderWidth: 1,
                      borderColor: alpha(colors.text, 0.1),
                    }}
                  >
                    <Text
                      className="flex-1 text-base font-semibold"
                      numberOfLines={1}
                      style={{ color: colors.text }}
                    >
                      {team}
                    </Text>
                    <Text className="ml-2 text-lg font-bold" style={{ color: colors.success }}>
                      {score}
                    </Text>
                  </View>
                ))}
              </View>
            </View>
          </Animated.View>
        </ScrollView>

        <View className="absolute bottom-4 left-0 right-0 items-center">
          <Pressable
            onPress={onGameEnd}
            className="rounded-game px-6 py-3"
            style={{ backgroundColor: colors.success }}
          >
            <Text className="font-semibold" style={{ color: colors.white }}>
              {t.gp_newGame}
            </Text>
          </Pressable>
        </View>
      </View>
    );
  }

  if (!gameState.isRoundActive && !roundEndingRef.current) {
    return (
      <View className="flex-1 items-center justify-center p-4">
        <Animated.View entering={ZoomIn.duration(300)} className="w-full max-w-md">
          <View
            className="w-full gap-6 rounded-game p-8"
            style={{
              backgroundColor: colors.card,
              borderWidth: 1,
              borderColor: alpha(colors.text, 0.1),
            }}
          >
            <Text className="text-center text-3xl font-bold" style={{ color: colors.text }}>
              {t.gp_round(gameState.currentRound)}
            </Text>
            <Text
              className="text-center text-lg font-bold"
              numberOfLines={1}
              style={{ color: colors.success }}
            >
              {currentTeam}
            </Text>

            <View
              className="gap-4 rounded-game p-6"
              style={{
                backgroundColor: alpha(colors.text, 0.04),
                borderWidth: 1,
                borderColor: alpha(colors.text, 0.1),
              }}
            >
              <Text className="text-lg font-semibold" style={{ color: colors.text }}>
                {t.gp_currentScores}
              </Text>
              {Object.entries(gameState.teamScores).map(([team, score]) => (
                <View key={team} className="flex-row items-center justify-between">
                  <Text style={{ color: colors.text }}>{team}</Text>
                  <Text className="font-bold" style={{ color: colors.text }}>
                    {t.gp_score(score, gameState.settings.pointsRequired)}
                  </Text>
                </View>
              ))}
            </View>

            <Text className="text-center" style={{ color: alpha(colors.text, 0.7) }}>
              {t.gp_wordsRemaining(availableWords.length)}
            </Text>

            <Button variant="success" onPress={startRound} textStyle={{ fontSize: 20 }}>
              {t.gp_startRound}
            </Button>
          </View>
        </Animated.View>
      </View>
    );
  }

  return (
    <View className="flex-1 items-center justify-center overflow-hidden p-2">
      <View className="absolute left-0 right-0 top-0 flex-row items-center justify-between p-2">
        <Text className="text-base font-semibold" style={{ color: colors.text }}>
          {t.gp_round(gameState.currentRound)}
        </Text>
        <Text
          className="max-w-[200px] text-base font-bold"
          numberOfLines={1}
          style={{ color: colors.success }}
        >
          {currentTeam}
        </Text>
      </View>

      <View className="absolute left-0 right-0 top-10 items-center gap-2">
        <Countdown seconds={displaySeconds} isWarning={timerWarning} suffix="s" />
        <View className="flex-row items-center gap-6">
          <View className="items-center gap-0.5">
            <Counter variant="error" value={skippedThisRound} />
            <Text className="text-xs" style={{ color: alpha(colors.text, 0.6) }}>
              {t.gp_skipped}
            </Text>
          </View>
          <Text className="pt-1 text-xs" style={{ color: alpha(colors.text, 0.6) }}>
            {roundResults.length} / {roundWords.length}
          </Text>
          <View className="items-center gap-0.5">
            <Counter variant="success" value={guessedThisRound} />
            <Text className="text-xs" style={{ color: alpha(colors.text, 0.6) }}>
              {t.gp_guessed}
            </Text>
          </View>
        </View>
      </View>

      {cheatingDetected && (
        <Animated.View
          entering={FadeInUp.duration(300)}
          exiting={FadeOutUp.duration(300)}
          className="absolute left-4 right-4 top-28 z-10 rounded-game px-4 py-3"
          style={{
            backgroundColor: colors.card,
            borderWidth: 1,
            borderColor: alpha(colors.error, 0.4),
          }}
        >
          <Text className="text-center text-sm font-semibold" style={{ color: colors.error }}>
            {t.gp_cheatingDetected}
          </Text>
        </Animated.View>
      )}

      {gameState.isPaused && (
        <Animated.View
          entering={FadeInUp.duration(300)}
          exiting={FadeOutUp.duration(300)}
          className="absolute left-4 right-4 top-32 z-10 rounded-game px-4 py-3"
          style={{
            backgroundColor: colors.card,
            borderWidth: 1,
            borderColor: alpha(colors.text, 0.2),
          }}
        >
          <Text className="text-center text-sm font-semibold" style={{ color: colors.text }}>
            {t.gp_roundPaused}
          </Text>
        </Animated.View>
      )}

      <View className="mt-20 w-full items-center gap-4">
        <GamePlayCardStack
          currentIndex={gameState.currentWordIndex}
          currentWord={currentWord}
          backWord={backWord}
          cardExitX={0}
          interactionLocked={isCardExiting}
          cheatingDetected={cheatingDetected}
          isPaused={gameState.isPaused}
          onSwipeCommit={handleWordAction}
        />

        {/* Action Buttons */}
        {!gameState.isPaused ? (
          <View className="z-20 mt-8 w-full max-w-[290px] gap-2 pb-2">
            <View className="w-full flex-row gap-3">
              <Button
                variant="error"
                disabled={cheatingDetected}
                onPress={() => handleWordAction(false)}
                style={{ flex: 1, paddingVertical: 12 }}
                textStyle={{ fontSize: 14 }}
              >
                {t.gp_skipBtn}
              </Button>
              <Button
                variant="success"
                disabled={cheatingDetected}
                onPress={() => handleWordAction(true)}
                style={{ flex: 1, paddingVertical: 12 }}
                textStyle={{ fontSize: 14 }}
              >
                {t.gp_guessedBtn}
              </Button>
            </View>

            <View className="items-center">
              <Button
                variant="muted"
                disabled={cheatingDetected || roundPausedOnce}
                onPress={stopRound}
                style={{ paddingHorizontal: 20, paddingVertical: 10, width: 'auto' }}
                textStyle={{ fontSize: 14 }}
              >
                ⏸️ {roundPausedOnce ? t.gp_paused : t.gp_pause}
              </Button>
            </View>
          </View>
        ) : (
          <View className="z-20 mt-6 w-full items-center pb-2">
            <Button
              variant="success"
              onPress={resumeRound}
              style={{ paddingHorizontal: 24, paddingVertical: 10, width: 'auto' }}
              textStyle={{ fontSize: 14 }}
            >
              {t.gp_resume}
            </Button>
          </View>
        )}
      </View>
    </View>
  );
}
