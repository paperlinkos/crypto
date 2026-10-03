/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        mint: {
          light: '#33EBAE',
          DEFAULT: '#00E599',
          dark: '#10B981',
        },
        emerald: {
          DEFAULT: '#0E5A3E',
          deep: '#0A3F2C',
        },
        obsidian: {
          DEFAULT: '#0A140F',
          surface: '#121C16',
          border: '#1C2C23',
        },
        porcelain: {
          DEFAULT: '#F6FAF7',
          sage: '#EEF4F0',
          border: '#E2ECE6',
        },
      },
      borderRadius: {
        pill: '28px',
        card: '24px',
      },
    },
  },
  plugins: [],
};
