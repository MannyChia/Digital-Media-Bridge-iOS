///
///
/// *************************************************
/// *** LIST OF AVAILABLE DMB SCREENS
/// *************************************************
///
import './main.dart';
import './players_page.dart';
import './dmb_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


//Create custom class to hold the dmb screens data
class DmbScreen{ //modal class for DmbScreen object
  String name;
  DmbScreen({required this.name});
}

//Add necessary public vars
//Global var to hold the list of account screens
List<DmbScreen> dmbScreens = [];
final List<int> colorCodesScreens = <int>[400,200,900];

class ScreensPage extends StatefulWidget {
  const ScreensPage({super.key, required this.screensPageTitle, required this.screensPageSubTitle});

  final String screensPageTitle;
  final String screensPageSubTitle;

  @override
  _ScreensPageState createState() => _ScreensPageState();
}

class _ScreensPageState extends State<ScreensPage> {
  late String screensPageTitle;
  late String screensPageSubTitle;

  String backgroundURL = dotenv.env['BACKGROUND_IMAGE_URL']!;

  ///This 'override' function is called once when the class is loaded
  ///(is used to update the pageTitle * subTitle)
  @override
  void initState() {
    super.initState();
    screensPageTitle = widget.screensPageTitle;
    screensPageSubTitle = widget.screensPageSubTitle;
  }


  @override
  Widget build(BuildContext context) {
    // Calculate viewport units
    final double vw = MediaQuery.of(context).size.width / 100;
    final double vh = MediaQuery.of(context).size.height / 100;

    return Scaffold(
      extendBodyBehindAppBar: true,  // allow body under AppBar
      // **********
      /* THE TITLE OF THE 'SCREENS' PAGE */
      // **********
      //   appBar: AppBar(
      //     iconTheme: const IconThemeData(
      //       color: Colors.white, //change your color here
      //     ),
      //     // TRY THIS: Try changing the color here to a specific color (to
      //     // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
      //     // change color while the other colors stay the same.
      //     flexibleSpace: Container(
      //       decoration: const BoxDecoration(
      //         gradient: LinearGradient(
      //             begin: Alignment.centerLeft,
      //             end: Alignment.centerRight,
      //             colors: <Color>[Colors.black87, Color.fromRGBO(10, 85, 163, 1.0)]),  //DMB BLUE
      //       ),
      //     ),
      //     // Here we take the value from the MyHomePage object that was created by
      //     // the App.build method, and use it to set our appbar title.
      //     title: Column(
      //       mainAxisAlignment: MainAxisAlignment.start,
      //       children: [
      //         Row(
      //           mainAxisAlignment: MainAxisAlignment.start,
      //           children: [
      //             Text(pageTitle,
      //                 style: const TextStyle(fontWeight: FontWeight.bold,
      //                     color:Colors.white,
      //                     fontSize: 20)),
      //           ],
      //         ),
      //         Row(
      //           mainAxisAlignment: MainAxisAlignment.start,
      //           children: [
      //             Text(pageSubTitle,
      //                 style: const TextStyle(fontStyle: FontStyle.italic,
      //                     color:Colors.white70,
      //                     fontSize: 17)),
      //           ],
      //         ),
      //       ],
      //     ),
      //   ),
      appBar: _appBarBackBtn(context, screensPageTitle, screensPageSubTitle),
      body: Stack(
        children: [
          // background image
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(backgroundURL),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // list of screens
          Padding(
            padding: EdgeInsets.only(top: vh * 16), // prevents overlap with appBar
              child: ListView.separated(
                padding: EdgeInsets.only(top: vh * 2, bottom: vh * 2, left: vw * 3, right: vw * 3),
                itemCount: dmbScreens.length,
                itemBuilder: (BuildContext context, int index) {
                  return InkWell(
                      onTap: (){   /// *** WHEN A SCREEN IS CLICKED
                        ///*** ONLY IF THE USER IS COMING FROM THE 'PLAYERS' PAGE:
                        ///show a pop-up window and ask the user to confirm publish
                        ///(function is in dmb_functions.dart)
                        if(selectedPlayerName != null) {
                          confirmPublish(
                              context, selectedPlayerName, dmbScreens[index].name);
                        }
                        else{  //NO MEDIA PLAYER SELECTED
                          ///show the user (in a small pop-up) informing
                          ///them that they don't have a player selected
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Select Media Player First")),
                          );
                        }
                      },
                      splashColor: Colors.yellow,
                      highlightColor: Colors.blue,
                      customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: Ink(
                          decoration: BoxDecoration(
                            color: Colors.lightGreen.withOpacity(0.65), // background for screens buttons
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.2), // White shadow with opacity
                                spreadRadius: 6, // How far the shadow spreads
                                blurRadius: 6, // How blurry the shadow is
                              ),
                            ],
                          ),
                          height: 75,
                          width: double.infinity,
                          child: Center(
                            child: Text(
                              dmbScreens[index].name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                  );
                },
                separatorBuilder: (context, index) => const Divider( // makes the divider between the items invisible
                  color: Colors.transparent,
                ),
              )
          )
        ]
      ),
    );
  }
}

/// app bar with back button
PreferredSizeWidget _appBarBackBtn(BuildContext context, String title, String subTitle) {
  // Calculate viewport units
  final double vw = MediaQuery.of(context).size.width / 100;
  final double vh = MediaQuery.of(context).size.height / 100;

  return PreferredSize(
    preferredSize: Size.fromHeight(vh * 11), // 11% of screen height
    child: AppBar(
      iconTheme: const IconThemeData(
        color: Colors.white, //change your color here
      ),
      backgroundColor: Colors.black.withOpacity(0.8), // app bar background
      automaticallyImplyLeading: true, // show back button
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: vw * 6, // Increase font size to 6% of smaller dimension
            ),
          ),
          Text(
            subTitle,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.white,
              fontSize: vw * 5.5, // Increase font size to 5% of smaller dimension
            ),
          ),
        ],
      ),
      titleSpacing: vw * 4, // Add padding to the left of the title (4% of screen width)
      toolbarHeight: vh * 12, // Match toolbarHeight to preferredSize height
      // BELOW SHOWS THE HAMBURGER MENU (UNNECESSARY HERE)
      // actions: [
      //   Builder(
      //     builder: (context) => IconButton(
      //       icon: Icon(
      //         Icons.menu,
      //         color: Colors.white,
      //         size: vw * 8, // Increase icon size to 8% of smaller dimension
      //       ),
      //       onPressed: () => Scaffold.of(context).openEndDrawer(),
      //       padding: EdgeInsets.all(vw * 2), // Add padding around icon
      //     ),
      //   ),
      // ],
    ),
  );
}

