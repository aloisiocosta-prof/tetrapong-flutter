import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

const gold = Color(0xFFFFD700);
const blue = Color(0xFF0055FF);
const pink = Color(0xFFFF3366);
const ink = Color(0xFF050505);

void main() => runApp(const TetraPongApp());

enum GamePhase {
  menu,
  howToPlay,
  settings,
  ready,
  playing,
  paused,
  danger,
  result,
}

class MatchState {
  GamePhase phase = GamePhase.menu;
  double ballX = .5, ballY = .5, vx = .42, vy = .18;
  double paddleLeft = .5, paddleRight = .5;
  int scoreLeft = 0, scoreRight = 0, missesLeft = 0, missesRight = 0;
  int linesLeft = 0, linesRight = 0;
  int? winner;
  final boardLeft = List.generate(16, (_) => List.filled(6, 0));
  final boardRight = List.generate(16, (_) => List.filled(6, 0));
}

class GameController extends ChangeNotifier {
  final state = MatchState();
  Timer? _timer;
  DateTime? _last;
  bool reducedMotion = false, highContrast = true;

  void start() {
    state.phase = GamePhase.ready;
    state.winner = null;
    state.scoreLeft = state.scoreRight = state.missesLeft = state.missesRight =
        0;
    state.linesLeft = state.linesRight = 0;
    for (final board in [state.boardLeft, state.boardRight]) {
      for (final row in board) row.fillRange(0, row.length, 0);
    }
    state.ballX = .5;
    state.ballY = .5;
    state.vx = .42;
    state.vy = .18;
    _timer?.cancel();
    _last = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => tick());
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (state.phase == GamePhase.ready) {
        state.phase = GamePhase.playing;
        notifyListeners();
      }
    });
  }

  void tick() {
    if (state.phase != GamePhase.playing && state.phase != GamePhase.danger)
      return;
    final now = DateTime.now();
    final dt = (now.difference(_last ?? now).inMicroseconds / 1000000).clamp(
      0.0,
      .05,
    );
    _last = now;
    state.ballX += state.vx * dt;
    state.ballY += state.vy * dt;
    if (state.ballY < .06 || state.ballY > .94) {
      state.ballY = state.ballY.clamp(.06, .94);
      state.vy *= -1;
    }
    if (state.ballX < .11 &&
        (state.ballY - state.paddleLeft).abs() < .14 &&
        state.vx < 0) {
      state.ballX = .12;
      state.vx = state.vx.abs() * 1.035;
      state.vy += (state.ballY - state.paddleLeft) * .5;
      state.scoreLeft++;
      notifyListeners();
      return;
    }
    if (state.ballX > .89 &&
        (state.ballY - state.paddleRight).abs() < .14 &&
        state.vx > 0) {
      state.ballX = .88;
      state.vx = -state.vx.abs() * 1.035;
      state.vy += (state.ballY - state.paddleRight) * .5;
      state.scoreRight++;
      notifyListeners();
      return;
    }
    if (state.ballX < .02) _miss(false);
    if (state.ballX > .98) _miss(true);
    notifyListeners();
  }

  void _miss(bool rightPlayer) {
    state.ballX = .5;
    state.ballY = .5;
    state.vx = rightPlayer ? -.42 : .42;
    state.vy = (math.Random().nextDouble() - .5) * .42;
    if (rightPlayer) {
      state.missesRight++;
      _addPenalty(state.boardRight);
    } else {
      state.missesLeft++;
      _addPenalty(state.boardLeft);
    }
    final board = rightPlayer ? state.boardRight : state.boardLeft;
    final filled = board.expand((r) => r).where((v) => v == 1).length;
    if (filled > 45) state.phase = GamePhase.danger;
    if (board.first.any((v) => v == 1)) {
      state.winner = rightPlayer ? 0 : 1;
      state.phase = GamePhase.result;
      _timer?.cancel();
    }
  }

  void _addPenalty(List<List<int>> board) {
    board.removeAt(0);
    board.add(List.generate(6, (i) => i == math.Random().nextInt(6) ? 0 : 1));
    final cleared = board.where((row) => row.every((v) => v == 1)).toList();
    for (final row in cleared) {
      board.remove(row);
      board.insert(0, List.filled(6, 0));
    }
    if (cleared.isNotEmpty) {
      if (identical(board, state.boardLeft))
        state.linesLeft += cleared.length;
      else
        state.linesRight += cleared.length;
      if (board.expand((r) => r).where((v) => v == 1).length < 35)
        state.phase = GamePhase.playing;
    }
  }

  void setPaddle(bool left, double y) {
    if (left)
      state.paddleLeft = y.clamp(.15, .85);
    else
      state.paddleRight = y.clamp(.15, .85);
    notifyListeners();
  }

  void pause() {
    if (state.phase == GamePhase.playing || state.phase == GamePhase.danger) {
      state.phase = GamePhase.paused;
      notifyListeners();
    }
  }

  void resume() {
    if (state.phase == GamePhase.paused) {
      state.phase = GamePhase.playing;
      notifyListeners();
    }
  }

  void disposeGame() {
    _timer?.cancel();
    super.dispose();
  }
}

