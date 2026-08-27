import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'remote_socket.dart';

const gold = Color(0xFFFFD700);
const blue = Color(0xFF0055FF);
const pink = Color(0xFFFF3366);
const ink = Color(0xFF050505);

void main() => runApp(const TetraPongApp());

enum P2Mode { ai, localKeyboard, remote }

enum TetrominoType { i, j, l, o, s, t, z }

const tetrominoCells = <TetrominoType, List<List<int>>>{
  TetrominoType.i: [
    [0, 1],
    [1, 1],
    [2, 1],
    [3, 1],
  ],
  TetrominoType.j: [
    [0, 0],
    [0, 1],
    [1, 1],
    [2, 1],
  ],
  TetrominoType.l: [
    [2, 0],
    [0, 1],
    [1, 1],
    [2, 1],
  ],
  TetrominoType.o: [
    [1, 0],
    [2, 0],
    [1, 1],
    [2, 1],
  ],
  TetrominoType.s: [
    [1, 0],
    [2, 0],
    [0, 1],
    [1, 1],
  ],
  TetrominoType.t: [
    [1, 0],
    [0, 1],
    [1, 1],
    [2, 1],
  ],
  TetrominoType.z: [
    [0, 0],
    [1, 0],
    [1, 1],
    [2, 1],
  ],
};

