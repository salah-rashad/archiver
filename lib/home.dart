import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:directory_picker/directory_picker.dart';
import "package:flutter/material.dart";
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart' as Intl;
import 'package:open_file/open_file.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  TextEditingController pathController = new TextEditingController();
  List<FileSystemEntity> files;
  Directory folderToCompress;
  String folderSize;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text("Archiver"),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 32),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height - kToolbarHeight - 30,
          ),
          child: Column(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "Choose folder:",
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      onTap: choose,
                      controller: pathController,
                      maxLines: 1,
                      readOnly: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    SizedBox(height: 32),
                    folderSize != null
                        ? Text("Size: $folderSize")
                        : Container(),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Expanded(
                child: Container(
                  color: Colors.black12,
                  child: folderToCompress != null
                      ? ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          itemCount: folderToCompress.listSync().length,
                          itemBuilder: (context, i) {
                            List<FileSystemEntity> subs =
                                folderToCompress.listSync();

                            subs.sort((a, b) => a.path
                                .replaceAll(folderToCompress.path + "/", "")
                                .compareTo(b.path.replaceAll(
                                    folderToCompress.path + "/", "")));

                            return ListTile(
                              contentPadding: EdgeInsets.all(0),
                              leading: Directory(subs[i].path).existsSync()
                                  ? Icon(Icons.folder)
                                  : Icon(Icons.insert_drive_file),
                              title: Text(
                                subs[i].path.replaceAll(
                                    folderToCompress.path + "/", ""),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14),
                              ),
                              trailing: Text(getSize(subs[i].path) ?? "- -"),
                            );
                          })
                      : Container(),
                ),
              ),
              SizedBox(height: 16),
              Center(
                child: RaisedButton(
                  onPressed: folderToCompress != null ? compress : null,
                  child: Text(
                    "Archive".toUpperCase(),
                    style: TextStyle(fontSize: 18),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void choose() async {
    // open directory picker
    Directory folder = await DirectoryPicker.pick(
      context: context,
      rootDirectory: Directory(folderToCompress?.path ?? "../sdcard"),
    ).catchError((e) => print(e));

    setState(() {
      pathController.text = folder?.path;
      folderToCompress = folder;
      folderSize = getSize(folder?.path);
    });
  }

  // get size of a specific file or folder
  String getSize(String path) {
    // final size
    num size = 0;

    // checking if this is a file or folder
    if (Directory(path).existsSync()) {

      // list of files & sub-folders
      List<FileSystemEntity> list =
          Directory(path).listSync(recursive: true, followLinks: true);

      list.forEach((FileSystemEntity entity) {
        // add size to the final size
        size += entity.statSync().size;
      });
    } else {
      // add size to the final size
      size += File(path).statSync().size;
    }

    // shotening the size ex: 80.145232 to 80.14
    void shorten() {
      if (size is double) {
        List<String> s = size.toString().split(".");
        if (s[1].length > 2)
          size = double.parse(s[0] + "." + s[1].substring(0, 2));
        else
          return;
      }
    }

    // bytes
    int kb = 1000;
    int mb = 1000000;
    int gb = 1000000000;

    if (size >= kb && size < mb) {
      size = size / kb;
      shorten();
      return "$size KB";
    } else if (size >= mb && size < gb) {
      size = size / mb;
      shorten();
      return "$size MB";
    } else if (size >= gb) {
      size = size / gb;
      shorten();
      return "$size GB";
    } else
      return "$size Bytes";
  }

  void compress() async {
    // date & time of compression
    var now = Intl.DateFormat("yyyy-MM-dd_HH:mm").format(DateTime.now());
    var encoder = ZipFileEncoder();
    // progress of compression
    int progress = 0;

    // encoder.zipDirectory(Directory(folderPath),
    //     filename: folderToCompress.path + "_" + now + ".zip");

    // list of files to compress
    files = folderToCompress.listSync();

    try {
      // creating empty ZIP file
      encoder.create(folderToCompress.path + "_" + now + ".zip");

      for (FileSystemEntity file in files) {
        /// checking if [file] is file or folder
        if (file is! File) {
          // add folder to that ZIP file
          encoder.addDirectory(file);
        } else {
          // add file to that ZIP file
          encoder.addFile(file);
        }

        setState(() {
          // update progress
          progress++;
        });

        print(progress);

        // show toast of the progress in percentage
        Fluttertoast.showToast(
            msg: ((progress / files.length) * 100).floor().toString() + "%",
            fontSize: 22,
            backgroundColor: Theme.of(context).backgroundColor,
            textColor: Theme.of(context).primaryColor,
            gravity: ToastGravity.CENTER,
            toastLength: Toast.LENGTH_LONG);

        if (progress == files.length) {
          // closing the encoder if done
          encoder.close();
          // show done dialog
          showDoneDialog(encoder);
        }
      }
    } catch (e) {
      print(e);
    }
  }

  void showDoneDialog(ZipFileEncoder encoder) {
    showDialog(
      context: (context),
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Center(
              child: Text(
                "Compression Done Successfully!",
                style: TextStyle(fontSize: 18),
              ),
            ),
            SizedBox(height: 16),
            Text(
              "Location:\n" + encoder.zip_path,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: <Widget>[
          FlatButton(
              onPressed: () => Navigator.pop(context), child: Text("Close")),
          FlatButton(
              onPressed: () => OpenFile.open(encoder.zip_path,
                          type: "application/x-zip-compressed")
                      .then((r) {
                    if (r.type == ResultType.done)
                      return;
                    else
                      Fluttertoast.showToast(msg: r.message);
                  }),
              textColor: Theme.of(context).primaryColor,
              child: Text("Open")),
        ],
      ),
    );
  }
}
