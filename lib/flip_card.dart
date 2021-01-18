library flip_card;

import 'dart:math';

import 'package:flutter/material.dart';

enum FlipDirection {
  VERTICAL,
  HORIZONTAL,
}

class AnimationCard extends StatelessWidget {
  AnimationCard({this.child, this.animation, this.direction});

  final Widget child;
  final Animation<double> animation;
  final FlipDirection direction;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget child) {
        var transform = Matrix4.identity();
        transform.setEntry(3, 2, 0.001);
        if (direction == FlipDirection.VERTICAL) {
          transform.rotateX(animation.value);
        } else {
          transform.rotateY(animation.value);
        }
        return Transform(
          transform: transform,
          alignment: Alignment.center,
          child: child,
        );
      },
      child: child,
    );
  }
}

typedef void BoolCallback(bool isFront);

class FlipCard extends StatefulWidget {
  final Widget front;
  final Widget back;

  /// The amount of milliseconds a turn animation will take.
  final int speed;
  final FlipDirection direction;
  final BoolCallback onFlip;
  final BoolCallback onFlipDone;

  /// When enabled, the card will flip automatically when touched. This behavior
  /// can be disabled if this is not desired. To manually flip a card from your
  /// code, you could do this:
  ///```dart
  /// GlobalKey<FlipCardState> cardKey = GlobalKey<FlipCardState>();
  ///
  /// @override
  /// Widget build(BuildContext context) {
  ///   return FlipCard(
  ///     key: cardKey,
  ///     flipOnTouch: false,
  ///     front: Container(
  ///       child: RaisedButton(
  ///         onPressed: () => cardKey.currentState.toggleCard(),
  ///         child: Text('Toggle'),
  ///       ),
  ///     ),
  ///     back: Container(
  ///       child: Text('Back'),
  ///     ),
  ///   );
  /// }
  ///```
  final bool flipOnTouch;
  final bool flipBySwipe;

  const FlipCard({
    Key key,
    @required this.front,
    @required this.back,
    this.speed = 500,
    this.onFlip,
    this.onFlipDone,
    this.direction = FlipDirection.HORIZONTAL,
    this.flipOnTouch = true,
    this.flipBySwipe = true,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return FlipCardState();
  }
}

class FlipCardState extends State<FlipCard> with SingleTickerProviderStateMixin {
  AnimationController controller;
  Animation<double> _frontRotation;
  Animation<double> _backRotation;

  bool isFront = true;

  bool _swipeFlipped = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(duration: Duration(milliseconds: 500), vsync: this)
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
          if (widget.onFlipDone != null) widget.onFlipDone(isFront);
        }
      });
    _updateRotations(true);
  }

  void leftRotation() {
    toggleCard(false);
  }

  void rightRotation() {
    toggleCard(true);
  }

  void toggleCard(bool isRightTap) {
    _updateRotations(isRightTap);
    if (isFront) {
      controller.forward();
    } else {
      controller.reverse();
    }

    setState(() {
      isFront = !isFront;
    });

    if (widget.onFlip != null) widget.onFlip(isFront);
  }

  @override
  Widget build(BuildContext context) {
    final child = Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        _buildContent(front: true),
        _buildContent(front: false),
      ],
    );

    // if we need to flip the card on taps, wrap the content
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.flipOnTouch ? _tapReaction : null,
      onHorizontalDragUpdate:
          widget.flipBySwipe && widget.direction == FlipDirection.HORIZONTAL ? _swipeReaction : null,
      onVerticalDragUpdate: widget.flipBySwipe && widget.direction == FlipDirection.VERTICAL ? _swipeReaction : null,
      onHorizontalDragEnd: widget.direction == FlipDirection.HORIZONTAL ? (details) => _swipeFlipped = false : null,
      onVerticalDragEnd: widget.direction == FlipDirection.VERTICAL ? (details) => _swipeFlipped = false : null,
      child: child,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget _buildContent({@required bool front}) {
    // pointer events that would reach the backside of the card should be
    // ignored
    return IgnorePointer(
      // absorb the front card when the background is active (!isFront),
      // absorb the background when the front is active
      ignoring: front ? !isFront : isFront,
      child: AnimationCard(
        animation: front ? _frontRotation : _backRotation,
        child: front ? widget.front : widget.back,
        direction: widget.direction,
      ),
    );
  }

  void _tapReaction() => toggleCard(!isFront);

  void _swipeReaction(details) {
    if (_swipeFlipped) return;

    var delta = widget.direction == FlipDirection.HORIZONTAL ? details.delta.dx : details.delta.dy;

    if (delta > 10) {
      if (widget.direction == FlipDirection.HORIZONTAL) {
        rightRotation();
      } else {
        leftRotation();
      }

      _swipeFlipped = true;
    } else if (delta < -10) {
      if (widget.direction == FlipDirection.HORIZONTAL) {
        leftRotation();
      } else {
        rightRotation();
      }
      _swipeFlipped = true;
    }
  }

  _updateRotations(bool isRightTap) {
    setState(() {
      bool rotateToLeft = (isFront && !isRightTap) || !isFront && isRightTap;
      _frontRotation = TweenSequence(
        <TweenSequenceItem<double>>[
          TweenSequenceItem<double>(
            tween: Tween(begin: 0.0, end: rotateToLeft ? (pi / 2) : (-pi / 2)).chain(CurveTween(curve: Curves.linear)),
            weight: 50.0,
          ),
          TweenSequenceItem<double>(
            tween: ConstantTween<double>(rotateToLeft ? (-pi / 2) : (pi / 2)),
            weight: 50.0,
          ),
        ],
      ).animate(controller);
      _backRotation = TweenSequence(
        <TweenSequenceItem<double>>[
          TweenSequenceItem<double>(
            tween: ConstantTween<double>(rotateToLeft ? (pi / 2) : (-pi / 2)),
            weight: 50.0,
          ),
          TweenSequenceItem<double>(
            tween: Tween(begin: rotateToLeft ? (-pi / 2) : (pi / 2), end: 0.0).chain(CurveTween(curve: Curves.linear)),
            weight: 50.0,
          ),
        ],
      ).animate(controller);
    });
  }
}
