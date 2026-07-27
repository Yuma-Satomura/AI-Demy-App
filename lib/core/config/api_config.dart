/// Web API base URL. Override at build time:
///   flutter run --dart-define=API_BASE_URL=https://your-app.vercel.app
const kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://ai-demy-chi.vercel.app',
);
