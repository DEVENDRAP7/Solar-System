# Contributing

Thanks for your interest in the project.

## Getting set up

```bash
flutter create --platforms=android --project-name solar_system_app --org com.devendra .
flutter pub get
flutter run
```

## Before opening a pull request

Run the same checks the CI workflow runs:

```bash
flutter analyze
flutter test
flutter build apk --release
```

All three must pass. A pull request that fails analysis or tests will fail CI.

## Code style

- Follow the rules in `analysis_options.yaml` (based on `flutter_lints`)
- Format with `dart format .` before committing
- Prefer `const` constructors where possible
- Keep widgets small and focused; put logic in `lib/services/` or
  `lib/providers/`, not in `build` methods

## Commit messages

Use short, imperative subjects that describe the change:

```
Add elliptical orbit calculation to the physics engine
Fix camera clipping when zoomed into Saturn
```

## Branches

- `main` — always buildable; every push produces a release APK artifact
- Feature branches — `feature/<short-description>`
- Fix branches — `fix/<short-description>`

## Reporting issues

Open an issue including:

- What you expected to happen and what happened instead
- Device model and Android version
- Steps to reproduce
- Relevant output from `flutter doctor -v`

## Assets

3D models belong in `assets/models/` as `.glb` files. Keep each model under
3 MB and roughly 1,500–3,000 polygons so the scene stays smooth on mid-range
phones.
