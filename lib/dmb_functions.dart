import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import './main.dart';
import './players_page.dart';
import './screens_page.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import '/Models/playlist_preview.dart';

List<PlaylistPreview> cachedPlaylistPreviews = [];
bool hasLoadedPlaylistPreviews = false;

Future<List<PlaylistPreview>> fetchPlaylistPreviews(String userEmail) async {
  final metaResp = await http.get(Uri.parse(
      'https://digitalmediabridge.tv/screenbuilder-server/api/GetPlaylist/$userEmail'));
  if (metaResp.statusCode != 200) {
    throw Exception('Failed to load playlist metadata');
  }
  final Map<String, dynamic> meta = jsonDecode(metaResp.body);
  final List<dynamic> screens = meta['data'] as List<dynamic>;
  final List<PlaylistPreview> previews = [];
  for (final screenEntry in screens) {
    final screenName = screenEntry['screenName'] as String;
    final playlistFiles = screenEntry['playLists'] as List<dynamic>;
    for (final rawName in playlistFiles) {
      final fileName = rawName as String;
      final encodedScreen = Uri.encodeComponent(screenName);
      final plUrl =
          'https://digitalmediabridge.tv/screen-builder/assets/content/${Uri.encodeComponent(userEmail)}/others/$encodedScreen/$fileName';
      final plResp = await http.get(Uri.parse(plUrl));
      if (plResp.statusCode != 200) continue;
      final lines = LineSplitter()
          .convert(plResp.body)
          .where((l) => l.trim().isNotEmpty)
          .toList();
      final String? previewUrl = lines.isNotEmpty
          ? 'https://digitalmediabridge.tv/screen-builder/assets/content/${Uri.encodeComponent(userEmail)}/images/${Uri.encodeComponent(lines.first.split(",").first)}'
          : null;
      previews.add(PlaylistPreview(
        screenName: screenName,
        name: fileName,
        previewImageUrl: previewUrl,
        itemCount: lines.length,
      ));
    }
  }
  return previews;
}

Future<void> preloadPlaylistPreviews(String userEmail) async {
  if (!hasLoadedPlaylistPreviews) {
    cachedPlaylistPreviews = await fetchPlaylistPreviews(userEmail);
    hasLoadedPlaylistPreviews = true;
  }
}

Future<List<String>> fetchAllUserImages(String userEmail) async {
  final url =
      'https://digitalmediabridge.tv/screen-builder/assets/api/get_images.php?email=$userEmail';
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    final List<dynamic> data = jsonDecode(response.body);
    return List<String>.from(data);
  } else {
    throw Exception('Failed to fetch user image filenames');
  }
}

Future<Map<String, dynamic>> uploadImage(
    File imageFile, String username) async {
  var uri = Uri.parse(
      'https://digitalmediabridge.tv/screenbuilder-server/api/upload');
  var request = http.MultipartRequest('POST', uri)
    ..fields['filetype'] = 'images'
    ..fields['username'] = username
    ..files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: MediaType('image', 'jpeg'),
      ),
    );
  try {
    var response = await request.send();
    final responseBody = await response.stream.bytesToString();
    final decoded = json.decode(responseBody);
    if (kDebugMode) {
      print("Server Response Body: $decoded");
    }
    if (response.statusCode == 200 && decoded['status'] == 'success') {
      return {'success': true, 'message': 'Image uploaded successfully'};
    } else {
      return {
        'success': false,
        'message': decoded['message'] ?? 'Unknown error occurred'
      };
    }
  } catch (e) {
    if (kDebugMode) {
      print("Upload exception: $e");
    }
    return {'success': false, 'message': 'Upload failed with exception'};
  }
}

Future<bool> updatePlaylist({
  required String userEmail,
  required String playlistFileName,
  required List<String> selectedFilenames,
}) async {
  final url = Uri.parse(
      'https://digitalmediabridge.tv/screenbuilder-server/api/file/updateplaylist');
  final body = jsonEncode({
    "userName": userEmail,
    "fileName": playlistFileName,
    "images": selectedFilenames,
  });
  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    final decoded = json.decode(response.body);
    if (kDebugMode) {
      print("Server status: ${response.statusCode}");
    }
    if (kDebugMode) {
      print("Server response: $decoded");
    }
    return response.statusCode == 200 && decoded['status'] == 'success';
  } catch (e) {
    if (kDebugMode) {
      print("Update playlist exception: $e");
    }
    return false;
  }
}

