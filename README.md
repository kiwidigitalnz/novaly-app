# Novaly

Multi-tenant SaaS platform built with modern web technologies.

## Tech Stack

- **Monorepo**: Turborepo + PNPM workspaces
- **Frontend**: React 19 + Vite 6 + TypeScript, TailwindCSS 4, ShadCN components
- **Backend**: Supabase (Edge Functions + Postgres, Auth, Storage)
- **Emails**: Resend
- **Payments**: Stripe

## Development

### Prerequisites

- Node.js 18+
- PNPM 10+

### Getting Started

1. Install dependencies:
   ```bash
   pnpm install
   ```

2. Start development server:
   ```bash
   pnpm dev
   ```

3. Start only the web app:
   ```bash
   pnpm --filter apps/web dev
   ```

### Available Scripts

- `pnpm dev` - Start all development servers
- `pnpm build` - Build all packages and apps
- `pnpm lint` - Run linting across all workspaces
- `pnpm clean` - Clean build artifacts

## Project Structure

```
novaly/
├── apps/
│   └── web/           # React frontend application
├── packages/
│   └── ui/            # Shared design system and components
└── supabase/          # Supabase configuration and functions
```

## Next Steps

### Supabase Setup

1. Install Supabase CLI:
   ```bash
   npm install -g supabase
   ```

2. Login to Supabase:
   ```bash
   supabase login
   ```

3. Initialize Supabase project:
   ```bash
   cd supabase
   supabase init
   ```

4. Link to your Supabase project:
   ```bash
   supabase link --project-ref YOUR_PROJECT_REF
   ```

### Deploy Edge Functions

1. Create your first Edge Function:
   ```bash
   supabase functions new hello-world
   ```

2. Deploy the function:
   ```bash
   supabase functions deploy hello-world
   ```

## Design System

The project uses a custom design system with:
- **Typeface**: Inter Variable
- **Primary Color**: #006B5E
- **Accent Color**: #FFA629
- **Surface Colors**: #FFFFFF, #F6F6F7, #EDEDF0
