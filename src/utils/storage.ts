import AsyncStorage from '@react-native-async-storage/async-storage';
import type { GameState, User } from '../types';

const GAME_STATE_STORAGE_KEY = 'tag_game_state';
const USER_STORAGE_KEY = 'tag_user';
const CURRENT_GAME_ID_KEY = 'tag_current_game_id';

export const storage = {
  getGameState: async (): Promise<GameState | null> => {
    try {
      const stored = await AsyncStorage.getItem(GAME_STATE_STORAGE_KEY);
      return stored ? JSON.parse(stored) : null;
    } catch {
      return null;
    }
  },

  saveGameState: async (state: GameState): Promise<void> => {
    await AsyncStorage.setItem(GAME_STATE_STORAGE_KEY, JSON.stringify(state));
  },

  clearGameState: async (): Promise<void> => {
    await AsyncStorage.removeItem(GAME_STATE_STORAGE_KEY);
  },

  // User
  getUser: async (): Promise<User | null> => {
    try {
      const stored = await AsyncStorage.getItem(USER_STORAGE_KEY);
      return stored ? JSON.parse(stored) : null;
    } catch {
      return null;
    }
  },

  saveUser: async (user: User): Promise<void> => {
    await AsyncStorage.setItem(USER_STORAGE_KEY, JSON.stringify(user));
  },

  clearUser: async (): Promise<void> => {
    await AsyncStorage.removeItem(USER_STORAGE_KEY);
  },

  // Current game id (web kept this directly in localStorage)
  getCurrentGameId: async (): Promise<string | null> => {
    return AsyncStorage.getItem(CURRENT_GAME_ID_KEY);
  },

  saveCurrentGameId: async (id: string): Promise<void> => {
    await AsyncStorage.setItem(CURRENT_GAME_ID_KEY, id);
  },

  clearCurrentGameId: async (): Promise<void> => {
    await AsyncStorage.removeItem(CURRENT_GAME_ID_KEY);
  },
};
