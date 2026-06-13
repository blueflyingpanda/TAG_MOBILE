module.exports = function (api) {
  api.cache(true);
  return {
    presets: [
      ['babel-preset-expo', { jsxImportSource: 'nativewind' }],
      'nativewind/babel',
    ],
    // Reanimated 4 / react-native-worklets: compiles worklets to run on the UI
    // thread. Without it, animations fall back to the JS thread and stutter.
    // Must be listed last.
    plugins: ['react-native-worklets/plugin'],
  };
};
