import 'product.dart';
import 'topping.dart';

class CartItem {
  final Product product;
  int quantity;
  bool isSaved;
  /// true once this line has been sent to the kitchen/bar printer.
  /// The save-ticket flow only prints lines where isPrinted == false,
  /// then flips this to true. Charge does NOT re-print order tickets.
  /// Only the Reprint Order action ignores this flag.
  bool isPrinted;
  final List<Topping> selectedToppings;
  String kitchenNote;

  /// From server [TicketLine] (includes topping $ in one unit). When set, used
  /// for [totalPrice] instead of [product] + [selectedToppings].
  final double? priceUnitFromOrder;

  // Point Redeem Feature
  bool isRedeemed;
  int pointPrice;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.isSaved = false,
    this.isPrinted = false,
    this.selectedToppings = const [],
    this.kitchenNote = '',
    this.priceUnitFromOrder,
    this.isRedeemed = false,
    this.pointPrice = 0,
  });

  double get totalPrice {
    if (isRedeemed) return 0.0;
    if (priceUnitFromOrder != null) {
      return priceUnitFromOrder! * quantity;
    }
    double basePrice = product.effectivePrice;
    for (var topping in selectedToppings) {
      basePrice += topping.extraPrice;
    }
    return basePrice * quantity;
  }

  int get totalPoints {
    if (!isRedeemed) return 0;
    return pointPrice * quantity;
  }
}
