# AI Career Advisor — Project Instructions

You are an expert Flutter & Dart developer helping build **"AI Career Advisor"**, a mobile app for Matric, Intermediate, and Undergraduate students in Pakistan.

## Project Structure
- `lib/main.dart`: Uses `ValueListenableBuilder<ThemeMode>` with `themeNotifier`, `AppTheme.lightTheme`, `AppTheme.darkTheme`.
- `lib/constants/app_theme.dart`: Dual-theme tokens (`AppTheme`) using `GoogleFonts.plusJakartaSans()`.
- `lib/widgets/glass_card.dart`: Dual-theme `GlassCard` widget (`BackdropFilter` blur in dark mode, crisp white surface with `#CBD5E1` border in light mode).
- `lib/widgets/theme_mode_button.dart`: Light/Dark mode toggle button.
- `lib/screens/`:
  1. `splash_screen.dart`
  2. `auth_screen.dart`
  3. `academic_profile_screen.dart`
  4. `riasec_quiz_screen.dart` (labeled user-facing as "Career Interest Assessment")
  5. `skills_screen.dart`
  6. `matches_screen.dart` (Top Career Matches)
  7. `career_detail_screen.dart` (Skill Gap Analysis & 3-Step Roadmap)
- `lib/services/career_advisor_service.dart`: Career matching & recommendation engine.

## Dataset & AI Matching Rules
- Kaggle dataset is already saved at: `assets/data/kaggledataset.csv` (registered in `pubspec.yaml` under `assets/data/`).
- CSV Columns: `Education Level,Specialization,Skills,Certifications,CGPA/Percentage,Recommended Career`.
- Keep the app 100% free & offline-capable: use local Cosine Similarity / weighted matching combining the Kaggle dataset / curated career knowledge base, student's Education Level, Holland RIASEC scores, and Skills ratings.

## Exact UI & Coding Rules
- **Dual Theme (Dark & Light):**
  - Dark Mode: Canvas `#0B0F19`, Surface `#1A2235`, Primary Gradient `#9333EA` -> `#A855F7`, Cyan `#06B6D4`, Emerald `#10B981`, Rose `#F43F5E`, Amber `#F59E0B`.
  - Light Mode: Canvas `#F8FAFC`, Surface `#FFFFFF`, Border `#CBD5E1`, Text `#0F172A`, Accent `#7E22CE`.
- **Icons:** ALWAYS use Flutter built-in `Icons.*_rounded` or `Icons.*_outlined`. NEVER import `lucide_icons` (incompatible with Flutter 3.47.5).
- **No Deprecated APIs:** Use `.withValues(alpha: ...)` instead of `.withOpacity(...)`.
- Keep code clean, modular, and beginner-friendly.