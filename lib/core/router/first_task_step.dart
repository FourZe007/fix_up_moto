/// Which step of the first-task guidance a page was opened as, handed over as
/// the route's `extra`.
///
/// The guidance walks a new member through their first two tasks in the only
/// order that works (a booking needs a bike): add a bike, then book. A page
/// behaves exactly as it always has unless it is opened as one of these steps,
/// so every other way of reaching it (My Bikes, the Bookings tab, a service's
/// detail page) is untouched.
enum FirstTaskStep {
  /// Add Bike, opened to register the member's first bike. Once it is saved the
  /// confirmation offers to book right away, instead of only saying "saved".
  addBike,

  /// Create Booking, opened by that offer. Once the booking is made the
  /// confirmation points to the Booking tab, since the member did not start
  /// from there and is not looking at their bookings.
  createBooking,
}
