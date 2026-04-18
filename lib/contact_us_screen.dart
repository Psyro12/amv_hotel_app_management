import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'api_config.dart';
import 'notification_button.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({Key? key}) : super(key: key);

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  List<dynamic> _messages = [];
  bool _isLoading = true;

  String _dbEmail = "";
  String _dbSource = "";

  final Color amvViolet = const Color(0xFF2D0F35);
  final Color amvGold = const Color(0xFFD4AF37);

  @override
  void initState() {
    super.initState();
    _fetchUserDataFromMySQL();
  }

  Future<void> _fetchUserDataFromMySQL() async {
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/api_get_user_email.php");
      final response = await http.post(url, body: {"uid": user!.uid});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _dbEmail = data['email'];
            _dbSource = data['source'] ?? 'email';
          });
          _fetchMessages();
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error connecting to DB: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMessages() async {
    if (_dbEmail.isEmpty) return;

    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/api_get_messages.php");
      final response = await http.post(
        url,
        body: {"email": _dbEmail, "source": _dbSource},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _messages = data['data'];
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print("Fetch Error: $e");
      setState(() => _isLoading = false);
    }
  }

  // Helper to send a new message
  Future<void> _sendMessageToApi(String text, VoidCallback onSuccess) async {
    if (text.trim().isEmpty) return;
    if (_dbEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: No verified email found.")),
      );
      return;
    }

    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/api_contact_us.php");
      final response = await http.post(
        url,
        body: {
          "name": user?.displayName ?? "Guest",
          "email": _dbEmail,
          "message": text.trim(),
          "source": _dbSource,
        },
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        onSuccess();
        _fetchMessages(); // Refresh list
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Message sent successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // 🟢 Show the specific error from the API (e.g., "Daily limit reached")
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Failed to send message."),
            backgroundColor: Colors.redAccent,
          ),
        );
        // Call onSuccess to close the dialog or just let them try again? 
        // Usually, for errors like "Limit reached", we close the dialog.
        if (data['message'].toString().contains("limit")) {
          onSuccess(); 
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // 🟢 UPDATED: Smooth Custom Slide-Up for Compose Modal
  void _showComposeDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 600), // 🟢 1. Slower duration
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // 🟢 2. Premium Curve: fastOutSlowIn
        var curve = Curves.fastOutSlowIn;
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: curve)),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              // 🟢 3. Manually handle keyboard padding since we replaced ModalBottomSheet
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 25,
                right: 25,
                top: 10,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    _ComposeMessageForm(
                      onSendPressed: (text) async {
                        await _sendMessageToApi(text, () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Read-Only Message Details Modal
  void _showMessageDetails(Map<String, dynamic> msg) {
    String date = msg['created_at'];
    try {
      DateTime dt = DateTime.parse(msg['created_at']);
      date = DateFormat('MMMM dd, yyyy • h:mm a').format(dt);
    } catch (e) {}

    bool isRead = (msg['is_read'] == 1 || msg['is_read'] == '1');
    String statusText = isRead ? "READ" : "SENT";
    
    // Gold for Read, Orange for Sent
    Color statusColor = isRead ? amvGold : Colors.orange;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 500),
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            color: Colors.white,
            child: Container(
              width: double.infinity,
              height: 500,
              padding: const EdgeInsets.fromLTRB(25, 10, 25, 25),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Drag Handle
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 25),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),

                  // 2. Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Message Details",
                            style: GoogleFonts.montserrat(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: amvViolet,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            date,
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withOpacity(0.5), width: 1),
                        ),
                        child: Text(
                          statusText,
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),
                  const Divider(),
                  const SizedBox(height: 20),

                  // 3. Message Content
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "YOUR MESSAGE",
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[400],
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Color(0xFFF9F9F9),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Text(
                              msg['message'],
                              style: GoogleFonts.montserrat(
                                fontSize: 15,
                                height: 1.6,
                                color: Colors.black87,
                              ),
                            ),
                          ),

                          if (msg['reply'] != null && msg['reply'].toString().isNotEmpty) ...[
                            const SizedBox(height: 25),
                            Row(
                              children: [
                                Icon(Icons.support_agent, size: 16, color: amvGold),
                                const SizedBox(width: 8),
                                Text(
                                  "ADMIN RESPONSE",
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: amvGold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: amvGold.withOpacity(0.3)),
                                boxShadow: [
                                  BoxShadow(
                                    color: amvGold.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Text(
                                msg['reply'],
                                style: GoogleFonts.montserrat(
                                  fontSize: 15,
                                  height: 1.6,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 4. Close Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: amvViolet,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "CLOSE",
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "My Messages",
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: amvViolet,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          NotificationButton(backgroundColor: Colors.transparent),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: amvGold))
          : _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        child: Icon(Icons.mail_outline,
                            size: 60, color: Colors.grey[300]),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "No messages yet",
                        style: GoogleFonts.montserrat(
                          color: Colors.grey,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchMessages,
                  color: amvGold,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 20,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return MessageRevealWrapper(
                        index: index,
                        child: _buildMessageCard(msg),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showComposeDialog,
        backgroundColor: amvViolet,
        icon: const Icon(Icons.edit, color: Colors.white),
        label: Text(
          "Compose",
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Card Item in the Main List
  Widget _buildMessageCard(dynamic msg) {
    String date = msg['created_at'];
    try {
      DateTime dt = DateTime.parse(msg['created_at']);
      date = DateFormat('MMM d').format(dt);
    } catch (e) {}

    bool isRead = (msg['is_read'] == 1 || msg['is_read'] == '1');
    bool hasReply = (msg['reply'] != null && msg['reply'].toString().trim().isNotEmpty);

    return GestureDetector(
      onTap: () => _showMessageDetails(msg),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: hasReply ? Border.all(color: amvGold, width: 1.5) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isRead ? amvGold.withOpacity(0.1) : amvViolet.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRead ? Icons.mark_email_read : Icons.forward_to_inbox,
                  size: 20,
                  color: isRead ? amvGold : amvViolet,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Sent to Admin",
                          style: GoogleFonts.montserrat(
                            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        Text(
                          date,
                          style: GoogleFonts.montserrat(
                            fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      msg['message'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                        fontSize: 14, height: 1.4, color: Colors.grey[600]),
                    ),
                    if (hasReply) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.subdirectory_arrow_right, size: 14, color: amvGold),
                          const SizedBox(width: 5),
                          Text(
                            "View Response",
                            style: GoogleFonts.montserrat(
                              fontSize: 11, fontWeight: FontWeight.bold, color: amvGold),
                          ),
                        ],
                      )
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 🟢 NEW ENGAGING COMPOSE FORM
class _ComposeMessageForm extends StatefulWidget {
  final Function(String) onSendPressed;

  const _ComposeMessageForm({Key? key, required this.onSendPressed}) : super(key: key);

  @override
  State<_ComposeMessageForm> createState() => _ComposeMessageFormState();
}

class _ComposeMessageFormState extends State<_ComposeMessageForm> {
  final TextEditingController _msgController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _sending = false;
  bool _isFocused = false;
  
  // Quick Topics
  String _selectedTopic = "General";
  final List<String> _topics = ["General", "Room Service", "Housekeeping", "Feedback"];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _msgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color amvViolet = const Color(0xFF2D0F35);
    Color amvGold = const Color(0xFFD4AF37);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Engaging Header
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: amvViolet.withOpacity(0.1),
              child: Icon(Icons.support_agent, color: amvViolet, size: 22),
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "How can we help?",
                  style: GoogleFonts.montserrat(
                    fontSize: 18, fontWeight: FontWeight.bold, color: amvViolet),
                ),
                Text(
                  "We usually reply within minutes",
                  style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        
        const SizedBox(height: 25),

        // 2. Topic Chips (Quick Selection)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _topics.map((topic) {
              bool isSelected = _selectedTopic == topic;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(topic),
                  labelStyle: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                  selected: isSelected,
                  selectedColor: amvViolet,
                  backgroundColor: Colors.grey[100],
                  onSelected: (bool selected) {
                    setState(() {
                      _selectedTopic = topic;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 15),

        // 3. Animated Text Field
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _isFocused ? Colors.white : Colors.grey[50],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: _isFocused ? amvGold : Colors.grey[200]!,
              width: _isFocused ? 1.5 : 1,
            ),
            boxShadow: _isFocused 
              ? [BoxShadow(color: amvGold.withOpacity(0.2), blurRadius: 8, offset: Offset(0, 3))] 
              : [],
          ),
          child: TextField(
            controller: _msgController,
            focusNode: _focusNode,
            maxLines: 5,
            style: GoogleFonts.montserrat(fontSize: 15, color: Colors.black87),
            decoration: InputDecoration(
              hintText: "Tell us more about your request...",
              hintStyle: GoogleFonts.montserrat(color: Colors.grey[400]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
        ),
        
        const SizedBox(height: 25),
        
        // 4. Send Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _sending
                ? null
                : () async {
                    if (_msgController.text.trim().isNotEmpty) {
                      setState(() => _sending = true);
                      // Prepend topic context for the admin
                      String fullMessage = "[$_selectedTopic] ${_msgController.text.trim()}";
                      await widget.onSendPressed(fullMessage);
                      if (mounted) setState(() => _sending = false);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: amvViolet,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 5,
              shadowColor: amvViolet.withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: _sending
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        "SEND REQUEST",
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14, letterSpacing: 1),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class MessageRevealWrapper extends StatefulWidget {
  final int index;
  final Widget child;

  const MessageRevealWrapper({Key? key, required this.index, required this.child}) : super(key: key);

  @override
  State<MessageRevealWrapper> createState() => _MessageRevealWrapperState();
}

class _MessageRevealWrapperState extends State<MessageRevealWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
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
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}