String tetrominoName(TetrominoType type) => type.name.toUpperCase();

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
  P2Mode p2Mode = P2Mode.ai;
  bool remoteConnected = false;
  TetrominoType activePiece = TetrominoType.t;
  final List<TetrominoType> nextPieces = [];
  int turn = 0;
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
  String remoteUrl = 'ws://localhost:8080';
  final RemoteSocketAdapter remote = BrowserRemoteSocket();
  double _aiTarget = .5;
  bool _up = false, _down = false, _p2Up = false, _p2Down = false;
  final _random = math.Random();

  void _resetPiecePool() {
    state.nextPieces
      ..clear()
      ..addAll(TetrominoType.values);
    state.nextPieces.shuffle(_random);
    state.activePiece = state.nextPieces.removeAt(0);
    state.nextPieces.addAll(TetrominoType.values);
    state.nextPieces.shuffle(_random);
    state.turn = 1;
  }

  void _advancePiece() {
    if (state.nextPieces.isEmpty) {
      state.nextPieces.addAll(TetrominoType.values);
      state.nextPieces.shuffle(_random);
    }
    state.activePiece = state.nextPieces.removeAt(0);
    if (state.nextPieces.length < 4) {
      final refill = [...TetrominoType.values]..shuffle(_random);
      state.nextPieces.addAll(refill);
    }
    state.turn++;
  }

  void setP2Mode(P2Mode mode) {
    state.p2Mode = mode;
    notifyListeners();
  }

  void connectRemote(String url) {
    remote.connect(
      url,
      (y) {
        state.paddleRight = y;
        notifyListeners();
      },
      (ok) {
        state.remoteConnected = ok;
        notifyListeners();
      },
    );
  }

  void keyDown(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW)
      _up = true;
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS)
      _down = true;
    if (key == LogicalKeyboardKey.keyI) _p2Up = true;
    if (key == LogicalKeyboardKey.keyK) _p2Down = true;
  }

  void keyUp(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW)
      _up = false;
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS)
      _down = false;
    if (key == LogicalKeyboardKey.keyI) _p2Up = false;
    if (key == LogicalKeyboardKey.keyK) _p2Down = false;
  }

  void setPaddleByPointer(double y, double height) =>
      setPaddle(true, y / height);
  void virtualMove(double direction) =>
      setPaddle(true, state.paddleLeft + direction * .055);

  void start() {
    if (state.p2Mode == P2Mode.remote) connectRemote(remoteUrl);
    state.phase = GamePhase.ready;
    state.winner = null;
    state.scoreLeft = state.scoreRight = state.missesLeft = state.missesRight =
        0;
    state.linesLeft = state.linesRight = 0;
    _resetPiecePool();
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
    if (_up) state.paddleLeft -= .55 * dt;
    if (_down) state.paddleLeft += .55 * dt;
    if (state.p2Mode == P2Mode.ai) {
      _aiTarget = (state.ballX > .45 ? state.ballY : .5);
      state.paddleRight += (state.paddleRight < _aiTarget ? 1 : -1) * .34 * dt;
      state.paddleRight = state.paddleRight.clamp(.15, .85);
    } else if (state.p2Mode == P2Mode.localKeyboard) {
      if (_p2Up) state.paddleRight -= .55 * dt;
      if (_p2Down) state.paddleRight += .55 * dt;
      state.paddleRight = state.paddleRight.clamp(.15, .85);
    } else if (state.p2Mode == P2Mode.remote) {
      remote.sendPaddle(state.paddleLeft);
    }
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
    state.vy = (_random.nextDouble() - .5) * .42;
    _advancePiece();
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
    remote.dispose();
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
            child: SizedBox(
              width: math.min(c.maxWidth, 1280),
              height: math.min(c.maxHeight, 720),
              child: _screen(context, c),
            ),
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
        const SizedBox(height: 24),
        const Text(
          'PLAYER 2 MODE',
          style: TextStyle(color: Colors.white70, letterSpacing: 2),
        ),
        DropdownButton<P2Mode>(
          value: game.state.p2Mode,
          dropdownColor: ink,
          underline: Container(height: 2, color: gold),
          onChanged: (mode) {
            if (mode != null) game.setP2Mode(mode);
          },
          items: const [
            DropdownMenuItem(value: P2Mode.ai, child: Text('AI OPPONENT')),
            DropdownMenuItem(
              value: P2Mode.localKeyboard,
              child: Text('LOCAL KEYBOARD'),
            ),
            DropdownMenuItem(
              value: P2Mode.remote,
              child: Text('REMOTE WEBSOCKET'),
            ),
          ],
        ),
        if (game.state.p2Mode == P2Mode.remote)
          const Text(
            'ws://localhost:8080  •  configure before online match',
            style: TextStyle(color: pink, fontSize: 11),
          ),
        const SizedBox(height: 18),
        ActionButton(
          label: 'PLAY',
          icon: Icons.play_arrow,
          onTap: game.start,
          primary: true,
        ),
        ActionButton(
          label: 'HOW TO PLAY',
          icon: Icons.menu_book_outlined,
          onTap: () {
            game.state.phase = GamePhase.howToPlay;
            game.notifyListeners();
          },
        ),
        ActionButton(
          label: 'SETTINGS',
          icon: Icons.settings_outlined,
          onTap: () {
            game.state.phase = GamePhase.settings;
            game.notifyListeners();
          },
        ),
        ActionButton(
          label: 'CREDITS',
          icon: Icons.star_outline,
          onTap: () {
            showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: ink,
                title: const Text('CREDITS', style: TextStyle(color: gold)),
                content: const Text(
                  'TetraPong — Flutter Web/Wasm prototype',
                  style: TextStyle(color: Colors.white),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CLOSE'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    ),
  );
}

class ActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool primary;
  const ActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 21),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ],
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
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent) game.keyDown(event.logicalKey);
        if (event is KeyUpEvent) game.keyUp(event.logicalKey);
        return KeyEventResult.handled;
      },
      child: MouseRegion(
        onHover: (event) =>
            game.setPaddleByPointer(event.localPosition.dy, size.height),
        child: GestureDetector(
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
                child: StatusPanel(
                  player: 'P1',
                  score: game.state.scoreLeft,
                  danger:
                      game.state.boardLeft
                          .expand((r) => r)
                          .where((v) => v == 1)
                          .length /
                      96,
                  color: blue,
                ),
              ),
              Positioned(
                top: 12,
                right: 18,
                child: StatusPanel(
                  player: 'P2',
                  score: game.state.scoreRight,
                  danger:
                      game.state.boardRight
                          .expand((r) => r)
                          .where((v) => v == 1)
                          .length /
                      96,
                  color: pink,
                ),
              ),
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 42,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: gold, width: 3),
                      color: ink,
                    ),
                    child: Text(
                      '${game.state.scoreLeft.toString().padLeft(2, '0')}  :  ${game.state.scoreRight.toString().padLeft(2, '0')}  •  ${game.state.phase.name.toUpperCase()}',
                      style: const TextStyle(
                        color: gold,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 90,
                child: IconButton(
                  tooltip: 'Pause game',
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
              Positioned(
                left: 20,
                bottom: 18,
                child: VirtualControl(
                  label: '▲',
                  semanticLabel: 'Move paddle up',
                  onTap: () => game.virtualMove(-1),
                ),
              ),
              Positioned(
                left: 20,
                bottom: 78,
                child: VirtualControl(
                  label: '▼',
                  semanticLabel: 'Move paddle down',
                  onTap: () => game.virtualMove(1),
                ),
              ),
              Positioned(
                left: 92,
                bottom: 18,
                child: const Text(
                  'P1: W/S or ↑/↓ • mouse • touch',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              if (game.state.p2Mode == P2Mode.localKeyboard)
                const Positioned(
                  right: 20,
                  bottom: 18,
                  child: Text(
                    'P2: I/K',
                    style: TextStyle(color: pink, fontSize: 12),
                  ),
                ),
              if (game.state.p2Mode == P2Mode.remote)
                Positioned(
                  right: 20,
                  bottom: 18,
                  child: Text(
                    game.state.remoteConnected ? 'P2: ONLINE' : 'P2: OFFLINE',
                    style: TextStyle(
                      color: game.state.remoteConnected ? gold : pink,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusPanel extends StatelessWidget {
  final String player;
  final int score;
  final double danger;
  final Color color;
  const StatusPanel({
    super.key,
    required this.player,
    required this.score,
    required this.danger,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: 270,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: ink,
      border: Border.all(color: color, width: 3),
    ),
    child: Row(
      children: [
        Container(
          width: 54,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(border: Border.all(color: gold, width: 2)),
          child: Text(
            player,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DANGER  ${score.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 5),
              LinearProgressIndicator(
                value: danger.clamp(0, 1),
                minHeight: 8,
                backgroundColor: Colors.white12,
                color: color,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class VirtualControl extends StatelessWidget {
  final String label, semanticLabel;
  final VoidCallback onTap;
  const VirtualControl({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    child: SizedBox(
      width: 54,
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: gold, width: 2),
          foregroundColor: gold,
          padding: EdgeInsets.zero,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    ),
  );
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
    final bx = s.ballX * size.width, by = s.ballY * size.height;
    _piece(c, s.activePiece, Offset(bx, by), 18, gold);
    for (var i = 0; i < math.min(4, s.nextPieces.length); i++) {
      _piece(
        c,
        s.nextPieces[i],
        Offset(size.width * .045, size.height * (.18 + i * .11)),
        7,
        gold,
      );
      _piece(
        c,
        s.nextPieces[i],
        Offset(size.width * .955, size.height * (.18 + i * .11)),
        7,
        gold,
      );
    }
  }

  void _piece(
    Canvas c,
    TetrominoType type,
    Offset center,
    double cell,
    Color color,
  ) {
    final paint = Paint()..color = color;
    for (final point in tetrominoCells[type]!) {
      final x = center.dx + (point[0] - 1.5) * cell;
      final y = center.dy + (point[1] - .75) * cell;
      c.drawRect(Rect.fromLTWH(x, y, cell - 2, cell - 2), paint);
      c.drawRect(
        Rect.fromLTWH(x, y, cell - 2, cell - 2),
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
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
          if (game.state.p2Mode == P2Mode.remote)
            SizedBox(
              width: 360,
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'REMOTE WEBSOCKET URL',
                  hintText: 'wss://server.example/game',
                ),
                keyboardType: TextInputType.url,
                onChanged: (value) {
                  if (value.trim().isNotEmpty) game.remoteUrl = value.trim();
                },
              ),
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
