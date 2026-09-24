// The Flow Canvas simulation: a coarse velocity field that fingers stir, soft
// glowing particles carried by it, and slow expanding ripples. Pure Dart so it
// can be unit-tested; drawn by FlowPainter.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

class Particle {
  double x = 0, y = 0, vx = 0, vy = 0;
  double life = 0; // 1 -> 0
  double lifetime = 1; // seconds
  double size = 4;
  int tone = 0;
  bool ambient = false;
}

class Ripple {
  final double x, y;
  double r;
  double age = 0;
  final double life;
  final int tone;
  Ripple(this.x, this.y, this.r, this.life, this.tone);
}

class FlowSim {
  final Random _rand;
  Size size = Size.zero;
  late int cols, rows;
  late double cell;
  Float32List vx = Float32List(0), vy = Float32List(0);
  Float32List _tx = Float32List(0), _ty = Float32List(0);
  final List<Particle> particles = [];
  final List<Ripple> ripples = [];

  /// 0.2 .. 1: how many particles (parent slider).
  double density;

  /// Overall speed multiplier (motion slider x Low Motion).
  double motion;

  double _ambientTimer = 0;
  double _clock = 0;

  FlowSim({this.density = 0.6, this.motion = 0.7, int? seed}) : _rand = Random(seed);

  int get maxParticles => (120 + 380 * density).round();
  int get ambientTarget => (14 + 30 * density).round();
  int get liveCount => particles.where((p) => p.life > 0).length;

  void resize(Size s) {
    if (s == size || s.isEmpty) return;
    size = s;
    cols = 18;
    cell = s.width / cols;
    rows = max(1, (s.height / cell).ceil());
    vx = Float32List(cols * rows);
    vy = Float32List(cols * rows);
    _tx = Float32List(cols * rows);
    _ty = Float32List(cols * rows);
    for (final p in particles) {
      p.x = p.x.clamp(0, s.width);
      p.y = p.y.clamp(0, s.height);
    }
  }

  int _idx(int c, int r) => r * cols + c;

  (double, double) sampleField(double x, double y) {
    if (size.isEmpty) return (0, 0);
    final c = (x / cell).floor().clamp(0, cols - 1);
    final r = (y / cell).floor().clamp(0, rows - 1);
    final i = _idx(c, r);
    return (vx[i], vy[i]);
  }

  Particle _obtain() {
    for (final p in particles) {
      if (p.life <= 0) return p;
    }
    if (particles.length < maxParticles) {
      final p = Particle();
      particles.add(p);
      return p;
    }
    // Pool full: recycle the oldest.
    var oldest = particles.first;
    for (final p in particles) {
      if (p.life < oldest.life) oldest = p;
    }
    return oldest;
  }

  /// A finger touched down at (x, y).
  void touchDown(double x, double y) {
    if (size.isEmpty) return;
    _ripple(x, y);
    final n = (6 + 10 * density).round();
    for (var i = 0; i < n; i++) {
      final a = _rand.nextDouble() * 2 * pi;
      final sp = 20 + _rand.nextDouble() * 40;
      _spawn(x, y, cos(a) * sp, sin(a) * sp);
    }
  }

  double _sinceRipple = 0;

  /// A finger moved by (dx, dy) over [dt] seconds.
  void touchMove(double x, double y, double dx, double dy, double dt) {
    if (size.isEmpty) return;
    dt = max(dt, 1 / 120);
    var ux = dx / dt, uy = dy / dt;
    final speed = sqrt(ux * ux + uy * uy);
    const maxSpeed = 1400.0;
    if (speed > maxSpeed) {
      ux *= maxSpeed / speed;
      uy *= maxSpeed / speed;
    }
    // Stir the field with a soft Gaussian brush (radius ~1.6 cells).
    final c0 = (x / cell).floor(), r0 = (y / cell).floor();
    for (var r = r0 - 2; r <= r0 + 2; r++) {
      for (var c = c0 - 2; c <= c0 + 2; c++) {
        if (r < 0 || c < 0 || r >= rows || c >= cols) continue;
        final cx = (c + 0.5) * cell - x, cy = (r + 0.5) * cell - y;
        final w = exp(-(cx * cx + cy * cy) / (2 * pow(1.6 * cell, 2))) * 0.35;
        final i = _idx(c, r);
        vx[i] += (ux - vx[i]) * w;
        vy[i] += (uy - vy[i]) * w;
      }
    }
    // Particles along the stroke.
    final dist = sqrt(dx * dx + dy * dy);
    final n = min(12, (dist / (9 - 5 * density)).floor() + 1);
    for (var i = 0; i < n; i++) {
      final f = i / n;
      _spawn(x - dx * f + _jitter(6), y - dy * f + _jitter(6), ux * 0.25 + _jitter(25), uy * 0.25 + _jitter(25));
    }
    _sinceRipple += dist;
    if (_sinceRipple > 90) {
      _sinceRipple = 0;
      _ripple(x, y);
    }
  }

  double _jitter(double a) => (_rand.nextDouble() - 0.5) * 2 * a;

