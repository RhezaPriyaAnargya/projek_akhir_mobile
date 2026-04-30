import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

const Color _navy = Color(0xFF1A3557);
const Color _teal = Color(0xFF2ABFBF);
const Color _cream = Color(0xFFF5F0E8);

// ─── Data Soal ────────────────────────────────────────────────────────────────

class QuizQuestion {
  final String question;
  final String correctAnswer;
  final List<String> options;
  final String emoji;

  QuizQuestion({
    required this.question,
    required this.correctAnswer,
    required this.options,
    required this.emoji,
  });
}

const List<Map<String, String>> _capitalData = [
  {'country': 'Indonesia', 'capital': 'Jakarta', 'emoji': '🇮🇩'},
  {'country': 'Jepang', 'capital': 'Tokyo', 'emoji': '🇯🇵'},
  {'country': 'Perancis', 'capital': 'Paris', 'emoji': '🇫🇷'},
  {'country': 'Brasil', 'capital': 'Brasília', 'emoji': '🇧🇷'},
  {'country': 'Australia', 'capital': 'Canberra', 'emoji': '🇦🇺'},
  {'country': 'Kanada', 'capital': 'Ottawa', 'emoji': '🇨🇦'},
  {'country': 'India', 'capital': 'New Delhi', 'emoji': '🇮🇳'},
  {'country': 'China', 'capital': 'Beijing', 'emoji': '🇨🇳'},
  {'country': 'Amerika Serikat', 'capital': 'Washington D.C.', 'emoji': '🇺🇸'},
  {'country': 'Rusia', 'capital': 'Moskow', 'emoji': '🇷🇺'},
  {'country': 'Jerman', 'capital': 'Berlin', 'emoji': '🇩🇪'},
  {'country': 'Italia', 'capital': 'Roma', 'emoji': '🇮🇹'},
  {'country': 'Spanyol', 'capital': 'Madrid', 'emoji': '🇪🇸'},
  {'country': 'Inggris', 'capital': 'London', 'emoji': '🇬🇧'},
  {'country': 'Korea Selatan', 'capital': 'Seoul', 'emoji': '🇰🇷'},
  {'country': 'Thailand', 'capital': 'Bangkok', 'emoji': '🇹🇭'},
  {'country': 'Malaysia', 'capital': 'Kuala Lumpur', 'emoji': '🇲🇾'},
  {'country': 'Filipina', 'capital': 'Manila', 'emoji': '🇵🇭'},
  {'country': 'Vietnam', 'capital': 'Hanoi', 'emoji': '🇻🇳'},
  {'country': 'Singapura', 'capital': 'Singapura', 'emoji': '🇸🇬'},
  {'country': 'Mesir', 'capital': 'Kairo', 'emoji': '🇪🇬'},
  {'country': 'Afrika Selatan', 'capital': 'Pretoria', 'emoji': '🇿🇦'},
  {'country': 'Argentina', 'capital': 'Buenos Aires', 'emoji': '🇦🇷'},
  {'country': 'Meksiko', 'capital': 'Mexico City', 'emoji': '🇲🇽'},
  {'country': 'Arab Saudi', 'capital': 'Riyadh', 'emoji': '🇸🇦'},
  {'country': 'Turki', 'capital': 'Ankara', 'emoji': '🇹🇷'},
  {'country': 'Portugal', 'capital': 'Lisbon', 'emoji': '🇵🇹'},
  {'country': 'Belanda', 'capital': 'Amsterdam', 'emoji': '🇳🇱'},
  {'country': 'Swiss', 'capital': 'Bern', 'emoji': '🇨🇭'},
  {'country': 'Swedia', 'capital': 'Stockholm', 'emoji': '🇸🇪'},
];

List<QuizQuestion> _generateQuestions() {
  final rng = Random();
  final shuffled = List<Map<String, String>>.from(_capitalData)..shuffle(rng);
  final selected = shuffled.take(10).toList();
  final allCapitals = _capitalData.map((e) => e['capital']!).toList();

  return selected.map((item) {
    final correct = item['capital']!;
    final wrongs = List<String>.from(allCapitals)..remove(correct);
    wrongs.shuffle(rng);
    final options = [correct, ...wrongs.take(3)]..shuffle(rng);

    return QuizQuestion(
      question: 'Apa ibu kota dari ${item['country']}?',
      correctAnswer: correct,
      options: options,
      emoji: item['emoji']!,
    );
  }).toList();
}

