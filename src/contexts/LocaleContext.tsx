import AsyncStorage from '@react-native-async-storage/async-storage';
import { getLocales } from 'expo-localization';
import { createContext, useCallback, useContext, useEffect, useState } from 'react';
import { type LocaleCode, type Translations, locales } from '../i18n/translations';

const STORAGE_KEY = 'tag_locale';

function getDeviceLocale(): LocaleCode {
  const device = getLocales()[0]?.languageCode ?? 'en';
  return device in locales ? (device as LocaleCode) : 'en';
}

interface LocaleContextValue {
  locale: LocaleCode;
  setLocale: (code: LocaleCode) => void;
  t: Translations;
}

const LocaleContext = createContext<LocaleContextValue | null>(null);

export function LocaleProvider({ children }: { children: React.ReactNode }) {
  const [locale, setLocaleState] = useState<LocaleCode>(getDeviceLocale);

  useEffect(() => {
    AsyncStorage.getItem(STORAGE_KEY).then((stored) => {
      if (stored && stored in locales) setLocaleState(stored as LocaleCode);
    });
  }, []);

  const setLocale = useCallback((code: LocaleCode) => {
    AsyncStorage.setItem(STORAGE_KEY, code).catch(() => {});
    setLocaleState(code);
  }, []);

  return (
    <LocaleContext.Provider value={{ locale, setLocale, t: locales[locale] }}>
      {children}
    </LocaleContext.Provider>
  );
}

export function useLocale() {
  const ctx = useContext(LocaleContext);
  if (!ctx) throw new Error('useLocale must be used inside LocaleProvider');
  return ctx;
}
