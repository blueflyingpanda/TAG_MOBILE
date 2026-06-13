import { useRef, useState } from 'react';
import { Modal, Pressable, ScrollView, Text, TextInput, View } from 'react-native';
import { useLocale } from '../contexts/LocaleContext';
import { alpha, useTheme } from '../contexts/ThemeContext';
import type { Theme, User } from '../types';
import { Card } from '../ui/Card';
import { Checkbox, OptionPills, StarRating } from '../ui/controls';
import { createTheme } from '../utils/themes';

interface CreateThemeProps {
  user: User;
  onBack: () => void;
  onThemeCreated?: (theme: Theme) => void;
}

export default function CreateTheme({ user: _user, onBack, onThemeCreated }: CreateThemeProps) {
  const { t } = useLocale();
  const { colors } = useTheme();
  const [lang, setLang] = useState('en');
  const [name, setName] = useState('');
  const [isPublic, setIsPublic] = useState(true);
  const [teams, setTeams] = useState<string[]>(['']);
  const [words, setWords] = useState<{ text: string; difficulty: number }[]>([
    { text: '', difficulty: 1 },
  ]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [showImportText, setShowImportText] = useState(false);
  const [importText, setImportText] = useState('');
  const scrollRef = useRef<ScrollView>(null);

  const validateTheme = (): string | null => {
    if (!name.trim()) return t.ct_errNameRequired;
    if (name.length > 64) return t.ct_errNameTooLong;
    const nameWords = name.trim().split(/\s+/);
    if (nameWords.length > 10) return t.ct_errNameTooManyWords;

    const validTeams = teams.filter((t) => t.trim());
    if (validTeams.length !== 10) return t.ct_errTeamsCount;

    const teamNameMap = new Map<string, string[]>();
    for (const team of validTeams) {
      const lower = team.trim().toLowerCase();
      if (!teamNameMap.has(lower)) teamNameMap.set(lower, []);
      teamNameMap.get(lower)!.push(team.trim());
    }
    const duplicateTeams = Array.from(teamNameMap.entries())
      .filter(([, originals]) => originals.length > 1)
      .map(([_lower, originals]) => `"${originals[0]}"`);
    if (duplicateTeams.length > 0) return t.ct_errTeamsDuplicate(duplicateTeams.join(', '));

    for (const team of validTeams) {
      if (team.length > 64) return t.ct_errTeamNameTooLong(team);
      if (team.trim().split(/\s+/).length > 10) return t.ct_errTeamNameTooManyWords(team);
    }

    const validWords = words.filter((w) => w.text.trim());
    const difficultyOneWords = validWords.filter((w) => w.difficulty === 1);
    if (difficultyOneWords.length < 30) return t.ct_errWordsMin;

    const wordMap = new Map<string, string[]>();
    for (const word of validWords) {
      const lower = word.text.trim().toLowerCase();
      if (!wordMap.has(lower)) wordMap.set(lower, []);
      wordMap.get(lower)!.push(word.text.trim());
    }
    const duplicateWords = Array.from(wordMap.entries())
      .filter(([, originals]) => originals.length > 1)
      .map(([_lower, originals]) => `"${originals[0]}"`);
    if (duplicateWords.length > 0) return t.ct_errWordsDuplicate(duplicateWords.join(', '));

    for (const word of validWords) {
      if (word.text.length > 64) return t.ct_errWordTooLong(word.text);
      if (word.text.trim().split(/\s+/).length > 10) return t.ct_errWordTooManyWords(word.text);
      if (word.difficulty < 1 || word.difficulty > 5) return t.ct_errWordDifficulty(word.text);
    }

    return null;
  };

  const handleSubmit = async () => {
    setError('');
    const validationError = validateTheme();
    if (validationError) {
      setError(validationError);
      scrollRef.current?.scrollTo({ y: 0, animated: true });
      return;
    }

    setIsSubmitting(true);
    const themePayload = {
      name: name.trim(),
      language: lang,
      public: isPublic,
      description: {
        words: Object.fromEntries(
          words
            .filter((w) => w.text.trim())
            .map((w) => [w.text.trim(), { difficulty: w.difficulty }]),
        ),
        teams: teams.filter((t) => t.trim()).map((t) => t.trim()),
      },
    };

    try {
      const createdTheme = await createTheme(themePayload);
      if (onThemeCreated) onThemeCreated(createdTheme);
      onBack();
    } catch (err) {
      setError(err instanceof Error ? err.message : t.ct_errFailed);
    } finally {
      setIsSubmitting(false);
    }
  };

  const addTeam = () => setTeams([...teams, '']);

  const removeTeam = (index: number) => {
    if (teams.length > 1) setTeams(teams.filter((_, i) => i !== index));
  };

  const updateTeam = (index: number, value: string) => {
    const newTeams = [...teams];
    newTeams[index] = value;
    setTeams(newTeams);
  };

  const addWord = () => setWords([...words, { text: '', difficulty: 1 }]);
  const removeWord = (index: number) => setWords(words.filter((_, i) => i !== index));

  const updateWord = (index: number, value: string) => {
    const newWords = [...words];
    newWords[index] = { ...newWords[index], text: value };
    setWords(newWords);
  };

  const updateWordDifficulty = (index: number, difficulty: number) => {
    const newWords = [...words];
    newWords[index] = { ...newWords[index], difficulty };
    setWords(newWords);
  };

  const importWords = (text: string) => {
    const imported = text
      .split('\n')
      .map((line) => line.trim())
      .filter((line) => line.length > 0)
      .map((line) => ({ text: line, difficulty: 1 }));
    setWords([...words.filter((w) => w.text.trim()), ...imported]);
  };

  const inputStyle = {
    backgroundColor: colors.card,
    borderWidth: 1,
    borderColor: alpha(colors.text, 0.15),
    color: colors.text,
  };

  return (
    <Card className="w-full" style={{ flex: 1 }}>
      <ScrollView ref={scrollRef} showsVerticalScrollIndicator={false}>
        <Text className="mb-6 text-center text-3xl font-bold" style={{ color: colors.text }}>
          {t.ct_title}
        </Text>
        <Text className="mb-6 text-center text-sm" style={{ color: alpha(colors.text, 0.6) }}>
          {t.ct_unverifiedNote}
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
          <View>
            <Text className="mb-2 font-semibold" style={{ color: colors.text }}>
              {t.ct_language}
            </Text>
            <OptionPills
              options={[
                { value: 'en', label: t.ts_langEnglish },
                { value: 'ru', label: t.ts_langRussian },
              ]}
              value={lang}
              onChange={setLang}
            />
          </View>

          <View>
            <Text className="mb-2 font-semibold" style={{ color: colors.text }}>
              {t.ct_public}
            </Text>
            <Checkbox checked={isPublic} onChange={setIsPublic} label={t.ct_makePublic} />
          </View>

          <View>
            <Text className="mb-2 font-semibold" style={{ color: colors.text }}>
              {t.ct_nameLabel}
            </Text>
            <TextInput
              value={name}
              onChangeText={setName}
              placeholder={t.ct_namePlaceholder}
              placeholderTextColor={alpha(colors.text, 0.4)}
              className="w-full rounded-game px-4 py-2"
              style={inputStyle}
              maxLength={64}
            />
            <Text className="mt-1 text-xs" style={{ color: alpha(colors.text, 0.6) }}>
              {t.ct_nameCounter(
                name.length,
                name
                  .trim()
                  .split(/\s+/)
                  .filter((w) => w).length,
              )}
            </Text>
          </View>

          <View>
            <Text className="mb-2 font-semibold" style={{ color: colors.text }}>
              {t.ct_teamsLabel}
            </Text>
            {teams.map((team, index) => (
              <View key={index} className="mb-2 flex-row gap-2">
                <TextInput
                  value={team}
                  onChangeText={(v) => updateTeam(index, v)}
                  placeholder={t.ct_teamPlaceholder(index + 1)}
                  placeholderTextColor={alpha(colors.text, 0.4)}
                  className="flex-1 rounded-game px-4 py-2"
                  style={inputStyle}
                  maxLength={64}
                />
                {teams.length > 1 && (
                  <Pressable
                    onPress={() => removeTeam(index)}
                    className="justify-center rounded-game px-4 py-2"
                    style={{
                      backgroundColor: alpha(colors.error, 0.1),
                      borderWidth: 1,
                      borderColor: alpha(colors.error, 0.3),
                    }}
                  >
                    <Text className="text-sm font-semibold" style={{ color: colors.error }}>
                      {t.ct_removeTeam}
                    </Text>
                  </Pressable>
                )}
              </View>
            ))}
            <View className="mt-2 flex-row items-center gap-2">
              <Pressable
                onPress={addTeam}
                disabled={teams.length >= 10}
                className="rounded-game px-4 py-2"
                style={{
                  backgroundColor: colors.success,
                  opacity: teams.length >= 10 ? 0.5 : 1,
                }}
              >
                <Text className="font-semibold" style={{ color: colors.white }}>
                  {t.ct_addTeam}
                </Text>
              </Pressable>
              <Text className="text-sm" style={{ color: alpha(colors.text, 0.6) }}>
                {t.ct_teamsCounter(teams.filter((t) => t.trim()).length, teams.length)}
              </Text>
            </View>
            {teams.filter((t) => t.trim()).length !== 10 && (
              <Text className="mt-2 text-sm" style={{ color: colors.error }}>
                {t.ct_teamsError}
              </Text>
            )}
          </View>

          <View>
            <Text className="mb-2 font-semibold" style={{ color: colors.text }}>
              {t.ct_wordsLabel}
            </Text>
            <View className="mb-2 flex-row">
              <Pressable
                onPress={() => setShowImportText(true)}
                className="rounded-game px-4 py-2"
                style={{
                  backgroundColor: alpha(colors.text, 0.06),
                  borderWidth: 1,
                  borderColor: alpha(colors.text, 0.15),
                }}
              >
                <Text className="text-sm font-semibold" style={{ color: colors.text }}>
                  {t.ct_importFromText}
                </Text>
              </Pressable>
            </View>
            <View className="mb-2 gap-2">
              {words.map((word, index) => (
                <View key={index} className="gap-2">
                  <View className="flex-row items-center gap-2">
                    <TextInput
                      value={word.text}
                      onChangeText={(v) => updateWord(index, v)}
                      placeholder={t.ct_wordPlaceholder(index + 1)}
                      placeholderTextColor={alpha(colors.text, 0.4)}
                      className="flex-1 rounded-game px-4 py-2 text-sm"
                      style={inputStyle}
                      maxLength={64}
                    />
                    <Pressable
                      onPress={() => removeWord(index)}
                      className="rounded-game px-3 py-2"
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
                  </View>
                  <View className="flex-row items-center gap-2 pl-1">
                    <Text className="text-sm" style={{ color: alpha(colors.text, 0.8) }}>
                      {t.ct_difficulty}
                    </Text>
                    <StarRating
                      value={word.difficulty}
                      onChange={(level) => updateWordDifficulty(index, level)}
                      size={18}
                    />
                  </View>
                </View>
              ))}
            </View>
            <View className="flex-row items-center gap-2">
              <Pressable
                onPress={addWord}
                className="rounded-game px-4 py-2"
                style={{ backgroundColor: colors.success }}
              >
                <Text className="font-semibold" style={{ color: colors.white }}>
                  {t.ct_addWord}
                </Text>
              </Pressable>
              <Text className="text-sm" style={{ color: alpha(colors.text, 0.6) }}>
                {t.ct_wordsCounter(
                  words.filter((w) => w.text.trim() && w.difficulty === 1).length,
                )}
              </Text>
            </View>
          </View>

          <View className="flex-row gap-4 pb-4 pt-4">
            <Pressable
              onPress={onBack}
              disabled={isSubmitting}
              className="flex-1 items-center rounded-game px-6 py-3"
              style={{
                backgroundColor: alpha(colors.text, 0.06),
                borderWidth: 1,
                borderColor: alpha(colors.text, 0.15),
                opacity: isSubmitting ? 0.5 : 1,
              }}
            >
              <Text className="font-semibold" style={{ color: colors.text }}>
                {t.ct_cancel}
              </Text>
            </Pressable>
            <Pressable
              onPress={handleSubmit}
              disabled={isSubmitting}
              className="flex-1 items-center rounded-game px-6 py-3"
              style={{ backgroundColor: colors.success, opacity: isSubmitting ? 0.5 : 1 }}
            >
              <Text className="font-semibold" style={{ color: colors.white }}>
                {isSubmitting ? t.ct_submitting : t.ct_submit}
              </Text>
            </Pressable>
          </View>
        </View>
      </ScrollView>

      {/* Import-from-text dialog (web used prompt()) */}
      <Modal
        visible={showImportText}
        transparent
        animationType="fade"
        onRequestClose={() => setShowImportText(false)}
      >
        <View
          className="flex-1 items-center justify-center p-4"
          style={{ backgroundColor: 'rgba(0,0,0,0.4)' }}
        >
          <View
            className="w-full rounded-game p-6"
            style={{
              backgroundColor: colors.card,
              borderWidth: 1,
              borderColor: alpha(colors.text, 0.15),
            }}
          >
            <Text className="mb-4 text-xl font-bold" style={{ color: colors.text }}>
              {t.ct_importFromText}
            </Text>
            <TextInput
              value={importText}
              onChangeText={setImportText}
              multiline
              textAlignVertical="top"
              className="h-48 w-full rounded-game p-4 text-sm"
              style={inputStyle}
            />
            <View className="mt-4 flex-row gap-4">
              <Pressable
                onPress={() => {
                  if (importText.trim()) importWords(importText);
                  setImportText('');
                  setShowImportText(false);
                }}
                className="rounded-game px-6 py-2"
                style={{ backgroundColor: colors.success }}
              >
                <Text className="font-semibold" style={{ color: colors.white }}>
                  {t.ct_addWord}
                </Text>
              </Pressable>
              <Pressable
                onPress={() => {
                  setImportText('');
                  setShowImportText(false);
                }}
                className="rounded-game px-6 py-2"
                style={{
                  backgroundColor: alpha(colors.text, 0.06),
                  borderWidth: 1,
                  borderColor: alpha(colors.text, 0.15),
                }}
              >
                <Text className="font-semibold" style={{ color: colors.text }}>
                  {t.ct_cancel}
                </Text>
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>
    </Card>
  );
}
