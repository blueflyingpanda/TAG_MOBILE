import { useCallback, useEffect, useState } from 'react';
import { Modal, Pressable, ScrollView, Text, TextInput, View } from 'react-native';
import { useLocale } from '../contexts/LocaleContext';
import { alpha, useTheme } from '../contexts/ThemeContext';
import type { Theme, ThemeListItem, ThemeOrderByType, User } from '../types';
import { ThemeOrderBy } from '../types';
import { Card } from '../ui/Card';
import { Checkbox, OptionPills } from '../ui/controls';
import { createTheme, getTheme, getThemes } from '../utils/themes';

/** Replaces the web URLSearchParams-based filter persistence */
export interface ThemeFilters {
  selectedLang: string;
  searchTerm: string;
  orderBy: ThemeOrderByType;
  orderDescending: boolean;
  onlyMyThemes: boolean;
  onlyFavorites: boolean;
  showUnverified: boolean;
}

export const defaultFilters: ThemeFilters = {
  selectedLang: 'en',
  searchTerm: '',
  orderBy: ThemeOrderBy.ID,
  orderDescending: false,
  onlyMyThemes: false,
  onlyFavorites: false,
  showUnverified: false,
};

interface ThemeSelectionProps {
  user: User | null;
  initialFilters?: ThemeFilters;
  onThemeSelect: (theme: Theme, difficulty?: number) => void;
  onCreateTheme?: () => void;
  onThemeDetails?: (themeId: number, filters?: ThemeFilters) => void;
}

function renderVerificationStatus(verified: boolean): string {
  return verified ? '✅' : '❌';
}

