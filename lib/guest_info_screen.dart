import 'dart:async';
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'api_config.dart';
import 'booking_summary_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_conditions_screen.dart';

class GuestInfoScreen extends StatefulWidget {
  final DateTimeRange dateRange;
  final List<dynamic> selectedRooms;
  final int adults;
  final int children;

  const GuestInfoScreen({
    Key? key,
    required this.dateRange,
    required this.selectedRooms,
    required this.adults,
    required this.children,
  }) : super(key: key);

  @override
  State<GuestInfoScreen> createState() => _GuestInfoScreenState();
}

class _GuestInfoScreenState extends State<GuestInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final Color amvViolet = const Color(0xFF2D0F35);
  final Color amvGold = const Color(0xFFD4AF37);

  // --- Controllers ---
  final _fNameCtrl = TextEditingController();
  final _lNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _requestsCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();
  final _birthdateCtrl = TextEditingController();
  final _arrivalTimeCtrl = TextEditingController();

  String _paymentTerm = "full";
  String? _gender;
  bool _agreedToTerms = false;
  
  // 🟢 STATE VARIABLES FOR ANIMATION
  bool _isLoadingData = true; // Start true to show spinner immediately
  bool _showForm = false;     // Controls when the stagger animation starts

  List<dynamic> _addressResults = [];
  bool _isSearchingAddress = false;
  Timer? _debounce;
  final Map<String, List<dynamic>> _addressCache = {};

  @override
  void initState() {
    super.initState();
    _prefillData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _fNameCtrl.dispose();
    _lNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _requestsCtrl.dispose();
    _nationalityCtrl.dispose();
    _birthdateCtrl.dispose();
    _arrivalTimeCtrl.dispose();
    super.dispose();
  }

  Future<void> _prefillData() async {
    // 🟢 1. Artificial Delay for Smooth Transition (1.2 seconds)
    await Future.delayed(const Duration(milliseconds: 1200));

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailCtrl.text = user.email ?? "";
      if (user.displayName != null && _fNameCtrl.text.isEmpty) {
        if (user.displayName!.contains(" ")) {
          List<String> names = user.displayName!.split(" ");
          _fNameCtrl.text = names.first;
          _lNameCtrl.text = names.sublist(1).join(" ");
        } else {
          _fNameCtrl.text = user.displayName ?? "";
        }
      }

      try {
        final response = await http.post(
          Uri.parse("${ApiConfig.baseUrl}/api_get_last_guest_info.php"),
          body: {'uid': user.uid},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true && data['data'] != null) {
            final info = data['data'];

            if (mounted) {
              setState(() {
                if (_fNameCtrl.text.isEmpty) _fNameCtrl.text = info['first_name'] ?? "";
                if (_lNameCtrl.text.isEmpty) _lNameCtrl.text = info['last_name'] ?? "";
                if (_emailCtrl.text.isEmpty) _emailCtrl.text = info['email'] ?? user.email;
                if (_phoneCtrl.text.isEmpty) _phoneCtrl.text = info['phone'] ?? "";
                if (_addressCtrl.text.isEmpty) _addressCtrl.text = info['address'] ?? "";
                if (_nationalityCtrl.text.isEmpty) _nationalityCtrl.text = info['nationality'] ?? "";
                if (_birthdateCtrl.text.isEmpty) _birthdateCtrl.text = info['birthdate'] ?? "";

                if (info['gender'] != null && ["Male", "Female", "Other"].contains(info['gender'])) {
                  _gender = info['gender'];
                }
              });
            }
          }
        }
      } catch (e) {
        print("Error fetching guest info: $e");
      }
    }

    // 🟢 2. Reveal Form
    if (mounted) {
      setState(() {
        _isLoadingData = false;
        _showForm = true; // Triggers the RevealWrappers
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: amvViolet, onPrimary: Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthdateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 14, minute: 0),
      helpText: "SELECT ARRIVAL TIME (2PM - 8PM)",
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: amvViolet, onPrimary: Colors.white),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // 🟢 Validation: Must be between 14:00 (2PM) and 20:00 (8PM)
      final int hour = picked.hour;
      if (hour < 14 || hour >= 20) {
        // Show error and don't update
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Check-in time is between 2:00 PM and 8:00 PM. Please select a valid time.",
                style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      setState(() {
        _arrivalTimeCtrl.text = picked.format(context);
      });
    }
  }

  void _onAddressChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().length > 3) {
        _searchAddress(query.trim());
      } else {
        setState(() => _addressResults = []);
      }
    });
  }

  Future<void> _searchAddress(String query) async {
    if (_addressCache.containsKey(query)) {
      setState(() {
        _addressResults = _addressCache[query]!;
        _isSearchingAddress = false;
      });
      return;
    }

    setState(() => _isSearchingAddress = true);
    try {
      final url = Uri.parse(
          "https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=5&addressdetails=1&countrycodes=ph");

      final response = await http.get(
        url,
        headers: {'User-Agent': 'AMV_Hotel_Mobile_App_v1.2'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _addressCache[query] = data;
        if (mounted) {
          setState(() {
            _addressResults = data;
            _isSearchingAddress = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isSearchingAddress = false);
    }
  }

  void _openInfoScreen(Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = const Offset(0.0, 1.0);
          var end = Offset.zero;
          var curve = Curves.fastOutSlowIn;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  void _proceedToSummary() {
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please agree to the Privacy Policy and Terms & Conditions.", style: GoogleFonts.montserrat()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          transitionDuration: const Duration(milliseconds: 600),
          reverseTransitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) {
            return BookingSummaryScreen(
              dateRange: widget.dateRange,
              selectedRooms: widget.selectedRooms,
              adults: widget.adults,
              children: widget.children,
              guestDetails: {
                'first_name': _fNameCtrl.text,
                'last_name': _lNameCtrl.text,
                'email': _emailCtrl.text,
                'phone': _phoneCtrl.text,
                'address': _addressCtrl.text,
                'requests': _requestsCtrl.text,
                'payment_term': _paymentTerm,
                'gender': _gender,
                'birthdate': _birthdateCtrl.text,
                'nationality': _nationalityCtrl.text,
                'arrival_time': _arrivalTimeCtrl.text,
                'salutation': _gender == 'Female' ? 'Ms.' : 'Mr.',
              },
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var begin = const Offset(0.0, 1.0);
            var end = Offset.zero;
            var curve = Curves.fastOutSlowIn;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(position: animation.drive(tween), child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text("Guest Details",
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: amvViolet,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // 🟢 3. CONDITIONAL BODY: Spinner OR Form
      body: _isLoadingData
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: amvGold),
                  const SizedBox(height: 20),
                  Text(
                    "Preparing form...",
                    style: GoogleFonts.montserrat(color: Colors.grey),
                  )
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // 1. Personal Information Section
                    _RevealWrapper(
                      index: 0,
                      isVisible: _showForm, // 🟢 Passes trigger to wrapper
                      child: Column(
                        children: [
                          _buildSectionHeader("Who is Checking In?", Icons.person),
                          Container(
                            decoration: _cardDecoration(),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _buildTextField("First Name", _fNameCtrl, Icons.person_outline)),
                                    const SizedBox(width: 15),
                                    Expanded(child: _buildTextField("Last Name", _lNameCtrl, Icons.person_outline)),
                                  ],
                                ),
                                const SizedBox(height: 15),
                                _buildGenderSelector(),
                                const SizedBox(height: 15),
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _selectDate(context),
                                        child: AbsorbPointer(
                                          child: _buildTextField("Birthdate", _birthdateCtrl, Icons.calendar_today),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(child: _buildTextField("Nationality", _nationalityCtrl, Icons.flag_outlined)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // 2. Contact Details Section
                    _RevealWrapper(
                      index: 1,
                      isVisible: _showForm,
                      child: Column(
                        children: [
                          _buildSectionHeader("Contact Information", Icons.contact_phone),
                          Container(
                            decoration: _cardDecoration(),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                _buildTextField("Email Address", _emailCtrl, Icons.email_outlined, isEmail: true),
                                const SizedBox(height: 15),
                                _buildTextField("Phone Number", _phoneCtrl, Icons.phone_outlined, isPhone: true),
                                const SizedBox(height: 15),
                                
                                // Address with Search
                                TextFormField(
                                  controller: _addressCtrl,
                                  onChanged: _onAddressChanged,
                                  style: GoogleFonts.montserrat(),
                                  decoration: _inputDecoration("Address", Icons.location_on_outlined).copyWith(
                                    suffixIcon: _isSearchingAddress 
                                      ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))) 
                                      : null,
                                  ),
                                  validator: (val) => (val == null || val.isEmpty) ? "Required" : null,
                                ),
                                
                                // Address Search Results
                                if (_addressResults.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(top: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.white, 
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.grey.shade200),
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]
                                    ),
                                    child: Column(
                                      children: _addressResults.map((place) => ListTile(
                                        leading: Icon(Icons.place, color: amvGold, size: 20),
                                        title: Text(place['display_name'], style: GoogleFonts.montserrat(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        onTap: () {
                                          setState(() {
                                            _addressCtrl.text = place['display_name'];
                                            _addressResults = [];
                                            _isSearchingAddress = false;
                                          });
                                        },
                                      )).toList(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // 3. Stay Preferences
                    _RevealWrapper(
                      index: 2,
                      isVisible: _showForm,
                      child: Column(
                        children: [
                          _buildSectionHeader("Stay Preferences", Icons.hotel),
                          Container(
                            decoration: _cardDecoration(),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: () => _selectTime(context),
                                  child: AbsorbPointer(
                                    child: _buildTextField("Est. Arrival Time", _arrivalTimeCtrl, Icons.access_time),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                _buildTextField("Special Requests (Optional)", _requestsCtrl, Icons.notes, maxLines: 3),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // 4. Payment Plan
                    _RevealWrapper(
                      index: 3,
                      isVisible: _showForm,
                      child: Column(
                        children: [
                          _buildSectionHeader("Payment Option", Icons.payment),
                          Row(
                            children: [
                              Expanded(child: _buildPaymentOption("Full Payment", "100%", "full")),
                              const SizedBox(width: 15),
                              Expanded(child: _buildPaymentOption("Downpayment", "50%", "partial")),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 35),

                    // 5. Terms & Button
                    _RevealWrapper(
                      index: 4,
                      isVisible: _showForm,
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 24, width: 24,
                                child: Checkbox(
                                  value: _agreedToTerms,
                                  activeColor: amvViolet,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[700], height: 1.5),
                                    children: [
                                      const TextSpan(text: "I agree to the "),
                                      TextSpan(
                                        text: "Privacy Policy",
                                        style: TextStyle(color: amvViolet, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                        recognizer: TapGestureRecognizer()..onTap = () => _openInfoScreen(const PrivacyPolicyScreen()),
                                      ),
                                      const TextSpan(text: " and "),
                                      TextSpan(
                                        text: "Terms & Conditions",
                                        style: TextStyle(color: amvViolet, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                        recognizer: TapGestureRecognizer()..onTap = () => _openInfoScreen(const TermsConditionsScreen()),
                                      ),
                                      const TextSpan(text: "."),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _proceedToSummary,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _agreedToTerms ? amvViolet : Colors.grey,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                elevation: _agreedToTerms ? 5 : 0,
                                shadowColor: amvViolet.withOpacity(0.4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              child: Text("PROCEED TO CONFIRMATION", 
                                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  // 🎨 Reusable Components

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5)),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, left: 5),
      child: Row(
        children: [
          Icon(icon, color: amvViolet, size: 20),
          const SizedBox(width: 10),
          Text(title, style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.bold, color: amvViolet)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey[600]),
      prefixIcon: Icon(icon, color: amvGold, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: amvViolet, width: 1.5)),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 15),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, IconData icon, {bool isEmail = false, bool isPhone = false, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: isEmail ? TextInputType.emailAddress : (isPhone ? TextInputType.phone : TextInputType.text),
      style: GoogleFonts.montserrat(fontSize: 14, color: Colors.black87),
      inputFormatters: isPhone ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))] : null,
      decoration: _inputDecoration(label, icon),
      validator: (val) {
        if (maxLines > 1) return null; // Optional fields
        if (val == null || val.isEmpty) return "Required";
        if (isEmail && !val.contains('@')) return "Invalid Email";
        if (isPhone) {
          if (!RegExp(r'^(09|\+639)\d{9}$').hasMatch(val)) return "Invalid format";
        }
        return null;
      },
    );
  }

  Widget _buildGenderSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: ["Male", "Female", "Other"].map((gender) {
        bool isSelected = _gender == gender;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _gender = gender),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? amvViolet : Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isSelected ? amvViolet : Colors.grey.shade300),
              ),
              child: Center(
                child: Text(
                  gender,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentOption(String title, String subtitle, String value) {
    bool isSelected = _paymentTerm == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentTerm = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.grey[50],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? amvGold : Colors.grey.shade300, width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: amvGold.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Column(
          children: [
            Text(subtitle, style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold, color: isSelected ? amvViolet : Colors.grey[800])),
            const SizedBox(height: 5),
            Text(title, style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 10),
            Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? amvGold : Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }
}

// 🟢 4. ANIMATION WRAPPER (Fixed Logic)
class _RevealWrapper extends StatefulWidget {
  final int index;
  final Widget child;
  final bool isVisible; // 🟢 Trigger

  const _RevealWrapper({required this.index, required this.child, required this.isVisible});

  @override
  State<_RevealWrapper> createState() => _RevealWrapperState();
}

class _RevealWrapperState extends State<_RevealWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    
    _offsetAnimation = Tween<Offset>(begin: const Offset(0.0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    // 🟢 FIX: Check if we should animate immediately upon creation
    if (widget.isVisible) {
      _startAnimation();
    }
  }

  @override
  void didUpdateWidget(_RevealWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 🟢 Handle updates (if it wasn't visible before, but is now)
    if (widget.isVisible && !oldWidget.isVisible) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    Future.delayed(Duration(milliseconds: widget.index * 100), () {
      if (mounted) _controller.forward();
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
      child: SlideTransition(
        position: _offsetAnimation, 
        child: widget.child
      )
    );
  }
}