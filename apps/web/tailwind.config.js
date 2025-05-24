import { Colors } from '@novaly/ui/tokens/brand.js';

/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
    "../../packages/ui/**/*.{js,ts,jsx,tsx}"
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter Variable', 'Inter', 'system-ui', 'sans-serif'],
      },
      colors: {
        primary: {
          DEFAULT: Colors.primary,
          foreground: Colors.primaryFg,
        },
        accent: {
          DEFAULT: Colors.accent,
          foreground: Colors.primaryFg,
        },
        surface: {
          0: Colors.surface[0],
          1: Colors.surface[1],
          2: Colors.surface[2],
        },
        border: {
          muted: Colors.borderMuted,
        },
        success: {
          50: Colors.success[0],
          100: Colors.success[1],
          600: Colors.success[2],
          700: Colors.success[3],
        },
        error: {
          50: Colors.error[0],
          100: Colors.error[1],
          600: Colors.error[2],
          700: Colors.error[3],
        },
        warning: {
          50: Colors.warning[0],
          100: Colors.warning[1],
          600: Colors.warning[2],
          700: Colors.warning[3],
        },
        info: {
          50: Colors.info[0],
          100: Colors.info[1],
          600: Colors.info[2],
          700: Colors.info[3],
        },
        // Tailwind defaults for compatibility
        background: Colors.surface[0],
        foreground: "#0a0a0a",
        muted: {
          DEFAULT: Colors.surface[1],
          foreground: "#6b7280",
        },
        input: Colors.borderMuted,
        ring: Colors.primary,
      },
    },
  },
  plugins: [],
}
