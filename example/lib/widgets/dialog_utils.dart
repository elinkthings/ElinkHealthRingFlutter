import 'package:flutter/material.dart';

void showListDialog<T>({
  required BuildContext context,
  required List<T> dataList,
  required String title,
  required Function(T, int) onSelected,
  String? unit = '',
}) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: dataList.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text("${dataList[index]} $unit"),
                onTap: () {
                  Navigator.pop(context);
                  onSelected(dataList[index], index);
                },
              );
            },
            separatorBuilder: (context, index) {
              return const Divider();
            },
          ),
        ),
      );
    },
  );
}
