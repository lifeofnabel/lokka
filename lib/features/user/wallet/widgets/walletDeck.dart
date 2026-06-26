import 'package:flutter/material.dart';
import 'package:lokka/features/user/wallet/models/walletCardModel.dart';
import 'package:lokka/features/user/wallet/widgets/walletCard.dart';

/// Apple-Wallet-style vertical deck — like a stack of cards held in hand.
///
/// You swipe up/down to move the focus: the centered card is full size and
/// crisp, the neighbours shrink and fade so they tuck behind it. Tap a side card
/// to bring it into focus; tap the focused card to open it.
class WalletDeck extends StatefulWidget {
  const WalletDeck({
    super.key,
    required this.cards,
    required this.onOpen,
  });

  final List<WalletCardModel> cards;
  final void Function(WalletCardModel card) onOpen;

  @override
  State<WalletDeck> createState() => _WalletDeckState();
}

class _WalletDeckState extends State<WalletDeck> {
  late final PageController _ctrl;
  double _page = 0;

  int get _len => widget.cards.length;
  // Loop the deck (≥2 cards) so there's always a card peeking above and below —
  // it looks endless from the very start instead of starting at an empty top.
  bool get _loop => _len >= 2;
  int get _virtualCount => _loop ? _len * 2000 : _len;

  @override
  void initState() {
    super.initState();
    final initial = _loop ? _len * 1000 : 0;
    _page = initial.toDouble();
    _ctrl = PageController(viewportFraction: 0.42, initialPage: initial);
    _ctrl.addListener(_onScroll);
  }

  void _onScroll() {
    final p = _ctrl.hasClients ? (_ctrl.page ?? 0) : 0.0;
    if (p != _page) setState(() => _page = p);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onScroll);
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap(int i) {
    if (_page.round() == i) {
      widget.onOpen(widget.cards[i % _len]);
    } else {
      _ctrl.animateToPage(
        i,
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _ctrl,
      scrollDirection: Axis.vertical,
      itemCount: _virtualCount,
      // A little extra friction so it feels like flicking through a real stack.
      physics: const _DeckScrollPhysics(),
      itemBuilder: (context, i) {
        final card = widget.cards[i % _len];
        final delta = _page - i; // +above focus / -below focus
        final ad = delta.abs();
        // Focused card: full size & opaque. Neighbours recede behind it.
        final scale = (1 - ad * 0.14).clamp(0.80, 1.0);
        final opacity = (1 - ad * 0.50).clamp(0.30, 1.0);
        final focused = ad < 0.5;
        return Align(
          alignment: Alignment.center,
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: AnimatedScale(
                  // Tiny pop on the focused card for liveliness.
                  scale: focused ? 1.0 : 0.985,
                  duration: const Duration(milliseconds: 180),
                  child: WalletCard(
                    card: card,
                    onTap: () => _onTap(i),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Slightly snappier than the default so the deck settles cleanly on one card.
class _DeckScrollPhysics extends PageScrollPhysics {
  const _DeckScrollPhysics({super.parent});

  @override
  _DeckScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _DeckScrollPhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.5,
        stiffness: 120,
        damping: 18,
      );
}
