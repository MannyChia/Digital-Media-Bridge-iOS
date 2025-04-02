///
///
///
/// *************************************************
/// *** LIST OF AVAILABLE DMB PLAYERS
/// *************************************************
///
import './main.dart';
import './screens_page.dart';
import './dmb_functions.dart';
import 'package:flutter/material.dart';
/*
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
///
dynamic _pageTitle = "DMB Media Players";
dynamic _pageSubTitle = "Select Player";
*/

dynamic activeDMBPlayers = 0;

//Create custom class to hold the media player data
class MediaPlayer{ //modal class for MediaPlayer object
  String name, status, currentScreen;
  MediaPlayer({required this.name, required this.status, required this.currentScreen});
}

//Add necessary public vars
List<MediaPlayer> dmbMediaPlayers = [];
dynamic selectedPlayerName;

//This var is used to determine whether we should show a 'refresh'
//or a 'back' button when showing the user a list of DMB Media Players
bool playersNoBackButton = true;

///
class PlayersPage extends StatefulWidget {
  //const PlayersPage({super.key, required this.pageTitle, required this.pageSubTitle});
  const PlayersPage({super.key, this.pageTitle, this.pageSubTitle});

  final String? pageTitle;
  final String? pageSubTitle;

  @override
  _PlayersPageState createState() => _PlayersPageState();
}

class _PlayersPageState extends State<PlayersPage> {

  ///This 'override' function is called once when the class is loaded
  ///(is used to update the pageTitle * subTitle)
  @override
  void initState() {
    super.initState();
    _updateTitle();
  }

  void _updateTitle() {

    setState(() {
      print("Set State .... anew");
      //pageTitle = "${widget.pageTitle} (${dmbMediaPlayers.length}), $activeDMBPlayers Active";
      pageTitle = "${widget.pageTitle} (${dmbMediaPlayers.length})";
      pageSubTitle = widget.pageSubTitle;
    });
  }

  //As the list of players is being build, this function will determine
  //whether we show a 'regular' color button or a 'red' one because
  //the status of the player is inactive
  _checkPlayerStatus(index){

    var pStatus = dmbMediaPlayers[index].status;
    return pStatus == "Active" ? true : false;
  }

  //In each view, provide a button to let the user logout
  void _userLogout() {

    confirmLogout(context);  //*** CONFIRM USER LOGOUT (function is in: dmb_functions.dart)
  }

  //Called this when the user pulls down the screen
  Future<void> _refreshData() async {

    try {
      //Go to the DMB server to get an updated list of players
      getUserData("billstanton@gmail.com", "abc123", "players-refresh").then((result){

        //*** If the return value is a string, then there was an error
        // getting the data, so don't do anything.
        // Otherwise, should be Ok to set the
        // dmbMediaPlayers var with the new data
        if(result.runtimeType != String){
          setState(() {
            dmbMediaPlayers = result;
          });
        }
      });
    } catch (err) {
      //error
    }

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      // **********
      /* THE HEADER OF THE 'PLAYERS' PAGE */
      // **********
      appBar: playersNoBackButton ? _appBarNoBackBtn(context) : _appBarBackBtn(context),
      body:
        //RefreshIndicator(
        //onRefresh: _refreshData,     ///*** // trigger the _refreshData function when the user pulls down

         ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: dmbMediaPlayers.length,
          //physics: const AlwaysScrollableScrollPhysics(),
          itemBuilder: (BuildContext context, int index) {

            return InkWell(

              onLongPress: (){   //*** When one of the DMB Media Players is selected

                ///set the global variable of the selected player
                //selectedPlayerName = dmbMediaPlayers[index].name;

                ///show the user (in a small pop-up) the player name
                ///that they just selected
                //ScaffoldMessenger.of(context).showSnackBar(
                  //SnackBar(content: Text("${dmbMediaPlayers[index].name} Selected")),
                //);





                print("NEW METHOD FOR NAVIGATING #3 - GO TO SCREENS");

                //masterNavigatorKey.currentState?.pushNamed("/screens");

                ///Go to the 'Screens' page so the user can select
                ///
                /*
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ScreensPage(
                          //pageTitle: "Player: $selectedPlayerName",
                          pageTitle: "Steve",
                          pageSubTitle: "Select Screen to Publish"
                      )),
                ).then(  ///*** WHEN THE USER RETURNS TO THE PLAYERS SCREEN VIA 'BACK' BTN
                     (context){
                        print("BACK FROM SCREENS PAGE!!!!!");

                    }
                );
                */

                 */
                /**
                 *
                 * Navigator.push(
                    context,
                    MaterialPageRoute(
                    builder: (context) =>
                    ScreensPage(
                    pageTitle: "Screens (${dmbScreens.length})",
                    pageSubTitle: selectedPlayerName != null ? _PlayerSelectedText() : _PlayerNotSelectedText()
                    )),
                    )
                 *
                 **/

              },
              customBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Ink(
                height: 75, width: 100,
                //child: Center(child: Text(dmbMediaPlayers[index])),
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  border: Border.all(
                      width: 1, //
                      //color: const Color.fromRGBO(10, 85, 163, 1.0)
                      color: Colors.blueGrey
                  ),
                  borderRadius:const BorderRadius.all(Radius.circular(8.0)),
                  gradient: _checkPlayerStatus(index) ? _gradientActiveMediaPlayer(context) : _gradientInActiveMediaPlayer(context),
                  /*
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topCenter,
                    end: AlignmentDirectional.bottomCenter,
                    colors: [
                      Colors.blueGrey,
                      //Color.fromRGBO(10, 85, 163, 1.0),
                      Colors.red,
                    ],
                  ),
                  */

                ),

                ///The two line text on each button
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(dmbMediaPlayers[index].name,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color:Colors.white)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            _checkPlayerStatus(index) ? _activeScreenText(context, index) : _inActiveScreenText(context, index),
                        ],
                      ),
                    ],
                  ),

                ),


              ),
            );
          },
          separatorBuilder: (context, index) => const Divider(  ///the divider between the items
            color: Colors.blueGrey,
          ),
      ),





      //),
      floatingActionButton: FloatingActionButton(
        onPressed: _userLogout,
        tooltip: 'Logout',
        child: const Icon(Icons.logout),
      ),
    );

  }
}

