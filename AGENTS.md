# IskoAko Monorepo - Agent Instructions

## Structure
```
iskoako/
├── mobile/    # Flutter app (Dart, SDK ^3.9.2)
└── web/       # React + Vite + TypeScript + TailwindCSS
```

## Commands

### Web (`web/`)
```bash
npm install        # Install deps
npm run dev        # Dev server (Vite)
npm run build      # Typecheck + build (tsc -b && vite build)
npm run lint       # Oxlint
npm run preview    # Preview production build
```

### Mobile (`mobile/`)
```bash
flutter pub get    # Install deps
flutter run        # Run on device/emulator
flutter analyze    # Static analysis (uses flutter_lints)
flutter test       # Run tests
```

## Key Config Files
- **Web**: `web/tsconfig.json` (project refs), `web/.oxlintrc.json`, `web/vite.config.ts` (alias `@` → `./src`)
- **Mobile**: `mobile/analysis_options.yaml` (flutter_lints), `mobile/pubspec.yaml`

## Environment
- **Web**: `web/.env` (VITE_* vars for Supabase, Google Maps, EmailJS)
- **Mobile**: `mobile/env` (EmailJS vars, loaded via flutter_dotenv)
- Root `.env` is empty

## Architecture Notes
- **Shared backend**: Supabase (both apps use same project)
- **Web entry**: `web/src/main.tsx` → `App.tsx`
- **Mobile entry**: `mobile/lib/main.dart`
- **Web path alias**: `@/` maps to `web/src/`
- **Web pages**: `home`, `about`, `impact`, `auth`, `provider`, `admin`
- **Mobile screens**: `auth`, `dashboard`, `scholarships`, `applications`, `profile`, `funds`, `notifications`

## Lint/Typecheck Order
- Web: `lint` → `build` (build runs `tsc -b`)
- Mobile: `flutter analyze` → `flutter test`

## Common Gotchas
- Web uses Oxlint (not ESLint); config in `.oxlintrc.json`
- Mobile uses `flutter_lints` via `analysis_options.yaml`
- Supabase keys are in `.env` files (not committed in real projects)
- Web build outputs to `web/dist/`