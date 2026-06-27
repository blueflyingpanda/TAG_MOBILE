import { useEffect, useState } from 'react';
import { Pressable, ScrollView, Text, TextInput, View } from 'react-native';
import { useLocale } from '../contexts/LocaleContext';
import { alpha, useTheme } from '../contexts/ThemeContext';
import type { Theme, User } from '../types';
import { Card } from '../ui/Card';
import { Checkbox } from '../ui/controls';
import { getTheme, patchThemeVisibility, updateTheme } from '../utils/themes';

interface EditThemeProps {
  user: User;
  themeId: number;
  onBack: () => void;
  onSaved: (theme: Theme) => void;
}

export default function EditTheme({ user: _user, themeId, onBack, onSaved }: EditThemeProps) {
  const { t } = useLocale();
  const { colors } = useTheme();
  const [theme, setTheme] = useState<Theme | null>(null);
  const [loading, setLoading] = useState(true);
  const [name, setName] = useState('');
  const [isPublic, setIsPublic] = useState(false);
  const [newWordTexts, setNewWordTexts] = useState<string[]>(['']);
  const [isSaving, setIsSaving] = useState(false);
  const [isTogglingVisibility, setIsTogglingVisibility] = useState(false);
  const [error, setError] = useState('');
  const [visibilityError, setVisibilityError] = useState('');

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const data = await getTheme(themeId);
        if (cancelled) return;
        setTheme(data);
        setName(data.name);
        setIsPublic(data.public);
      } catch {
        if (!cancelled) setError(t.et_errFailed);
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, [themeId]);

  const handleVisibilityToggle = async (next: boolean) => {
    if (!theme || isTogglingVisibility) return;
    setVisibilityError('');
    setIsTogglingVisibility(true);
    try {
      const updated = await patchThemeVisibility(theme.id, { public: next });
      setIsPublic(updated.public);
      setTheme(updated);
    } catch (err) {
      setVisibilityError(
        err instanceof Error && err.message === 'forbidden'
          ? t.et_errForbidden
          : t.et_errVisibility,
      );
    } finally {
      setIsTogglingVisibility(false);
    }
  };

  const addWord = () => setNewWordTexts([...newWordTexts, '']);

  const updateWord = (i: number, val: string) => {
    const next = [...newWordTexts];
    next[i] = val;
    setNewWordTexts(next);
  };

  const removeWord = (i: number) => setNewWordTexts(newWordTexts.filter((_, idx) => idx !== i));

  const handleSave = async () => {
    if (!theme) return;
    setError('');

    if (!name.trim()) { setError(t.ct_errNameRequired); return; }
    if (name.length > 64) { setError(t.ct_errNameTooLong); return; }
    if (name.trim().split(/\s+/).length > 10) { setError(t.ct_errNameTooManyWords); return; }

    const validNew = newWordTexts.map((w) => w.trim()).filter(Boolean);

    for (const word of validNew) {
      if (word.length > 64) { setError(t.ct_errWordTooLong(word)); return; }
      if (word.split(/\s+/).length > 10) { setError(t.ct_errWordTooManyWords(word)); return; }
    }

    // Duplicates within new words
    const newLower = validNew.map((w) => w.toLowerCase());
    if (new Set(newLower).size !== newLower.length) {
      const seen = new Set<string>();
      const dupes = newLower.filter((w) => { if (seen.has(w)) return true; seen.add(w); return false; });
      setError(t.ct_errWordsDuplicate([...new Set(dupes)].map((w) => `"${w}"`).join(', ')));
      return;
    }

    // Duplicates against existing words
    const existingLower = new Set(Object.keys(theme.description.words).map((w) => w.toLowerCase()));
    const clashes = validNew.filter((w) => existingLower.has(w.toLowerCase()));
    if (clashes.length > 0) {
      setError(t.et_errWordDuplicate(clashes.slice(0, 3).map((w) => `"${w}"`).join(', ')));
      return;
    }

    setIsSaving(true);
    try {
      const mergedWords = {
        ...theme.description.words,
        ...Object.fromEntries(validNew.map((w) => [w, { difficulty: 1 as const }])),
      };
      const updated = await updateTheme(theme.id, {
        name: name.trim(),
        description: { words: mergedWords, teams: theme.description.teams },
      });
      onSaved(updated);
    } catch (err) {
      setError(
        err instanceof Error && err.message === 'forbidden'
          ? t.et_errForbidden
          : t.et_errFailed,
      );
    } finally {
      setIsSaving(false);
    }
  };

  const inputStyle = {
    backgroundColor: colors.card,
    borderWidth: 1,
    borderColor: alpha(colors.text, 0.15),
    color: colors.text,
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

  if (!theme) {
    return (
      <Card className="w-full p-8">
        <Text className="mb-4 text-center" style={{ color: colors.error }}>
          {error || t.td_notFound}
        </Text>
        <Pressable
          onPress={onBack}
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

  const existingWordList = Object.keys(theme.description.words);

  return (
    <Card className="w-full" style={{ flex: 1 }}>
      <ScrollView showsVerticalScrollIndicator={false}>
        <Text className="mb-6 text-center text-3xl font-bold" style={{ color: colors.text }}>
          {t.et_title}
        </Text>

        {error ? (
          <View
            className="mb-4 rounded-game p-4"
            style={{
              backgroundColor: alpha(colors.error, 0.1),
              borderWidth: 1,
              borderColor: alpha(colors.error, 0.4),
            }}
          >
            <Text className="text-sm" style={{ color: colors.error }}>
              {error}
            </Text>
          </View>
        ) : null}

        <View className="gap-6">
          {/* Name */}
          <View>
            <Text className="mb-2 font-semibold" style={{ color: colors.text }}>
              {t.et_nameLabel}
            </Text>
            <TextInput
              value={name}
              onChangeText={setName}
              placeholderTextColor={alpha(colors.text, 0.4)}
              className="w-full rounded-game px-4 py-2"
              style={inputStyle}
              maxLength={64}
            />
            <Text className="mt-1 text-xs" style={{ color: alpha(colors.text, 0.6) }}>
              {t.ct_nameCounter(
                name.length,
                name.trim().split(/\s+/).filter(Boolean).length,
              )}
            </Text>
          </View>

          {/* Visibility — calls PATCH immediately on toggle */}
          <View>
            <Text className="mb-2 font-semibold" style={{ color: colors.text }}>
              {t.et_visibilityLabel}
            </Text>
            <Checkbox
              checked={isPublic}
              onChange={isTogglingVisibility ? () => {} : handleVisibilityToggle}
              label={t.ct_makePublic}
            />
            {isTogglingVisibility && (
              <Text className="mt-1 text-sm" style={{ color: alpha(colors.text, 0.6) }}>
                {t.et_updatingVisibility}
              </Text>
            )}
            {visibilityError ? (
              <Text className="mt-1 text-sm" style={{ color: colors.error }}>
                {visibilityError}
              </Text>
            ) : null}
          </View>

          {/* Teams (read-only) */}
          <View>
            <Text className="mb-2 font-semibold" style={{ color: colors.text }}>
              {t.et_teamsLabel}
            </Text>
            <View
              className="rounded-game p-4"
              style={{
                backgroundColor: alpha(colors.text, 0.04),
                borderWidth: 1,
                borderColor: alpha(colors.text, 0.1),
              }}
            >
              <View className="flex-row flex-wrap gap-2">
                {theme.description.teams.map((team, i) => (
                  <View
                    key={i}
                    className="rounded-game p-2"
                    style={{ backgroundColor: colors.card, minWidth: '45%' }}
                  >
                    <Text className="text-sm" style={{ color: alpha(colors.text, 0.8) }}>
                      {team}
                    </Text>
                  </View>
                ))}
              </View>
            </View>
          </View>

          {/* Existing words (read-only) */}
          <View>
            <Text className="mb-2 font-semibold" style={{ color: colors.text }}>
              {t.et_existingWords(existingWordList.length)}
            </Text>
            <View
              style={{
                maxHeight: 192,
                backgroundColor: alpha(colors.text, 0.04),
                borderWidth: 1,
                borderColor: alpha(colors.text, 0.1),
                borderRadius: 8,
                padding: 16,
              }}
            >
              <ScrollView nestedScrollEnabled showsVerticalScrollIndicator={false}>
                <View className="flex-row flex-wrap gap-2">
                  {existingWordList.map((word, i) => (
                    <View
                      key={i}
                      className="rounded-game p-2"
                      style={{ backgroundColor: colors.card, minWidth: '30%' }}
                    >
                      <Text className="text-sm" style={{ color: alpha(colors.text, 0.7) }}>
                        {word}
                      </Text>
                    </View>
                  ))}
                </View>
              </ScrollView>
            </View>
          </View>

          {/* New words to add */}
          <View>
            <Text className="mb-1 font-semibold" style={{ color: colors.text }}>
              {t.et_addWordsLabel}
            </Text>
            <Text className="mb-3 text-sm" style={{ color: alpha(colors.text, 0.6) }}>
              {t.et_addWordsHint}
            </Text>
            <View className="gap-2">
              {newWordTexts.map((word, i) => (
                <View key={i} className="flex-row gap-2">
                  <TextInput
                    value={word}
                    onChangeText={(v) => updateWord(i, v)}
                    placeholder={t.ct_wordPlaceholder(i + 1)}
                    placeholderTextColor={alpha(colors.text, 0.4)}
                    className="flex-1 rounded-game px-4 py-2 text-sm"
                    style={inputStyle}
                    maxLength={64}
                  />
                  {newWordTexts.length > 1 && (
                    <Pressable
                      onPress={() => removeWord(i)}
                      className="justify-center rounded-game px-3 py-2"
                      style={{
                        backgroundColor: alpha(colors.error, 0.1),
                        borderWidth: 1,
                        borderColor: alpha(colors.error, 0.3),
                      }}
                    >
                      <Text className="text-sm font-semibold" style={{ color: colors.error }}>
                        ×
                      </Text>
                    </Pressable>
                  )}
                </View>
              ))}
            </View>
            <Pressable
              onPress={addWord}
              className="mt-2 rounded-game px-4 py-2"
              style={{ backgroundColor: colors.success, alignSelf: 'flex-start' }}
            >
              <Text className="font-semibold" style={{ color: colors.white }}>
                {t.ct_addWord}
              </Text>
            </Pressable>
          </View>

          {/* Actions */}
          <View className="flex-row gap-4 pb-4 pt-4">
            <Pressable
              onPress={onBack}
              disabled={isSaving}
              className="flex-1 items-center rounded-game px-6 py-3"
              style={{
                backgroundColor: alpha(colors.text, 0.06),
                borderWidth: 1,
                borderColor: alpha(colors.text, 0.15),
                opacity: isSaving ? 0.5 : 1,
              }}
            >
              <Text className="font-semibold" style={{ color: colors.text }}>
                {t.ct_cancel}
              </Text>
            </Pressable>
            <Pressable
              onPress={handleSave}
              disabled={isSaving}
              className="flex-1 items-center rounded-game px-6 py-3"
              style={{ backgroundColor: colors.success, opacity: isSaving ? 0.5 : 1 }}
            >
              <Text className="font-semibold" style={{ color: colors.white }}>
                {isSaving ? t.et_saving : t.et_save}
              </Text>
            </Pressable>
          </View>
        </View>
      </ScrollView>
    </Card>
  );
}
