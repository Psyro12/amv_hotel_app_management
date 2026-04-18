import 'dart:convert';

void main() {
  // 🟢 PASTE YOUR SHA-1 KEY INSIDE THESE QUOTES:
  String sha1 = "d9:b6:16:1c:7b:35:02:ef:82:d4:2e:25:44:ab:b3:d9:5c:a7:96:99"; 
  
  // Clean up the string
  List<int> bytes = sha1
      .replaceAll(":", "") // Remove colons
      .replaceAll(" ", "") // Remove spaces
      .split("")
      .fold<List<String>>([], (list, char) {
        if (list.isEmpty || list.last.length == 2) {
          list.add(char);
        } else {
          list.last += char;
        }
        return list;
      })
      .map((hex) => int.parse(hex, radix: 16))
      .toList();

  // Convert to Base64
  String keyHash = base64.encode(bytes);
  
  print("------------------------------------------------");
  print("YOUR FACEBOOK KEY HASH IS: $keyHash");
  print("------------------------------------------------");
}