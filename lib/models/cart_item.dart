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

  CartItem({
    required this.product,
    this.quantity = 1,
    this.isSaved = false,
    this.isPrinted = false,
    this.selectedToppings = const [],
  });

  double get totalPrice {
    double basePrice = product.price;
    for (var topping in selectedToppings) {
      basePrice += topping.extraPrice;
    }
    return basePrice * quantity;
  }
}