export default function ThemeSelection({
  user,
  initialFilters,
  onThemeSelect,
  onCreateTheme,
  onThemeDetails,
}: ThemeSelectionProps) {
  const { t } = useLocale();
  const { colors } = useTheme();

  const init = initialFilters ?? defaultFilters;

  const [themes, setThemes] = useState<ThemeListItem[]>([]);
  const [selectedLang, setSelectedLang] = useState(init.selectedLang);
  const [onlyMyThemes, setOnlyMyThemes] = useState(init.onlyMyThemes);
  const [onlyFavorites, setOnlyFavorites] = useState(init.onlyFavorites);
  const [showUnverified, setShowUnverified] = useState(init.showUnverified);
  const [showImportDialog, setShowImportDialog] = useState(false);
  const [searchTerm, setSearchTerm] = useState(init.searchTerm);
  const [importJson, setImportJson] = useState('');
  const [importError, setImportError] = useState('');
  const [importIsPublic, setImportIsPublic] = useState(true);
  const [orderBy, setOrderBy] = useState<ThemeOrderByType>(init.orderBy);
  const [orderDescending, setOrderDescending] = useState(init.orderDescending);

  const fetchThemes = useCallback(async () => {
    try {
      const response = await getThemes(
        1,
        50,
        selectedLang,
        searchTerm || undefined,
        onlyMyThemes,
        showUnverified ? false : undefined,
        onlyFavorites,
        orderBy,
        orderDescending,
      );
      setThemes(response.items);
    } catch (err) {
      console.error('Failed to fetch themes:', err);
    }
  }, [selectedLang, searchTerm, onlyMyThemes, showUnverified, onlyFavorites, orderBy, orderDescending]);

  useEffect(() => {
    fetchThemes();
    // Search is applied via the search button, like on web
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedLang, onlyMyThemes, onlyFavorites, showUnverified, orderBy, orderDescending]);

  const currentFilters = (): ThemeFilters => ({
    selectedLang,
    searchTerm,
    orderBy,
    orderDescending,
    onlyMyThemes,
    onlyFavorites,
    showUnverified,
  });

  const handleThemeSelect = async (themeItem: ThemeListItem) => {
    try {
      const fullTheme = await getTheme(themeItem.id);
      onThemeSelect(fullTheme);
    } catch (err) {
      console.error('Failed to load theme details:', err);
    }
  };

  const handleImport = async () => {
    try {
      const themeData = JSON.parse(importJson);

      if (
        !themeData.name ||
        !themeData.language ||
        !themeData.description ||
        !Array.isArray(themeData.description.teams) ||
        (!Array.isArray(themeData.description.words) &&
          typeof themeData.description.words !== 'object')
      ) {
        throw new Error(
          'Invalid theme format. Expected API format with name, language, and description object',
        );
      }

      const rawWords = themeData.description.words;
      let wordsMap: Record<string, { difficulty: number }>;

      if (Array.isArray(rawWords)) {
        wordsMap = Object.fromEntries(
          rawWords.map((word: any) => [String(word).trim(), { difficulty: 1 }]),
        );
      } else {
        wordsMap = Object.fromEntries(
          Object.entries(rawWords as Record<string, any>).map(([word, meta]) => {
            const difficulty = meta?.difficulty ?? 1;
            return [String(word).trim(), { difficulty }];
          }),
        );
      }

      if (Object.keys(wordsMap).length < 30) {
        throw new Error('Theme must have at least 30 words');
      }

      if (themeData.description.teams.length !== 10) {
        throw new Error('Theme must contain exactly 10 teams');
      }

      const teamNames = themeData.description.teams.map((t: any) =>
        String(t).trim().toLowerCase(),
      );
      const uniqueTeamNames = new Set(teamNames);
      if (uniqueTeamNames.size !== teamNames.length) {
        const duplicates = themeData.description.teams.filter(
          (t: any, index: number) =>
            teamNames.indexOf(String(t).trim().toLowerCase()) !== index,
        );
        throw new Error(
          `Team names must be unique. Duplicates found: ${duplicates
            .map((t: any) => `"${t}"`)
            .join(', ')}`,
        );
      }

      const wordValues = Array.isArray(rawWords)
        ? rawWords.map((w: any) => String(w).trim().toLowerCase())
        : Object.keys(rawWords).map((w) => String(w).trim().toLowerCase());
      const uniqueWords = new Set(wordValues);
      if (uniqueWords.size !== wordValues.length) {
        const duplicates = wordValues.filter(
          (word, index) => wordValues.indexOf(word) !== index,
        );
        throw new Error(
          `Words must be unique within a theme. Duplicates found: ${[
            ...new Set(duplicates),
          ]
            .slice(0, 5)
            .map((w) => `"${w}"`)
            .join(', ')}${duplicates.length > 5 ? '...' : ''}`,
        );
      }

      const payload = {
        ...themeData,
        public: importIsPublic,
        description: {
          teams: themeData.description.teams.map((t: any) => String(t).trim()),
          words: wordsMap,
        },
      };

      await createTheme(payload);

      setShowImportDialog(false);
      setImportJson('');
      setImportError('');
      setImportIsPublic(true);

      fetchThemes();
    } catch (error) {
      setImportError(error instanceof Error ? error.message : 'Invalid JSON');
    }
  };

  const inputStyle = {
    backgroundColor: colors.card,
    borderWidth: 1,
    borderColor: alpha(colors.text, 0.15),
    color: colors.text,
  };

  const labelColor = { color: alpha(colors.text, 0.8) };

  return (
    <Card className="w-full">
      <Text className="mb-6 text-center text-3xl font-bold" style={{ color: colors.text }}>
        {t.ts_title}
      </Text>

      <View className="mb-6 gap-4">
        {/* Row 1: Filtering */}
        <View>
          <Text className="mb-2" style={labelColor}>
            {t.ts_language}
          </Text>
          <OptionPills
            options={[
              { value: 'en', label: t.ts_langEnglish },
              { value: 'ru', label: t.ts_langRussian },
            ]}
            value={selectedLang}
            onChange={setSelectedLang}
          />
        </View>

        <View>
          <Text className="mb-2" style={labelColor}>
            {t.ts_search}
          </Text>
          <View className="gap-2">
            <TextInput
              value={searchTerm}
              onChangeText={setSearchTerm}
              placeholder={t.ts_searchPlaceholder}
              placeholderTextColor={alpha(colors.text, 0.4)}
              className="w-full rounded-game px-4 py-2"
              style={inputStyle}
              onSubmitEditing={fetchThemes}
              returnKeyType="search"
            />
            <Pressable
              onPress={fetchThemes}
              className="items-center rounded-game px-4 py-2"
              style={{ backgroundColor: colors.success }}
            >
              <Text className="font-semibold" style={{ color: colors.white }}>
                {t.ts_search}
              </Text>
            </Pressable>
          </View>
        </View>

        {/* Row 2: Ordering */}
        <View>
          <Text className="mb-2" style={labelColor}>
            {t.ts_orderBy}
          </Text>
          <OptionPills
            options={[
              { value: ThemeOrderBy.ID, label: t.ts_orderByDate },
              { value: ThemeOrderBy.NAME, label: t.ts_orderByName },
              { value: ThemeOrderBy.LIKES, label: t.ts_orderByLikes },
            ]}
            value={orderBy}
            onChange={(v) => setOrderBy(v as ThemeOrderByType)}
          />
        </View>

        <View>
          <Text className="mb-2" style={labelColor}>
            {t.ts_orderDirection}
          </Text>
          <OptionPills
            options={[
              { value: 'asc', label: t.ts_ascending },
              { value: 'desc', label: t.ts_descending },
            ]}
            value={orderDescending ? 'desc' : 'asc'}
            onChange={(v) => setOrderDescending(v === 'desc')}
          />
        </View>

        {/* Row 3: Modifiers */}
        {user && (
          <View className="flex-row flex-wrap items-center justify-center gap-x-6 gap-y-3">
            <Checkbox checked={showUnverified} onChange={setShowUnverified} label={t.ts_showUnverified} />
            <Checkbox checked={onlyMyThemes} onChange={setOnlyMyThemes} label={t.ts_onlyMine} />
            <Checkbox checked={onlyFavorites} onChange={setOnlyFavorites} label={t.ts_onlyFavorites} />
          </View>
        )}

        {/* Row 4: Action buttons */}
        <View className="flex-row flex-wrap items-center justify-center gap-4">
          <Pressable
            onPress={() => setShowImportDialog(true)}
            className="rounded-game px-6 py-2"
            style={{ backgroundColor: colors.success }}
          >
            <Text className="font-semibold" style={{ color: colors.white }}>
              {t.ts_import}
            </Text>
          </Pressable>

          {user && (
            <Pressable
              onPress={() => onCreateTheme?.()}
              className="rounded-game px-6 py-2"
              style={{ backgroundColor: colors.success }}
            >
              <Text className="font-semibold" style={{ color: colors.white }}>
                {t.ts_create}
              </Text>
            </Pressable>
          )}
        </View>
      </View>

      {showUnverified && (
        <View
          className="mb-4 rounded-game p-4"
          style={{
            backgroundColor: colors.card,
            borderWidth: 1,
            borderColor: alpha(colors.text, 0.2),
          }}
        >
          <Text className="text-sm" style={{ color: colors.text }}>
            {t.ts_unverifiedWarning}
          </Text>
        </View>
      )}

      <View className="gap-3">
        {themes.map((theme) => (
          <Pressable
            key={theme.id}
            onPress={() => {
              if (onThemeDetails) {
                onThemeDetails(theme.id, currentFilters());
              } else {
                handleThemeSelect(theme);
              }
            }}
            className="rounded-game p-4"
            style={{
              backgroundColor: alpha(colors.text, 0.04),
              borderWidth: 1,
              borderColor: alpha(colors.text, 0.1),
            }}
          >
            <Text className="font-semibold" style={{ color: colors.text }}>
              {renderVerificationStatus(theme.verified)} {theme.name}
            </Text>
          </Pressable>
        ))}
      </View>

      {themes.length === 0 && (
        <Text className="py-8 text-center" style={{ color: alpha(colors.text, 0.6) }}>
          {t.ts_noThemes}
        </Text>
      )}

      <Modal
        visible={showImportDialog}
        transparent
        animationType="fade"
        onRequestClose={() => setShowImportDialog(false)}
      >
        <View className="flex-1 items-center justify-center p-4" style={{ backgroundColor: 'rgba(0,0,0,0.4)' }}>
          <View
            className="max-h-[80%] w-full rounded-game p-6"
            style={{
              backgroundColor: colors.card,
              borderWidth: 1,
              borderColor: alpha(colors.text, 0.15),
            }}
          >
            <ScrollView>
              <Text className="mb-4 text-2xl font-bold" style={{ color: colors.text }}>
                {t.ts_importTitle}
              </Text>
              <TextInput
                value={importJson}
                onChangeText={(v) => {
                  setImportJson(v);
                  setImportError('');
                }}
                placeholder={t.ts_importPlaceholder}
                placeholderTextColor={alpha(colors.text, 0.4)}
                multiline
                textAlignVertical="top"
                className="h-64 w-full rounded-game p-4 text-sm"
                style={[inputStyle, { fontFamily: 'monospace' }]}
              />
              <View className="mt-4">
                <Checkbox checked={importIsPublic} onChange={setImportIsPublic} label={t.ts_public} />
              </View>
              {importError ? (
                <Text className="mt-2 text-sm" style={{ color: colors.error }}>
                  {importError}
                </Text>
              ) : null}
              <View className="mt-4 flex-row gap-4">
                <Pressable
                  onPress={handleImport}
                  className="rounded-game px-6 py-2"
                  style={{ backgroundColor: colors.success }}
                >
                  <Text className="font-semibold" style={{ color: colors.white }}>
                    {t.ts_importBtn}
                  </Text>
                </Pressable>
                <Pressable
                  onPress={() => {
                    setShowImportDialog(false);
                    setImportJson('');
                    setImportError('');
                    setImportIsPublic(true);
                  }}
                  className="rounded-game px-6 py-2"
                  style={{
                    backgroundColor: alpha(colors.text, 0.06),
                    borderWidth: 1,
                    borderColor: alpha(colors.text, 0.15),
                  }}
                >
                  <Text className="font-semibold" style={{ color: colors.text }}>
                    {t.ts_cancel}
                  </Text>
                </Pressable>
              </View>
            </ScrollView>
          </View>
        </View>
      </Modal>
    </Card>
  );
}
