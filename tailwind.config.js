/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./App.tsx', './src/**/*.{js,ts,jsx,tsx}'],
  darkMode: 'class',
  presets: [require('nativewind/preset')],
  theme: {
    extend: {
      colors: {
        // Mirrors TAG web src/index.css tokens (light); dark handled via ThemeContext palette
        primary: '#223164',
        secondary: '#ECACAE',
        error: '#e53d00',
        success: '#21a0a0',
        card: '#fcfff7',
        text: '#222222',
      },
      borderRadius: {
        game: '15px',
      },
    },
  },
  plugins: [],
};
