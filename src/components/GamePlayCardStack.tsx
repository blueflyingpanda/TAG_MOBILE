import { Dimensions, Text, View } from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Animated, {
  Easing,
  interpolate,
  runOnJS,
  useAnimatedStyle,
  useSharedValue,
  withSpring,
  withTiming,
  ZoomIn,
} from 'react-native-reanimated';
import { useLocale } from '../contexts/LocaleContext';
import { alpha, useTheme } from '../contexts/ThemeContext';

/** alias-main card-deck swipe (web parity) */
const SWIPE_PX = 100;
const SWIPE_VELOCITY = 500;

const CARD_SIZE = Math.min(300, Dimensions.get('window').width - 32);

export type GamePlayCardStackProps = {
  currentIndex: number;
  currentWord: string;
  backWord: string | null;
  cardExitX: number;
  interactionLocked: boolean;
  cheatingDetected: boolean;
  isPaused: boolean;
  onSwipeCommit: (guessed: boolean) => void;
};

/**
 * Two-layer deck: the back card sits scaled-down behind the front card; the
 * front card is draggable. On commit the front card flies out and the parent
 * advances the word (the new front mounts in place of the promoted back card).
 */
export function GamePlayCardStack({
  currentWord,
  backWord,
  interactionLocked,
  cheatingDetected,
  isPaused,
  onSwipeCommit,
}: GamePlayCardStackProps) {
  const { t } = useLocale();
  const { colors } = useTheme();

  const x = useSharedValue(0);
  const exiting = useSharedValue(0);

  const commit = (guessed: boolean) => {
    onSwipeCommit(guessed);
    // reset for the next card after the exit tween
    setTimeout(() => {
      x.value = 0;
      exiting.value = 0;
    }, 120);
  };

  const pan = Gesture.Pan()
    .enabled(!interactionLocked && !cheatingDetected && !isPaused)
    .onChange((e) => {
      if (exiting.value) return;
      x.value = Math.max(-280, Math.min(280, e.translationX));
    })
    .onEnd((e) => {
      if (exiting.value) return;
      const offsetX = e.translationX;
      const velocityX = e.velocityX;
      if (offsetX > SWIPE_PX || velocityX > SWIPE_VELOCITY) {
        exiting.value = 1;
        x.value = withTiming(CARD_SIZE * 1.2, { duration: 200, easing: Easing.inOut(Easing.ease) });
        runOnJS(commit)(true);
        return;
      }
      if (offsetX < -SWIPE_PX || velocityX < -SWIPE_VELOCITY) {
        exiting.value = 1;
        x.value = withTiming(-CARD_SIZE * 1.2, { duration: 200, easing: Easing.inOut(Easing.ease) });
        runOnJS(commit)(false);
        return;
      }
      x.value = withSpring(0, { stiffness: 400, damping: 30 });
    });

  const frontStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: x.value },
      { rotate: `${interpolate(x.value, [-220, 220], [-14, 14])}deg` },
      { scale: exiting.value ? withTiming(0.5, { duration: 200 }) : 1 },
    ],
    opacity: exiting.value ? withTiming(0, { duration: 200 }) : 1,
  }));

  const backStyle = useAnimatedStyle(() => {
    // back card rises as the front card travels away
    const progress = Math.min(1, Math.abs(x.value) / (SWIPE_PX * 2));
    return {
      transform: [
        { scale: 0.75 + 0.25 * progress * (exiting.value ? 1 : 0.3) },
        { translateY: 30 - 30 * progress * (exiting.value ? 1 : 0.3) },
      ],
      opacity: 0.5 + 0.5 * progress,
    };
  });

  const showStack = !!currentWord && !cheatingDetected && !isPaused;

  const cardFace = (word: string) => (
    <View
      className="h-full w-full items-center justify-center rounded-[15px] p-[10px]"
      style={{ backgroundColor: colors.card }}
    >
      <Text
        className="text-center text-lg font-semibold capitalize leading-tight"
        style={{ color: colors.text }}
      >
        {word}
      </Text>
    </View>
  );

  return (
    <View className="w-full items-center">
      <View className="h-[340px] w-full items-center overflow-hidden pt-4">
        <View style={{ width: CARD_SIZE, height: CARD_SIZE }}>
          {showStack && backWord && (
            <Animated.View
              key={`back-${backWord}`}
              className="absolute inset-0"
              style={backStyle}
            >
              {cardFace(backWord)}
            </Animated.View>
          )}

          {showStack && (
            <GestureDetector gesture={pan}>
              <Animated.View
                key={`front-${currentWord}`}
                className="absolute inset-0"
                style={[frontStyle, { zIndex: 1 }]}
              >
                {cardFace(currentWord)}
              </Animated.View>
            </GestureDetector>
          )}

          {cheatingDetected && (
            <Animated.View
              key="cheating-placeholder"
              entering={ZoomIn.duration(200)}
              className="absolute inset-0 items-center justify-center rounded-[15px] p-[10px]"
              style={{
                backgroundColor: alpha(colors.error, 0.1),
                borderWidth: 1,
                borderColor: alpha(colors.error, 0.3),
                zIndex: 2,
              }}
            >
              <View className="items-center gap-3">
                <Text className="text-5xl">⚠️</Text>
                <Text className="text-xl font-bold text-center" style={{ color: colors.text }}>
                  {t.cs_cheatingTitle}
                </Text>
                <Text className="text-center text-sm" style={{ color: alpha(colors.text, 0.7) }}>
                  {t.cs_cheatingDesc}
                </Text>
              </View>
            </Animated.View>
          )}

          {isPaused && (
            <Animated.View
              key="paused-placeholder"
              entering={ZoomIn.duration(200)}
              className="absolute inset-0 items-center justify-center rounded-[15px] p-[10px]"
              style={{
                backgroundColor: colors.card,
                borderWidth: 1,
                borderColor: alpha(colors.text, 0.15),
                zIndex: 2,
              }}
            >
              <View className="items-center gap-3">
                <Text className="text-5xl">⏸️</Text>
                <Text className="text-xl font-bold text-center" style={{ color: colors.text }}>
                  {t.cs_pausedTitle}
                </Text>
                <Text className="text-center text-sm" style={{ color: alpha(colors.text, 0.7) }}>
                  {t.cs_pausedDesc}
                </Text>
              </View>
            </Animated.View>
          )}
        </View>
      </View>
    </View>
  );
}
