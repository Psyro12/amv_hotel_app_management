import 'package:amv_hotel_app/my_bookings_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_view/photo_view.dart'; // 🟢 1. Import photo_view
import 'package:photo_view/photo_view_gallery.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import 'api_config.dart';
import 'all_events_screen.dart';
import 'all_news_screen.dart'; // 🟢 Added Import
import 'profile_screen.dart';
import 'contact_us_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_html/flutter_html.dart';
import 'checkout_screen.dart';
import 'receipt_screen.dart';
import 'orders_screen.dart'; // 🟢 Add this line
import 'notification_button.dart';
import 'dart:io';
import 'available_rooms_screen.dart';

void main() {
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: HomeScreen()));
}

final GlobalKey<_HomeScreenState> homeKey = GlobalKey<_HomeScreenState>();

class HomeScreen extends StatefulWidget {
  HomeScreen() : super(key: homeKey);

  static void clearSelectedDates() {
    homeKey.currentState?._clearDates();
  }

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final Color amvViolet = Color(0xFF2D0F35);
  final Color amvGold = Color(0xFFD4AF37);

  void _clearDates() {
    setState(() {
      _selectedDateRange = null;
      _adults = 1;
      _children = 0;
    });
  }

  int _currentIndex = 2;
  int _selectedCategoryIndex = 0;
  int _selectedFoodFilter = 0;
  final ValueNotifier<double> _notifOpacityNotifier = ValueNotifier(0.15);

  // 🟢 NEW: Dynamic Empty List (Starts with "All")
  List<String> _foodCategories = ["All"];

  final Map<String, int> _cartItems = {};

  // 🟢 NEW: Search Variables
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  DateTimeRange? _selectedDateRange;
  int _adults = 1;
  int _children = 0;

  final ScrollController _homeScrollController = ScrollController();

  // Animations
  late AnimationController _animationController;
  late AnimationController _sheetController;
  Timer? _statusTimer; // 🟢 Timer for real-time status updates

  // 🟢 List to store events from Database
  List<dynamic> _homeEvents = [];
  bool _isLoadingEvents = true;

  // 🟢 NEW: List to store News from Database
  List<dynamic> _homeNews = [];
  bool _isLoadingNews = true;

  List<dynamic> _homeRooms = [];
  bool _isLoadingRooms = true;

  // 🟢 MISSING FOOD VARIABLES
  List<dynamic> _homeFood = [];
  bool _isLoadingFood = true;
  bool _isBlocked = false; // 🟢 Track if user is blocked


  // 🟢 Helper to get filtered food list
  List<dynamic> _getFilteredFood() {
    String selectedFilter = _foodCategories[_selectedFoodFilter];

    return _homeFood.where((item) {
      bool matchesCategory =
          selectedFilter == "All" || item['category'] == selectedFilter;
      String itemName = (item['item_name'] ?? "").toString().toLowerCase();
      bool matchesSearch = itemName.contains(_searchQuery);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    _sheetController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );

    // 🟢 OPTIMIZED SCROLL LISTENER
    _homeScrollController.addListener(() {
      double offset = _homeScrollController.offset;

      // Calculate new opacity (0.15 -> 0.0)
      double newOpacity = (0.15 - (offset / 100) * 0.15).clamp(0.0, 0.15);

      // Only update if the value actually changed significantly
      if ((_notifOpacityNotifier.value - newOpacity).abs() > 0.001) {
        _notifOpacityNotifier.value =
            newOpacity; // ⚡ Updates without rebuilding the whole screen
      }
    });

    // 🟢 CALL BOTH APIs ON STARTUP
    _fetchHomeEvents();
    _fetchHomeNews();
    _fetchHomeRooms();
    _fetchFoodMenu();
    _checkUserStatus(); // 🟢 Check if user is blocked

    // 🟢 Real-time status polling (Every 5 seconds)
    _statusTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _checkUserStatus();
    });