class TetraPongApp extends StatefulWidget {
  const TetraPongApp({super.key});
  @override
  State<TetraPongApp> createState() => _TetraPongAppState();
}

class _TetraPongAppState extends State<TetraPongApp> {
  final game = GameController();
  @override
  void dispose() {
    game.disposeGame();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: game,
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: ink,
        colorScheme: const ColorScheme.dark(primary: gold, surface: ink),
      ),
      home: GameShell(game: game),
    ),
  );
}

class GameShell extends StatelessWidget {
  final GameController game;
  const GameShell({super.key, required this.game});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, c) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: _screen(context, c),
          ),
        ),
      ),
    ),
  );
  Widget _screen(BuildContext context, BoxConstraints c) {
    final s = game.state;
    switch (s.phase) {
      case GamePhase.menu:
        return MenuView(game: game);
      case GamePhase.howToPlay:
        return InfoView(
          title: 'HOW TO PLAY',
          body: 'Mova o paddle para interceptar o tetraminó. Um HIT rebate a peça. Um MISS cria uma penalidade no seu board. Limpe linhas para recuperar espaço. O primeiro board a transbordar perde.',
          onBack: () {
            s.phase = GamePhase.menu;
            game.notifyListeners();
          },
        );
      case GamePhase.settings:
        return SettingsView(game: game);
      case GamePhase.result:
        return ResultView(game: game);
      default:
        return GameplayView(game: game, size: Size(c.maxWidth, c.maxHeight));
    }
  }
}

class Frame extends StatelessWidget {
  final Widget child;
  const Frame({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: gold, width: 4),
      color: ink,
    ),
    child: child,
  );
}

class MenuView extends StatelessWidget {
  final GameController game;
  const MenuView({super.key, required this.game});
  @override
  Widget build(BuildContext context) => Frame(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'TETRAPONG',
          style: TextStyle(
            color: gold,
            fontSize: 58,
            fontWeight: FontWeight.w900,
            letterSpacing: 5,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'EVERY MISS BUILDS A PROBLEM',
          style: TextStyle(color: Colors.white70, letterSpacing: 2),
        ),
        const SizedBox(height: 40),
        ActionButton(label: 'PLAY', onTap: game.start, primary: true),
        ActionButton(
          label: 'HOW TO PLAY',
          onTap: () {
            game.state.phase = GamePhase.howToPlay;
            game.notifyListeners();
          },
        ),
        ActionButton(
          label: 'SETTINGS',
          onTap: () {
            game.state.phase = GamePhase.settings;
            game.notifyListeners();
          },
        ),
      ],
    ),
  );
}

class ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  const ActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 24),
    child: SizedBox(
      width: 330,
      height: 54,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: primary ? gold : Colors.white70, width: 2),
          foregroundColor: primary ? gold : Colors.white,
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2),
        ),
      ),
    ),
  );
}

