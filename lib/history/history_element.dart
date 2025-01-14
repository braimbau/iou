import 'dart:convert';
import 'dart:ui';

import 'package:deed/cards/amount_card.dart';
import 'package:deed/classes/iou_transaction.dart';
import 'package:deed/classes/quick_pref.dart';
import 'package:deed/classes/user.dart';
import 'package:deed/utils/error.dart';
import 'package:deed/utils/user_list_preview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../Utils.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';



class HistoryElement extends StatefulWidget {
  final IouTransaction transaction;
  final IOUser usr;
  final String group;
  final List<IOUser> userList;

  HistoryElement({this.transaction, this.usr, this.group, this.userList});

  @override
  _HistoryElementState createState() => _HistoryElementState();
}

class _HistoryElementState extends State<HistoryElement> {
  bool isExpanded = false;
  bool listExpanded = false;

  @override
  Widget build(BuildContext context) {
    var date = DateTime.fromMillisecondsSinceEpoch(
        this.widget.transaction.getTimestamp());
    var formattedDate = DateFormat.yMMMd().add_Hm().format(date);
    String evo = (((this.widget.transaction.getBalanceEvo() > 0) ? "+" : "") +
        (this.widget.transaction.getBalanceEvo() / 100).toString());
    double displayedAmount = this.widget.transaction.getDisplayedAmount() / 100;

    IouTransaction transaction = this.widget.transaction;
    List<IOUser> userList = this.widget.userList;

    List<String> selectedString = transaction.getUsers().split(':');
    List<IOUser> selectedUsers = [];
    selectedString.forEach((el) {
      selectedUsers
          .add(userList.firstWhere((element) => element.getId() == el));
    });

    AppLocalizations t = AppLocalizations.of(context);

    return InkWell(
        onTap: () {
          setState(() {
            isExpanded = !isExpanded;
          });
        },
        child: Padding(
            padding: EdgeInsets.all(4.0),
            child: Column(children: [
              Text(
                  transaction.getLabel(),
                  overflow: (isExpanded) ? null : TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyText2),
              Row(children: [
                Text(formattedDate,
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.normal)),
                Expanded(child: Container()),
                Text(
                  evo,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: (transaction.getBalanceEvo() >= 0)
                          ? Colors.green
                          : Colors.red),
                ),
              ]),
              if (isExpanded)
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      t.payer + " " + userList.firstWhere((element) => element.getId() == transaction.getPayer()).getName(),
                      style: Theme.of(context).textTheme.bodyText1,
                    )),
              if (isExpanded)
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      t.totalAmount + displayedAmount.toString() + "€",
                      style: Theme.of(context).textTheme.bodyText1,
                    )),
              if (isExpanded &&
                  transaction.getUsers() != "" &&
                  transaction.getUsers() != null)
                InkWell(
                  onTap: () {
                    setState(() {
                      listExpanded = !listExpanded;
                    });
                  },
                  child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      semanticContainer: true,
                      elevation: 5,
                      color: Theme.of(context).appBarTheme.backgroundColor,
                      child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      t.receivers,
                                      style:
                                          Theme.of(context).textTheme.bodyText1,
                                    ),
                                  ),
                                  Icon((listExpanded) ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down)
                                ],
                              ),
                              if (listExpanded)
                                ListView.builder(
                                    shrinkWrap: true,
                                    padding: EdgeInsets.zero,
                                    itemCount: selectedUsers.length,
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                      return Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 15,
                                              backgroundColor: Theme.of(context)
                                                  .primaryColor,
                                              child: CircleAvatar(
                                                  radius: 13,
                                                  backgroundImage: NetworkImage(
                                                      selectedUsers[index]
                                                          .getUrl())),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 8),
                                              child: Text(selectedUsers[index]
                                                  .getName()),
                                            ),
                                          ],
                                        ),
                                      );
                                    })
                              else
                                Align(
                                    alignment: Alignment.centerLeft,
                                    child: UserListPreview(
                                      list: selectedUsers,
                                      maxLength: 10,
                                    )),
                            ],
                          ))),
                ),
              if (isExpanded && transaction.getActualAmount() > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                        onPressed: () {
                          Navigator.popUntil(
                              context, ModalRoute.withName('/mainPage'));
                          QuickPref pref = QuickPref(
                              this.widget.transaction.getLabel(),
                              this.widget.transaction.getUsers(),
                              this.widget.transaction.getDisplayedAmount(),
                              null,
                              null);
                          showDialog(
                            context: context,
                            builder: (BuildContext context) =>
                                _buildPopupDialog(context, this.widget.usr,
                                    pref, this.widget.group),
                          );
                        },
                        child: Row(
                          children: [Icon(Icons.repeat), Text(t.repeat)],
                        )),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(primary: Colors.red),
                      onPressed: () async {
                        if (await confirmRevert(context) == false) {
                          return;
                        }
                        IOUser payer =
                            await getUserById(transaction.getPayer());
                        String err = await runTransactionToUpdateBalances(
                            selectedUsers,
                            this.widget.group,
                            -transaction.getActualAmount(),
                            payer, t);
                        if (err == null) {
                          newTransaction(
                              -transaction.getDisplayedAmount(),
                              -transaction.getActualAmount(),
                              payer,
                              selectedUsers,
                              t.revertOf + transaction.getLabel(),
                              this.widget.group,
                              this.widget.usr.getId());
                        }
                        else {
                          displayError(t.err2, context);
                        }
                      },
                      child: Row(
                        children: [Icon(Icons.replay), Text(t.revert)],
                      ),
                    )
                  ],
                )
            ])));
  }

  Widget _buildPopupDialog(
      BuildContext context, IOUser usr, QuickPref pref, String group) {
    return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Wrap(children: <Widget>[
              AmountCard(
                currentUserId: usr.getId(),
                pref: pref,
                isPreFilled: true,
                group: group,
              )
            ])));
  }
}

Future<bool> confirmRevert(BuildContext context) async {
  return await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      AppLocalizations t = AppLocalizations.of(context);

      return AlertDialog(
        title: Text(t.revertTransaction, style: TextStyle(color: Colors.red),),
        content: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              Text(t.revertWarning1, style: Theme.of(context).textTheme.bodyText1,),
              Align(alignment: Alignment.centerLeft, child: Text(t.revertWarning2, style: Theme.of(context).textTheme.bodyText1,)),
              Align(alignment: Alignment.centerLeft, child: Text(t.revertWarning3, style: Theme.of(context).textTheme.bodyText1,)),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text(t.no),
            onPressed: () {
              Navigator.of(context).pop(false);
            },
          ),
          TextButton(
            child: Text(t.yes),
            onPressed: () async {
                Navigator.of(context).pop(true);
            },
          ),
        ],
      );
    },
  );
}