    _startHeroCarousel();
    _checkForPendingReceipt();
  }

  // 🟢 NEW: Check User Block Status
  Future<void> _checkUserStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api_get_user_status.php?uid=${user.uid}"),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _isBlocked = data['is_blocked'] ?? false;
            });
          }
        }
      }
    } catch (e) {
      print("Error checking user status: $e");
    }
  }

  // 🟢 ENHANCED: Premium Slide-Up Modal for Order Limit
  void _showOrderLimitModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black87, // Darker backdrop
      transitionDuration: const Duration(milliseconds: 600),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn)),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              padding: const EdgeInsets.fromLTRB(30, 15, 30, 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle Bar
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 25),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  // Scrollable Content
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                                                    // 🟢 ENHANCED: Signature AMV Icon Header
                                                    Container(
                                                      width: 90,
                                                      height: 90,
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: [amvViolet, const Color(0xFF4A1955)],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        ),
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: amvViolet.withOpacity(0.3),
                                                            blurRadius: 20,
                                                            offset: const Offset(0, 10),
                                                          )
                                                        ],
                                                      ),
                                                      child: Icon(Icons.shopping_cart_checkout_rounded, color: amvGold, size: 45),
                                                    ),
                                                    const SizedBox(height: 25),
                                                    Text(
                                                      "ORDER LIMIT REACHED",
                                                      textAlign: TextAlign.center, // 🟢 Centered
                                                      style: GoogleFonts.montserrat(
                                                        fontSize: 20,
                                                        fontWeight: FontWeight.w800,
                                                        color: amvViolet,
                                                        letterSpacing: 1.2,
                                                      ),
                                                    ),                          const SizedBox(height: 15),
                          Text(
                            "You have 4 active pending orders. To maintain our high standard of service, please allow us to process your current orders before placing new ones.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              color: Colors.grey[600],
                              height: 1.6,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 35),
                          
                          // Action Buttons
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: amvViolet,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                elevation: 0,
                              ),
                              child: Text(
                                "UNDERSTOOD",
                                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 🟢 NEW FUNCTION: CHECKS IF USER JUST CAME BACK FROM PAYMENT
  Future<void> _checkForPendingReceipt() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool awaiting = prefs.getBool('awaiting_payment') ?? false;

    if (awaiting) {
      // 1. Get the saved data
      String? dataString = prefs.getString('pending_receipt_data');

      if (dataString != null) {
        var data = json.decode(dataString);

        // 2. Convert JSON back to correct Map format
        Map<String, int> savedCart = Map<String, int>.from(
          data['cartItems'].map((k, v) => MapEntry(k, v as int)),
        );

        // 3. Clear the flag so it doesn't show again next time
        await prefs.setBool('awaiting_payment', false);
        await prefs.remove('pending_receipt_data');

        // 4. Navigate to Receipt Screen immediately
        // We use addPostFrameCallback to ensure the context is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReceiptScreen(
                cartItems: savedCart,
                foodData: _homeFood, // Use current food data
                subtotal: data['subtotal'],
                deliveryFee: data['deliveryFee'],
                grandTotal: data['grandTotal'],
                deliveryLocation: data['location'],
                contactNumber: data['phone'],
                paymentMethod: data['payment'],
                orderDate: data['date'],
              ),
            ),
          );
        });
      }
    }
  }

  void _startHeroCarousel() {
    _heroTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _currentHeroIndex = (_currentHeroIndex + 1) % _heroImages.length;
        });
      }
    });
  }

  Future<void> _fetchHomeRooms() async {
    final prefs = await SharedPreferences.getInstance();
    const String cacheKey = 'home_rooms_cache';

    // 🟢 1. Load Saved Data (Instant)
    String? cachedData = prefs.getString(cacheKey);
    if (cachedData != null) {
      final jsonResponse = json.decode(cachedData);
      if (mounted) {
        setState(() {
          _homeRooms = jsonResponse['data'];
          _isLoadingRooms = false;
        });
      }
    }

    // 🟢 2. Fetch Fresh Data (Background)
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api_get_rooms.php"),
      );
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          // Save new data to phone
          await prefs.setString(cacheKey, response.body);

          if (mounted) {
            setState(() {
              _homeRooms = jsonResponse['data'];
              _isLoadingRooms = false;
            });
          }
        }
      }
    } catch (e) {
      print("Error loading rooms: $e");
      // Don't stop loading if we have cached data!
      if (mounted && _homeRooms.isEmpty)
        setState(() => _isLoadingRooms = false);
    }
  }

  // Fetch Events Function
  Future<void> _fetchHomeEvents() async {
    final prefs = await SharedPreferences.getInstance();
    const String cacheKey = 'home_events_cache'; // 🔑 Unique Key for Events

    // 🟢 1. Load Saved Data (Instant)
    String? cachedData = prefs.getString(cacheKey);
    if (cachedData != null) {
      final jsonResponse = json.decode(cachedData);
      if (mounted) {
        setState(() {
          _homeEvents = jsonResponse['data'];
          _isLoadingEvents = false;
        });
      }
    }

    // 🟢 2. Fetch Fresh Data (Background)
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api_get_events.php"),
      );
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          // Save new data to phone
          await prefs.setString(cacheKey, response.body);

          if (mounted) {
            setState(() {
              _homeEvents = jsonResponse['data'];
              _isLoadingEvents = false;
            });
          }
        }
      }
    } catch (e) {
      print("Error loading home events: $e");
      // Keep showing cached data if internet fails
      if (mounted && _homeEvents.isEmpty)
        setState(() => _isLoadingEvents = false);
    }
  }

  // 🟢 NEW: Fetch News Function
  Future<void> _fetchHomeNews() async {
    final prefs = await SharedPreferences.getInstance();
    const String cacheKey = 'home_news_cache'; // 🔑 Unique Key for News

    // 🟢 1. Load Saved Data (Instant)
    String? cachedData = prefs.getString(cacheKey);
    if (cachedData != null) {
      final jsonResponse = json.decode(cachedData);
      if (mounted) {
        setState(() {
          _homeNews = jsonResponse['data'];
          _isLoadingNews = false;
        });
      }
    }

    // 🟢 2. Fetch Fresh Data (Background)
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api_get_news.php"),
      );
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          // Save new data to phone
          await prefs.setString(cacheKey, response.body);

          if (mounted) {
            setState(() {
              _homeNews = jsonResponse['data'];
              _isLoadingNews = false;
            });
          }
        }
      }
    } catch (e) {
      print("Error loading news: $e");
      // Keep showing cached data if internet fails
      if (mounted && _homeNews.isEmpty) setState(() => _isLoadingNews = false);
    }
  }

  // 🟢 DEBUG VERSION OF FETCH FOOD
  Future<void> _fetchFoodMenu() async {
    final prefs = await SharedPreferences.getInstance();
    const String cacheKey = 'food_menu_cache'; // 🔑 Unique Key for Food

    // 🟢 HELPER: Processes data to extract categories & update UI
    void updateFoodState(List<dynamic> data) {
      Set<String> categorySet = {"All"};
      for (var item in data) {
        if (item['category'] != null) {
          categorySet.add(item['category']);
        }
      }

      if (mounted) {
        setState(() {
          _homeFood = data;
          _foodCategories = categorySet.toList(); // Update the pill selector
          _isLoadingFood = false;
        });
      }
    }

    // 🟢 1. Load Saved Data (Instant)
    String? cachedData = prefs.getString(cacheKey);
    if (cachedData != null) {
      final jsonResponse = json.decode(cachedData);
      if (jsonResponse['data'] != null) {
        updateFoodState(jsonResponse['data']);
      }
    }

    // 🟢 2. Fetch Fresh Data (Background)
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api_get_food_menu.php"),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        if (jsonResponse['success'] == true) {
          // Save new data to phone
          await prefs.setString(cacheKey, response.body);

          // Update UI with fresh data
          updateFoodState(jsonResponse['data']);
        }
      }
    } catch (e) {
      print("❌ Error loading food: $e");
      // If internet fails, stop loading spinner (cache is already showing)
      if (mounted && _homeFood.isEmpty) setState(() => _isLoadingFood = false);
    }
  }

  Future<void> _submitOrderToApi(
    String location,
    String payment,
    String notes, {
    bool isOutside = false,
    String phone = "",
    File? receiptImage, 
    String? paymentRef, // 🟢 Added this
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showError("You must be logged in to order.");
      return;
    }

    // 🟢 BLOCK CHECK: Pre-flight check
    if (_isBlocked) {
      _showError("Your account is blocked. Please contact front desk.");
      return;
    }

    double total = 0;
    _cartItems.forEach((key, value) {
      var item = _homeFood.firstWhere(
        (e) => e['item_name'] == key,
        orElse: () => {},
      );
      if (item.isNotEmpty) {
        total += (double.tryParse(item['price'].toString()) ?? 0) * value;
      }
    });
    double deliveryFee = isOutside ? 50.0 : 0.0;
    double grandTotal = total + deliveryFee;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          Center(child: CircularProgressIndicator(color: amvGold)),
    );

    try {
      // 🟢 1. Create Multipart Request instead of simple POST
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("${ApiConfig.baseUrl}/api_place_order.php"),
      );

      // 🟢 2. Add Text Fields
      request.fields['user_id'] = user.uid;
      request.fields['cart_items'] = json.encode(_cartItems);
      request.fields['total_price'] = grandTotal.toString();
      request.fields['room_number'] = location;
      request.fields['payment_method'] = payment;
      request.fields['notes'] = notes + (isOutside ? " [CONTACT: $phone]" : "");
      if (paymentRef != null) {
        request.fields['payment_reference'] = paymentRef; // 🟢 Send ref to PHP
      }

      // 🟢 3. Add Receipt Image (Only if exists)
      if (receiptImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'receipt', // PHP will look for $_FILES['receipt']
            receiptImage.path,
          ),
        );
      }

      // 🟢 4. Send & Await Response
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      Navigator.pop(context); // Close Loading

      if (response.statusCode == 200) {
        var result = json.decode(response.body);

        if (result['success'] == true) {
          setState(() => _cartItems.clear());
          _showSuccessDialog();
        } else {
          // 🟢 Check if blocking occurred
          if (result['message'] != null && result['message'].toString().contains("blocked")) {
             setState(() => _isBlocked = true);
          }
          _showError(result['message'] ?? "Order Failed");
        }
      } else {
        _showError("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      print("❌ ERROR: $e");
      _showError("Connection Failed. Check internet.");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccessDialog() {
    // 🟢 Navigate with a Smooth Slide-Up Animation
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            OrderSuccessScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Starts from below the screen (Offset 0, 1) to the final position (Offset 0, 0)
          var begin = const Offset(0.0, 1.0);
          var end = Offset.zero;
          var curve = Curves
              .fastOutSlowIn; // 🟢 Premium Curve used in your other screens

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(
          milliseconds: 600,
        ), // Matching your other premium transitions
      ),
    );
  }

  // 🟢 HELPER: Get Icon based on Category
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case "Main Course":
        return FontAwesomeIcons.utensils;
      case "Breakfast":
        return Icons.breakfast_dining;
      case "Soup":
        return Icons.soup_kitchen;
      case "Snack":
        return FontAwesomeIcons.cookieBite; // or Icons.fastfood
      case "Dessert":
        return Icons.icecream;
      case "Beverage":
        return FontAwesomeIcons.glassWater; // or Icons.local_drink
      default:
        return Icons.restaurant_menu;
    }
  }

  // 🟢 HERO CAROUSEL VARIABLES
  int _currentHeroIndex = 0;
  Timer? _heroTimer;

  // Local Assets List
  final List<String> _heroImages = [
    "assets/images/hotel_background.png", // Exterior
    "assets/images/hotel_foods.jpg", // Food
    "assets/images/hotel_events.png", // Events
    "assets/images/test_1.png", // Room or Feature
  ];
  // 💡 NOTE: If you don't have these specific filenames yet, use placeholders to test:
  // final List<String> _heroImages = [
  //   "https://placehold.co/600x800/2D0F35/FFF?text=Exterior",
  //   "https://placehold.co/600x800/D4AF37/FFF?text=Dining",
  //   "https://placehold.co/600x800/550000/FFF?text=Events",
  // ];

  @override
  void dispose() {
    _statusTimer?.cancel(); // 🟢 Stop the polling timer
    _homeScrollController.dispose();
    _animationController.dispose();
    _sheetController.dispose();
    _heroTimer?.cancel();
    _notifOpacityNotifier.dispose();
    super.dispose();
  }

  // --- NAVIGATION TRIGGERS ---

  void _openAllEvents() {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) =>
            AllEventsScreen(transitionAnimation: animation),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.fastOutSlowIn,
                  ),
                ),
            child: child,
          );
        },
        transitionDuration: Duration(milliseconds: 600),
        reverseTransitionDuration: Duration(milliseconds: 600),
      ),
    );
  }

  // 🟢 NEW: Navigation for News
  void _openAllNews() {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) =>
            AllNewsScreen(transitionAnimation: animation),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.fastOutSlowIn,
                  ),
                ),
            child: child,
          );
        },
        transitionDuration: Duration(milliseconds: 600),
        reverseTransitionDuration: Duration(milliseconds: 600),
      ),
    );
  }

  void _closeAllEvents() {
    _animationController.reverse();
  }

  // 🟢 UPDATED: Navigate to News Page (Instead of Popup)
  void _showNewsDetails(Map<String, dynamic> newsItem) {
    String imageUrl = Uri.encodeFull(newsItem['full_image_url']);
    String title = newsItem['title'] ?? "News";
    String date = newsItem['formatted_date'] ?? "";
    String rawDate = newsItem['news_date'] ?? ""; // Added raw date
    String content =
        newsItem['content'] ??
        newsItem['description'] ??
        "No details available.";

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false, // Keeps background slightly visible during transition
        pageBuilder: (context, animation, secondaryAnimation) =>
            NewsDetailScreen(
              title: title,
              imageUrl: imageUrl,
              date: date,
              rawDate: rawDate, // Pass raw date
              content: content,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Slide from Bottom to Top (Premium Feel)
          var begin = const Offset(0.0, 1.0);
          var end = Offset.zero;
          var curve = Curves.fastOutSlowIn;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  // 🟢 2. SHOW EVENT DETAILS SHEET (Dynamic "Status" Badge)
  void _showEventDetails(Map<String, dynamic> event) {
    String imageUrl = Uri.encodeFull(event['full_image_url']);
    String title = event['title'] ?? "Event";
    String dateString = event['formatted_date'] ?? "";
    String rawDate = event['display_date_raw'] ?? ""; // Added for time ago

    // 🟢 1. LOGIC: Determine Status (Upcoming / Happening / Past)
    String statusText = "UPCOMING EVENT";
    Color statusColor = amvGold; // Default Gold

    try {
      DateTime? eventDate;
      if (event['event_date'] != null) {
        eventDate = DateTime.parse(event['event_date']);
      } else {
        eventDate = DateFormat("MMMM d, yyyy").parse(dateString);
      }
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final eDate = DateTime(eventDate.year, eventDate.month, eventDate.day);

      if (eDate.isBefore(today)) {
        statusText = "PAST EVENT";
        statusColor = Colors.grey;
      } else if (eDate.isAtSameMomentAs(today)) {
        statusText = "HAPPENING NOW";
        statusColor = Colors.green;
      } else {
        statusText = "UPCOMING EVENT";
        statusColor = amvGold;
      }
    } catch (e) {
      print("Date parse error: $e");
    }

    // 🟢 2. Relative Time (Time Ago) Calculation Logic
    String getTimeAgo(String raw, String formatted) {
      try {
        if (raw.isEmpty || raw.contains("0000-00-00") || formatted.toLowerCase().contains("recently")) {
          return "posted recently";
        }
        DateTime postDate = DateTime.parse(raw);
        DateTime now = DateTime.now();
        if (postDate.year < 2010) return "posted recently";
        Duration diff = now.difference(postDate);
        if (diff.isNegative) return "posted just now";

        if (diff.inDays >= 365) {
          int years = (diff.inDays / 365).floor();
          return "posted $years ${years == 1 ? 'year' : 'years'} ago";
        } else if (diff.inDays >= 30) {
          int months = (diff.inDays / 30).floor();
          return "posted $months ${months == 1 ? 'month' : 'months'} ago";
        } else if (diff.inDays > 0) {
          return "posted ${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago";
        } else if (diff.inHours > 0) {
          return "posted ${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago";
        } else if (diff.inMinutes > 0) {
          return "posted ${diff.inMinutes} ${diff.inMinutes == 1 ? 'min' : 'mins'} ago";
        } else {
          return "posted just now";
        }
      } catch (e) { return "posted recently"; }
    }

    String postedTimeAgo = getTimeAgo(rawDate, dateString);

    // 🟢 3. Extract Month/Day
    List<String> dateParts = dateString.split(' ');
    String month = dateParts.isNotEmpty
        ? dateParts[0].substring(0, 3).toUpperCase()
        : "JAN";
    String day = dateParts.length > 1 ? dateParts[1].replaceAll(',', '') : "01";

    String content =
        event['description'] ?? event['content'] ?? "No details available.";

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 600),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn),
              ),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            clipBehavior: Clip.antiAlias,
            color: Colors.white,
            child: Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.90,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HEADER IMAGE SECTION
                        Stack(
                          children: [
                            Container(
                              height: 300,
                              width: double.infinity,
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return SkeletonContainer(
                                        width: double.infinity,
                                        height: 300,
                                        borderRadius: 0,
                                        icon: Icons.event,
                                      );
                                    },
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(color: Colors.grey[900]),
                              ),
                            ),
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.3),
                                      Colors.black.withOpacity(0.8),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Floating Calendar Badge (Top Right)
                            Positioned(
                              top: 20,
                              right: 20,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      month,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: amvGold,
                                      ),
                                    ),
                                    Text(
                                      day,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black87,
                                        height: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // 🟢 DYNAMIC STATUS TAG & TITLE (Bottom Left)
                            Positioned(
                              bottom: 25,
                              left: 25,
                              right: 25,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 🟢 DYNAMIC TAG HERE
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor, // Dynamic Color
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      statusText, // Dynamic Text
                                      style: GoogleFonts.montserrat(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    title,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      height: 1.1,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 10.0,
                                          color: Colors.black.withOpacity(0.5),
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // DETAILS BODY
                        Padding(
                          padding: const EdgeInsets.all(25.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 🟢 Meta Row (Time Ago & Icon)
                              Row(
                                children: [
                                  const Icon(Icons.access_time_filled_rounded, size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    postedTimeAgo,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(Icons.event_available_rounded, color: amvGold, size: 20),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Divider(),
                              const SizedBox(height: 20),

                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: amvViolet.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.calendar_today,
                                            color: amvViolet,
                                            size: 20,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "DATE",
                                              style: GoogleFonts.montserrat(
                                                fontSize: 10,
                                                color: Colors.grey,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              dateString,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: amvViolet.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.access_time_filled,
                                            color: amvViolet,
                                            size: 20,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "TIME",
                                              style: GoogleFonts.montserrat(
                                                fontSize: 10,
                                                color: Colors.grey,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              event['time_start'] ?? "TBA",
                                              style: GoogleFonts.montserrat(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 30),
                              Divider(color: Colors.grey[200]),
                              SizedBox(height: 20),
                              Text(
                                "About this Event",
                                style: GoogleFonts.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: amvViolet,
                                ),
                              ),
                              SizedBox(height: 10),
                              Html(
                                data: content,
                                style: {
                                  "body": Style(
                                    fontFamily:
                                        GoogleFonts.montserrat().fontFamily,
                                    fontSize: FontSize(15),
                                    lineHeight: LineHeight(1.8),
                                    color: Colors.grey[700],
                                    margin: Margins.zero,
                                  ),
                                },
                              ),
                              SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 20,
                    left: 20,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget homeTabStructure = _buildHomeContent();

    final List<Widget> screens = [
      MyBookingsScreen(),
      OrdersScreen(),
      homeTabStructure,
      ContactUsScreen(),
      const ProfileScreen(),
    ];

    return PopScope(
      canPop: _animationController.isDismissed,
      onPopInvokedWithResult: (didPop, result) {
        if (_animationController.isCompleted ||
            _animationController.isAnimating) {
          _closeAllEvents();
        }
      },
      child: Scaffold(
        backgroundColor: Color(0xFFF9F9F9),
        // 🟢 UPDATED BODY: Smooth Fade Transition between Tabs
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500), // Smooth luxury speed
          switchInCurve: Curves.fastOutSlowIn,
          switchOutCurve: Curves.fastOutSlowIn,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: KeyedSubtree(
            key: ValueKey<int>(
              _currentIndex,
            ), // 🟢 Triggers animation when index changes
            child: screens[_currentIndex],
          ),
        ),
        floatingActionButton:
            (_currentIndex == 2 &&
                _animationController.isDismissed &&
                _selectedCategoryIndex == 1)
            ? FloatingActionButton.extended(
                onPressed: () => _showCartDialog(),
                backgroundColor: amvGold,
                icon: Icon(Icons.shopping_cart, color: Colors.white),
                label: Text(
                  "${_cartItems.length} Items",
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 15, spreadRadius: 1),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
                if (_animationController.value > 0) {
                  _animationController.reset();
                }
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            selectedLabelStyle: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
            selectedItemColor: amvViolet,
            unselectedItemColor: Colors.grey,
            items: [
              _buildNavItem(Icons.book, "Bookings", 0),
              _buildNavItem(Icons.receipt_long, "Orders", 1),
              _buildNavItem(Icons.home, "Home", 2),
              _buildNavItem(Icons.message, "Message", 3),
              _buildNavItem(Icons.person, "Profile", 4),
            ],
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(
    IconData icon,
    String label,
    int index,
  ) {
    bool isSelected = _currentIndex == index;
    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: Duration(milliseconds: 400),
        curve: Curves.easeOutQuad,
        margin: EdgeInsets.only(bottom: isSelected ? 6.0 : 0.0, top: 5),
        padding: EdgeInsets.all(isSelected ? 12 : 8),
        decoration: BoxDecoration(
          color: isSelected ? amvViolet : Colors.transparent,
          shape: BoxShape.circle,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: amvViolet.withOpacity(0.4),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Icon(
          icon,
          color: isSelected ? amvGold : Colors.grey,
          size: isSelected ? 26 : 24,
        ),
      ),
      label: label,
    );
  }

  // --- MAIN HOME CONTENT ---
  Widget _buildHomeContent() {
    List<dynamic> filteredFood = _selectedCategoryIndex == 1
        ? _getFilteredFood()
        : [];
    bool isFoodEmpty =
        _selectedCategoryIndex == 1 && filteredFood.isEmpty && !_isLoadingFood;

    return CustomScrollView(
      controller: _homeScrollController,
      slivers: [
        SliverAppBar(
          expandedHeight: 310.0,
          pinned: true,
          backgroundColor: amvViolet,
          automaticallyImplyLeading: false,

          // 🟢 NEW: Notification Icon in Top Right
          actions: [
            // 🟢 CLEANER: Uses reusable button + Keeps the scroll fade effect
            ValueListenableBuilder<double>(
              valueListenable: _notifOpacityNotifier,
              builder: (context, opacity, child) {
                return NotificationButton(
                  // Pass the dynamic opacity color to our reusable widget
                  backgroundColor: Colors.white.withOpacity(opacity),
                );
              },
            ),
          ],

          bottom: PreferredSize(
            preferredSize: Size.fromHeight(70.0),
            child: Container(
              height: 70,
              alignment: Alignment.topCenter,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.2)],
                ),
              ),
              padding: EdgeInsets.only(bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeroButton(0, "Stays", FontAwesomeIcons.bed),
                  SizedBox(width: 15),
                  _buildHeroButton(1, "Foods", FontAwesomeIcons.utensils),
                ],
              ),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            centerTitle: true,
           title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🟢 Replaced Icon with Image
                Image.asset(
                  'assets/images/5.png', 
                  height: 20, // Keep it small to match text
                ),
                SizedBox(width: 8),
                Text(
                  "AMV HOTEL",
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            titlePadding: EdgeInsets.only(bottom: 90),
            background: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedSwitcher(
                  duration: Duration(milliseconds: 1000),
                  child: ZoomingHeroImage(
                    key: ValueKey<String>(_heroImages[_currentHeroIndex]),
                    imagePath: _heroImages[_currentHeroIndex],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        amvViolet.withOpacity(0.3),
                        Colors.black.withOpacity(0.9),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 10),
                      Text(
                        "YOUR VIBRANT EXPERIENCES AWAIT",
                        style: GoogleFonts.montserrat(
                          color: amvGold,
                          letterSpacing: 3,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "EXPERIENCE LUXURY\n& COMFORT",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Sticky Search Bar
        if (_selectedCategoryIndex == 1)
          SliverPersistentHeader(
            pinned: true,
            delegate: StickySearchBarDelegate(
              controller: _searchController,
              searchQuery: _searchQuery,
              amvViolet: amvViolet,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              onClear: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = "";
                });
              },
            ),
          ),

        SliverList(
          delegate: SliverChildListDelegate([
            _selectedCategoryIndex == 0
                ? _buildAvailabilitySearch()
                : _buildFoodCategoryFilter(),
            _buildSectionHeader(
              _selectedCategoryIndex == 0 ? "Our Rooms" : "Dining Menu",
              _selectedCategoryIndex == 0
                  ? "Stay in comfort and style"
                  : "Savor exquisite flavors",
            ),
          ]),
        ),

        // Content Logic
        if (_selectedCategoryIndex == 0)
          SliverToBoxAdapter(
            child: Container(
              height: 280,
              margin: EdgeInsets.only(bottom: 20),
              child: PageView(
                controller: PageController(viewportFraction: 0.7),
                padEnds: false,
                children: _getCategoryContent(),
              ),
            ),
          )
        else if (isFoodEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    size: 50,
                    color: Colors.grey[300],
                  ),
                  SizedBox(height: 10),
                  Text(
                    "No items available",
                    style: GoogleFonts.montserrat(color: Colors.grey),
                  ),
                  SizedBox(height: 100),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: 0.65,
              children: _getCategoryContent(),
            ),
          ),

        // News Header
        SliverList(
          delegate: SliverChildListDelegate([
            SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Latest News",
                          style: GoogleFonts.montserrat(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: amvViolet,
                          ),
                        ),
                        Text(
                          "Updates from the hotel",
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _openAllNews,
                    child: Text(
                      "View All",
                      style: GoogleFonts.montserrat(
                        color: amvViolet,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),

        // News Slider
        SliverToBoxAdapter(
          child: Container(
            height: 330,
            child: _isLoadingNews
                ? PageView.builder(
                    controller: PageController(viewportFraction: 0.7),
                    padEnds: false,
                    itemCount: 3,
                    itemBuilder: (context, index) => NewsSkeletonCard(),
                  )
                : _homeNews.isEmpty
                ? Center(child: Text("No news updates."))
                : PageView.builder(
                    controller: PageController(viewportFraction: 0.7),
                    padEnds: false,
                    itemCount: _homeNews.length,
                    itemBuilder: (context, index) {
                      return HomeEventRevealWrapper(
                        index: index,
                        child: _buildNewsCard(_homeNews[index]),
                      );
                    },
                  ),
          ),
        ),

        // Events Header
        SliverList(
          delegate: SliverChildListDelegate([
            SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Memorable Events",
                          style: GoogleFonts.montserrat(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: amvViolet,
                          ),
                        ),
                        Text(
                          "Moments we cherished",
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _openAllEvents,
                    child: Text(
                      "View All",
                      style: GoogleFonts.montserrat(
                        color: amvViolet,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),

        // Events Slider
        SliverToBoxAdapter(
          child: Container(
            height: 220,
            margin: EdgeInsets.only(bottom: 50),
            child: _isLoadingEvents
                ? PageView.builder(
                    controller: PageController(viewportFraction: 0.8),
                    padEnds: false,
                    itemCount: 3,
                    itemBuilder: (context, index) => RoomSkeletonCard(),
                  )
                : PageView.builder(
                    controller: PageController(viewportFraction: 0.8),
                    padEnds: false,
                    itemCount: _homeEvents.length,
                    itemBuilder: (context, index) {
                      return HomeEventRevealWrapper(
                        index: index,
                        child: _buildEventCard(_homeEvents[index]),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // 🟢 UPDATED: _buildNewsCard with tighter spacing
  Widget _buildNewsCard(Map<String, dynamic> newsItem) {
    String rawUrl = newsItem['full_image_url'] ?? "";
    String imageUrl = Uri.encodeFull(rawUrl);
    String title = newsItem['title'] ?? "News Update";
    String desc = newsItem['short_desc'] ?? "";
    String date = newsItem['formatted_date'] ?? "";

    return GestureDetector(
      onTap: () => _showNewsDetails(newsItem),
      child: Container(
        // 🟢 CHANGED: Horizontal margin reduced from 20 to 10
        margin: EdgeInsets.fromLTRB(10, 10, 10, 30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: amvViolet.withOpacity(0.15),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          // ... (Rest of the child code remains exactly the same)
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. IMAGE HEADER WITH HERO ANIMATION
            Stack(
              children: [
                Container(
                  height: 180,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: Hero(
                      tag: imageUrl,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return SkeletonContainer(
                            width: double.infinity,
                            height: 180,
                            borderRadius: 0,
                            icon: Icons.newspaper,
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[100],
                            child: Icon(
                              Icons.newspaper,
                              color: Colors.grey[300],
                              size: 50,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // Floating Glass Date Badge
                Positioned(
                  top: 15,
                  right: 15,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: amvViolet,
                        ),
                        SizedBox(width: 6),
                        Text(
                          date,
                          style: GoogleFonts.montserrat(
                            color: amvViolet,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // 2. TEXT CONTENT
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 8),

                    // Description
                    Expanded(
                      child: Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                    ),

                    // "Read More" Action
                    Row(
                      children: [
                        Text(
                          "READ ARTICLE",
                          style: GoogleFonts.montserrat(
                            color: amvGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.0,
                          ),
                        ),
                        SizedBox(width: 5),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: amvGold,
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🟢 UPDATED: Engaging "Event Poster" Style with Hero Animation
  Widget _buildEventCard(Map<String, dynamic> event) {
    String rawUrl = event['full_image_url'] ?? "";
    String imageUrl = Uri.encodeFull(rawUrl);
    String title = event['title'] ?? "Special Event";
    String dateString = event['formatted_date'] ?? "";

    // Parse Date for the Badge (e.g. "FEB 14")
    String month = "EVENT";
    String day = "";
    try {
      // Assuming format like "January 24, 2026"
      List<String> parts = dateString.split(' ');
      if (parts.isNotEmpty) month = parts[0].substring(0, 3).toUpperCase();
      if (parts.length > 1) day = parts[1].replaceAll(',', '');
    } catch (e) {
      // Fallback if parsing fails
    }

    return GestureDetector(
      onTap: () => _showEventDetails(event),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. FULL BACKGROUND IMAGE WITH HERO ANIMATION
              Hero(
                tag: imageUrl, // 🟢 Key for flying animation
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return SkeletonContainer(
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: 0,
                      icon: Icons.event,
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[800],
                      child: Icon(
                        Icons.event_busy,
                        color: Colors.white24,
                        size: 40,
                      ),
                    );
                  },
                ),
              ),

              // 2. GRADIENT OVERLAY (For Text Readability)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.2),
                      Colors.black.withOpacity(0.9),
                    ],
                    stops: [0.4, 0.7, 1.0],
                  ),
                ),
              ),

              // 3. CALENDAR BADGE (Top Left)
              if (day.isNotEmpty)
                Positioned(
                  top: 15,
                  left: 15,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          month,
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: amvViolet,
                          ),
                        ),
                        Text(
                          day,
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w900, // Extra Bold
                            color: Colors.black87,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 4. TITLE & ACTION (Bottom)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "FEATURED EVENT",
                            style: GoogleFonts.montserrat(
                              color: amvGold,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilitySearch() {
    String formatDate(DateTime? date, String placeholder) {
      if (date == null) return placeholder;
      return DateFormat('dd MMM yyyy').format(date);
    }

    int nights = _selectedDateRange?.duration.inDays ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: amvViolet.withOpacity(0.07),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // --- LUXURY NIGHT COUNTER TAG ---
          if (nights > 0)
            Positioned(
              top: -12,
              right: 30,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                builder: (context, value, child) => Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: amvGold,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: amvGold.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      "$nights ${nights == 1 ? 'NIGHT' : 'NIGHTS'}",
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(25, 30, 25, 25),
            child: Column(
              children: [
                // --- HEADER ---
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 20,
                      decoration: BoxDecoration(
                        color: amvGold,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "BOOK YOUR EXPERIENCE",
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: amvViolet,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),

                // --- DATE SELECTOR SECTION (Luxury Row) ---
                GestureDetector(
                  onTap: _pickDateRange,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBFBFB),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[100]!),
                    ),
                    child: Row(
                      children: [
                        _buildLuxuryDateItem(
                          "CHECK IN",
                          formatDate(_selectedDateRange?.start, "Arrival"),
                        ),
                        Container(
                          height: 30,
                          width: 1,
                          color: Colors.grey[200],
                          margin: const EdgeInsets.symmetric(horizontal: 15),
                        ),
                        _buildLuxuryDateItem(
                          "CHECK OUT",
                          formatDate(_selectedDateRange?.end, "Departure"),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // --- GUEST SELECTOR SECTION ---
                GestureDetector(
                  onTap: _showGuestBottomSheet,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBFBFB),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[100]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          FontAwesomeIcons.userGroup,
                          color: amvGold,
                          size: 18,
                        ),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "STAYING GUESTS",
                              style: GoogleFonts.montserrat(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[400],
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "$_adults Adults, $_children Children",
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: amvViolet,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: amvViolet,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                // --- THE GLOWING ACTION BUTTON ---
                Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: amvViolet.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      if (_selectedDateRange == null) {
                        _showError("Please select your travel dates");
                      } else {
                        // Your Navigation Logic
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            opaque: false,
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    AvailableRoomsScreen(
                                      // <--- This will use the import!
                                      dateRange: _selectedDateRange!,
                                      adults: _adults,
                                      children: _children,
                                      transitionAnimation: animation,
                                    ),
                            transitionsBuilder:
                                (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                ) {
                                  return SlideTransition(
                                    position:
                                        Tween<Offset>(
                                          begin: Offset(0, 1),
                                          end: Offset.zero,
                                        ).animate(
                                          CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.fastOutSlowIn,
                                          ),
                                        ),
                                    child: child,
                                  );
                                },
                            transitionDuration: Duration(milliseconds: 600),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: amvViolet,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      "FIND YOUR SUITE",
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Sub-widget for the date items
  Widget _buildLuxuryDateItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: amvViolet,
            ),
          ),
        ],
      ),
    );
  }

  // 🟢 REPLACE THE _pickDateRange FUNCTION IN HOME_SCREEN.DART
  Future<void> _pickDateRange() async {
    DateTime now = DateTime.now();
    // 8 PM restriction: If it's 8 PM or later, today is disabled to avoid no-shows.
    DateTime firstSelectableDay = now.hour >= 20
        ? DateTime(now.year, now.month, now.day + 1)
        : DateTime(now.year, now.month, now.day);

    DateTime focusedDay = _selectedDateRange?.start ?? firstSelectableDay;
    if (focusedDay.isBefore(firstSelectableDay)) {
      focusedDay = firstSelectableDay;
    }

    DateTime? tempStart = _selectedDateRange?.start;
    DateTime? tempEnd = _selectedDateRange?.end;

    // If current selection is now disabled (e.g., they selected today earlier and now it's past 8 PM), clear it
    if (tempStart != null && tempStart.isBefore(firstSelectableDay)) {
      tempStart = null;
      tempEnd = null;
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: Duration(milliseconds: 600),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: Offset(0, 1), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn),
              ),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            color: Colors.white,
            child: Container(
              height: 600,
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              width: double.infinity,
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Select Dates",
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: amvViolet,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempStart = null;
                                tempEnd = null;
                                focusedDay = firstSelectableDay;
                              });
                            },
                            child: Text(
                              "Clear",
                              style: GoogleFonts.montserrat(
                                color: Colors.red[400],
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Divider(),
                      Expanded(
                        child: TableCalendar(
                          firstDay: firstSelectableDay,
                          lastDay: DateTime.now().add(Duration(days: 365 * 2)),
                          focusedDay: focusedDay,
                          rangeStartDay: tempStart,
                          rangeEndDay: tempEnd,
                          rangeSelectionMode: RangeSelectionMode.toggledOn,
                          headerStyle: HeaderStyle(
                            titleCentered: true,
                            formatButtonVisible: false,
                            titleTextStyle: GoogleFonts.montserrat(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: amvViolet,
                            ),
                            leftChevronIcon: Icon(
                              Icons.chevron_left,
                              color: amvGold,
                            ),
                            rightChevronIcon: Icon(
                              Icons.chevron_right,
                              color: amvGold,
                            ),
                          ),
                          calendarStyle: CalendarStyle(
                            rangeHighlightColor: amvGold.withValues(alpha: 0.2),
                            rangeStartDecoration: BoxDecoration(
                              color: amvGold,
                              shape: BoxShape.circle,
                            ),
                            rangeEndDecoration: BoxDecoration(
                              color: amvGold,
                              shape: BoxShape.circle,
                            ),
                            todayDecoration: BoxDecoration(
                              color: amvViolet.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            defaultTextStyle: GoogleFonts.montserrat(),
                            weekendTextStyle: GoogleFonts.montserrat(
                              color: Colors.red[300],
                            ),
                          ),
                          onRangeSelected: (start, end, fDay) {
                            setModalState(() {
                              tempStart = start;
                              tempEnd = end;
                              focusedDay = fDay;
                            });
                          },
                          onPageChanged: (fDay) {
                            focusedDay = fDay;
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                // 🟢 CRITICAL FIX HERE:
                                // If start is selected but end is missing, default to 1 night stay.
                                if (tempStart != null) {
                                  DateTime end = tempEnd ?? tempStart!;

                                  // If they are the same day, force end date to be tomorrow
                                  if (end.isAtSameMomentAs(tempStart!)) {
                                    end = tempStart!.add(Duration(days: 1));
                                  }

                                  _selectedDateRange = DateTimeRange(
                                    start: tempStart!,
                                    end: end,
                                  );
                                } else {
                                  _selectedDateRange = null;
                                }
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: amvViolet,
                              padding: EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              "APPLY DATES",
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showGuestBottomSheet() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 600),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn),
              ),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: Container(
              height: 380, // Slightly taller for better spacing
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setModalState) {
                  return Column(
                    children: [
                      // 1. Handle Bar
                      Center(
                        child: Container(
                          width: 50,
                          height: 5,
                          margin: const EdgeInsets.only(top: 15, bottom: 25),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),

                      // 2. Title
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25),
                        child: Row(
                          children: [
                            Text(
                              "Who is staying?",
                              style: GoogleFonts.montserrat(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: amvViolet,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 3. Selectors (Wrapped in ListView just in case)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 25),
                          child: Column(
                            children: [
                              _buildGuestRow(
                                title: "Adults",
                                subtitle: "Ages 13 or above",
                                icon: Icons.person,
                                value: _adults,
                                onMinus: () {
                                  if (_adults > 1) {
                                    setModalState(() => _adults--);
                                  }
                                },
                                onPlus: () {
                                  setModalState(() => _adults++);
                                },
                              ),

                              const Divider(height: 30),

                              _buildGuestRow(
                                title: "Children",
                                subtitle: "Ages 2 - 12",
                                icon: Icons.child_care,
                                value: _children,
                                onMinus: () {
                                  if (_children > 0) {
                                    setModalState(() => _children--);
                                  }
                                },
                                onPlus: () {
                                  setModalState(() => _children++);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 4. Apply Button area
                      Container(
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              offset: const Offset(0, -5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {}); // Updates the main screen
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: amvViolet,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              "APPLY SELECTION",
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // 🟢 NEW HELPER: More engaging row design
  Widget _buildGuestRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required int value,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Row(
      children: [
        // A. Icon Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: amvViolet.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: amvViolet, size: 28),
        ),
        const SizedBox(width: 15),

        // B. Text Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // C. Modern Counter Controls
        Row(
          children: [
            // Minus Button
            _buildCircleButton(
              icon: Icons.remove,
              onTap: onMinus,
              isActive: (title == "Adults" ? value > 1 : value > 0),
            ),

            // Value
            Container(
              width: 40,
              alignment: Alignment.center,
              child: Text(
                "$value",
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),

            // Plus Button
            _buildCircleButton(
              icon: Icons.add,
              onTap: onPlus,
              isActive: true, // Always active usually
              isPlus: true, // Special styling for plus
            ),
          ],
        ),
      ],
    );
  }

  // 🟢 NEW HELPER: Circular Buttons
  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isActive,
    bool isPlus = false,
  }) {
    return GestureDetector(
      onTap: isActive ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          // If Plus: Filled Gold. If Minus: Outlined Grey (or Gold if active)
          color: isPlus ? amvGold : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isPlus
                ? amvGold
                : (isActive ? Colors.grey[400]! : Colors.grey[200]!),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          // If Plus: White Icon. If Minus: Dark Icon (or Light Grey if disabled)
          color: isPlus
              ? Colors.white
              : (isActive ? Colors.black87 : Colors.grey[300]),
        ),
      ),
    );
  }

  Widget _buildFoodCategoryFilter() {
    return Container(
      height: 50,
      margin: EdgeInsets.only(top: 20, bottom: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20),
        itemCount: _foodCategories.length,
        itemBuilder: (context, index) {
          bool isActive = _selectedFoodFilter == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFoodFilter = index;
              });
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              margin: EdgeInsets.only(right: 10),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? amvViolet : Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isActive ? amvViolet : Colors.grey[300]!,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: amvViolet.withOpacity(0.3),
                          blurRadius: 5,
                          offset: Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: Text(
                  _foodCategories[index],
                  style: GoogleFonts.montserrat(
                    color: isActive ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroButton(int index, String label, IconData icon) {
    bool isSelected = _selectedCategoryIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _selectedCategoryIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? amvViolet : Colors.white),
            SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.montserrat(
                color: isSelected ? amvViolet : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _getCategoryContent() {
    if (_selectedCategoryIndex == 0) {
      // 🟢 1. Loading State
      if (_isLoadingRooms) {
        return List.generate(
          3,
          (index) =>
              HomeEventRevealWrapper(index: index, child: RoomSkeletonCard()),
        );
      }

      // 🟢 2. Empty State
      if (_homeRooms.isEmpty) {
        return [Center(child: Text("No rooms available"))];
      }

      // 🟢 3. Map Data to Cards (Updated Logic)
      return _homeRooms.asMap().entries.map((entry) {
        // --- A. PARSE IMAGES ---
        List<String> images = [];

        // Priority 1: Use the new 'all_images' array from the PHP API
        if (entry.value['all_images'] != null) {
          // Ensure it's treated as a List of Strings
          images = List<String>.from(entry.value['all_images']);
        }
        // Priority 2: Fallback to the single 'full_image_url' if array is missing
        else {
          String mainImg = entry.value['full_image_url'] ?? "";
          if (mainImg.isNotEmpty) images.add(mainImg);
        }

        // Safety Fallback
        if (images.isEmpty) {
          images.add("https://placehold.co/600x400/2D0F35/FFF?text=No+Image");
        }

        return HomeEventRevealWrapper(
          index: entry.key,
          child: _buildDetailCard(
            title: entry.value['name'] ?? "Room",
            bedType: entry.value['bed_type'] ?? "Standard Bed",
            description: entry.value['description'] ?? "",
            price: entry.value['formatted_price'] ?? "0",

            // 🟢 B. PASS NEW DATA FIELDS
            amenities:
                entry.value['amenities'] ??
                "", // Passes the string "Wifi, Pool, etc."
            imageUrls: images, // Passes the List of all image URLs

            isLast: entry.key == _homeRooms.length - 1,
          ),
        );
      }).toList();
    } else {
      // FOOD LOGIC
      if (_isLoadingFood) {
        return List.generate(
          4,
          (index) =>
              HomeEventRevealWrapper(index: index, child: RoomSkeletonCard()),
        );
      }

      List<dynamic> filteredFood = _getFilteredFood();

      // 🔴 NO EMPTY CHECK HERE (Handled in buildHomeContent)

      return filteredFood.asMap().entries.map((entry) {
        int idx = entry.key;
        var food = entry.value;

        return KeepAliveWrapper(
          child: HomeEventRevealWrapper(
            index: idx,
            durationMs: 300,
            child: _buildFoodOrderCard(
              food['item_name'] ?? "Unknown Item",
              food['category'] ?? "General",
              food['price'].toString(),
              food['full_image_url'] ?? "",
              isLast: idx == filteredFood.length - 1,
              description: food['description'] ?? "",
            ),
          ),
        );
      }).toList();
    }
  }

  Widget _buildDetailCard({
    required String title,
    required String bedType,
    required String description,
    required String price,
    required String amenities,
    required List<String> imageUrls,
    bool isLast = false,
  }) {
    return GestureDetector(
      // 🟢 UPDATED ANIMATION: Matches "View All" slide-up effect
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            opaque: false, // Makes the transition feel lighter
            pageBuilder: (context, animation, secondaryAnimation) =>
                RoomDetailScreen(
                  title: title,
                  price: price,
                  description: description,
                  bedType: bedType,
                  amenities: amenities,
                  images: imageUrls,
                ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  // 1. Slide from Bottom (Offset 0, 1) to Top (Offset 0, 0)
                  var begin = const Offset(0.0, 1.0);
                  var end = Offset.zero;
                  var curve = Curves.fastOutSlowIn; // 🟢 PREMIUM CURVE

                  var tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: curve));

                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
            transitionDuration: const Duration(
              milliseconds: 600,
            ), // Slower, smoother speed
            reverseTransitionDuration: const Duration(milliseconds: 600),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(left: 20, right: isLast ? 20 : 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // 1. REPLACED STATIC IMAGE WITH SLIDESHOW
              Positioned.fill(child: RoomCardSlideshow(images: imageUrls)),

              // 2. Gradient Overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Price Badge
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "₱$price",
                    style: GoogleFonts.montserrat(
                      color: amvViolet,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),

              // 4. Details Text
              Positioned(
                bottom: 15,
                left: 15,
                right: 15,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      bedType,
                      style: GoogleFonts.montserrat(
                        color: amvGold,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 10,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🟢 UPDATED: Vertical Food Card for Grid Layout
  Widget _buildFoodOrderCard(
    String title,
    String subtitle,
    String price,
    String imageUrl, {
    bool isLast = false,
    String description = "",
  }) {
    int qty = _cartItems[title] ?? 0;

    bool hasImage =
        imageUrl.isNotEmpty &&
        !imageUrl.contains("placehold.co") &&
        !imageUrl.contains("default_image") &&
        !imageUrl.endsWith(".svg") &&
        imageUrl.startsWith("http");

    return Container(
      // No margins needed here, the Grid handles spacing
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. IMAGE AREA (Top Half)
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    color: hasImage ? null : amvViolet.withOpacity(0.05),
                    image: hasImage
                        ? DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: !hasImage
                      ? Center(
                          child: Icon(
                            _getCategoryIcon(subtitle),
                            size: 35,
                            color: amvViolet.withOpacity(0.3),
                          ),
                        )
                      : null,
                ),
                // Price Badge (Top Right)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "₱$price",
                      style: GoogleFonts.montserrat(
                        color: amvViolet,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. DETAILS AREA (Bottom Half)
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title & Category
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle.toUpperCase(),
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  // Quantity Controls
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: qty == 0
                        ? SizedBox(
                            width: double.infinity,
                            height: 32,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _cartItems[title] = 1;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: amvViolet,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                                padding: EdgeInsets.zero,
                              ),
                              child: Text(
                                "ADD",
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (qty > 0) {
                                        _cartItems[title] = qty - 1;
                                        if (_cartItems[title] == 0)
                                          _cartItems.remove(title);
                                      }
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                    ),
                                    child: Icon(
                                      Icons.remove,
                                      size: 14,
                                      color: amvViolet,
                                    ),
                                  ),
                                ),
                                Text(
                                  "$qty",
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: amvViolet,
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _cartItems[title] = qty + 1;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                    ),
                                    child: Icon(
                                      Icons.add,
                                      size: 14,
                                      color: amvViolet,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Section Header Widget
  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: amvViolet,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🟢 UPDATED: "Checkout" now slides up nicely like the Events page
  void _showCartDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 600),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn),
              ),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            color: Colors.white,
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
                minHeight: 300,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  // Calculate Total
                  double totalAmount = 0.0;
                  _cartItems.forEach((key, qty) {
                    var foodItem = _homeFood.firstWhere(
                      (element) => element['item_name'] == key,
                      orElse: () => {},
                    );
                    if (foodItem.isNotEmpty) {
                      double price =
                          double.tryParse(foodItem['price'].toString()) ?? 0.0;
                      totalAmount += (price * qty);
                    }
                  });

                  return Column(
                    children: [
                      // Handle Bar
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(top: 15, bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Title
                      Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: Text(
                          "Your Order",
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: amvViolet,
                          ),
                        ),
                      ),
                      const Divider(height: 1),

                      // List
                      Expanded(
                        child: _cartItems.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.remove_shopping_cart,
                                      size: 40,
                                      color: Colors.grey[300],
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      "Your cart is empty",
                                      style: GoogleFonts.montserrat(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                itemCount: _cartItems.length,
                                itemBuilder: (context, index) {
                                  String key = _cartItems.keys.elementAt(index);
                                  int value = _cartItems[key]!;

                                  var foodItem = _homeFood.firstWhere(
                                    (element) => element['item_name'] == key,
                                    orElse: () => {},
                                  );
                                  String imageUrl = "";
                                  String category = "General";

                                  if (foodItem.isNotEmpty) {
                                    imageUrl = foodItem['full_image_url'] ?? "";
                                    category =
                                        foodItem['category'] ?? "General";
                                  }

                                  bool hasImage =
                                      imageUrl.isNotEmpty &&
                                      !imageUrl.contains("placehold") &&
                                      imageUrl.startsWith("http");

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      leading: Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          color: Colors.grey[200],
                                          image: hasImage
                                              ? DecorationImage(
                                                  image: NetworkImage(
                                                    Uri.encodeFull(imageUrl),
                                                  ),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: !hasImage
                                            ? Icon(
                                                _getCategoryIcon(category),
                                                color: amvViolet.withOpacity(
                                                  0.5,
                                                ),
                                                size: 24,
                                              )
                                            : null,
                                      ),
                                      title: Text(
                                        key,
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: Colors.grey[300]!,
                                              ),
                                            ),
                                            child: Text(
                                              "x$value",
                                              style: GoogleFonts.montserrat(
                                                fontWeight: FontWeight.bold,
                                                color: amvViolet,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          IconButton(
                                            icon: Icon(
                                              Icons.close,
                                              color: Colors.red[300],
                                              size: 20,
                                            ),
                                            constraints: BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                            splashRadius: 20,
                                            onPressed: () {
                                              setModalState(() {
                                                _cartItems.remove(key);
                                              });
                                              setState(() {});
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),

                      // Total Amount
                      if (_cartItems.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 15,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            border: Border(
                              top: BorderSide(color: Colors.grey[200]!),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Total Amount",
                                style: GoogleFonts.montserrat(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(
                                "₱${totalAmount.toStringAsFixed(2)}",
                                style: GoogleFonts.montserrat(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: amvViolet,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Buttons
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: Colors.grey[100]!),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  side: BorderSide(color: Colors.grey[300]!),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  "Close",
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: () {
                                  if (_isBlocked) {
                                    _showOrderLimitModal();
                                    return;
                                  }

                                  if (_cartItems.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Cart is empty!",
                                          style: GoogleFonts.montserrat(),
                                        ),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }

                                  // 🟢 NAVIGATE WITH SLIDE-UP ANIMATION
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      opaque:
                                          false, // Optional: Keep background if you want transparency
                                      pageBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                          ) => CheckoutScreen(
                                            cartItems: _cartItems,
                                            foodData: _homeFood,
                                            roomData: _homeRooms,
                                            transitionAnimation: animation,

                                            // 🟢 UPDATED onSubmit: Now accepts 'receiptImage'
                                            onSubmit:
                                                (
                                                  location,
                                                  payment,
                                                  notes, {
                                                  bool isOutside = false,
                                                  String phone = "",
                                                  File? receiptImage,
                                                  String? paymentRef, // 🟢 Catch the ref
                                                }) {
                                                  _submitOrderToApi(
                                                    location,
                                                    payment,
                                                    notes,
                                                    isOutside: isOutside,
                                                    phone: phone,
                                                    receiptImage: receiptImage,
                                                    paymentRef: paymentRef, // 🟢 Pass the ref
                                                  );
                                                },
                                          ),
                                      transitionsBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                            child,
                                          ) {
                                            return SlideTransition(
                                              position:
                                                  Tween<Offset>(
                                                    begin: const Offset(0, 1),
                                                    end: Offset.zero,
                                                  ).animate(
                                                    CurvedAnimation(
                                                      parent: animation,
                                                      curve: Curves
                                                          .fastOutSlowIn, // Premium Feel
                                                    ),
                                                  ),
                                              child: child,
                                            );
                                          },
                                      transitionDuration: const Duration(
                                        milliseconds: 600,
                                      ),
                                      reverseTransitionDuration: const Duration(
                                        milliseconds: 600,
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _cartItems.isEmpty
                                      ? Colors.grey[400]
                                      : amvGold,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "CHECKOUT",
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

// 🟢 NEW HELPER WIDGET FOR DELAYED LOADING
class _DelayedDisplay extends StatefulWidget {
  final Widget child;
  const _DelayedDisplay({required this.child});

  @override
  _DelayedDisplayState createState() => _DelayedDisplayState();
}

class _DelayedDisplayState extends State<_DelayedDisplay> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 150), () {
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: Duration(milliseconds: 300),
      opacity: _loaded ? 1.0 : 0.0,
      child: _loaded
          ? widget.child
          : Center(child: CircularProgressIndicator(color: Color(0xFF2D0F35))),
    );
  }
}

/// 🟢 HELPER: Shows a Spinkit animation while the modal slides up
class DelayedRender extends StatefulWidget {
  final Widget child;
  const DelayedRender({Key? key, required this.child}) : super(key: key);

  @override
  _DelayedRenderState createState() => _DelayedRenderState();
}

class _DelayedRenderState extends State<DelayedRender> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 700), () {
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 400),
      child: _loaded
          ? widget.child
          : Center(
              child: SpinKitThreeBounce(color: Color(0xFF2D0F35), size: 30.0),
            ),
    );
  }
}

// 🟢 UPDATED WRAPPER: Now accepts a custom duration
class HomeEventRevealWrapper extends StatefulWidget {
  final int index;
  final Widget child;
  final int durationMs; // 1. Add this

  const HomeEventRevealWrapper({
    required this.index,
    required this.child,
    this.durationMs = 500, // Default is 500ms (for Rooms/Events)
  });

  @override
  _HomeEventRevealWrapperState createState() => _HomeEventRevealWrapperState();
}

class _HomeEventRevealWrapperState extends State<HomeEventRevealWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      // 2. Use the passed duration here
      duration: Duration(milliseconds: widget.durationMs),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    // 3. Optional: Make the delay faster too if the duration is short
    int delay = (widget.durationMs < 400) ? 30 : 80;

    Future.delayed(Duration(milliseconds: widget.index * delay), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _offsetAnimation, child: widget.child),
    );
  }
}

// 🟢 UPDATED: Skeleton with optional "Fancy Icon"
class SkeletonContainer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final IconData? icon; // 🟢 NEW: Pass an icon here

  const SkeletonContainer({
    Key? key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.icon,
  }) : super(key: key);

  @override
  _SkeletonContainerState createState() => _SkeletonContainerState();
}

class _SkeletonContainerState extends State<SkeletonContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.6).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[400],
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
        // 🟢 IF ICON EXISTS, CENTER IT
        child: widget.icon != null
            ? Center(
                child: Icon(
                  widget.icon,
                  color: Colors.white.withOpacity(0.5), // Subtle white tint
                  size: 30,
                ),
              )
            : null,
      ),
    );
  }
}

// 🟢 NEW: Room/Event Skeleton Card (Matches your Room Card Layout)
class RoomSkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Image Placeholder
          Positioned.fill(
            child: SkeletonContainer(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 20,
            ),
          ),
          // Price Badge Placeholder (Top Right)
          Positioned(
            top: 12,
            right: 12,
            child: SkeletonContainer(width: 60, height: 25, borderRadius: 8),
          ),
          // Text Content Placeholder (Bottom Left)
          Positioned(
            bottom: 15,
            left: 15,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonContainer(width: 120, height: 20, borderRadius: 4),
                SizedBox(height: 8),
                SkeletonContainer(width: 80, height: 12, borderRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 🟢 NEW: News Skeleton Card (Matches your News Layout)
class NewsSkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Area
          Container(
            height: 140,
            width: double.infinity,
            padding: EdgeInsets.all(0),
            child: SkeletonContainer(
              width: double.infinity,
              height: 140,
              borderRadius: 12,
            ),
          ),
          // Text Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonContainer(
                    width: 80,
                    height: 10,
                    borderRadius: 4,
                  ), // Date
                  SizedBox(height: 10),
                  SkeletonContainer(
                    width: double.infinity,
                    height: 16,
                    borderRadius: 4,
                  ), // Title
                  SizedBox(height: 10),
                  SkeletonContainer(
                    width: 200,
                    height: 12,
                    borderRadius: 4,
                  ), // Desc Line 1
                  SizedBox(height: 5),
                  SkeletonContainer(
                    width: 150,
                    height: 12,
                    borderRadius: 4,
                  ), // Desc Line 2
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 🟢 NEW: Handles the smooth Zoom-In animation for the Hero Image
class ZoomingHeroImage extends StatefulWidget {
  final String imagePath;

  const ZoomingHeroImage({Key? key, required this.imagePath}) : super(key: key);

  @override
  _ZoomingHeroImageState createState() => _ZoomingHeroImageState();
}

class _ZoomingHeroImageState extends State<ZoomingHeroImage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // 1. Setup a slow animation (e.g., 6 seconds)
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 6),
    );

    // 2. Define the scale (Zoom from 1.0 to 1.15)
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));

    // 3. Start the animation immediately
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Image.asset(
        widget.imagePath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}

// 🟢 NEW: Keeps the PageView items alive so they don't reload/re-animate
class KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const KeepAliveWrapper({Key? key, required this.child}) : super(key: key);

  @override
  _KeepAliveWrapperState createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context); // 🟢 IMPORTANT: Must call super.build
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true; // 🟢 TRUE = Keep in memory
}

// 🟢 NEW: Handles the Sticky Search Bar logic
class StickySearchBarDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController controller;
  final String searchQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final Color amvViolet;

  StickySearchBarDelegate({
    required this.controller,
    required this.searchQuery,
    required this.onChanged,
    required this.onClear,
    required this.amvViolet,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      width: double.infinity,
      height: 80,
      // 🟢 Slightly transparent background when sticky
      // color: Color(0xFFF9F9F9).withOpacity(0.95),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          style: GoogleFonts.montserrat(color: Colors.black87),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: "Search menu...",
            hintStyle: GoogleFonts.montserrat(color: Colors.grey),
            prefixIcon: Icon(Icons.search, color: amvViolet),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey),
                    onPressed: onClear,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 80.0; // Height of the sticky area

  @override
  double get minExtent => 80.0;

  @override
  bool shouldRebuild(covariant StickySearchBarDelegate oldDelegate) {
    return oldDelegate.searchQuery != searchQuery;
  }
}

// 🟢 NEW: Auto-playing Slideshow for Room Cards
class RoomCardSlideshow extends StatefulWidget {
  final List<String> images;
  const RoomCardSlideshow({Key? key, required this.images}) : super(key: key);

  @override
  _RoomCardSlideshowState createState() => _RoomCardSlideshowState();
}

class _RoomCardSlideshowState extends State<RoomCardSlideshow> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.images.length > 1) {
      _timer = Timer.periodic(Duration(seconds: 4), (timer) {
        if (mounted) {
          setState(() {
            _currentIndex = (_currentIndex + 1) % widget.images.length;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Duration(seconds: 1),
      child: Image.network(
        widget.images[_currentIndex],
        key: ValueKey<String>(widget.images[_currentIndex]),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(color: Colors.grey[200]); // Simple placeholder
        },
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[300],
          child: Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      ),
    );
  }
}

// 🟢 NEW: Full Screen Image Viewer Widget
class FullScreenImageViewer extends StatelessWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenImageViewer({
    Key? key,
    required this.images,
    required this.initialIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Photo View Gallery for swipeable, zoomable images
          PhotoViewGallery.builder(
            itemCount: images.length,
            builder: (context, index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: NetworkImage(images[index]),
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
                heroAttributes: PhotoViewHeroAttributes(tag: images[index]),
              );
            },
            scrollPhysics: const BouncingScrollPhysics(),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            pageController: PageController(initialPage: initialIndex),
            loadingBuilder: (context, event) => Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                value: event == null
                    ? null
                    : event.cumulativeBytesLoaded /
                          (event.expectedTotalBytes ?? 1),
              ),
            ),
          ),
          // Close Button
          Positioned(
            top: 40,
            right: 20,
            child: SafeArea(
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 🟢 UPDATED: Room Details with Bento Grid & Smart Interactions
class RoomDetailScreen extends StatelessWidget {
  final String title;
  final String price;
  final String description;
  final String bedType;
  final String amenities;
  final List<String> images;

  const RoomDetailScreen({
    Key? key,
    required this.title,
    required this.price,
    required this.description,
    required this.bedType,
    required this.amenities,
    required this.images,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Define colors locally if not available globally
    final Color amvViolet = const Color(0xFF2D0F35);
    final Color amvGold = const Color(0xFFD4AF37);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. BENTO GRID HEADER
              SliverAppBar(
                expandedHeight: 400, // Tall header for the mosaic
                pinned: true,
                backgroundColor: amvViolet,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 20),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin, // Keeps images visible longer
                  background: _buildBentoGrid(context),
                ),
              ),

              // 2. CONTENT BODY
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.all(25.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title & Bed Type Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: amvViolet,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: amvGold.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      bedType.toUpperCase(),
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: amvGold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // 🟢 CHANGED: Engaging Static Bed Icon
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: amvGold.withOpacity(0.2), width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: amvGold.withOpacity(0.15),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.king_bed_rounded, 
                                size: 28, 
                                color: amvGold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),
                        const Divider(),
                        const SizedBox(height: 25),

                        // Description
                        Text(
                          "Room Overview",
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          description,
                          style: GoogleFonts.montserrat(
                            fontSize: 15,
                            color: Colors.grey[700],
                            height: 1.6,
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Smart Amenities Grid
                        Text(
                          "What this room offers",
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 15),
                        _buildSmartAmenities(context, amenities),

                        const SizedBox(
                            height: 120), // Bottom padding for sticky bar
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          ),

          // 3. STICKY BOOKING BAR (Floating)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    // Price Display
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Start from",
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                "₱$price",
                                style: GoogleFonts.montserrat(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: amvViolet,
                                ),
                              ),
                              Text(
                                " / night",
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Book Button
                    ElevatedButton(
                      onPressed: () {
                        // Close this screen to return to home (or trigger booking logic)
                        Navigator.pop(context, "BOOK_NOW");
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: amvViolet,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 5,
                        shadowColor: amvViolet.withOpacity(0.4),
                      ),
                      child: Text(
                        "Book Now",
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🟢 HELPER: Build Bento/Mosaic Grid
  Widget _buildBentoGrid(BuildContext context) {
    if (images.isEmpty) return Container(color: Colors.grey[200]);

    if (images.length == 1) {
      return _buildImage(context, images[0], 0);
    } else if (images.length == 2) {
      return Row(
        children: [
          Expanded(child: _buildImage(context, images[0], 0)),
          const SizedBox(width: 2),
          Expanded(child: _buildImage(context, images[1], 1)),
        ],
      );
    } else if (images.length == 3) {
      return Row(
        children: [
          Expanded(flex: 2, child: _buildImage(context, images[0], 0)),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildImage(context, images[1], 1)),
                const SizedBox(height: 2),
                Expanded(child: _buildImage(context, images[2], 2)),
              ],
            ),
          ),
        ],
      );
    } else {
      // 4 or more images
      return Column(
        children: [
          Expanded(flex: 2, child: _buildImage(context, images[0], 0)),
          const SizedBox(height: 2),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildImage(context, images[1], 1)),
                const SizedBox(width: 2),
                Expanded(child: _buildImage(context, images[2], 2)),
                const SizedBox(width: 2),
                // Show "+X" on the last image if there are more than 4
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImage(context, images[3], 3),
                      if (images.length > 4)
                        Container(
                          color: Colors.black.withOpacity(0.5),
                          child: Center(
                            child: Text(
                              "+${images.length - 4}",
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  // 🟢 HELPER: Single Image Tile with Click
  Widget _buildImage(BuildContext context, String url, int index) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                FullScreenImageViewer(images: images, initialIndex: index),
          ),
        );
      },
      child: Hero(
        tag: url, // Hero animation tag
        child: Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (_, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.image, color: Colors.grey),
              ),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey[200],
            child: const Icon(Icons.broken_image),
          ),
        ),
      ),
    );
  }

  // 🟢 Smart Amenities Builder
  Widget _buildSmartAmenities(BuildContext context, String rawAmenities) {
    if (rawAmenities.isEmpty)
      return const Text("No specific amenities listed.");

    List<String> items =
        rawAmenities.split(',').map((e) => e.trim()).toList();
    // Re-define colors locally for helper method
    final Color amvViolet = const Color(0xFF2D0F35);

    return Wrap(
      spacing: 15,
      runSpacing: 15,
      children: items.map((item) {
        return Container(
          width: MediaQuery.of(context).size.width / 2 - 40, // 2 items per row
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: amvViolet.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getAmenityIcon(item),
                  size: 20,
                  color: amvViolet,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

 // 🟢 Helper to guess icon based on keyword from Database
  IconData _getAmenityIcon(String name) {
    String lower = name.toLowerCase();
    
    // Tech & Media
    if (lower.contains("wifi") || lower.contains("net")) return Icons.wifi;
    if (lower.contains("tv") || lower.contains("tele")) return Icons.tv;
    
    // Comfort & Climate
    if (lower.contains("ac") || lower.contains("air")) return Icons.ac_unit;
    if (lower.contains("fan")) return Icons.mode_fan_off;
    if (lower.contains("heat")) return Icons.thermostat;
    
    // Bathroom
    if (lower.contains("bath") || lower.contains("tub")) return Icons.bathtub;
    if (lower.contains("shower")) return Icons.shower;
    if (lower.contains("toilet") || lower.contains("wc")) return Icons.wc;
    if (lower.contains("jacuzzi") || lower.contains("hot tub")) return Icons.hot_tub;
    if (lower.contains("towel")) return Icons.dry;
    
    // Sleeping
    if (lower.contains("bed")) return Icons.bed;
    if (lower.contains("crib") || lower.contains("baby")) return Icons.crib;
    
    // Food & Drink
    if (lower.contains("food") || lower.contains("break") || lower.contains("din")) return Icons.restaurant;
    if (lower.contains("coffee") || lower.contains("tea")) return Icons.coffee;
    if (lower.contains("bar") || lower.contains("drink")) return Icons.local_bar;
    if (lower.contains("fridge") || lower.contains("refrig")) return Icons.kitchen;
    if (lower.contains("kitchen")) return Icons.countertops;
    
    // Facilities
    if (lower.contains("pool")) return Icons.pool;
    if (lower.contains("gym") || lower.contains("fit")) return Icons.fitness_center;
    if (lower.contains("spa") || lower.contains("mass")) return Icons.spa;
    if (lower.contains("park")) return Icons.local_parking;
    if (lower.contains("elevator") || lower.contains("lift")) return Icons.elevator;
    if (lower.contains("wheelchair") || lower.contains("access")) return Icons.accessible;
    
    // Room Features
    if (lower.contains("view")) return Icons.landscape;
    if (lower.contains("balcony") || lower.contains("terrace")) return Icons.balcony;
    if (lower.contains("work") || lower.contains("desk")) return Icons.work;
    if (lower.contains("safe")) return Icons.security;
    if (lower.contains("smoke")) return Icons.smoke_free; // or smoking_rooms depending on context

    // Default Fallback
    return Icons.check_circle_outline; 
  }
}

// 🟢 NEW: Immersive "Article Reader" Screen
class NewsDetailScreen extends StatefulWidget {
  final String title;
  final String imageUrl;
  final String date;
  final String rawDate;
  final String content;

  const NewsDetailScreen({
    Key? key,
    required this.title,
    required this.imageUrl,
    required this.date,
    required this.rawDate,
    required this.content,
  }) : super(key: key);

  @override
  _NewsDetailScreenState createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Setup Entrance Animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    // Start animation after page load
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 🟢 Helper: Calculate Relative Time
  String _getTimeAgo() {
    try {
      // 1. Check for invalid or "Recently" fallbacks
      if (widget.rawDate.isEmpty || 
          widget.rawDate.contains("0000-00-00") || 
          widget.date.toLowerCase().contains("recently") ||
          widget.date.contains("-0001")) {
        return "posted recently";
      }

      DateTime postDate = DateTime.parse(widget.rawDate);
      DateTime now = DateTime.now();

      // 2. Sanity Check: If the date is absurdly old (e.g., year 0/1/-1 from DB error)
      if (postDate.year < 2010) { // News probably isn't from before 2010
        return "posted recently";
      }

      Duration diff = now.difference(postDate);

      // 3. Handle future dates (if server time is slightly ahead)
      if (diff.isNegative) {
        return "posted just now";
      }

      if (diff.inDays >= 365) {
        int years = (diff.inDays / 365).floor();
        return "posted $years ${years == 1 ? 'year' : 'years'} ago";
      } else if (diff.inDays >= 30) {
        int months = (diff.inDays / 30).floor();
        return "posted $months ${months == 1 ? 'month' : 'months'} ago";
      } else if (diff.inDays > 0) {
        return "posted ${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago";
      } else if (diff.inHours > 0) {
        return "posted ${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago";
      } else if (diff.inMinutes > 0) {
        return "posted ${diff.inMinutes} ${diff.inMinutes == 1 ? 'min' : 'mins'} ago";
      } else {
        return "posted just now";
      }
    } catch (e) {
      return "posted recently";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 1. Immersive Parallax Header
          SliverAppBar(
            expandedHeight: 400, // Very tall header for impact
            pinned: true,
            backgroundColor: const Color(0xFF2D0F35),
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // 🟢 Hero Image (Catches the flying image)
                  Hero(
                    tag: widget.imageUrl,
                    child: Image.network(
                      widget.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: Colors.grey),
                    ),
                  ),
                  // Gradient for Text Visibility
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          const Color(0xFF2D0F35).withOpacity(0.2),
                          const Color(0xFF2D0F35).withOpacity(0.9),
                        ],
                        stops: const [0.4, 0.7, 1.0],
                      ),
                    ),
                  ),
                  // Title on Image
                  Positioned(
                    bottom: 40,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category / Date Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            (widget.date.contains("-0001") || widget.date.contains("0000")) 
                                ? "RECENTLY" 
                                : widget.date.toUpperCase(),
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.title,
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Animated Content Body
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  // Overlap effect
                  transform: Matrix4.translationValues(0, -20, 0),
                  padding: const EdgeInsets.all(25),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Meta Row
                      Row(
                        children: [
                          const Icon(Icons.access_time_filled_rounded, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            _getTimeAgo(),
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.newspaper_rounded,
                            color: Color(0xFFD4AF37),
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 20),

                      // Main Content
                      Html(
                        data: widget.content,
                        style: {
                          "body": Style(
                            fontFamily: GoogleFonts.montserrat().fontFamily,
                            fontSize: FontSize(16),
                            lineHeight: LineHeight(1.8),
                            color: Colors.grey[800],
                            margin: Margins.zero,
                          ),
                          "p": Style(margin: Margins.only(bottom: 20)),
                          "strong": Style(color: const Color(0xFF2D0F35)),
                        },
                      ),

                      // Footer
                      const SizedBox(height: 40),
                      Center(
                        child: Text(
                          "●  ●  ●",
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 🟢 UPDATED: Engaging "Event Showcase" Screen
class EventDetailScreen extends StatelessWidget {
  final String title;
  final String imageUrl;
  final String date;
  final String content;

  const EventDetailScreen({
    Key? key,
    required this.title,
    required this.imageUrl,
    required this.date,
    required this.content,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Clean background
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. IMMERSIVE HEADER
          SliverAppBar(
            expandedHeight: 400, // Tall header for impact
            pinned: true,
            backgroundColor: const Color(0xFF2D0F35), // amvViolet
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // 🟢 Hero Image Transition
                  Hero(
                    tag: imageUrl, // Matches the list tag
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: Colors.grey[300]),
                    ),
                  ),

                  // Gradient Overlay for Title Visibility
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          const Color(0xFF2D0F35).withOpacity(0.2),
                          const Color(0xFF2D0F35).withOpacity(0.8),
                        ],
                        stops: const [0.5, 0.8, 1.0],
                      ),
                    ),
                  ),

                  // Title on Image
                  Positioned(
                    bottom: 40,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37), // amvGold
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            "EXCLUSIVE EVENT",
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          title,
                          style: GoogleFonts.montserrat(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.1,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. CONTENT BODY
          SliverToBoxAdapter(
            child: Container(
              transform: Matrix4.translationValues(0, -20, 0), // Pull up effect
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: const EdgeInsets.all(25.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date & Info Row
                  Row(
                    children: [
                      // Date Badge
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D0F35).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              color: Color(0xFF2D0F35),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "DATE",
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                Text(
                                  date,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF2D0F35),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                  const Divider(),
                  const SizedBox(height: 20),

                  // Description Title
                  Text(
                    "About this Event",
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // HTML Content
                  Html(
                    data: content,
                    style: {
                      "body": Style(
                        fontFamily: GoogleFonts.montserrat().fontFamily,
                        fontSize: FontSize(15),
                        lineHeight: LineHeight(1.8),
                        color: Colors.grey[700],
                        margin: Margins.zero,
                      ),
                      "p": Style(margin: Margins.only(bottom: 15)),
                    },
                  ),

                  const SizedBox(height: 50),

                  // Decorative End
                  Center(
                    child: Icon(
                      Icons.star,
                      color: const Color(0xFFD4AF37).withOpacity(0.3),
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OrderSuccessScreen extends StatelessWidget {
  final Color amvViolet = const Color(0xFF2D0F35);
  final Color amvGold = const Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🟢 Success Icon with Gold Background
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: amvGold.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, color: amvGold, size: 100),
              ),
              const SizedBox(height: 30),
              Text(
                "Order Placed!",
                style: GoogleFonts.montserrat(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: amvViolet,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                "Your delicious meal is being prepared and will be delivered to your room shortly.",
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 50),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => HomeScreen(),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 1),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.fastOutSlowIn,
                            )),
                            child: child,
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 600),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: amvViolet,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    "BACK TO HOME",
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
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
