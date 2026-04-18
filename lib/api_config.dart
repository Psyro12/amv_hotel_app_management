class ApiConfig {
  // 🟢 SET THIS TO true TO USE YOUR LAPTOP, false TO USE THE WEBSITE
  static const bool isLocal = true;

  // 🟢 YOUR LAPTOP'S IP ADDRESS (Auto-detected from ipconfig)
  static const String localIp = "10.83.159.223";

  // 🟢 PRODUCTION DOMAIN
  static const String onlineDomain = "amvhotel.online";

  // 🟢 DYNAMIC BASE URL
  static String get baseUrl {
    if (isLocal) {
      return "http://$localIp/AMV_Project_exp/API";
    } else {
      return "https://$onlineDomain/API";
    }
  }

  // 🟢 DYNAMIC ADMIN/PHP URL
  static String get adminPhpUrl {
    if (isLocal) {
      return "http://$localIp/AMV_Project_exp/ADMIN/PHP";
    } else {
      return "https://$onlineDomain/ADMIN/PHP";
    }
  }

  // 🟢 IMAGE PATHS
  static String get foodImageUrl => "http://$localIp/AMV_Project_exp/room_includes/uploads/food/";
  static String get newsImageUrl => "http://$localIp/AMV_Project_exp/room_includes/uploads/news/";
  static String get eventImageUrl => "http://$localIp/AMV_Project_exp/room_includes/uploads/events/";
  static String get roomImageUrl => "http://$localIp/AMV_Project_exp/room_includes/uploads/images/";
}