///**** This is the 'App bar' to the players tab when you don't want
/// to show a 'back' btn
PreferredSizeWidget _appBarNoBackBtn(BuildContext context){

  return AppBar(
    flexibleSpace: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: <Color>[Colors.black87, Color.fromRGBO(10, 85, 163, 1.0)]),  //DMB BLUE
      ),
    ),
    automaticallyImplyLeading: false,
    // Here we take the value from the MyHomePage object that was created by
    // the App.build method, and use it to set our appbar title.
    title: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(pageTitle,
                style: const TextStyle(fontWeight: FontWeight.bold,
                    color:Colors.white,
                    fontSize: 16)),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(pageSubTitle,
                style: const TextStyle(fontStyle: FontStyle.italic,
                    color:Colors.white70,
                    fontSize: 14)),
          ],
        ),
      ],
    ),
  );
}

///**** This is the 'App bar' to the players tab when you want to show a
/// back icon and let the user return to the previous page
PreferredSizeWidget _appBarBackBtn(BuildContext context){

  void _goBack(){  //when the back arrow is selected

    Navigator.of(context).pop();  //just remove this layer to return to the previous screen
  }

  return AppBar(
    leading: IconButton(
      icon: Icon(Icons.arrow_back, color: Colors.white),
      onPressed: _goBack,
    ),
    flexibleSpace: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: <Color>[Colors.black87, Color.fromRGBO(10, 85, 163, 1.0)]),  //DMB BLUE
      ),
    ),
    automaticallyImplyLeading: true,
    // Here we take the value from the MyHomePage object that was created by
    // the App.build method, and use it to set our appbar title.
    title: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(pageTitle,
                style: const TextStyle(fontWeight: FontWeight.bold,
                    color:Colors.white,
                    fontSize: 16)),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(pageSubTitle,
                style: const TextStyle(fontStyle: FontStyle.italic,
                    color:Colors.white70,
                    fontSize: 14)),
          ],
        ),
      ],
    ),
  );

}

///**** As the list is being displayed use this object to show a
/// player whose status is 'active'
LinearGradient _gradientActiveMediaPlayer(BuildContext context){

  return const LinearGradient(
    begin: AlignmentDirectional.topCenter,
    end: AlignmentDirectional.bottomCenter,
    colors: [
      Colors.blueGrey,
      Color.fromRGBO(10, 85, 163, 1.0),
    ],
  );

}

///**** As the list is being displayed use this object to show a
/// player whose status is 'inactive'
LinearGradient _gradientInActiveMediaPlayer(BuildContext context){

  return const LinearGradient(
    begin: AlignmentDirectional.topCenter,
    end: AlignmentDirectional.bottomCenter,
    colors: [
      Colors.red,
      Colors.blueGrey,
    ],
  );

}

///*** As the list is being displayed, show a (slightly) different
/// text (label) to the user for players that are active vs. inactive
Text _activeScreenText(BuildContext context, pIndex){

  return Text("Status: ${dmbMediaPlayers[pIndex]
      .status} - Current Screen: ${dmbMediaPlayers[pIndex]
      .currentScreen}",
      style: const TextStyle(
          fontSize: 10,
          fontStyle: FontStyle.italic,
          color: Colors.white70));
}

Text _inActiveScreenText(BuildContext context, pIndex){

  return Text("Status: ${dmbMediaPlayers[pIndex]
      .status} - Last Screen: ${dmbMediaPlayers[pIndex]
      .currentScreen}",
      style: const TextStyle(
          fontSize: 10,
          fontStyle: FontStyle.italic,
          color: Colors.white70));
}


