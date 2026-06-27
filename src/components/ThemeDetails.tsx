import { useEffect, useState } from 'react';
import { Pressable, ScrollView, Share, Text, View } from 'react-native';
import { useLocale } from '../contexts/LocaleContext';
import { alpha, useTheme } from '../contexts/ThemeContext';
import type { Theme, User } from '../types';
import { Card } from '../ui/Card';
import { addThemeToFavorites, getTheme, removeThemeFromFavorites } from '../utils/themes';
import type { ThemeFilters } from './ThemeSelection';

interface ThemeDetailsProps {
  user: User;
  themeId: number;
  onBack: (filters?: ThemeFilters) => void;
  onThemeSelect?: (theme: Theme) => void;
  onEdit?: () => void;
  filters?: ThemeFilters;
}

export default function ThemeDetails({
  user,
  themeId,
  onBack,
  onThemeSelect,
  onEdit,
  filters,
}: ThemeDetailsProps) {
  const { t } = useLocale();
  const { colors } = useTheme();
  const [theme, setTheme] = useState<Theme | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isTogglingFavorite, setIsTogglingFavorite] = useState(false);
  const wordList = theme ? Object.keys(theme.description.words) : [];

  useEffect(() => {
    const fetchThemeDetails = async () => {
      try {
        setLoading(true);
        const themeData = await getTheme(themeId);
        setTheme(themeData);
        setError(null);
      } catch (err) {
        console.error('Failed to fetch theme details:', err);
        setError(t.td_failedLoad);
      } finally {
        setLoading(false);
      }
    };
    fetchThemeDetails();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [themeId]);

  const handleToggleFavorite = async () => {
    if (!theme || isTogglingFavorite) return;
    try {
      setIsTogglingFavorite(true);
      if (theme.is_favorited) {
        await removeThemeFromFavorites(theme.id);
        setTheme({ ...theme, is_favorited: false, likes_count: (theme.likes_count || 0) - 1 });
      } else {
        await addThemeToFavorites(theme.id);
        setTheme({ ...theme, is_favorited: true, likes_count: (theme.likes_count || 0) + 1 });
      }
    } catch (err) {
      console.error('Failed to toggle favorite:', err);
      setError(t.td_failedFavorite);
    } finally {
      setIsTogglingFavorite(false);
    }
  };

  if (loading) {
    return (
      <Card className="w-full p-8">
        <Text className="text-center" style={{ color: alpha(colors.text, 0.8) }}>
          {t.td_loading}
        </Text>
      </Card>
    );
  }

  if (error || !theme) {
    return (
      <Card className="w-full p-8">
        <Text className="mb-4 text-center" style={{ color: colors.error }}>
          {error || t.td_notFound}
        </Text>
        <Pressable
          onPress={() => onBack(filters)}
          className="self-start rounded-game px-6 py-2"
          style={{ backgroundColor: colors.success }}
        >
          <Text className="font-semibold" style={{ color: colors.white }}>
            {t.td_back}
          </Text>
        </Pressable>
      </Card>
    );
  }

  return (
    <Card className="w-full">
      <View className="mb-6 flex-row flex-wrap items-center justify-between gap-3">
        <Pressable
          onPress={() => onBack(filters)}
          className="rounded-game px-4 py-2"
          style={{
            backgroundColor: alpha(colors.text, 0.06),
            borderWidth: 1,
            borderColor: alpha(colors.text, 0.15),
          }}
        >
          <Text className="font-semibold" style={{ color: colors.text }}>
            {t.td_back}
          </Text>
        </Pressable>

        <View className="flex-row flex-wrap items-center gap-2">
          <Pressable
            onPress={() =>
              Share.share({
                url: `https://blueflyingpanda.github.io/TAG/theme/${theme.id}/`,
                message: `https://blueflyingpanda.github.io/TAG/theme/${theme.id}/`,
              })
            }
            className="rounded-game px-4 py-2"
            style={{
              backgroundColor: alpha(colors.text, 0.06),
              borderWidth: 1,
              borderColor: alpha(colors.text, 0.15),
            }}
          >
            <Text className="font-semibold" style={{ color: colors.text }}>
              {t.td_share}
            </Text>
          </Pressable>

          {onEdit && (user.admin || user.email === theme.creator?.email) && (
            <Pressable
              onPress={onEdit}
              className="rounded-game px-4 py-2"
              style={{
                backgroundColor: alpha(colors.text, 0.06),
                borderWidth: 1,
                borderColor: alpha(colors.text, 0.15),
              }}
            >
              <Text className="font-semibold" style={{ color: colors.text }}>
                {t.et_edit}
              </Text>
            </Pressable>
          )}

          {user && (
            <Pressable
              onPress={handleToggleFavorite}
              disabled={isTogglingFavorite}
              className="flex-row items-center gap-2 rounded-game px-4 py-2"
              style={
                theme.is_favorited
                  ? { backgroundColor: colors.error, opacity: isTogglingFavorite ? 0.5 : 1 }
                  : {
                      backgroundColor: alpha(colors.text, 0.06),
                      borderWidth: 1,
                      borderColor: alpha(colors.text, 0.15),
                      opacity: isTogglingFavorite ? 0.5 : 1,
                    }
              }
            >
              <Text
                className="font-semibold"
                style={{ color: theme.is_favorited ? colors.white : colors.text }}
              >
                {theme.is_favorited ? '❤️' : '🤍'} {theme.likes_count || 0}
              </Text>
            </Pressable>
          )}

          {onThemeSelect && (
            <Pressable
              onPress={() => onThemeSelect(theme)}
              className="rounded-game px-6 py-2"
              style={{ backgroundColor: colors.success }}
            >
              <Text className="font-semibold" style={{ color: colors.white }}>
                {t.td_select}
              </Text>
            </Pressable>
          )}
        </View>
      </View>

      <View className="gap-6">
        <View>
          <Text className="mb-2 text-3xl font-bold" style={{ color: colors.text }}>
            {theme.name}
          </Text>
          <View className="flex-row flex-wrap items-center gap-4">
            <Text style={{ color: alpha(colors.text, 0.8) }}>
              {t.td_language(theme.language.toUpperCase())}
            </Text>
            <Text style={{ color: alpha(colors.text, 0.8) }}>
              {theme.verified ? t.td_verified : t.td_unverified}
            </Text>
            <Text style={{ color: alpha(colors.text, 0.8) }}>
              {t.td_visibility(theme.public)}
            </Text>
          </View>
          {theme.creator && (
            <Text className="mt-2" style={{ color: alpha(colors.text, 0.6) }}>
              {t.td_createdBy(theme.creator.email)}
            </Text>
          )}
        </View>

        <View className="gap-6">
          <View>
            <Text className="mb-4 text-xl font-semibold" style={{ color: colors.text }}>
              {t.td_teams(theme.description.teams.length)}
            </Text>
            <View
              className="max-h-64 rounded-game p-4"
              style={{
                backgroundColor: alpha(colors.text, 0.04),
                borderWidth: 1,
                borderColor: alpha(colors.text, 0.1),
              }}
            >
              <ScrollView nestedScrollEnabled>
                <View className="flex-row flex-wrap gap-2">
                  {theme.description.teams.map((team, index) => (
                    <View
                      key={index}
                      className="rounded-game p-2"
                      style={{ backgroundColor: colors.card, minWidth: '45%' }}
                    >
                      <Text className="text-sm" style={{ color: alpha(colors.text, 0.8) }}>
                        {team}
                      </Text>
                    </View>
                  ))}
                </View>
              </ScrollView>
            </View>
          </View>

          <View>
            <Text className="mb-4 text-xl font-semibold" style={{ color: colors.text }}>
              {t.td_words(wordList.length)}
            </Text>
            <View
              className="max-h-64 rounded-game p-4"
              style={{
                backgroundColor: alpha(colors.text, 0.04),
                borderWidth: 1,
                borderColor: alpha(colors.text, 0.1),
              }}
            >
              <ScrollView nestedScrollEnabled>
                <View className="flex-row flex-wrap gap-2">
                  {wordList.slice(0, 50).map((word, index) => (
                    <View
                      key={index}
                      className="rounded-game p-2"
                      style={{ backgroundColor: colors.card, minWidth: '30%' }}
                    >
                      <Text className="text-sm" style={{ color: alpha(colors.text, 0.8) }}>
                        {word}
                      </Text>
                    </View>
                  ))}
                  {wordList.length > 50 && (
                    <Text
                      className="w-full p-2 text-center text-sm"
                      style={{ color: alpha(colors.text, 0.6) }}
                    >
                      {t.td_moreWords(wordList.length - 50)}
                    </Text>
                  )}
                </View>
              </ScrollView>
            </View>
          </View>
        </View>
      </View>
    </Card>
  );
}
