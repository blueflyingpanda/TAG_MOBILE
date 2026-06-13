/**
 * API Configuration
 * Override with EXPO_PUBLIC_API_BASE (e.g. http://10.0.2.2:8000 for the
 * Android emulator against a local backend).
 */

export const API_BASE =
  process.env.EXPO_PUBLIC_API_BASE || 'https://tag-api.servegame.com';

export const AUTH_ENDPOINTS = {
  login: `${API_BASE}/auth/login`,
  exchange: `${API_BASE}/auth/exchange`,
  telegram: `${API_BASE}/auth/telegram`,
};
