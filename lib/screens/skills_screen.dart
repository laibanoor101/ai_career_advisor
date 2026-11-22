import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../models/student_profile.dart';
import '../services/auth_service.dart';
import 'results_screen.dart';
import '../widgets/glass_card.dart';
import '../widgets/theme_mode_button.dart';

const Map<String, List<({String name, String category})>>
intermediateSkillsByGroup = {
  'Pre-Engineering (Math, Physics, Chemistry)': [
    (name: 'Mathematics', category: 'Analytical'),
    (name: 'Physics', category: 'Analytical'),
    (name: 'Chemistry', category: 'Analytical'),
    (name: 'English', category: 'Soft'),
    (name: 'Logic & Problem Solving', category: 'Analytical'),
    (name: 'Electronics & Hardware', category: 'Tech'),
    (name: 'Critical Thinking', category: 'Analytical'),
    (name: 'Technical Drawing & Design', category: 'Tech'),
    (name: 'Team Collaboration', category: 'Soft'),
  ],
  'Pre-Medical (Biology, Physics, Chemistry)': [
    (name: 'Biology', category: 'Analytical'),
    (name: 'Chemistry', category: 'Analytical'),
    (name: 'Physics', category: 'Analytical'),
    (name: 'Mathematics', category: 'Analytical'),
    (name: 'English', category: 'Soft'),
    (name: 'Scientific Research', category: 'Analytical'),
    (name: 'Critical Thinking', category: 'Analytical'),
    (name: 'Communication & Empathy', category: 'Soft'),
    (name: 'Team Collaboration', category: 'Soft'),
    (name: 'Data Analysis & Statistics', category: 'Analytical'),
  ],
  'ICS (Computer Science, Math, Physics)': [
    (name: 'Computer Science', category: 'Tech'),
    (name: 'Mathematics', category: 'Analytical'),
    (name: 'Physics', category: 'Analytical'),
    (name: 'English', category: 'Soft'),
    (name: 'Logic & Problem Solving', category: 'Analytical'),
    (name: 'Python Programming', category: 'Tech'),
    (name: 'Web Development Basics', category: 'Tech'),
    (name: 'Database Querying (SQL)', category: 'Tech'),
    (name: 'System Design & Algorithms', category: 'Tech'),
    (name: 'Data Analysis & Statistics', category: 'Analytical'),
    (name: 'Graphic Design & UI/UX', category: 'Tech'),
    (name: 'Team Collaboration', category: 'Soft'),
  ],
  'I.Com (Commerce, Economics, Accounting)': [
    (name: 'Accounting & Finance', category: 'Analytical'),
    (name: 'Economics', category: 'Analytical'),
    (name: 'Business Studies', category: 'Soft'),
    (name: 'Mathematics', category: 'Analytical'),
    (name: 'English', category: 'Soft'),
    (name: 'Data Analysis & Statistics', category: 'Analytical'),
    (name: 'Public Speaking', category: 'Soft'),
    (name: 'Critical Thinking', category: 'Analytical'),
    (name: 'Team Collaboration', category: 'Soft'),
    (name: 'Project Management', category: 'Soft'),
  ],
  'Humanities / Arts': [
    (name: 'English', category: 'Soft'),
    (name: 'Psychology', category: 'Analytical'),
    (name: 'Sociology', category: 'Analytical'),
    (name: 'Civics & Political Science', category: 'Analytical'),
    (name: 'Economics', category: 'Analytical'),
    (name: 'History', category: 'Analytical'),
    (name: 'Education', category: 'Soft'),
    (name: 'Fine Arts', category: 'Soft'),
    (name: 'Home Economics', category: 'Soft'),
    (name: 'Public Speaking', category: 'Soft'),
    (name: 'Critical Thinking', category: 'Analytical'),
    (name: 'Creative Writing', category: 'Soft'),
  ],
};

