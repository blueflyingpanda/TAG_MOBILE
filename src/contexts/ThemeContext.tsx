import AsyncStorage from '@react-native-async-storage/async-storage';
import { createContext, useContext, useEffect, useState } from 'react';
import { Appearance } from 'react-native';

type ThemeMode = 'light' | 'dark';

const STORAGE_KEY = 'tag_theme';

/** Mirrors TAG web src/index.css color tokens */
export interface Palette {
  primary: string;
  secondary: string;
  error: string;
  success: string;
  card: string;
  text: string;
  bgStart: string;
  bgMid: string;
  bgEnd: string;
  white: string;
}

const lightPalette: Palette = {
  primary: '#223164',
  secondary: '#ECACAE',
  error: '#e53d00',
  success: '#21a0a0',
  card: '#fcfff7',
  text: '#222222',
  bgStart: '#fdecc7',
  bgMid: '#f2deb5',
  bgEnd: '#e7d0a4',
  white: '#ffffff',
};

const darkPalette: Palette = {
  primary: '#4a6fd4',
  secondary: '#d28c8f',
  error: '#ff5238',
  success: '#26b5b5',
  card: '#212540',
  text: '#e8e8f4',
  bgStart: '#1d2035',
  bgMid: '#181b2d',
  bgEnd: '#141626',
  white: '#ffffff',
};

/** rgba helper for the text/xx opacity classes used on web */
export function alpha(hex: string, opacity: number): string {
  const r = parseInt(hex.slice(1, 3), 16);
  const g = parseInt(hex.slice(3, 5), 16);
  const b = parseInt(hex.slice(5, 7), 16);
  return `rgba(${r}, ${g}, ${b}, ${opacity})`;
}

interface ThemeContextValue {
  theme: ThemeMode;
  colors: Palette;
  toggle: () => void;
}

const ThemeContext = createContext<ThemeContextValue | null>(null);

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setTheme] = useState<ThemeMode>(
    Appearance.getColorScheme() === 'dark' ? 'dark' : 'light',
  );

  useEffect(() => {
    AsyncStorage.getItem(STORAGE_KEY).then((stored) => {
      if (stored === 'light' || stored === 'dark') setTheme(stored);
    });
  }, []);

  const toggle = () =>
    setTheme((t) => {
      const next = t === 'dark' ? 'light' : 'dark';
      AsyncStorage.setItem(STORAGE_KEY, next).catch(() => {});
      return next;
    });

  return (
    <ThemeContext.Provider
      value={{
        theme,
        colors: theme === 'dark' ? darkPalette : lightPalette,
        toggle,
      }}
    >
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error('useTheme must be used inside ThemeProvider');
  return ctx;
}