// ─── Game Screen ──────────────────────────────────────────────────────────────

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  _GamePhase _phase = _GamePhase.home;
  List<QuizQuestion> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  String? _selectedAnswer;
  bool _answered = false;
  int _timeLeft = 15;
  Timer? _timer;
  int _streak = 0;
  int _bestStreak = 0;
  List<bool> _answerHistory = [];

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = 15;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) {
        t.cancel();
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    if (_answered) return;
    setState(() {
      _answered = true;
      _selectedAnswer = null;
      _streak = 0;
      _answerHistory.add(false);
    });
    Future.delayed(const Duration(seconds: 2), _nextQuestion);
  }

  void _startGame() {
    setState(() {
      _questions = _generateQuestions();
      _currentIndex = 0;
      _score = 0;
      _streak = 0;
      _bestStreak = 0;
      _selectedAnswer = null;
      _answered = false;
      _answerHistory = [];
      _phase = _GamePhase.playing;
    });
    _startTimer();
  }

  void _selectAnswer(String answer) {
    if (_answered) return;
    _timer?.cancel();

    final correct = answer == _questions[_currentIndex].correctAnswer;
    if (correct) {
      _streak++;
      if (_streak > _bestStreak) _bestStreak = _streak;
      _score += _timeLeft > 10
          ? 150
          : _timeLeft > 5
          ? 100
          : 70;
    } else {
      _streak = 0;
    }

    setState(() {
      _selectedAnswer = answer;
      _answered = true;
      _answerHistory.add(correct);
    });

    Future.delayed(const Duration(milliseconds: 1200), _nextQuestion);
  }

  void _nextQuestion() {
    if (!mounted) return;
    if (_currentIndex + 1 >= _questions.length) {
      setState(() => _phase = _GamePhase.result);
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedAnswer = null;
      _answered = false;
    });
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Row(
          children: [
            Text('🌍', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text(
              'Trek Quiz',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: switch (_phase) {
          _GamePhase.home => _buildHome(),
          _GamePhase.playing => _buildPlaying(),
          _GamePhase.result => _buildResult(),
        },
      ),
    );
  }

  // ─── Home ─────────────────────────────────────────────────────────────────

  Widget _buildHome() {
    return SingleChildScrollView(
      key: const ValueKey('home'),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // Hero banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_navy, Color(0xFF254878)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _navy.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -20,
                  right: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _teal.withOpacity(0.2),
                    ),
                  ),
                ),
                Column(
                  children: [
                    const Text('🌍', style: TextStyle(fontSize: 60)),
                    const SizedBox(height: 14),
                    const Text(
                      'Kuis Ibu Kota Dunia',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Uji pengetahuanmu tentang ibu kota negara-negara di dunia!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Info cards
          Row(
            children: [
              _infoCard('🎯', '10', 'Soal'),
              const SizedBox(width: 10),
              _infoCard('⏱️', '15', 'Detik/Soal'),
              const SizedBox(width: 10),
              _infoCard('⭐', '150', 'Maks/Soal'),
            ],
          ),
          const SizedBox(height: 20),

          // Cara bermain
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _navy.withOpacity(0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _teal,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Cara Bermain',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ruleItem('1', 'Pilih jawaban yang benar sebelum waktu habis'),
                _ruleItem('2', 'Jawab cepat untuk poin lebih besar'),
                _ruleItem('3', 'Bangun streak untuk jadi yang terbaik'),
                _ruleItem('4', 'Ada 10 soal di setiap sesi'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Mulai button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                  SizedBox(width: 8),
                  Text(
                    'Mulai Kuis!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _infoCard(String emoji, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _navy.withOpacity(0.07),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: _navy,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ruleItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _teal.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _teal,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Playing ──────────────────────────────────────────────────────────────

  Widget _buildPlaying() {
    final q = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;
    final timerColor = _timeLeft > 10
        ? Colors.green
        : _timeLeft > 5
        ? Colors.orange
        : Colors.red;

    return SingleChildScrollView(
      key: ValueKey('playing_$_currentIndex'),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Progress & stats
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _navy.withOpacity(0.07),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Soal ${_currentIndex + 1}/10',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _navy,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 4),
                          Text(
                            '$_streak streak',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Text('⭐', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 4),
                          Text(
                            '$_score',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: Colors.grey.shade100,
                    color: _teal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Timer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: timerColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: timerColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_outlined, color: timerColor, size: 18),
                const SizedBox(width: 6),
                Text(
                  '$_timeLeft detik',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: timerColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Question card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_navy, Color(0xFF254878)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _navy.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(q.emoji, style: const TextStyle(fontSize: 50)),
                const SizedBox(height: 12),
                Text(
                  q.question,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Options
          ...q.options.map((option) => _buildOptionButton(option, q)),

          // Dots
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_questions.length, (i) {
              Color color;
              if (i < _answerHistory.length) {
                color = _answerHistory[i] ? Colors.green : Colors.red;
              } else if (i == _currentIndex) {
                color = _teal;
              } else {
                color = Colors.grey.shade300;
              }
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _currentIndex ? 16 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildOptionButton(String option, QuizQuestion q) {
    Color bgColor = Colors.white;
    Color borderColor = Colors.grey.shade200;
    Color textColor = _navy;
    IconData? icon;

    if (_answered) {
      if (option == q.correctAnswer) {
        bgColor = const Color(0xFFE8F5E9);
        borderColor = Colors.green;
        textColor = Colors.green.shade800;
        icon = Icons.check_circle_rounded;
      } else if (option == _selectedAnswer) {
        bgColor = const Color(0xFFFFEBEE);
        borderColor = Colors.red;
        textColor = Colors.red.shade800;
        icon = Icons.cancel_rounded;
      }
    }

    return GestureDetector(
      onTap: () => _selectAnswer(option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _navy.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            if (icon != null)
              Icon(
                icon,
                color: option == q.correctAnswer ? Colors.green : Colors.red,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  // ─── Result ───────────────────────────────────────────────────────────────

  Widget _buildResult() {
    final total = _questions.length;
    final correct = _answerHistory.where((e) => e).length;
    final pct = (correct / total * 100).round();

    String medal;
    String message;
    Color medalColor;

    if (pct >= 90) {
      medal = '🏆';
      message = 'Luar Biasa! Kamu jenius geografi!';
      medalColor = const Color(0xFFFFD700);
    } else if (pct >= 70) {
      medal = '🥈';
      message = 'Bagus sekali! Hampir sempurna!';
      medalColor = const Color(0xFFC0C0C0);
    } else if (pct >= 50) {
      medal = '🥉';
      message = 'Lumayan! Terus berlatih!';
      medalColor = const Color(0xFFCD7F32);
    } else {
      medal = '📚';
      message = 'Jangan menyerah, coba lagi!';
      medalColor = _teal;
    }

    return SingleChildScrollView(
      key: const ValueKey('result'),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // Medal card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  medalColor.withOpacity(0.85),
                  medalColor.withOpacity(0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: medalColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(medal, style: const TextStyle(fontSize: 60)),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stats
          Row(
            children: [
              _statCard('✅', '$correct/$total', 'Benar', Colors.green),
              const SizedBox(width: 10),
              _statCard('⭐', '$_score', 'Skor', Colors.amber),
              const SizedBox(width: 10),
              _statCard('🔥', '$_bestStreak', 'Best Streak', Colors.deepOrange),
            ],
          ),
          const SizedBox(height: 16),

          // Rekap jawaban
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _navy.withOpacity(0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _teal,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Rekap Jawaban',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...List.generate(_questions.length, (i) {
                  final isCorrect =
                      i < _answerHistory.length && _answerHistory[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Text(
                          _questions[i].emoji,
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _questions[i].question
                                .replaceAll('Apa ibu kota dari ', '')
                                .replaceAll('?', ''),
                            style: const TextStyle(fontSize: 13, color: _navy),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _questions[i].correctAnswer,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isCorrect
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          isCorrect ? Icons.check_circle : Icons.cancel,
                          color: isCorrect ? Colors.green : Colors.red,
                          size: 16,
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _phase = _GamePhase.home),
                  icon: const Icon(Icons.home_rounded, color: _navy, size: 18),
                  label: const Text(
                    'Menu',
                    style: TextStyle(color: _navy, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: _navy),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _startGame,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    'Main Lagi',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _statCard(String emoji, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _navy.withOpacity(0.07),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

enum _GamePhase { home, playing, result }
