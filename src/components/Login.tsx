import { useState } from 'react';
import { Pressable, Text, View } from 'react-native';
import { alpha, useTheme } from '../contexts/ThemeContext';
import { Card } from '../ui/Card';

interface LoginProps {
  onLogin: () => Promise<void>;
}

export default function Login({ onLogin }: LoginProps) {
  const { colors } = useTheme();
  const [isLoading, setIsLoading] = useState(false);

  const handleGoogleLogin = async () => {
    setIsLoading(true);
    try {
      await onLogin();
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <View className="w-full flex-1 items-center justify-center px-4 py-4">
      <Card className="w-full max-w-[310px]">
        <View className="items-center">
          <Text className="mb-2 text-center text-3xl font-bold" style={{ color: colors.text }}>
            T.A.G.
          </Text>
          <Text className="mb-8 text-center" style={{ color: alpha(colors.text, 0.7) }}>
            Themed Alias Game
          </Text>

          <Pressable
            onPress={handleGoogleLogin}
            disabled={isLoading}
            className="w-full flex-row items-center justify-center gap-3 rounded-game px-6 py-4"
            style={{
              backgroundColor: '#ffffff',
              borderWidth: 1,
              borderColor: alpha(colors.text, 0.1),
              opacity: isLoading ? 0.5 : 1,
            }}
          >
            <Text className="text-lg">🔑</Text>
            <Text className="font-semibold" style={{ color: '#222222' }}>
              {isLoading ? 'Loading...' : 'Continue with Google'}
            </Text>
          </Pressable>
        </View>
      </Card>
    </View>
  );
}
