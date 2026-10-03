# TAG — Google Play release guide

Everything needed to fill in Play Console for the first release. Values in `code`
can be pasted as-is.

## 0. Before you start (blocking)

1. **Deploy the web app** so the policy pages are live (Play checks the URLs):
   `cd TAG && npm run deploy`, then open
   - https://blueflyingpanda.github.io/TAG/privacy.html
   - https://blueflyingpanda.github.io/TAG/delete-account.html
2. **Deploy TAG_API** with the new `DELETE /auth/me` endpoint. In-app account deletion
   fails until it's live.
3. **Back up the upload key.** Copy both to a password manager or other safe storage:
   - `~/keys/tag-upload-keystore.jks`
   - `TAG_MOBILE/android/key.properties` (holds the password)

   If you lose them you can't publish updates until Google resets the upload key
   (a support request that takes days).

## 1. Create the app

| Field | Value |
|---|---|
| App name | `TAG` |
| Default language | English (United States) – en-US |
| App or game | Game |
| Free or paid | Free |
| Package name (set by the first upload) | `com.tag.aliasgame` |

Enrol in **Play App Signing** (the default). Google then re-signs the app with its own key.

## 2. Google Sign-In: register both signing keys

Play re-signs the app, so the SHA-1 on users' phones is Google's, not yours. Sign-in fails
with a developer error until both are registered.

In Google Cloud Console → APIs & Services → Credentials → **Create credentials → OAuth
client ID → Android**, package `com.tag.aliasgame`, one client per SHA-1:

| Key | SHA-1 |
|---|---|
| Upload key (local release builds, internal testing uploads) | `18:89:45:C4:A3:75:98:C0:55:CE:2D:70:9E:49:CA:67:D4:26:C4:DD` |
| Play app signing key | Play Console → Test and release → Setup → **App signing** → copy "SHA-1 certificate fingerprint" |
| Debug key (already registered) | `52:88:A4:2A:05:9E:AB:EB:92:E7:01:A0:5F:0F:13:B6:A5:67:7F:9D` |

Don't change `googleWebClientId` in the app. It stays the web client the backend verifies.

## 3. Upload the build

- File: `TAG_MOBILE/build/app/outputs/bundle/release/app-release.aab`
- Start with **Testing → Internal testing**, install from the Play link, and confirm that
  Google sign-in works (that's how you know step 2 is right). Then promote to Production.
- Personal developer accounts created after Nov 2023 must run a **closed test with at least
  12 testers for 14 days** before Production is unlocked.
- Release notes (en-US): `First release of TAG on Google Play.`
- Release notes (ru-RU): `Первый релиз TAG в Google Play.`

## 4. Store listing

**App name:** `TAG`

### English (en-US)

**Short description** (max 80):
```
Themed Alias party game: explain words, swipe cards, beat the other teams!
```

**Full description:**
```
TAG is a Themed Alias party game for friends and family.

Split into teams, pick a theme and take turns explaining words to your teammates without saying the word itself. Swipe right when they guess, left to skip, and race the clock to reach the target score first.

• Community themes on movies, books, science, sport and more, in English and Russian
• Create your own themes with custom words, difficulty levels and team names, or import them from JSON
• Flexible rules: 2–10 teams, target score, round timer and an optional skip penalty
• Round review: fix any mis-swipes before points are counted
• Game history: pause and resume unfinished games at any time
• Favourites, search and filters to find the perfect theme
• Light and dark mode
• No ads

Sign in with Google to save your themes and game history.
```

### Russian (ru-RU)

**Short description:**
```
Тематический Элиас: объясняйте слова, свайпайте карточки и побеждайте команды!
```

**Full description:**
```
TAG — тематическая версия игры «Элиас» для компании друзей и семьи.

Разделитесь на команды, выберите тему и по очереди объясняйте слова, не называя их. Свайп вправо — угадано, влево — пропуск. Успейте набрать нужное количество очков раньше соперников!

• Темы от сообщества — кино, книги, наука, спорт и многое другое — на русском и английском
• Создавайте свои темы: слова, уровни сложности и названия команд, или импортируйте из JSON
• Гибкие правила: от 2 до 10 команд, цель по очкам, таймер раунда и штраф за пропуск
• Проверка раунда: исправьте ошибочные свайпы до подсчёта очков
• История игр: ставьте игру на паузу и продолжайте позже
• Избранное, поиск и фильтры
• Светлая и тёмная тема
• Без рекламы

Войдите через Google, чтобы сохранять темы и историю игр.
```

### Graphics (`store/graphics/`)

| Asset | File | Status |
|---|---|---|
| App icon 512×512 | `icon-512.png` | Ready |
| Feature graphic 1024×500 | `feature-1024x500.png` | Ready (tag.jpeg on white) |
| Phone screenshots (max 8, ≤ 2:1) | `play/01…08-*.png` (1080×2160) | Ready — upload in numbered order |

### Categorisation & contact

| Field | Value |
|---|---|
| Category | Game → **Word** |
| Tags | Word, Party, Trivia |
| Email | `ilya.sagaidac@gmail.com` |
| Website | `https://blueflyingpanda.github.io/TAG/` |
| Privacy policy | `https://blueflyingpanda.github.io/TAG/privacy.html` |

## 5. App content (Policy → App content)

**Privacy policy:** `https://blueflyingpanda.github.io/TAG/privacy.html`

**Ads:** No, the app doesn't contain ads.

**App access:** "All or some functionality is restricted" →
Instructions: `Sign in with any Google account using the "Continue with Google" button. No invitation or special account is needed.`

**Content rating (IARC questionnaire):** category *Game*. Answer **No** to violence, sexuality,
language, drugs and gambling. Answer **Yes** to "Users can interact or exchange content": public
themes made by other players are visible. Expected rating: Everyone / PEGI 3, with an
"Users Interact" notice.

**Target audience:** 13+ (choose 13–15, 16–17 and 18+). Don't include under-13 age
groups; that brings in Families policy requirements the app doesn't meet.

**News app:** No. **Government app:** No. **Financial features:** None. **Health:** None.

**Data safety:**

| Question | Answer |
|---|---|
| Collects or shares required user data? | Yes, collects |
| Encrypted in transit? | Yes |
| Users can request deletion? | Yes |
| Account deletion URL | `https://blueflyingpanda.github.io/TAG/delete-account.html` |

Data types (all **Collected**, **not Shared**, **required**, purpose **App functionality** + **Account management**):

| Category | Type | Notes |
|---|---|---|
| Personal info | Email address | Google sign-in |
| Personal info | Name | Display name (Telegram users) |
| Personal info | User IDs | Account ID; Telegram ID |
| Photos and videos | — | *Not collected.* The profile picture is a URL from Google/Telegram, not an uploaded photo |
| App activity | Other user-generated content | Themes: words, team names |
| App activity | App interactions | Game history, favourites |

Not collected: location, financial info, health, messages, contacts, files, audio, calendar,
web history, device IDs, crash logs, diagnostics.

**User-generated content:** the app has a Report action on every theme (theme page → ⋮ →
Report), which emails `ilya.sagaidac@gmail.com`. Public themes are marked unverified until an
admin reviews them, and unverified themes are hidden by default. Review reports promptly;
Play expects objectionable content to be removed.

## 6. Every later release

1. Bump `version:` in `pubspec.yaml`: `1.0.1+2`. The number after `+` (versionCode) must
   increase on every upload.
2. `flutter build appbundle --release`
3. Upload `build/app/outputs/bundle/release/app-release.aab`.
