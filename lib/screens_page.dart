import './players_page.dart';
import './dmb_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DmbScreen {
  String name;
  DmbScreen({required this.name});
}

List<DmbScreen> dmbScreens = [];
final List<int> colorCodesScreens = <int>[400, 200, 900];

class ScreensPage extends StatefulWidget {
  const ScreensPage(
      {super.key,
      required this.screensPageTitle,
      required this.screensPageSubTitle});

  final String screensPageTitle;
  final String screensPageSubTitle;

  @override
  _ScreensPageState createState() => _ScreensPageState();
}

class _ScreensPageState extends State<ScreensPage> {
  late String screensPageTitle;
  late String screensPageSubTitle;
  String backgroundURL = dotenv.env['BACKGROUND_IMAGE_URL']!;

  @override
  void initState() {
    super.initState();
    screensPageTitle = widget.screensPageTitle;
    screensPageSubTitle = widget.screensPageSubTitle;
  }

  @override
  Widget build(BuildContext context) {
    final double vw = MediaQuery.of(context).size.width / 100;
    final double vh = MediaQuery.of(context).size.height / 100;
    final lightGreyTheme = dotenv.env['LIGHT_GREY_THEME'];
    final int colorNum = int.parse(lightGreyTheme!, radix: 16);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _appBarBackBtn(context, screensPageTitle, screensPageSubTitle),
      body: Stack(children: [
        Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(backgroundURL),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Padding(
            padding: EdgeInsets.only(top: vh * 16),
            child: ListView.separated(
              padding: EdgeInsets.only(
                  top: vh * 2, bottom: vh * 2, left: vw * 3, right: vw * 3),
              itemCount: dmbScreens.length,
              itemBuilder: (BuildContext context, int index) {
                return InkWell(
                  onTap: () {
                    if (screensPageTitle != "Available Screens") {
                      if (selectedPlayerName != null) {
                        confirmPublish(context, selectedPlayerName,
                            dmbScreens[index].name);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Select a Player First",
                                style: TextStyle(fontSize: 20)),
                            backgroundColor: Colors.redAccent,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Select a Player First",
                              style: TextStyle(fontSize: 20)),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  },
                  customBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Ink(
                      decoration: BoxDecoration(
                        color: Color(colorNum).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      height: 75,
                      width: double.infinity,
                      child: Center(
                        child: Text(
                          dmbScreens[index].name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (context, index) => const Divider(
                color: Colors.transparent,
              ),
            ))
      ]),
    );
  }
}

PreferredSizeWidget _appBarBackBtn(
    BuildContext context, String title, String subTitle) {
  final double vw = MediaQuery.of(context).size.width / 100;
  final double vh = MediaQuery.of(context).size.height / 100;
  return PreferredSize(
    preferredSize: Size.fromHeight(vh * 11),
    child: AppBar(
      iconTheme: IconThemeData(
        color: Colors.white,
        size: vw * 8,
      ),
      backgroundColor: Colors.black.withValues(alpha: 0.8),
      automaticallyImplyLeading: true,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: vw * 6,
            ),
          ),
          Text(
            subTitle,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.white,
              fontSize: vw * 5.5,
            ),
          ),
        ],
      ),
      titleSpacing: vw * 4,
      toolbarHeight: vh * 12,
    ),
  );
}