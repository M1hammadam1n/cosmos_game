import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';

class LaneManager {
  LaneManager({this.laneCount = 5});

  final int laneCount;

  late Rect roadRect;
  late double laneWidth;
  late double _playerStartY;

  void resize(Vector2 gameSize) {
    // The road fills the screen vertically; the player still stays above
    // the touch controls so the bottom of the game area is not black.
    final controlInset = math.max(108.0, gameSize.y * 0.14);

    roadRect = Rect.fromLTWH(0, 0, gameSize.x, math.max(1, gameSize.y));
    laneWidth = roadRect.width / laneCount;
    _playerStartY = gameSize.y - controlInset - laneWidth * 1.05;
  }

  double laneCenterX(int lane) {
    return roadRect.left + (laneWidth * (lane + 0.5));
  }

  Vector2 playerStartPosition(int lane) {
    return Vector2(laneCenterX(lane), _playerStartY);
  }

  double normalizedCarWidth() {
    return math.min(laneWidth * 0.58, 76);
  }

  double normalizedObstacleWidth() {
    return math.min(laneWidth * 0.68, 86);
  }

  int clampLane(int lane) {
    return lane.clamp(0, laneCount - 1);
  }
}