getUserData(String username, String password, String requestType) async {
  final response = await http.post(
    Uri.parse(
        'https://digitalmediabridge.tv/ScreenBuilder-Server/api/Resource/GetUserResources'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(
        <String, String>{'UserName': username, 'Password': password}),
  );
  if (response.statusCode == 200) {
    Map<String, dynamic> myData = json.decode(response.body);
    if (myData["status"] == "error") {
      return "invalid_login";
    }
    List<dynamic> screenInfo = myData["data"]["screens"];
    if (screenInfo.isEmpty) {
      return "no_screens";
    }
    dmbMediaPlayers = [];
    dmbScreens = [];
    activeDMBPlayers = 0;
    List<dynamic> playerInfo = myData["data"]["players"];
    if (playerInfo.isEmpty) {
      return "no_players";
    }
    for (var player in playerInfo) {
      var dPlayerName = player["playerName"];
      var dPlayerStatus = player["status"];
      var dPlayerCurrentScreen = player["currentScreen"];
      if (dPlayerCurrentScreen.length > 13) {
        dPlayerCurrentScreen = dPlayerCurrentScreen.substring(0, 12) + "...";
      }
      if (dPlayerStatus == "Active") {
        activeDMBPlayers++;
      }
      dmbMediaPlayers.add(MediaPlayer(
          name: "$dPlayerName",
          status: "$dPlayerStatus",
          currentScreen: "$dPlayerCurrentScreen"));
    }
    for (var screen in screenInfo) {
      var dScreenName = screen["screenName"];
      dmbScreens.add(DmbScreen(name: "$dScreenName"));
    }

    if (requestType == "user-login" || requestType == "bypass-login") {
      return true;
    } else if (requestType == "players-refresh") {
      return dmbMediaPlayers;
    }
  } else {
    return false;
  }
}

confirmPublish(BuildContext context, String playerName, String screenName) {
  final double vw = MediaQuery.of(context).size.width / 100;
  final double vh = MediaQuery.of(context).size.height / 100;

  Widget cancelButton = OutlinedButton(
    child: Text(
      "CANCEL",
      style: TextStyle(
          color: Colors.white, fontWeight: FontWeight.bold, fontSize: vw * 4),
    ),
    onPressed: () {
      Navigator.of(context).pop();
    },
  );
  Widget continueButton = OutlinedButton(
    child: Text(
      "PUBLISH",
      style: TextStyle(
          color: Colors.white, fontWeight: FontWeight.bold, fontSize: vw * 4),
    ),
    onPressed: () {
      Navigator.of(context).pop();
      publishScreen(loginUsername, playerName, screenName).then((result) {
        if (result) {
          publishSuccess(context);
        }
      });
    },
  );
  showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Center(
              child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      "CONFIRM PUBLISH",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: vw * 7,
                      ),
                    ),
                    SizedBox(height: vh * 2),
                    Text(
                      "Do you want to play screen '$screenName' on player $playerName?",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.normal,
                        fontSize: vw * 4,
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        cancelButton,
                        SizedBox(width: 10),
                        continueButton,
                      ],
                    ),
                  ]))),
        );
      });
}

publishScreen(String userName, String playerName, String screenName) async {
  var publishData = {
    "UserName": userName,
    "screenName": screenName,
    "players": [playerName]
  };
  final response = await http.post(
    Uri.parse(
        'https://digitalmediabridge.tv/ScreenBuilder-Server/api/screen/publishToPlayers'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(publishData),
  );
  if (response.statusCode == 200) {
    return true;
  } else {
    return false;
  }
}

publishSuccess(BuildContext context) {
  final double vw = MediaQuery.of(context).size.width / 100;
  final double vh = MediaQuery.of(context).size.height / 100;

  Widget okButton = OutlinedButton(
    child: Text(
      "OK",
      style: TextStyle(
          color: Colors.white, fontWeight: FontWeight.bold, fontSize: vw * 4),
    ),
    onPressed: () {
      Navigator.of(context).pop();
    },
  );

  showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Center(
              child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.green,
                      width: 5,
                    ),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      "PUBLISH SUCCESS",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: vw * 7,
                      ),
                    ),
                    SizedBox(height: vh * 2),
                    Text(
                      "Note: It may take up to 30 seconds for the screen change to take effect",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.normal,
                        fontSize: vw * 4,
                      ),
                    ),
                    SizedBox(height: 20),
                    okButton,
                  ]))),
        );
      });
}

void _deleteStorage() async {
  await systemStorage.deleteAll();
}

confirmLogout(BuildContext context) {
  final double vw = MediaQuery.of(context).size.width / 100;
  final double vh = MediaQuery.of(context).size.height / 100;

  Widget cancelButton = OutlinedButton(
    child: const Text(
      "CANCEL",
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
    onPressed: () {
      Navigator.of(context).pop();
    },
  );
  Widget continueButton = OutlinedButton(
    child: const Text(
      "LOGOUT",
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
    onPressed: () {
      Navigator.of(context).pop();
      _deleteStorage();
      loginUsername = "none";
      loginPassword = "none";
      selectedIndex = 0;
      dmbMediaPlayers = [];
      dmbScreens = [];
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
    },
  );
  AlertDialog alert = AlertDialog(
    backgroundColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
    contentPadding: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    content: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "CONFIRM LOGOUT",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: vw * 7,
            ),
          ),
          SizedBox(height: vh * 2),
          Text(
            "Do you want to log out of the DMB App?",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.normal,
              fontSize: vw * 4,
            ),
          ),
          SizedBox(height: vh * 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              cancelButton,
              const SizedBox(width: 10),
              continueButton,
            ],
          ),
        ],
      ),
    ),
  );
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
    barrierDismissible: true,
    barrierColor: Colors.black54,
  );
}