class GameplayView extends StatelessWidget {
  final GameController game;
  final Size size;
  const GameplayView({super.key, required this.game, required this.size});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (d) => game.setPaddle(
        true,
        game.state.paddleLeft +
            d.delta.dy / (size.height == 0 ? 1 : size.height),
      ),
      child: Stack(
        children: [
          CustomPaint(size: size, painter: ArenaPainter(game.state)),
          Positioned(
            top: 12,
            left: 18,
            child: Text(
              'P1  ${game.state.scoreLeft}',
              style: const TextStyle(
                color: blue,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 18,
            child: Text(
              '${game.state.scoreRight}  P2',
              style: const TextStyle(
                color: pink,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                game.state.phase == GamePhase.ready
                    ? 'READY'
                    : game.state.phase == GamePhase.paused
                    ? 'PAUSED'
                    : game.state.phase == GamePhase.danger
                    ? 'DANGER'
                    : 'PLAYING',
                style: TextStyle(
                  color: game.state.phase == GamePhase.danger ? pink : gold,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 90,
            child: IconButton(
              onPressed: game.pause,
              icon: const Icon(Icons.pause, color: Colors.white),
            ),
          ),
          if (game.state.phase == GamePhase.paused)
            Center(
              child: ActionButton(
                label: 'RESUME',
                onTap: game.resume,
                primary: true,
              ),
            ),
        ],
      ),
    );
  }
}

class ArenaPainter extends CustomPainter {
  final MatchState s;
  ArenaPainter(this.s);
  @override
  void paint(Canvas c, Size size) {
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = gold.withOpacity(.25);
    for (var x = 0.0; x < size.width; x += size.width / 24)
      c.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    for (var y = 0.0; y < size.height; y += size.height / 14)
      c.drawLine(Offset(0, y), Offset(size.width, y), grid);
    c.drawRect(
      Rect.fromLTRB(8, 8, size.width - 8, size.height - 8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = gold,
    );
    _board(c, s.boardLeft, 20, size.height * .25, blue);
    _board(c, s.boardRight, size.width - 110, size.height * .25, pink);
    final paddle = Paint();
    paddle.color = blue;
    c.drawRect(
      Rect.fromCenter(
        center: Offset(size.width * .11, s.paddleLeft * size.height),
        width: 18,
        height: 100,
      ),
      paddle,
    );
    paddle.color = pink;
    c.drawRect(
      Rect.fromCenter(
        center: Offset(size.width * .89, s.paddleRight * size.height),
        width: 18,
        height: 100,
      ),
      paddle,
    );
    paddle.color = gold;
    final bx = s.ballX * size.width, by = s.ballY * size.height;
    c.drawRect(
      Rect.fromCenter(center: Offset(bx, by), width: 28, height: 28),
      paddle,
    );
    final tet = Path()
      ..moveTo(bx, by - 23)
      ..lineTo(bx - 23, by)
      ..lineTo(bx - 8, by)
      ..lineTo(bx - 8, by + 18)
      ..lineTo(bx + 8, by + 18)
      ..lineTo(bx + 8, by)
      ..lineTo(bx + 23, by)
      ..close();
    c.drawPath(
      tet,
      Paint()
        ..color = gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  void _board(Canvas c, List<List<int>> b, double x, double y, Color color) {
    final fill = Paint()..color = color;
    for (var r = 0; r < b.length; r++)
      for (var col = 0; col < b[r].length; col++)
        if (b[r][col] == 1)
          c.drawRect(Rect.fromLTWH(x + col * 12, y + r * 12, 11, 11), fill);
  }

  @override
  bool shouldRepaint(covariant ArenaPainter oldDelegate) => true;
}

class InfoView extends StatelessWidget {
  final String title, body;
  final VoidCallback onBack;
  const InfoView({
    super.key,
    required this.title,
    required this.body,
    required this.onBack,
  });
  @override
  Widget build(BuildContext context) => Frame(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: gold,
                fontSize: 42,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, height: 1.5),
              ),
            ),
            const SizedBox(height: 35),
            ActionButton(label: 'BACK', onTap: onBack),
          ],
        ),
      ),
    ),
  );
}

class SettingsView extends StatelessWidget {
  final GameController game;
  const SettingsView({super.key, required this.game});
  @override
  Widget build(BuildContext context) => Frame(
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'SETTINGS',
            style: TextStyle(
              color: gold,
              fontSize: 42,
              fontWeight: FontWeight.bold,
            ),
          ),
          SwitchListTile(
            title: const Text('HIGH CONTRAST'),
            value: game.highContrast,
            onChanged: (v) {
              game.highContrast = v;
              game.notifyListeners();
            },
          ),
          SwitchListTile(
            title: const Text('REDUCE MOTION'),
            value: game.reducedMotion,
            onChanged: (v) {
              game.reducedMotion = v;
              game.notifyListeners();
            },
          ),
          const SizedBox(height: 25),
          ActionButton(
            label: 'BACK',
            onTap: () {
              game.state.phase = GamePhase.menu;
              game.notifyListeners();
            },
          ),
        ],
      ),
    ),
  );
}

class ResultView extends StatelessWidget {
  final GameController game;
  const ResultView({super.key, required this.game});
  @override
  Widget build(BuildContext context) {
    final blueWon = game.state.winner == 0;
    return Frame(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              blueWon ? 'VICTORY' : 'DEFEAT',
              style: TextStyle(
                color: blueWon ? blue : pink,
                fontSize: 62,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'P1 ${game.state.scoreLeft}  —  ${game.state.scoreRight} P2',
              style: const TextStyle(color: Colors.white, fontSize: 26),
            ),
            const SizedBox(height: 35),
            ActionButton(label: 'REMATCH', onTap: game.start, primary: true),
            ActionButton(
              label: 'MAIN MENU',
              onTap: () {
                game.state.phase = GamePhase.menu;
                game.notifyListeners();
              },
            ),
          ],
        ),
      ),
    );
  }
}