  void _spawn(double x, double y, double vx0, double vy0, {bool ambient = false}) {
    final p = _obtain()
      ..x = x
      ..y = y
      ..vx = vx0
      ..vy = vy0
      ..life = 1
      ..lifetime = ambient ? 7 + _rand.nextDouble() * 5 : 2.2 + _rand.nextDouble() * 2.2
      ..size = ambient ? 2 + _rand.nextDouble() * 2.5 : 3 + _rand.nextDouble() * 5
      ..tone = _rand.nextInt(3)
      ..ambient = ambient;
    p.life = 1;
  }

  void _ripple(double x, double y) {
    if (ripples.length >= 18) ripples.removeAt(0);
    ripples.add(Ripple(x, y, 8, 2.8, _rand.nextInt(3)));
  }

  /// Clears the canvas gently: everything fades out quickly instead of
  /// vanishing (no sudden change).
  void reset() {
    for (final p in particles) {
      if (p.life > 0.25) p.life = 0.25;
      if (p.lifetime > 2.4) p.lifetime = 2.4; // gone within ~0.6 s
    }
    for (final r in ripples) {
      r.age = max(r.age, r.life * 0.8);
    }
    vx.fillRange(0, vx.length, 0);
    vy.fillRange(0, vy.length, 0);
  }

  void step(double dt) {
    if (size.isEmpty) return;
    dt = dt.clamp(0, 0.05);
    _clock += dt;
    final m = motion;

    // Field: diffuse to neighbours and decay (drag resistance).
    final keep = pow(0.35, dt).toDouble();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final i = _idx(c, r);
        var sx = 0.0, sy = 0.0, n = 0;
        if (c > 0) { sx += vx[i - 1]; sy += vy[i - 1]; n++; }
        if (c < cols - 1) { sx += vx[i + 1]; sy += vy[i + 1]; n++; }
        if (r > 0) { sx += vx[i - cols]; sy += vy[i - cols]; n++; }
        if (r < rows - 1) { sx += vx[i + cols]; sy += vy[i + cols]; n++; }
        final mix = min(1.0, 6 * dt);
        _tx[i] = (vx[i] * (1 - mix) + (sx / n) * mix) * keep;
        _ty[i] = (vy[i] * (1 - mix) + (sy / n) * mix) * keep;
      }
    }
    final t1 = vx, t2 = vy;
    vx = _tx;
    vy = _ty;
    _tx = t1;
    _ty = t2;

    // Particles follow the field with inertia, plus a slow swirl for ambient ones.
    final follow = min(1.0, 2.5 * dt);
    for (final p in particles) {
      if (p.life <= 0) continue;
      final (fx, fy) = sampleField(p.x, p.y);
      p.vx += (fx * 0.9 - p.vx) * follow;
      p.vy += (fy * 0.9 - p.vy) * follow;
      if (p.ambient) {
        p.vx += sin(_clock * 0.3 + p.y * 0.01) * 6 * dt;
        p.vy += (-8 - p.vy * 0.2) * dt;
      }
      p.x += p.vx * dt * m;
      p.y += p.vy * dt * m;
      p.life -= dt / p.lifetime;
      // Soft walls: a particle that reaches an edge drifts back a little and
      // fades out, so swipes never pile bright blobs up along the border.
      var hitWall = false;
      if (p.x < 0) { p.x = 0; p.vx = p.vx.abs() * 0.3; hitWall = true; }
      if (p.x > size.width) { p.x = size.width; p.vx = -p.vx.abs() * 0.3; hitWall = true; }
      if (p.y < 0) { p.y = 0; p.vy = p.vy.abs() * 0.3; hitWall = true; }
      if (p.y > size.height) { p.y = size.height; p.vy = -p.vy.abs() * 0.3; hitWall = true; }
      if (hitWall && !p.ambient && p.life > 0.3) p.life = 0.3;
    }

    // Ripples widen slowly and fade.
    for (final r in ripples) {
      r.age += dt;
      r.r += (55 + 25 * (1 - r.age / r.life)) * dt * (0.5 + m);
    }
    ripples.removeWhere((r) => r.age >= r.life);

    // Keep a few slow ambient motes so the canvas is never empty.
    _ambientTimer += dt;
    final ambientLive = particles.where((p) => p.ambient && p.life > 0).length;
    if (_ambientTimer > 0.35 && ambientLive < ambientTarget) {
      _ambientTimer = 0;
      _spawn(_rand.nextDouble() * size.width, size.height * (0.3 + 0.7 * _rand.nextDouble()), _jitter(6), -6 - _rand.nextDouble() * 6,
          ambient: true);
    }
  }

  /// Breathing guide: 4 s in, 6 s out (PDD Screen 3). Returns 0..1 and
  /// whether the child is breathing in.
  static (double, bool) breathAt(double seconds) {
    final t = seconds % 10;
    if (t < 4) {
      final x = t / 4;
      return (0.5 - 0.5 * cos(pi * x), true);
    }
    final x = (t - 4) / 6;
    return (0.5 + 0.5 * cos(pi * x), false);
  }
}
