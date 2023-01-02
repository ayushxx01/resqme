import 'dart:developer';

import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:women_safety_app/services/contacts.dart';
import 'package:women_safety_app/services/database_methods.dart';

class SelectContact extends StatefulWidget {
  const SelectContact({super.key});

  @override
  State<SelectContact> createState() => _SelectContactState();
}

class _SelectContactState extends State<SelectContact> {
  DatabaseMethods databaseHelper = DatabaseMethods();
  List<Contact> contacts = [];
  List<Contact> contactsFiltered = [];
  Map<String, Color> contactsColorMap = {};
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    getContactsPermissions();
  }

  getContactsPermissions() async {
    try {
      if (!await Permission.contacts.isGranted) {
        final isGranted = await Permission.contacts.request().isGranted;
        if (!isGranted) {
          Fluttertoast.showToast(msg: "Please grant contacts permission to continue");
          return;
        }
      }
      if (await Permission.contacts.isGranted) {
        getAllContacts();
        searchController.addListener(() {
          filterContacts();
        });
      }
    } catch (e) {
      log(e.toString());
    }
  }

  String flattenPhoneNumber(String phoneStr) {
    return phoneStr.replaceAllMapped(RegExp(r'^(\+)|\D'), (Match m) {
      return m[0] == "+" ? "+" : "";
    });
  }

  getAllContacts() async {
    List colors = [Colors.green, Colors.indigo, Colors.yellow, Colors.orange];
    int colorIndex = 0;
    List<Contact> contactList = (await ContactsService.getContacts(withThumbnails: false)).toList();
    for (var contact in contactList) {
      Color baseColor = colors[colorIndex];
      String contactName = contact.displayName ?? "";
      contactsColorMap[contactName] = baseColor;
      colorIndex++;
      if (colorIndex == colors.length) colorIndex = 0;
    }
    if (!mounted) {
      return;
    } else {
      setState(() {
        contacts = contactList;
      });
    }
  }

  filterContacts() {
    List<Contact> contactList = [];
    contactList.addAll(contacts);
    if (searchController.text.isNotEmpty) {
      contactList.retainWhere((contact) {
        String searchTerm = searchController.text.toLowerCase();
        String searchTermFlatten = flattenPhoneNumber(searchTerm);
        String contactName = contact.displayName ?? "";
        bool nameMatches = contactName.toLowerCase().contains(searchTerm);

        if (nameMatches == true) return true;
        if (searchTermFlatten.isEmpty) return false;

        Item? phone = contact.phones?.firstWhere((phn) {
          String phnFlattened = flattenPhoneNumber(phn.value ?? "");
          return phnFlattened.contains(searchTermFlatten);
        });

        return phone != null;
      });
    }
    setState(() {
      contactsFiltered = contactList;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isSearching = searchController.text.isNotEmpty;
    bool listItemsExist = (contactsFiltered.isNotEmpty || contacts.isNotEmpty);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Select a Contact",
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(
          color: Colors.black, //change your color here
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            TextField(
              autofocus: true,
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Search',
                border: OutlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).primaryColor)),
                prefixIcon: Icon(Icons.search, color: Theme.of(context).primaryColor),
              ),
            ),
            listItemsExist == true
                ? Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: isSearching == true ? contactsFiltered.length : contacts.length,
                      itemBuilder: (context, index) {
                        Contact contact =
                            isSearching == true ? contactsFiltered[index] : contacts[index];

                        var baseColor = contactsColorMap[contact.displayName] as dynamic;

                        Color color1 = baseColor[800];
                        Color color2 = baseColor[400];
                        return ListTile(
                          title: Text(contact.displayName ?? ""),
                          subtitle: Text(() {
                            List<Item>? phones = contact.phones;
                            if (phones != null && phones.isNotEmpty) {
                              return contact.phones?.elementAt(0).value ?? "";
                            } else {
                              return "No phone number";
                            }
                          }()),
                          // leading: (contact.avatar != null && contact.avatar.isNotEmpty)
                          //     ? CircleAvatar(backgroundImage: MemoryImage(contact.avatar))
                          //     : Container(
                          //         decoration: BoxDecoration(
                          //           shape: BoxShape.circle,
                          //           gradient: LinearGradient(
                          //             colors: [color1, color2],
                          //             begin: Alignment.bottomLeft,
                          //             end: Alignment.topRight,
                          //           ),
                          //         ),
                          //         child: CircleAvatar(
                          //           backgroundColor: Colors.transparent,
                          //           child: Text(
                          //             contact.initials(),
                          //             style: const TextStyle(
                          //               color: Colors.white,
                          //             ),
                          //           ),
                          //         ),
                          //       ),
                          leading: () {
                            final avatar = contact.avatar;
                            if (avatar != null && avatar.isNotEmpty) {
                              return CircleAvatar(backgroundImage: MemoryImage(avatar));
                            } else {
                              return Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [color1, color2],
                                    begin: Alignment.bottomLeft,
                                    end: Alignment.topRight,
                                  ),
                                ),
                                child: CircleAvatar(
                                  backgroundColor: Colors.transparent,
                                  child: Text(
                                    contact.initials(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              );
                            }
                          }(),
                          onTap: () {
                            List<Item>? phones = contact.phones;
                            if (phones != null && phones.isNotEmpty) {
                              final String phoneNum = phones.elementAt(0).value ?? "";
                              final String name = contact.displayName ?? "";
                              _addContact(TContact(phoneNum, name));
                            } else {
                              Fluttertoast.showToast(
                                msg: "Oops! Phone number of this contact does not exist!",
                              );
                            }
                          },
                        );
                      },
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      isSearching ? 'No search results to show' : 'No contacts found yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  )
          ],
        ),
      ),
    );
  }

  void moveToLastScreen() {
    Navigator.pop(context, true);
  }

  void _addContact(TContact newContact) async {
    int result = await databaseHelper.insertContact(newContact);
    if (result != 0) {
      log('Contact added Successfully');
    } else {
      log('add Contact Failed');
      Fluttertoast.showToast(msg: "Failed to Add Contact");
    }
    moveToLastScreen();
  }
}
