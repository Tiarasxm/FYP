# ShapeRush

ShapeRush is a fitness platform that connects users with fitness professionals and helps track workouts, meals, water, and health metrics. It consists of a Next.js website for account management and administration, and a Flutter mobile app for users(clients) and professionals.

## Overview

- **Website**: Built with Next.js. Users create accounts, download the mobile app, and admins manage users and content.
- **Mobile app**: Built with Flutter. Clients follow plans, log workouts, track health, and chat with professionals. Professionals create plans, manage clients, and provide personalized programs.
- **Backend**: Supabase (PostgreSQL database, authentication, real-time, and storage).

## Tech Stack

- **Frontend (website)**: Next.js, React, Tailwind CSS
- **Mobile app**: Flutter, Supabase Flutter client
- **Backend**: Supabase (PostgreSQL, Auth, Realtime, Storage, Edge Functions)
- **Database**: PostgreSQL with custom schema and RLS policies

## Project Structure

```
/
├── src/                  # Next.js website source
│   ├── app/              # Pages and layouts
│   ├── components/       # Shared React components
│   └── lib/              # Supabase client and helpers
├── mobile/               # Flutter mobile app
│   ├── lib/
│   │   ├── screens/      # App screens
│   │   ├── widgets/      # Reusable widgets
│   │   ├── models/       # Data models
│   │   └── services/     # Supabase services
│   └── pubspec.yaml
├── database/             # SQL schema and migration files
│   ├── schema.sql
│   ├── leaderboard_migration.sql
│   └── follow_leaderboard_migration.sql
└── .env.local            # Website environment variables
```

## Features

### Website

- Account registration and login
- Google OAuth sign-in
- Role selection: Free User, Fitness Professional, Admin
- Admin dashboard for user and content management
- APK download page for the mobile app
- Fitness professional approval workflow

### Mobile App

- Client and fitness professional accounts
- Real-time chat with plan sharing
- Workout plans (free and personalized)
- Workout, meal, and water logging
- Health data tracking and leaderboards
- Social features: posts, follows, likes, comments

## Setup

### Website

1. Install dependencies:
   ```bash
   npm install
   ```

2. Create `.env.local`:
   ```
   NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
   ```

3. Run the development server:
   ```bash
   npm run dev
   ```

### Mobile App

1. Navigate to the mobile directory:
   ```bash
   cd mobile
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

4. Build a release APK:
   ```bash
   flutter build apk
   ```

### Supabase

1. Create a new Supabase project.
2. Run the SQL files in order in the SQL Editor:
   1. `database/schema.sql`
   2. `database/leaderboard_migration.sql`
   3. `database/follow_leaderboard_migration.sql`
3. Enable the Google OAuth provider and set the redirect URLs for `http://localhost:3000` and your production domain.
4. Configure SMTP under Authentication > SMTP & Mailer for transactional emails.

## Deployment

- **Website**: Deploy the `main` branch to Vercel with the same Supabase environment variables.
- **Mobile APK**: Build with `flutter build apk`, then upload the APK to a GitHub Release or any public file host. Update the download link on the website welcome page.

## Configuration Notes

- The website and mobile app should point to the same Supabase project for a unified user base.
- Production redirect URLs must be added in Supabase Auth settings.
- The APK download link is set in `src/app/welcome/page.js`.

## Authors

This project was developed as a Final Year Project.
