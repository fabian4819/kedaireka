# Agora Video Call Setup Guide

This guide will help you configure Agora for video calling functionality in the Pix2Land app.

## Prerequisites

1. An Agora account (sign up at https://console.agora.io/)
2. A valid Agora App ID
3. (Optional) Agora Token for production use

## Setup Steps

### 1. Get Your Agora App ID

1. Go to [Agora Console](https://console.agora.io/)
2. Sign in or create an account
3. Create a new project or use an existing one
4. Copy your **App ID**

### 2. Configure the App

1. Open `lib/core/config/agora_config.dart`
2. Replace `'YOUR_AGORA_APP_ID'` with your actual App ID:

```dart
static const String appId = 'your-actual-app-id-here';
```

### 3. Token Configuration (Optional for Testing)

For testing purposes, you can leave `tempToken` as an empty string and set `useToken` to `false`.

For production:
1. Generate a temporary token from [Agora Console](https://console.agora.io/)
2. Update `tempToken` with your generated token
3. Set `useToken` to `true`
4. **Important**: Implement a token server for production apps

### 4. Test the Configuration

1. Run the app
2. Navigate to the Video Call feature
3. Click "Create Room"
4. If configured correctly, you should see "Room created!" message

## Troubleshooting

### "Failed to create room: Agora App ID not configured"
- Make sure you've replaced `'YOUR_AGORA_APP_ID'` with your actual App ID
- Verify the App ID is correct (no extra spaces or quotes)

### Permissions Issues
- Ensure camera and microphone permissions are granted
- Check Android/iOS permission settings

### Token Expiration
- Tokens expire after the configured time (default: 3600 seconds)
- For production, implement a token server to generate fresh tokens

## Production Considerations

1. **Token Server**: Never hardcode tokens in production. Implement a server to generate tokens on demand.
2. **Security**: Keep your App ID and token generation logic secure
3. **Error Handling**: Add robust error handling for network issues
4. **User Experience**: Provide clear feedback when permissions are denied

## Resources

- [Agora Documentation](https://docs.agora.io/)
- [Flutter SDK Guide](https://docs.agora.io/en/video-calling/get-started/get-started-sdk?platform=flutter)
- [Token Generation](https://docs.agora.io/en/video-calling/develop/authentication-workflow)
