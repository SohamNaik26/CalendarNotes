# Google Sign-In Setup Guide

This guide explains how to configure Google Sign-In for CalendarNotes.

## Prerequisites

1. A Google Cloud Console project
2. OAuth 2.0 credentials configured

## Setup Steps

### 1. Create OAuth 2.0 Credentials in Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (or create a new one)
3. Navigate to **APIs & Services** > **Credentials**
4. Click **Create Credentials** > **OAuth client ID**
5. Configure the OAuth consent screen if prompted
6. For **Application type**, select:
   - **iOS** (for iOS app)
   - **macOS** (for macOS app)
7. Enter your bundle identifier: `com.calendarnotes.app`
8. Copy the **Client ID** (it looks like: `XXXXX.apps.googleusercontent.com`)

### 2. Configure Redirect URI

In Google Cloud Console, add the following authorized redirect URI:
- `com.calendarnotes.app:/oauth2callback`

### 3. Configure the App

#### Option A: Via Code (Development)

In `CalendarNotesApp.swift`, uncomment and set your Client ID:

```swift
UserDefaults.standard.set("YOUR_CLIENT_ID.apps.googleusercontent.com", forKey: "google.oauth.clientId")
```

#### Option B: Via Info.plist (Production)

Add to your `Info.plist`:

```xml
<key>GoogleOAuthClientID</key>
<string>YOUR_CLIENT_ID.apps.googleusercontent.com</string>
```

Then update `GoogleSignInService.swift` to read from Info.plist:

```swift
private let googleClientId: String = {
    if let clientId = Bundle.main.object(forInfoDictionaryKey: "GoogleOAuthClientID") as? String {
        return clientId
    }
    // Fallback to UserDefaults
    return UserDefaults.standard.string(forKey: "google.oauth.clientId") ?? "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com"
}()
```

### 4. Configure URL Scheme

The app uses the URL scheme `com.calendarnotes.app` for OAuth callbacks. This should already be configured in your `AppInfo.plist` or Xcode project settings under:
- **Target** > **Info** > **URL Types**

If not, add:
- **Identifier**: `com.calendarnotes.app`
- **URL Schemes**: `com.calendarnotes.app`

### 5. Backend API Endpoint

Your backend needs to implement:

**POST /api/auth/google/exchange**

Request body:
```json
{
  "code": "authorization_code_from_google",
  "redirectURI": "com.calendarnotes.app:/oauth2callback"
}
```

Response:
```json
{
  "idToken": "google_id_token",
  "accessToken": "google_access_token",
  "fullName": "User Name",
  "email": "user@example.com"
}
```

The backend should:
1. Exchange the authorization code for tokens using Google's token endpoint
2. Verify the ID token
3. Extract user information
4. Return the tokens and user info

**POST /api/auth/google**

Request body:
```json
{
  "idToken": "google_id_token",
  "accessToken": "google_access_token",
  "fullName": "User Name"
}
```

Response: Same as other auth endpoints (AuthResponse with user, accessToken, refreshToken)

## Testing

1. Set your Google OAuth Client ID
2. Run the app
3. Tap "Continue with Google" on login/signup screen
4. Complete Google authentication
5. You should be logged in

## Troubleshooting

- **"Configuration missing" error**: Make sure you've set the Google OAuth Client ID
- **"Invalid callback" error**: Verify the redirect URI matches in Google Cloud Console
- **"Token exchange failed"**: Check that your backend `/api/auth/google/exchange` endpoint is working
- **URL scheme not working**: Verify URL scheme is configured in Xcode project settings