const Map<String, List<({String name, String category, String hint})>>
bachelorsSkillsByGroup = {
  'BS Software Engineering / Computer Science': [
    (name: 'Programming Fundamentals', category: 'Tech', hint: 'Python, C++ or Java'),
    (name: 'Data Structures & Algorithms', category: 'Tech', hint: 'DSA'),
    (name: 'Object-Oriented Programming', category: 'Tech', hint: 'OOP'),
    (
      name: 'Database Management',
      category: 'Tech',
      hint: 'SQL & NoSQL, e.g. MySQL, SQL Server, MongoDB',
    ),
    (name: 'Version Control', category: 'Tech', hint: 'Git & GitHub'),
    (
      name: 'Web Development Basics',
      category: 'Tech',
      hint: 'HTML5, CSS3, JavaScript',
    ),
    (name: 'Mobile App Development', category: 'Tech', hint: 'Flutter or React Native'),
    (name: 'RESTful APIs & Backend Integration', category: 'Tech', hint: ''),
    (
      name: 'SDLC & Agile/Scrum',
      category: 'Soft',
      hint: 'Software development life cycle',
    ),
    (name: 'UI/UX Design & Prototyping', category: 'Tech', hint: 'e.g. Figma'),
    (name: 'Operating Systems & Linux', category: 'Tech', hint: 'Linux command line'),
    (name: 'Software Testing & Debugging', category: 'Tech', hint: ''),
    (
      name: 'Cloud Computing Basics',
      category: 'Tech',
      hint: 'AWS, Firebase or Azure',
    ),
    (name: 'Problem Solving & Analytical Thinking', category: 'Analytical', hint: ''),
  ],
  'BE Electrical / Electronics Engineering': [
    (name: 'Circuit Design & Analysis', category: 'Tech', hint: ''),
    (name: 'PCB Design & Layout', category: 'Tech', hint: 'KiCad, Altium, EasyEDA'),
    (
      name: 'Microcontrollers & Embedded Systems',
      category: 'Tech',
      hint: 'Arduino, ESP32, STM32',
    ),
    (name: 'Embedded C / C++ Programming', category: 'Tech', hint: ''),
    (name: 'MATLAB & Simulink', category: 'Analytical', hint: 'Simulation & modeling'),
    (name: 'Digital Logic Design & HDL', category: 'Tech', hint: 'DLD, Verilog/VHDL'),
    (name: 'Power Systems & Electrical Machines', category: 'Tech', hint: 'Analysis'),
    (name: 'Control Systems & Automation', category: 'Tech', hint: 'PLC / SCADA'),
    (name: 'Signal Processing', category: 'Analytical', hint: 'DSP'),
    (
      name: 'Lab Equipment Handling',
      category: 'Tech',
      hint: 'Oscilloscope, multimeter, function generator',
    ),
    (name: 'AutoCAD Electrical', category: 'Tech', hint: ''),
    (name: 'IoT Integration', category: 'Tech', hint: 'Internet of Things'),
    (
      name: 'Troubleshooting & Fault Diagnosis',
      category: 'Analytical',
      hint: 'Hardware faults',
    ),
    (
      name: 'Technical Documentation & Safety Standards',
      category: 'Soft',
      hint: '',
    ),
  ],
  'BBA / BS Accounting & Finance': [
    (
      name: 'Financial Statement Analysis',
      category: 'Analytical',
      hint: 'Balance sheet, income statement, cash flow',
    ),
    (
      name: 'Advanced Excel',
      category: 'Analytical',
      hint: 'Pivot tables, XLOOKUP, macros, financial modeling',
    ),
    (name: 'Accounting Software', category: 'Tech', hint: 'QuickBooks, SAP, Xero or Tally'),
    (name: 'Budgeting & Forecasting', category: 'Analytical', hint: ''),
    (name: 'Taxation & Regulatory Compliance', category: 'Analytical', hint: ''),
    (name: 'Auditing & Internal Controls', category: 'Analytical', hint: ''),
    (name: 'Corporate Finance & Valuation', category: 'Analytical', hint: ''),
    (name: 'Business Communication & Report Writing', category: 'Soft', hint: ''),
    (name: 'Data Visualization & BI Tools', category: 'Tech', hint: 'Power BI or Tableau'),
    (name: 'Digital Marketing & Market Research', category: 'Soft', hint: 'Especially for BBA'),
    (name: 'Project Management & Operations', category: 'Soft', hint: ''),
    (name: 'Negotiation & Client Relationship Management', category: 'Soft', hint: ''),
    (name: 'Risk Management', category: 'Analytical', hint: ''),
    (name: 'Presentation & Pitching Skills', category: 'Soft', hint: 'PowerPoint'),
  ],
  'BS Biotechnology / Microbiology': [
    (name: 'Aseptic Techniques & Sterilization', category: 'Tech', hint: ''),
    (name: 'Microbial Culturing & Isolation', category: 'Tech', hint: ''),
    (name: 'PCR & Gel Electrophoresis', category: 'Tech', hint: 'Polymerase chain reaction'),
    (name: 'DNA/RNA Extraction & Quantification', category: 'Tech', hint: ''),
    (name: 'Microscopy & Staining Techniques', category: 'Tech', hint: 'Gram staining etc.'),
    (name: 'ELISA & Immunoassays', category: 'Tech', hint: ''),
    (name: 'Spectrophotometry & Chromatography', category: 'Tech', hint: 'HPLC / GC'),
    (name: 'Bioinformatics & Sequence Analysis', category: 'Analytical', hint: 'BLAST, NCBI tools'),
    (name: 'Biosafety & Lab Waste Management', category: 'Soft', hint: 'GLP / GMP'),
    (name: 'Fermentation & Bioprocess Technology', category: 'Tech', hint: ''),
    (name: 'Quality Control & Quality Assurance', category: 'Analytical', hint: 'QC / QA'),
    (name: 'Scientific Research & Literature Review', category: 'Analytical', hint: ''),
    (name: 'Statistical Data Analysis', category: 'Analytical', hint: 'SPSS, R or GraphPad Prism'),
    (name: 'Lab Documentation & Report Writing', category: 'Soft', hint: ''),
  ],
  'BS Psychology / Social Sciences': [
    (name: 'Research Methodology', category: 'Analytical', hint: 'Qualitative & quantitative'),
    (name: 'Statistical Analysis & Software', category: 'Analytical', hint: 'SPSS, R or Jamovi'),
    (name: 'Psychological Assessment & Psychometrics', category: 'Analytical', hint: ''),
    (name: 'Active Listening & Empathy', category: 'Soft', hint: ''),
    (name: 'Case History Taking & Clinical Observation', category: 'Analytical', hint: ''),
    (name: 'Counseling & Interviewing Techniques', category: 'Soft', hint: ''),
    (name: 'Academic & Policy Writing', category: 'Soft', hint: ''),
    (name: 'Survey Design & Data Collection', category: 'Analytical', hint: ''),
    (name: 'Critical Thinking & Behavioral Analysis', category: 'Analytical', hint: ''),
    (name: 'Conflict Resolution & Mediation', category: 'Soft', hint: ''),
    (name: 'Ethical Standards & Confidentiality', category: 'Soft', hint: ''),
    (name: 'Public Speaking & Workshop Facilitation', category: 'Soft', hint: ''),
    (name: 'Community Outreach & Fieldwork', category: 'Soft', hint: ''),
    (name: 'Cross-Cultural Competence', category: 'Soft', hint: ''),
  ],
};

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({
    super.key,
    required this.academicProfile,
    required this.riasecScores,
    this.authService,
  });

  final StudentAcademicProfile academicProfile;
  final Map<String, int> riasecScores;
  final AuthService? authService;

  static List<String> get skillNames => List.unmodifiable(
    _SkillsScreenState._skillCatalog.map((skill) => skill.name),
  );

  static List<String> skillNamesForEducationLevel(
    String educationLevel, {
    String? specialization,
  }) => List.unmodifiable(
    _SkillsScreenState._skillsForEducationLevel(
      educationLevel,
      specialization,
    ).map((skill) => skill.name),
  );

  static List<({String name, String category})>
  intermediateSkillsForGroup(String specialization) =>
      List.unmodifiable(intermediateSkillsByGroup[specialization] ?? const []);

  static List<({String name, String category, String hint})>
  bachelorsSkillsForGroup(String specialization) =>
      List.unmodifiable(bachelorsSkillsByGroup[specialization] ?? const []);

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  static const List<_Skill> _skillCatalog = [
    _Skill('Python Programming', 'Tech', 4),
    _Skill('Logic & Problem Solving', 'Analytical', 4),
    _Skill('Mathematics & Calculus', 'Analytical', 4),
    _Skill('Data Analysis & Statistics', 'Analytical', 3),
    _Skill('System Design & Algorithms', 'Tech', 2),
    _Skill('Graphic Design & UI/UX', 'Tech', 2),
    _Skill('Public Speaking & English', 'Soft', 3),
    _Skill('Team Collaboration', 'Soft', 4),
    _Skill('Scientific Research', 'Analytical', 3),
    _Skill('Web Development Basics', 'Tech', 3),
    _Skill('Accounting & Finance', 'Analytical', 1),
    _Skill('Electronics & Hardware', 'Tech', 2),
    _Skill('Biology & Medical Terms', 'Analytical', 1),
    _Skill('Project Management', 'Soft', 3),
    _Skill('Critical Thinking', 'Analytical', 4),
    _Skill('Technical Writing', 'Soft', 3),
    _Skill('Database Querying (SQL)', 'Tech', 2),
    _Skill('Mentoring & Teaching', 'Soft', 3),
  ];

  static const Map<String, List<String>> _matricSubjectsByGroup = {
    'Science Group (Bio-Science)': [
      'English',
      'Mathematics',
      'Physics',
      'Chemistry',
      'Biology',
    ],
    'General Science Group (Computer Science)': [
      'English',
      'Mathematics',
      'Physics',
      'Chemistry',
      'Computer Science',
    ],
    'Arts / Humanities & Home Economics Group': [
      'English',
      'Mathematics',
      'General Science',
      'Civics',
      'Economics',
      'History',
      'Education',
      'Home Economics',
      'Geography',
    ],
  };
  static const Map<String, String> _matricSubjectCategories = {
    'English': 'Soft',
    'Mathematics': 'Analytical',
    'Physics': 'Analytical',
    'Chemistry': 'Analytical',
    'Biology': 'Analytical',
    'Computer Science': 'Tech',
    'General Science': 'Analytical',
    'Civics': 'Soft',
    'Economics': 'Soft',
    'History': 'Soft',
    'Education': 'Soft',
    'Home Economics': 'Soft',
    'Geography': 'Soft',
  };

  static const List<_SkillCategory> _categories = [
    _SkillCategory('All', 'All'),
    _SkillCategory('Tech', 'Technical'),
    _SkillCategory('Analytical', 'Analytical'),
    _SkillCategory('Soft', 'Communication'),
  ];

  late final List<_Skill> _visibleSkillCatalog;
  late final Map<String, int> _ratings;
  String _selectedCategory = 'All';
  String _searchQuery = '';

  static List<_Skill> _skillsForEducationLevel(
    String educationLevel,
    String? specialization,
  ) {
    switch (educationLevel.trim().toLowerCase()) {
      case 'matric':
        return [
          for (final name
              in _matricSubjectsByGroup[specialization] ?? const [])
            _Skill(name, _matricSubjectCategories[name]!, 1),
        ];
      case 'intermediate':
        return [
          for (final skill
              in intermediateSkillsByGroup[specialization] ?? const [])
            _Skill(skill.name, skill.category, 3),
        ];
      case 'bachelors':
      case "bachelor's":
        return [
          for (final skill
              in bachelorsSkillsByGroup[specialization] ?? const [])
            _Skill(skill.name, skill.category, 3, hint: skill.hint),
        ];
      default:
        return _skillCatalog;
    }
  }

  @override
  void initState() {
    super.initState();
    final isMatric =
        widget.academicProfile.educationLevel.trim().toLowerCase() == 'matric';
    _visibleSkillCatalog = _skillsForEducationLevel(
      widget.academicProfile.educationLevel,
      widget.academicProfile.specialization,
    );
    _ratings = {
      for (final skill in _visibleSkillCatalog)
        skill.name: isMatric ? 1 : skill.initialRating,
    };
  }

  List<_Skill> get _visibleSkills {
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    return _visibleSkillCatalog.where((skill) {
      final matchesCategory =
          _selectedCategory == 'All' || skill.category == _selectedCategory;
      final matchesQuery =
          skill.name.toLowerCase().contains(normalizedQuery) ||
          skill.hint.toLowerCase().contains(normalizedQuery);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  void _openResults() {
    Navigator.of(context).push<void>(
      _fadeSlideRoute(
        ResultsScreen(
          academicProfile: widget.academicProfile,
          riasecScores: Map.unmodifiable(widget.riasecScores),
          skillRatings: Map.unmodifiable(_ratings),
          authService: widget.authService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleSkills = _visibleSkills;
    final visibleCategories = _categories
        .where(
          (category) =>
              category.key == 'All' ||
              _visibleSkillCatalog.any(
                (skill) => skill.category == category.key,
              ),
        )
        .toList(growable: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMatric =
        widget.academicProfile.educationLevel.trim().toLowerCase() == 'matric';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 12, 0),
              child: Row(
                children: [
                  _BackButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primaryLight.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Step 3 of 3: Skills',
                      style: AppTheme.label(
                        fontSize: 10,
                        color: AppTheme.accent(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const ThemeModeButton(),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: _StepProgress(value: 1),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 17, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Rate Your Core Skills',
                    style: AppTheme.heading(
                      fontSize: 23,
                      color: AppTheme.onCanvas(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Self-rate your proficiency (1 = Beginner, 5 = Master).',
                    style: AppTheme.body(
                      fontSize: 12,
                      color: AppTheme.muted(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: AppTheme.body(
                      fontSize: 13,
                      color: AppTheme.onCanvas(context),
                    ),
                    decoration: InputDecoration(
                      hintText: isMatric
                          ? 'Search subjects (e.g. Biology, Math)...'
                          : 'Search skills (e.g. Python, Math)...',
                      hintStyle: AppTheme.body(
                        fontSize: 12,
                        color: AppTheme.muted(context),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppTheme.muted(context),
                        size: 19,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? AppTheme.surface
                          : AppTheme.lightSurface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      border: _inputBorder(context),
                      enabledBorder: _inputBorder(context),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.accent(context),
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (
                          var index = 0;
                          index < visibleCategories.length;
                          index++
                        ) ...[
                          _CategoryChip(
                            category: visibleCategories[index],
                            selected:
                                _selectedCategory ==
                                visibleCategories[index].key,
                            count: visibleCategories[index].key == 'All'
                                ? _visibleSkillCatalog.length
                                : _visibleSkillCatalog
                                      .where(
                                        (skill) =>
                                            skill.category ==
                                            visibleCategories[index].key,
                                      )
                                      .length,
                            onTap: () {
                              setState(() {
                                _selectedCategory =
                                    visibleCategories[index].key;
                              });
                            },
                          ),
                          if (index < visibleCategories.length - 1)
                            const SizedBox(width: 7),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: visibleSkills.isEmpty
                  ? Center(
                      child: Text(
                        'No matching skills found.',
                        style: AppTheme.body(
                          fontSize: 13,
                          color: AppTheme.muted(context),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                      itemCount: visibleSkills.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 9),
                      itemBuilder: (context, index) {
                        final skill = visibleSkills[index];
                        final rating = _ratings[skill.name]!;
                        return _SkillRatingCard(
                          skill: skill,
                          rating: rating,
                          onChanged: (value) {
                            setState(() => _ratings[skill.name] = value);
                          },
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppTheme.glassBorder : AppTheme.lightBorder,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Progress: ',
                        style: AppTheme.label(
                          fontSize: 11,
                          color: AppTheme.muted(context),
                        ),
                      ),
                      Text(
                        '${_ratings.length} of '
                        '${_visibleSkillCatalog.length} rated',
                        style: AppTheme.label(
                          fontSize: 11,
                          color: AppTheme.accent(context),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.cyan,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ready',
                        style: AppTheme.label(
                          fontSize: 10,
                          color: AppTheme.cyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  _GradientButton(
                    label: isMatric
                        ? 'Get Study Path Recommendations'
                        : 'Get AI Career Matches',
                    onPressed: _openResults,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Skill {
  const _Skill(
    this.name,
    this.category,
    this.initialRating, {
    this.hint = '',
  });

  final String name;
  final String category;
  final int initialRating;
  final String hint;
}

class _SkillCategory {
  const _SkillCategory(this.key, this.label);

  final String key;
  final String label;
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final _SkillCategory category;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: selected
          ? Colors.transparent
          : isDark
          ? AppTheme.surface
          : AppTheme.lightSurface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            gradient: selected ? AppTheme.primaryGradient : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : isDark
                  ? AppTheme.glassBorder
                  : AppTheme.lightBorder,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            category.key == 'All' ? 'All ($count)' : category.label,
            style: AppTheme.label(
              fontSize: 10,
              color: selected ? Colors.white : AppTheme.muted(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkillRatingCard extends StatelessWidget {
  const _SkillRatingCard({
    required this.skill,
    required this.rating,
    required this.onChanged,
  });

  final _Skill skill;
  final int rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  skill.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.label(
                    fontSize: 12,
                    color: AppTheme.onCanvas(context),
                  ),
                ),
              ),
              if (skill.category.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accent(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: AppTheme.accent(context).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    skill.category == 'Soft'
                        ? 'Communication'
                        : skill.category == 'Tech'
                        ? 'Technical'
                        : skill.category,
                    style: AppTheme.label(
                      fontSize: 9,
                      color: AppTheme.accent(context),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (skill.hint.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                skill.hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.body(
                  fontSize: 9,
                  color: AppTheme.muted(context),
                ),
              ),
            ),
          const SizedBox(height: 2),
          Text(
            'Level $rating: ${_ratingLabel(rating)}',
            style: AppTheme.label(
              fontSize: 10,
              color: AppTheme.accent(context),
            ),
          ),
          Slider(
            value: rating.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '$rating',
            activeColor: AppTheme.accent(context),
            inactiveColor: AppTheme.muted(context).withValues(alpha: 0.24),
            onChanged: (value) => onChanged(value.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1 Beginner',
                style: AppTheme.body(
                  fontSize: 9,
                  color: AppTheme.muted(context),
                ),
              ),
              Text(
                '5 Master',
                style: AppTheme.body(
                  fontSize: 9,
                  color: AppTheme.muted(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _ratingLabel(int rating) {
  return switch (rating) {
    1 => 'Beginner',
    2 => 'Elementary',
    3 => 'Intermediate',
    4 => 'Advanced',
    5 => 'Master',
    _ => 'Not rated',
  };
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      onPressed: onPressed,
      tooltip: 'Back',
      style: IconButton.styleFrom(
        backgroundColor: isDark ? AppTheme.surface : AppTheme.lightSurface,
        foregroundColor: AppTheme.onCanvas(context),
        side: BorderSide(
          color: isDark ? AppTheme.glassBorder : AppTheme.lightBorder,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 6,
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.surface
            : AppTheme.lightBorder,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value,
          child: const SizedBox.expand(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryLight, AppTheme.cyan],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputBorder _inputBorder(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(
      color: isDark ? AppTheme.glassBorder : AppTheme.lightBorder,
    ),
  );
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryLight, AppTheme.cyan],
        ),
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 16),
                const SizedBox(width: 8),
                Text(label, style: AppTheme.title(fontSize: 13)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Route<void> _fadeSlideRoute(Widget page) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
