/**
 * OAuth utilities for the mobile app.
 * Backend flow:
 * 1. App opens in-app browser at /auth/login?redirect_uri=tag://auth
 * 2. BE handles Google OAuth, redirects to tag://auth?code=<one-time-code>
 * 3. App exchanges code with /exchange -> gets {"token": <jwt>}
 * 4. Store token in AsyncStorage, use in Authorization: Bearer <token>
 * 5. If token expired, logout automatically
 */

import AsyncStorage from '@react-native-async-storage/async-storage';
import * as Linking from 'expo-linking';
import * as WebBrowser from 'expo-web-browser';
import type { User } from '../types';
import { AUTH_ENDPOINTS } from './config';

const TOKEN_STORAGE_KEY = 'auth_token';

/** Deep link the backend redirects to (must match TAG_API settings.mobile_redirect_uri) */
const MOBILE_REDIRECT_URI = 'tag://auth';

/**
 * JWT payload structure
 */
interface JWTPayload {
  user_id: number;
  email?: string | null;
  username?: string;
  picture?: string;
  admin: boolean;
  exp: number;
  iat: number;
}

// In-memory cache so auth headers stay synchronous after startup
let cachedToken: string | null = null;

/**
 * Load token from AsyncStorage into the in-memory cache (call once at startup)
 */
export async function loadStoredToken(): Promise<string | null> {
  cachedToken = await AsyncStorage.getItem(TOKEN_STORAGE_KEY);
  return cachedToken;
}

/**
 * Run the full OAuth login flow in an in-app browser session.
 * Resolves with the JWT on success, null if the user cancelled.
 */
export async function loginWithGoogle(): Promise<string | null> {
  const loginUrl = `${AUTH_ENDPOINTS.login}?redirect_uri=${encodeURIComponent(
    MOBILE_REDIRECT_URI,
  )}`;

  const result = await WebBrowser.openAuthSessionAsync(
    loginUrl,
    MOBILE_REDIRECT_URI,
  );

  if (result.type !== 'success' || !result.url) {
    return null; // cancelled / dismissed
  }

  const { queryParams } = Linking.parse(result.url);
  const code = queryParams?.code;
  if (typeof code !== 'string' || !code) {
    throw new Error('OAuth callback missing code');
  }

  return exchangeOAuthCode(code);
}

/**
 * Exchange OAuth code for JWT token
 */
export async function exchangeOAuthCode(code: string): Promise<string> {
  const response = await fetch(AUTH_ENDPOINTS.exchange, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ code }),
  });

  if (!response.ok) {
    throw new Error(`OAuth exchange failed: ${response.statusText}`);
  }

  const data = await response.json();
  const token = data.token;

  cachedToken = token;
  await AsyncStorage.setItem(TOKEN_STORAGE_KEY, token);

  return token;
}

/**
 * Get stored JWT token (from in-memory cache; call loadStoredToken first)
 */
export function getStoredToken(): string | null {
  return cachedToken;
}

/** base64url -> string (Hermes provides atob; normalize the alphabet + padding) */
function base64UrlDecode(input: string): string {
  let base64 = input.replace(/-/g, '+').replace(/_/g, '/');
  while (base64.length % 4 !== 0) base64 += '=';
  return atob(base64);
}

/**
 * Decode JWT token to get payload (client-side decoding for UI purposes)
 */
function decodeJWT(token: string): JWTPayload | null {
  try {
    const payload = token.split('.')[1];
    const decoded = JSON.parse(base64UrlDecode(payload)) as JWTPayload;
    return decoded;
  } catch (err) {
    console.error('Failed to decode JWT:', err);
    return null;
  }
}

/**
 * Get current user from stored token
 */
export function getCurrentUser(): User | null {
  const token = getStoredToken();
  if (!token) return null;

  const payload = decodeJWT(token);
  if (!payload) return null;

  // Check if token is expired
  if (payload.exp && Date.now() >= payload.exp * 1000) {
    // Token expired, clear it
    clearStoredToken();
    return null;
  }

  const email = payload.email ?? null;
  const username =
    payload.username ||
    (typeof email === 'string' && email.includes('@')
      ? email.split('@')[0]
      : 'Player');

  return {
    id: payload.user_id.toString(),
    email,
    username,
    picture: payload.picture,
    admin: payload.admin,
  };
}

/**
 * Clear stored token (logout)
 */
export function clearStoredToken(): void {
  cachedToken = null;
  AsyncStorage.removeItem(TOKEN_STORAGE_KEY).catch(() => {});
}

/**
 * Get authorization header for API requests
 */
export function getAuthHeader(): { Authorization: string } | Record<string, never> {
  const token = getStoredToken();
  return token ? { Authorization: `Bearer ${token}` } : {};
}

let unauthorizedHandler: (() => void) | null = null;

export function setUnauthorizedHandler(handler: () => void): void {
  unauthorizedHandler = handler;
}

/**
 * Make authenticated API request with Bearer token
 */
export async function authenticatedFetch(url: string, options: RequestInit = {}): Promise<Response> {
  const authHeader = getAuthHeader();
  const headers = {
    ...options.headers,
    ...authHeader,
  };

  const response = await fetch(url, {
    ...options,
    headers,
  });

  if (response.status === 401) {
    unauthorizedHandler?.();
  }

  return response;
}
